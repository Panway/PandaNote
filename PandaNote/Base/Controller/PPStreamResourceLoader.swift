//
//  PPStreamResourceLoader.swift
//  PandaNote
//
//  作用：让 AVPlayer 播放网络视频时可以带上自定义请求头（比如 WebDAV 的认证头），
//  并且边缓冲边播放，同时把下载到的数据顺手存成本地缓存文件，下次直接本地秒开。
//
//  为什么需要这个类：
//  AVPlayer 自己发 HTTP 请求时，苹果没有公开 API 能让我们塞自定义请求头
//  （AVURLAssetHTTPHeaderFieldsKey 是私有 API，上架会被拒）。
//  官方留的唯一口子是 AVAssetResourceLoaderDelegate，思路是"骗"AVPlayer：
//  把 URL 的协议名改成它不认识的假名字（https://... -> ppstream-https://...），
//  AVPlayer 不知道怎么下载，就会回头找我们要数据；
//  我们再用 URLSession 带上请求头去真正下载，把收到的数据一段段交还给 AVPlayer。
//  AVPlayer 拿到开头的数据就开始播，后面的边下边播，这就是"边缓冲边播放"。
//
//  缓存怎么做：
//  每收到一段数据，除了交给 AVPlayer，还按它在文件里的真实位置（字节偏移）
//  写进一个 ".part" 临时文件。全部字节都写齐了，就把 ".part" 改名成正式缓存文件。
//  按偏移写而不是顺序追加，是因为 AVPlayer 有时会先取文件末尾（比如 mp4 的元数据在尾部），
//  顺序追加会写乱；按偏移写无论数据什么顺序到，都能拼出完整正确的文件。
//

import Foundation
import AVFoundation
import MobileCoreServices

class PPStreamResourceLoader: NSObject {

    /// 每个 HTTP 请求都要附加的自定义请求头
    private let headers: [String: String]

