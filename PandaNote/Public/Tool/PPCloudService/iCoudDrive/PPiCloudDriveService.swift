//
//  PPiCloudDriveService.swift
//  PandaNote
//
//  Created by Panway on 2023/7/23.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

/// iCloud Drive 读写实现，全部基于系统框架，不再依赖 FilesProvider。
/// 三件事分别交给三个系统 API：定位容器用 FileManager，列目录用 NSMetadataQuery，读写删用 FileManager + NSFileCoordinator。
/// 为什么列目录不用 FileManager：只存在云上、本地还没下载的文件，FileManager 只能看到一个「.文件名.icloud」占位符，名字、大小、修改时间全是错的；NSMetadataQuery 读的是元数据，云上文件也能正确列出来。
class PPiCloudDriveService: NSObject, PPCloudServiceProtocol {

    var url = ""
    var baseURL: String {
        return url
    }

    /// ubiquity 容器 ID。传空串表示用 entitlements 里的第一个容器
    private let containerId: String
    /// 解析好的容器 Documents 目录。只在 resolveQueue 上读写，避免多个请求同时问系统要地址
    private var cachedRootURL: URL?
    /// 只负责「解析容器地址」这一件事。FileManager.url(forUbiquityContainerIdentifier:) 首次调用可能很慢，苹果明确要求别放主线程
    private let resolveQueue = DispatchQueue(label: "PPiCloudDrive.resolve")
    /// 文件读写队列。用并发而不是串行，否则下载一个大图会把整个列表的刷新堵在后面
    private let ioQueue = DispatchQueue(label: "PPiCloudDrive.io", qos: .userInitiated, attributes: .concurrent)

    /// 列目录时要向系统要的元数据字段，查询和解析两边必须用同一份，少一个字段解析出来就是空值
    private static let metadataAttributes = [
        NSMetadataItemURLKey,
        NSMetadataItemFSNameKey,
        NSMetadataItemPathKey,
        NSMetadataItemFSSizeKey,
        NSMetadataItemContentTypeTreeKey,
        NSMetadataItemFSContentChangeDateKey,
    ]

    init(containerId: String) {
        self.containerId = containerId
        super.init()
    }

    /// 添加配置前先问一句「现在能不能用」。
    /// 两件事都要查：系统里有没有登录 iCloud、能不能拿到容器。只查第一个不够，没签 iCloud 权限的包账号是正常的，但容器一定是 nil，配置加进去只会得到一个空列表。
    /// 返回 nil 表示可用，否则返回一句能直接弹给用户看的原因
    static func unavailableReason(containerId: String, completion: @escaping (String?) -> Void) {
        // ubiquityIdentityToken 和 url(forUbiquityContainerIdentifier:) 第一次访问都要等系统去查账号 / 建容器，可能卡一下，所以放到后台队列，别堵主线程
        DispatchQueue.global(qos: .userInitiated).async {
            let manager = FileManager.default
            var reason: String?
            if manager.ubiquityIdentityToken == nil {
                reason = "没有检测到 iCloud 账号：可能是系统里没登录 Apple ID，或者没打开 iCloud 云盘"
            }
            else if manager.url(forUbiquityContainerIdentifier: containerId) == nil,
                    manager.url(forUbiquityContainerIdentifier: nil) == nil {
                reason = "拿不到 iCloud 容器：可能是安装包没有开启 iCloud 能力（entitlements 里要有 ubiquity-container-identifiers，并用带 iCloud 权限的证书签名），也可能是系统设置里关掉了这个 App 的 iCloud 云盘开关"
            }
            DispatchQueue.main.async {
                completion(reason)
            }
        }
    }

    // MARK: - 容器与路径