    /// 负责真正下载的 URLSession，回调走下面的 URLSessionDataDelegate 方法。
    /// 用 lazy 是因为创建时要传 self 当 delegate，得等 init 跑完才允许引用 self。
    /// 注意：URLSession 会强引用 delegate，用完必须调 shutdown() 解除，否则本对象永远不会释放
    private lazy var session: URLSession = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1 // 网络回调串行执行，逻辑更简单
        return URLSession(configuration: .default, delegate: self, delegateQueue: queue)
    }()

    /// 假协议前缀。AVPlayer 看到不认识的协议才会来找我们要数据
    private static let schemePrefix = "ppstream-"

    /// 记录"哪个下载任务对应 AVPlayer 的哪个要数据的请求"。
    /// AVPlayer 可能同时要好几段数据（比如用户拖了进度条），所以用字典一一对应。
    private var pending: [URLSessionTask: AVAssetResourceLoadingRequest] = [:]

    /// pending / taskStartOffset 会被两个队列访问（AVPlayer 的回调队列 + URLSession 的回调队列），
    /// 用锁保证同一时刻只有一个线程在改它们，避免数据竞争
    private let lock = NSLock()

    // MARK: - 边播边缓存相关（除 taskStartOffset 外，只在串行的网络回调队列上读写，无需额外加锁）

    /// 正式缓存文件的最终位置；nil 表示这次不缓存
    private let cacheFileURL: URL?
    /// 正在写入的临时文件（cacheFileURL + ".part"），写完整了再改名成正式文件
    private var cachePartURL: URL?
    private var cacheHandle: FileHandle?
    /// 文件总大小，从服务器响应里得到；0 表示还不知道
    private var expectedSize: Int64 = 0
    /// 已经写进缓存的字节区间（按起点升序、互不重叠）。
    /// 为什么要记区间而不是简单累加：AVPlayer 会发重叠的请求
    /// （比如先探测开头 2 字节，再从头下整个文件；取消后又从中间某处重新要），
    /// 简单累加会把重复下载的字节数两遍，导致缓存"看起来写齐了"实际缺尾巴。
    /// 区间合并后统计的才是真正写进文件的不同字节数
    private var coveredRanges: [(start: Int64, end: Int64)] = []
    /// coveredRanges 覆盖的字节总数，凑够 expectedSize 就说明缓存完整了
    private var coveredBytes: Int64 = 0
    /// 每个下载任务"要数据时的起始偏移"，用来算这段数据在文件里的真实位置（建任务在另一个队列，故加锁读写）
    private var taskStartOffset: [URLSessionTask: Int64] = [:]
    /// 每个下载任务已经收到多少字节（只在网络回调队列读写）
    private var taskReceived: [URLSessionTask: Int64] = [:]
    /// 缓存是否已完成（改名成功），完成后不再重复处理
    private var cacheDone = false

    /// - Parameter cacheFileURL: 想把边播的数据缓存到哪里；传 nil 就只播不缓存
    init(headers: [String: String], cacheFileURL: URL? = nil) {
        self.headers = headers
        self.cacheFileURL = cacheFileURL
        super.init()
    }

    /// 播放结束或页面销毁时调用：停掉所有下载、关闭缓存文件、解除 URLSession 对本对象的强引用，
    /// 否则本对象（连同里面的下载任务）会一直留在内存里
    func shutdown() {
        session.invalidateAndCancel()
        lock.lock()
        let requests = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for request in requests {
            request.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))
        }
        // 没缓存完就删掉半成品 .part，避免留下损坏文件被误当成有效缓存
        closeCacheFile(commit: false)
    }

    // MARK: - 缓存写入（只在网络回调队列上调用）

    /// 把一段数据写到 .part 文件的指定偏移处
    private func writeCache(_ data: Data, atOffset offset: Int64) {
        guard let finalURL = cacheFileURL, !cacheDone else { return }

        // 第一次写：建好目录和 .part 空文件，打开写入句柄
        if cacheHandle == nil {
            let partURL = URL(fileURLWithPath: finalURL.path + ".part")
            try? FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: partURL.path) {
                FileManager.default.createFile(atPath: partURL.path, contents: nil)
            }
            cacheHandle = try? FileHandle(forWritingTo: partURL)
            cachePartURL = partURL
        }
        guard let handle = cacheHandle else { return }

        // 按真实偏移写：先移动到该位置再写，数据乱序到达也能拼出完整文件
        let writeOffset = max(0, offset)
        handle.seek(toFileOffset: UInt64(writeOffset))
        handle.write(data)
        markCovered(writeOffset, writeOffset + Int64(data.count))

        // 字节写齐了就把 .part 转正为正式缓存文件
        if expectedSize > 0 && coveredBytes >= expectedSize {
            closeCacheFile(commit: true)
        }
    }

    /// 把新写入的 [start, end) 记进区间表：和已有区间重叠的部分合并成一段，
    /// 然后重新统计"真正写进文件的不同字节数"
    private func markCovered(_ start: Int64, _ end: Int64) {
        guard end > start else { return }
        var newStart = start
        var newEnd = end
        var kept: [(start: Int64, end: Int64)] = []
        for range in coveredRanges {
            if range.end < newStart || range.start > newEnd {
                kept.append(range) // 和新段不挨着，原样保留
            } else {
                // 有重叠或首尾相接，并进新段
                newStart = min(newStart, range.start)
                newEnd = max(newEnd, range.end)
            }
        }
        kept.append((newStart, newEnd))
        kept.sort { $0.start < $1.start }
        coveredRanges = kept
        coveredBytes = kept.reduce(0) { $0 + ($1.end - $1.start) }
    }

    /// 关闭缓存文件。commit=true 表示缓存完整、改名成正式文件；false 表示放弃、删掉半成品
    private func closeCacheFile(commit: Bool) {
        guard let handle = cacheHandle else { return }
        try? handle.close()
        cacheHandle = nil
        guard let partURL = cachePartURL, let finalURL = cacheFileURL else { return }
        cachePartURL = nil

        if commit {
            try? FileManager.default.removeItem(at: finalURL) // 防止目标已存在导致改名失败
            do {
                try FileManager.default.moveItem(at: partURL, to: finalURL)
                cacheDone = true
                debugPrint("边播边缓存完成：\(finalURL.path)")
            } catch {
                debugPrint("缓存改名失败：\(error.localizedDescription)")
                try? FileManager.default.removeItem(at: partURL)
            }
        } else if !cacheDone {
            try? FileManager.default.removeItem(at: partURL)
        }
    }

    /// 把真实 URL（https://...）换成假协议 URL（ppstream-https://...）。
    /// PlayerViewController 用假 URL 创建 AVURLAsset，AVPlayer 就会来找我们要数据。
    static func fakeSchemeURL(for realURL: URL) -> URL? {
        guard var comps = URLComponents(url: realURL, resolvingAgainstBaseURL: false),
              let scheme = comps.scheme else { return nil }
        comps.scheme = schemePrefix + scheme
        return comps.url
    }

    /// 反向操作：把假协议 URL 还原成真实 URL
    private static func realURL(from fakeURL: URL) -> URL? {
        guard var comps = URLComponents(url: fakeURL, resolvingAgainstBaseURL: false),
              let scheme = comps.scheme, scheme.hasPrefix(schemePrefix) else { return nil }
        comps.scheme = String(scheme.dropFirst(schemePrefix.count))
        return comps.url
    }

    /// 查字典：这个下载任务对应哪个要数据的请求
    private func loadingRequest(for task: URLSessionTask) -> AVAssetResourceLoadingRequest? {
        lock.lock()
        let request = pending[task]
        lock.unlock()
        return request
    }
}

// MARK: - AVPlayer 来要数据时走这里

extension PPStreamResourceLoader: AVAssetResourceLoaderDelegate {

    /// AVPlayer："我缺一段数据，你去弄来。"
    /// 返回 true 表示"这个请求我接了"，之后必须调用 finishLoading 告诉它结束。
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let fakeURL = loadingRequest.request.url,
              let realURL = Self.realURL(from: fakeURL) else {
            return false // 不是我们的假协议 URL，不接
        }

        // 组装真正的 HTTP 请求：真实地址 + 自定义请求头
        var request = URLRequest(url: realURL)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // AVPlayer 说的是"我要从第 offset 字节开始的 length 个字节"，
        // 翻译成 HTTP 的 Range 请求头，服务器就只发这一段，不用发整个文件。
        // length 是负数时表示"从 offset 一直到文件结尾"。
        var startOffset: Int64 = 0
        if let dataRequest = loadingRequest.dataRequest {
            startOffset = dataRequest.requestedOffset
            let length = dataRequest.requestedLength
            if length > 0 {
                request.setValue("bytes=\(startOffset)-\(startOffset + Int64(length) - 1)", forHTTPHeaderField: "Range")
            } else {
                request.setValue("bytes=\(startOffset)-", forHTTPHeaderField: "Range")
            }
        }

        let task = session.dataTask(with: request)
        debugPrint("PPStream 收到要数据请求: offset=\(startOffset) length=\(loadingRequest.dataRequest?.requestedLength ?? 0)")
        lock.lock()
        pending[task] = loadingRequest
        taskStartOffset[task] = startOffset // 记下起始偏移，缓存时算这段数据的真实位置要用
        lock.unlock()
        task.resume()
        return true
    }

    /// AVPlayer 不要这段数据了（比如用户拖走了进度条），把对应下载停掉，别浪费流量
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        lock.lock()
        let target = pending.first { $0.value === loadingRequest }
        if let task = target?.key {
            pending.removeValue(forKey: task)
            taskStartOffset.removeValue(forKey: task)
        }
        lock.unlock()
        target?.key.cancel()
    }
}

// MARK: - URLSession 收到网络数据时走这里

extension PPStreamResourceLoader: URLSessionDataDelegate {

    /// 跨协议跳转（http→https）时保住认证头。
    /// 坚果云会把 http 强制 308 跳到 https，URLSession 默认会在跨协议跳转时删掉 Authorization，
    /// 导致第二个请求 401。这里在域名不变的前提下把认证头补回去（和 PPCloudHTTP 的做法一致）。
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        var newRequest = request
        let original = task.currentRequest ?? task.originalRequest
        if original?.url?.host == newRequest.url?.host,
           newRequest.value(forHTTPHeaderField: "Authorization") == nil,
           let auth = original?.value(forHTTPHeaderField: "Authorization") {
            newRequest.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        completionHandler(newRequest)
    }