    /// 统一的执行外壳：后台队列里拿到容器根目录、干活、回主线程回调。
    /// 所有文件操作都从这里进，保证没人在主线程碰 ubiquity 容器
    private func perform<T>(_ work: @escaping (URL) throws -> T, completion: @escaping (T?, Error?) -> Void) {
        ioQueue.async {
            do {
                let root = try self.rootURL()
                let value = try work(root)
                DispatchQueue.main.async {
                    completion(value, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    /// 取容器里的 Documents 目录并缓存。
    /// 只能在后台队列上调，内部用 resolveQueue.sync 保证并发进来时也只解析一次
    private func rootURL() throws -> URL {
        var result: Result<URL, Error>?
        resolveQueue.sync {
            if let root = self.cachedRootURL {
                result = .success(root)
                return
            }
            do {
                let root = try self.resolveRootURL()
                self.cachedRootURL = root
                result = .success(root)
            } catch {
                // 失败不缓存：用户可能刚去系统设置里登录了 iCloud，下一次请求应该能自己恢复，不该逼人重装 App
                result = .failure(error)
            }
        }
        guard let resolved = result else {
            throw CloudDriveError.unknown("iCloud 容器解析失败")
        }
        return try resolved.get()
    }

    /// 真正去问系统要容器地址
    private func resolveRootURL() throws -> URL {
        let manager = FileManager.default
        // 没登录 iCloud 时后面每一步都会失败，先给一句人话，别让用户对着「文件不存在」猜
        guard manager.ubiquityIdentityToken != nil else {
            throw CloudDriveError.notAuthenticated
        }
        // 配置里的容器 ID 和 entitlements 对不上时系统返回 nil，回落到「entitlements 里的第一个容器」，这样改过 container id 的老配置不用重装也能用
        var containerURL = manager.url(forUbiquityContainerIdentifier: containerId.isEmpty ? nil : containerId)
        if containerURL == nil {
            containerURL = manager.url(forUbiquityContainerIdentifier: nil)
        }
        guard let container = containerURL else {
            throw CloudDriveError.unknown("App 未开启 iCloud 容器，请检查 entitlements 里的 ubiquity-container-identifiers")
        }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        // 全新安装时 Documents 还不存在，先建出来，否则列目录会直接报文件不存在
        try manager.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }

    /// 业务层的 path 是相对容器的（列表里拿到的都不带前导斜杠），但新建、移动的调用方有时会拼出 "/a/b"，这里统一吃掉开头的斜杠，免得 appendingPathComponent 拼出 "//a/b"
    private func fileURL(for path: String, root: URL) -> URL {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasPrefix("/") {
            clean.removeFirst()
        }
        if clean.isEmpty {
            return root
        }
        return root.appendingPathComponent(clean)
    }

    /// 从绝对 URL 还原业务层要的相对路径。
    /// 列表里存的 path 必须是相对的，写死绝对路径等于把沙盒目录结构存进缓存，App 一升级就全失效。
    /// 返回值一定要带前导斜杠，跟 WebDAV / OneDrive 保持同一种格式：缓存 key 是「备注 + path」直接拼字符串，少了斜杠会拼成 iClouda.jpg，而读缓存拼的是「备注 + / + path」，写和读落在两个位置，表现就是列表能看、点开图片打不开
    private func relativePath(of url: URL, root: URL) -> String {
        let base = root.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        guard full.hasPrefix(base) else {
            return "/" + url.lastPathComponent
        }
        var relative = String(full.dropFirst(base.count))
        // 统一收敛成「一个前导斜杠」，多出来的先削掉再由下面补一个，免得出现 // 或空串
        while relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return "/" + relative
    }

    // MARK: - 文件列表

    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping (_ data: [PPFileObject], _ error: Error?) -> Void) {
        ioQueue.async {
            do {
                let root = try self.rootURL()
                let dirURL = self.fileURL(for: path, root: root)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    throw CloudDriveError.fileNotFound(path)
                }
                self.listDirectory(at: dirURL, root: root) { files in
                    DispatchQueue.main.async {
                        completion(files, nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }

    /// 用 NSMetadataQuery 列一层目录。
    /// 它是「实时查询」，start 之后要等系统把结果收齐再发通知，所以结果只能通过一次性回调交出去，没法同步返回
    private func listDirectory(at dirURL: URL, root: URL, completion: @escaping ([PPFileObject]) -> Void) {
        let query = NSMetadataQuery()
        // 先用路径前缀粗筛，再在解析时只留直接子项，不然会把整棵子树的文件都捞回来
        query.predicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, dirURL.path)
        query.valueListAttributes = Self.metadataAttributes
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        // 下面这几个回调都只在主线程执行，用 finished 挡住重复回调（通知和超时可能同时到）
        var observer: NSObjectProtocol?
        var finished = false
        let finish: ([PPFileObject]) -> Void = { files in
            if finished {
                return
            }
            finished = true
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            query.disableUpdates()
            query.stop()
            completion(files)
        }

        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
            query.disableUpdates()
            finish(self.parseItems(of: query, in: dirURL, root: root))
        }
        // 兜底：查询启动失败或者 iCloud 守护进程迟迟不收尾时，不能让列表一直转圈，超时就当空目录处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            finish([])
        }
        DispatchQueue.main.async {
            if query.start() == false {
                finish([])
            }
        }
    }

    /// NSMetadataItem 转成列表模型，字段口径和以前 FilesProvider 的转换保持一致
    private func parseItems(of query: NSMetadataQuery, in dirURL: URL, root: URL) -> [PPFileObject] {
        let parentPath = dirURL.standardizedFileURL.path
        var files = [PPFileObject]()
        for case let item as NSMetadataItem in query.results {
            let attributes = item.values(forAttributes: Self.metadataAttributes) ?? [:]
            guard let url = (attributes[NSMetadataItemURLKey] as? URL)?.standardizedFileURL else {
                continue
            }
            // 前缀匹配会把子目录里的东西也带出来，这里只留直接子项
            if url.deletingLastPathComponent().path != parentPath {
                continue
            }
            let file = PPFileObject()
            file.name = (attributes[NSMetadataItemFSNameKey] as? String) ?? url.lastPathComponent
            file.path = relativePath(of: url, root: root)
            file.size = (attributes[NSMetadataItemFSSizeKey] as? NSNumber)?.int64Value ?? 0
            file.modifiedDate = (attributes[NSMetadataItemFSContentChangeDateKey] as? Date)?.toString() ?? ""
            let contentTypeTree = attributes[NSMetadataItemContentTypeTreeKey] as? [String] ?? []
            file.isDirectory = contentTypeTree.contains("public.folder")
            files.append(file)
        }
        // 文件夹排前面，同类按名字排，和其它云盘的列表顺序保持一致
        files.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return files
    }

    // MARK: - 文件内容

    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (Data?, String, Error?) -> Void) {
        perform({ root -> Data in
            let target = self.fileURL(for: path, root: root)
            try self.ensureDownloaded(target)
            return try self.readData(at: target)
        }) { data, error in
            completion(data, "", error)
        }
    }

    /// 未下载文件在本地的占位符地址。只在云上、还没拉下来的文件，磁盘上只有 `.<文件名>.icloud` 这样一个隐藏文件，真正的文件名根本不存在。判断「文件在不在」必须看这个占位符，光看真实路径会把「在云上」误判成「被删了」
    private func placeholderURL(for fileURL: URL) -> URL {
        let name = "." + fileURL.lastPathComponent + ".icloud"
        return fileURL.deletingLastPathComponent().appendingPathComponent(name)
    }

    /// 文件只在云上、本地没下载时直接读会报「文件不存在」。这里先让 iCloud 拉下来，再等占位符换成真实文件。
    /// 等不到必须抛错，不能静默往下走：后面读文件只会得到一个含糊的系统错误，看不出是「网络慢」还是「文件没了」
    private func ensureDownloaded(_ fileURL: URL) throws {
        let manager = FileManager.default
        let placeholder = placeholderURL(for: fileURL)
        let realExists = manager.fileExists(atPath: fileURL.path)
        let placeholderExists = manager.fileExists(atPath: placeholder.path)

        // 本地有实体文件、也没有占位符，还得再看一眼下载状态：macOS 上的 dataless 文件名字在、内容其实还没下来
        if realExists && !placeholderExists {
            let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
            let status = (try? fileURL.resourceValues(forKeys: keys))?.ubiquitousItemDownloadingStatus
            // 拿不到状态说明不是 iCloud 管理的文件，直接用
            if status == nil || status == .current || status == .downloaded {
                return
            }
        }
        // 真实文件和占位符都不在，才是文件真没了（比如在别的设备上删掉，本机还没同步到）
        guard realExists || placeholderExists else {
            throw CloudDriveError.fileNotFound(fileURL.lastPathComponent)
        }
        // 已经在下载时重复调会报错，这里忽略即可，下面的轮询会等到最终结果
        try? manager.startDownloadingUbiquitousItem(at: fileURL)

        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
        // 大图加上慢网络可能要几十秒，给足 60 秒；再长用户也会以为卡死，不如早点报错让人重试
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            // 主判据：占位符消失了，真实文件出现了
            if manager.fileExists(atPath: fileURL.path), manager.fileExists(atPath: placeholder.path) == false {
                return
            }
            // 兜底判据：万一系统改了占位符命名规则，用下载状态也能认出来
            if manager.fileExists(atPath: fileURL.path),
               let status = (try? fileURL.resourceValues(forKeys: keys))?.ubiquitousItemDownloadingStatus,
               status == .current || status == .downloaded {
                return
            }
            // 每 0.2 秒查一次够了，查太密只是白烧 CPU
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw CloudDriveError.downloadFailed("iCloud 下载超时，请检查网络后重试：\(fileURL.lastPathComponent)")
    }

    /// 读文件内容。走一遍读协调，避免正巧 iCloud 在同步同一个文件时读到半截内容
    private func readData(at fileURL: URL) throws -> Data {
        var coordinatorError: NSError?
        var readError: Error?
        var result: Data?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &coordinatorError) { url in
            do {
                result = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }
        if let error = coordinatorError {
            throw error
        }
        if let error = readError {
            throw error
        }
        guard let data = result else {
            throw CloudDriveError.downloadFailed(fileURL.lastPathComponent)
        }
        return data
    }

    // MARK: - 增删改

    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        perform({ root -> Void in
            let parent = self.fileURL(for: atPath, root: root)
            let target = parent.appendingPathComponent(folderName)
            try self.coordinateWriting(at: target, options: .forReplacing) { url in
                // withIntermediateDirectories 开着，调用方传了多级目录也能一次建完
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }) { _, error in
            completion(error)
        }
    }

    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping ([String : String]?, Error?) -> Void) {
        perform({ root -> Void in
            let target = self.fileURL(for: path, root: root)
            // 有些调用方（比如按年月分目录存笔记）不会先建目录，这里补一下，省得写入报文件不存在
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try self.coordinateWriting(at: target, options: .forReplacing) { url in
                // .atomic 先写临时文件再替换，避免写一半被系统杀掉留下半个文件
                try contents.write(to: url, options: .atomic)
            }
        }) { _, error in
            completion(nil, error)
        }
    }

    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (Error?) -> Void) {
        perform({ root -> Void in
            let source = self.fileURL(for: srcPath, root: root)
            let destination = self.fileURL(for: destPath, root: root)
            try self.coordinateMove(from: source, to: destination)
        }) { _, error in
            completion(error)
        }
    }

    func removeItem(_ path: String, _ fileID: String, completion: @escaping (Error?) -> Void) {
        perform({ root -> Void in
            let target = self.fileURL(for: path, root: root)
            try self.coordinateWriting(at: target, options: .forDeleting) { url in
                try FileManager.default.removeItem(at: url)
            }
        }) { _, error in
            completion(error)
        }
    }

    // MARK: - 文件协调

    /// 单文件写协调的通用外壳。
    /// 一定要用 accessor 回调里给的新 URL，不能拿外面那个：协调器可能把写入重定向到临时文件，用老 URL 写等于绕过了协调
    private func coordinateWriting(at url: URL, options: NSFileCoordinator.WritingOptions, change: @escaping (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var changeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinatorError) { newURL in
            do {
                try change(newURL)
            } catch {
                changeError = error
            }
        }
        if let error = coordinatorError {
            throw error
        }
        if let error = changeError {
            throw error
        }
    }

    /// 移动/重命名。源和目标要一起进协调，中间还得告诉协调器「开始挪」「挪完了」，否则别的进程（包括 iCloud 守护进程）可能在半路读到不一致的状态
    private func coordinateMove(from source: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: source, options: .forMoving,
                               writingItemAt: destination, options: .forReplacing,
                               error: &coordinatorError) { newSource, newDestination in
            do {
                coordinator.item(at: newSource, willMoveTo: newDestination)
                try FileManager.default.moveItem(at: newSource, to: newDestination)
                coordinator.item(at: newSource, didMoveTo: newDestination)
            } catch {
                moveError = error
            }
        }
        if let error = coordinatorError {
            throw error
        }
        if let error = moveError {
            throw error
        }
    }
}