    /// 收到响应头（还没收到正文）：告诉 AVPlayer 这个文件多大、什么类型、支不支持按段取
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let loadingRequest = self.loadingRequest(for: dataTask),
              let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        // 服务器报错（如 401 没带对认证头）时马上告诉 AVPlayer 失败原因。
        // 不能把错误网页当成影片数据交出去，否则播放器会卡在未知状态不报错
        if http.statusCode >= 400 {
            completionHandler(.cancel)
            dataTask.cancel()
            lock.lock()
            pending.removeValue(forKey: dataTask)
            lock.unlock()
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse,
                                userInfo: [NSLocalizedDescriptionKey: "服务器返回错误状态码 \(http.statusCode)"])
            loadingRequest.finishLoading(with: error)
            return
        }

        // 注意：AVPlayer 只在第一个请求里带 contentInformationRequest（问文件多大、什么类型），
        // 后续请求只有 dataRequest（单纯要数据）。这种情况直接放行，千万不能当成错误取消，
        // 否则后面的数据请求全被掐死，播放会报 -11800/-999 失败
        guard let infoRequest = loadingRequest.contentInformationRequest else {
            completionHandler(.allow)
            return
        }

        // 文件类型：把服务器给的 MIME（如 video/mp4）翻译成 AVPlayer 认识的 UTI（如 public.mpeg-4）
        if let mime = http.mimeType as CFString?,
           let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mime, nil)?.takeRetainedValue() {
            infoRequest.contentType = uti as String
        }

        // 取 Content-Range 必须用 value(forHTTPHeaderField:)，它不区分大小写。
        // 服务器走 HTTP/2 时返回的头名全是小写（content-range），用 allHeaderFields["Content-Range"]
        // 下标取值会拿到 nil，接着就会把"这一段的大小"当成"整个文件的大小"。
        // AVPlayer 拿到 contentLength=2 会认为整个影片只有 2 字节，直接报 -11829 无法打开（媒体可能已损坏）
        let contentRange = http.value(forHTTPHeaderField: "Content-Range")

        if http.statusCode == 206, let range = contentRange,
           let total = Int64(range.components(separatedBy: "/").last ?? "") {
            // 206 表示服务器只发了我们要的那一段。
            // 文件总大小藏在 Content-Range: bytes 0-99/12345 最后那个数字里，
            // AVPlayer 靠它显示总时长、支持拖进度条。
            infoRequest.contentLength = total
            infoRequest.isByteRangeAccessSupported = true
            expectedSize = total // 缓存也靠它判断"写齐了没"
        } else if http.statusCode == 206 {
            // 按协议 206 必须带 Content-Range，真拿不到就是服务器不规范。
            // 这时 response.expectedContentLength 只是这一段的长度，绝不能当总长度，
            // 只能如实告诉 AVPlayer"总长未知"，让它继续按需来要；缓存也不做，免得只存下半截
            infoRequest.contentLength = -1
            infoRequest.isByteRangeAccessSupported = true
        } else {
            // 200 表示服务器把整个文件都发过来了
            infoRequest.contentLength = response.expectedContentLength
            // 服务器不理 Range 请求就如实说"不支持分段"，AVPlayer 会禁用拖进度条
            infoRequest.isByteRangeAccessSupported = false
            if response.expectedContentLength > 0 {
                expectedSize = response.expectedContentLength
            }
        }

        completionHandler(.allow)
    }

    /// 收到一段正文数据：交给 AVPlayer（边播），同时按偏移写进缓存文件（边缓存）
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let loadingRequest = self.loadingRequest(for: dataTask) else { return }

        // AVPlayer 已经不要这段了（用户拖了进度条），停止下载
        if loadingRequest.isCancelled {
            dataTask.cancel()
            lock.lock()
            pending.removeValue(forKey: dataTask)
            taskStartOffset.removeValue(forKey: dataTask)
            lock.unlock()
            taskReceived.removeValue(forKey: dataTask)
            return
        }

        // 1) 交给播放器
        loadingRequest.dataRequest?.respond(with: data)

        // 2) 写进缓存：这段数据在文件里的真实位置 = 任务起始偏移 + 该任务已收字节
        lock.lock()
        let start = taskStartOffset[dataTask] ?? 0
        lock.unlock()
        let received = taskReceived[dataTask] ?? 0
        taskReceived[dataTask] = received + Int64(data.count)
        writeCache(data, atOffset: start + received)
    }

    /// 下载结束（正常完成或出错）：通知 AVPlayer 这个请求完结了
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let loadingRequest = pending.removeValue(forKey: task)
        taskStartOffset.removeValue(forKey: task)
        lock.unlock()
        taskReceived.removeValue(forKey: task)

        // 有些服务器不按 Range 分段、而是一次性把整段发完，coveredBytes 可能到这里才凑齐，
        // 所以任务结束时再兜底判断一次缓存是否完整
        if !cacheDone, expectedSize > 0, coveredBytes >= expectedSize {
            closeCacheFile(commit: true)
        }

        guard let loadingRequest = loadingRequest else { return }
        if let error = error {
            loadingRequest.finishLoading(with: error)
        } else {
            loadingRequest.finishLoading()
        }
    }
}
