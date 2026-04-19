//
//  WebDAVProvider.swift
//  CloudDrive
//
//  WebDAV 协议实现（RFC 4918）
//
//  HTTP 方法对应关系：
//  ┌─────────────────┬───────────────────┐
//  │ 操作            │ HTTP Method       │
//  ├─────────────────┼───────────────────┤
//  │ 列举目录         │ PROPFIND (Depth:1)│
//  │ 下载文件         │ GET               │
//  │ 上传文件         │ PUT               │
//  │ 删除            │ DELETE            │
//  │ 移动/重命名      │ MOVE              │
//  │ 复制            │ COPY              │
//  │ 创建目录         │ MKCOL             │
//  │ 验证连接         │ PROPFIND (Depth:0)│
//  └─────────────────┴───────────────────┘
//

import Alamofire
import Foundation

public final class WebDAVProvider: CloudDriveProvider {
    // MARK: - 私有属性

    /// PPCloudHTTP 实例（注入了 BasicAuthInterceptor，无需每次手动传 Authorization header）
    private var http: PPCloudHTTP!

    // MARK: - Credential 快捷访问

    private var serverURL: String {
        var url = credential[CloudCredentialKey.serverURL] ?? ""
        // 去除末尾斜杠，统一拼接处理
        while url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }

    private var username: String { credential[CloudCredentialKey.username] ?? "" }
    private var password: String { credential[CloudCredentialKey.password] ?? "" }

    // MARK: - ✅ 核心修复：提取服务器 base path

    //
    // 问题复现：
    //   serverURL  = "http://dav.jianguoyun.com/dav"
    //   PROPFIND 返回 href = "/dav/level1Path"（服务器总是返回完整的服务器绝对路径）
    //   buildFullURL("/dav/level1Path") = "http://dav.jianguoyun.com/dav/dav/level1Path" ❌
    //
    // 修复原理：
    //   serverBasePath = "/dav"（从 serverURL 里提取）
    //   解析 XML 时，对每个 href 剥离 serverBasePath 前缀：
    //   "/dav/level1Path" → "/level1Path"
    //   后续 buildFullURL("/level1Path") = "http://dav.jianguoyun.com/dav/level1Path" ✅
    //
    private var serverBasePath: String {
        guard let url = URL(string: serverURL) else { return "" }
        let path = url.path
        guard path != "/", !path.isEmpty else { return "" }
        // 去除末尾斜杠："/dav/" → "/dav"，保留前导斜杠
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    // MARK: - PROPFIND 请求体（请求常用属性）

    private let propfindBody = """
    <?xml version="1.0" encoding="utf-8"?>
    <D:propfind xmlns:D="DAV:">
        <D:prop>
            <D:displayname/>
            <D:getcontentlength/>
            <D:getcontenttype/>
            <D:getetag/>
            <D:getlastmodified/>
            <D:creationdate/>
            <D:resourcetype/>
        </D:prop>
    </D:propfind>
    """

    // MARK: - Init

    override public init(credential: CloudDriveCredential, providerID: String? = nil) {
        super.init(credential: credential, providerID: providerID)
        rebuildHTTPClient()
    }

    /// 凭据变更后（如密码修改）重建 HTTP 客户端
    private func rebuildHTTPClient() {
        http = PPCloudHTTP.configure(
            baseURL: serverURL, // ✅ baseURL = serverURL，后续方法只传相对路径
            timeout: 30,
            interceptor: BasicAuthInterceptor(username: username, password: password)
        )
        // WebDAV 各方法有自己的 Content-Type，清空全局默认值
        http.setDefaultHeaders(["User-Agent": "PPCloudHTTP-WebDAV/1.0"])
    }

    // MARK: - Login

    /// 通过向根目录发送 PROPFIND 验证账号密码是否正确
    override public func login(completion: @escaping CloudLoginCallback) {
        guard !serverURL.isEmpty else {
            completion(.failure(.invalidCredential("服务器地址不能为空")))
            return
        }

        setLoginState(.loggingIn)

        // 向根路径发 PROPFIND Depth:0，验证账号密码是否正确
        http.request(
            url: "/",
            method: .propfind,
            bodyData: propfindBody.data(using: .utf8),
            headers: [
                "Depth": "0",
                "Content-Type": "application/xml; charset=utf-8",
            ]
        ) { [weak self] response in
            guard let self else { return }
            if response.isSuccess {
                self.setLoginState(.loggedIn)
                completion(.success(()))
            } else {
                let error = self.mapHTTPError(response)
                self.setLoginState(.error(error.localizedDescription ?? ""))
                completion(.failure(error))
            }
        }
    }

    // MARK: - Logout

    override public func logout(completion: @escaping CloudOperationCallback) {
        setLoginState(.loggedOut)
        // WebDAV 无服务端 Session，仅清理本地缓存
        clearAllCache()
        completion(.success(.success("已退出登录")))
    }

    // MARK: - List Files

    /// 先返回 SQLite 缓存（isCached: true），再返回网络数据（isCached: false）
    override public func listFiles(path: String, completion: @escaping CloudFileListCallback) {
        let normalized = normalizePath(path)

        // 1️⃣ 立即返回 SQLite 缓存（isCached: true）
        if enableListCache,
           let cached = cache.loadFileList(providerID: providerID, parentPath: normalized)
        {
            completion(.success(CloudFileListResult(
                files: cached, isCached: true, path: normalized
            )))
        }

        // 2️⃣ 再拉取网络最新数据（isCached: false）
        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }
            self.fetchRemoteFileList(path: normalized) { fetchResult in
                switch fetchResult {
                case let .success(files):
                    if self.enableListCache {
                        self.cache.saveFileList(
                            files,
                            providerID: self.providerID,
                            providerType: self.type,
                            parentPath: normalized
                        )
                    }
                    completion(.success(CloudFileListResult(
                        files: files, isCached: false, path: normalized
                    )))
                case let .failure(e):
                    completion(.failure(e))
                }
            }
        }
    }

    private func fetchRemoteFileList(
        path: String,
        completion: @escaping (Result<[CloudFile], CloudDriveError>) -> Void
    ) {
        http.request(
            url: encodePath(path),
            method: .propfind,
            bodyData: propfindBody.data(using: .utf8),
            headers: [
                "Depth": "1",
                "Content-Type": "application/xml; charset=utf-8",
            ]
        ) { [weak self] response in
            guard let self else { return }
            guard response.isSuccess, let data = response.data else {
                completion(.failure(self.mapHTTPError(response)))
                return
            }
            self.parseMultiStatusXML(data: data, parentPath: path, completion: completion)
        }
    }

    // MARK: - Download

    override public func downloadFile(
        remotePath: String,
        useCache: Bool = true,
        progress: CloudProgressCallback? = nil,
        completion: @escaping CloudDownloadCallback
    ) {
        let normalized = normalizePath(remotePath)

        // 命中沙盒缓存直接返回
        if useCache, enableDownloadCache,
           let cachedURL = cachedLocalURL(for: normalized)
        {
            completion(.success(CloudDownloadResult(
                localURL: cachedURL, isCached: true, fileSize: fileSize(at: cachedURL)
            )))
            return
        }

        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }

            let destination = self.localFileURL(for: normalized)

            self.http.download(
                url: self.encodePath(normalized),
                to: destination,
                progress: { completed, total in
                    progress?(CloudTransferProgress(
                        totalBytes: total,
                        transferredBytes: completed
                    ))
                }
            ) { [weak self] response in
                guard let self else { return }
                if response.isSuccess, let localURL = response.data {
                    let size = self.fileSize(at: localURL)
                    if useCache, self.enableDownloadCache {
                        self.cache.saveDownloadCache(
                            providerID: self.providerID,
                            remotePath: normalized,
                            localPath: localURL.path,
                            fileSize: size,
                            etag: response.headers?["ETag"]
                        )
                    }
                    completion(.success(CloudDownloadResult(
                        localURL: localURL, isCached: false, fileSize: size
                    )))
                } else {
                    completion(.failure(self.mapHTTPError(response)))
                }
            }
        }
    }

    // MARK: - Upload

    override public func uploadFile(
        localURL: URL,
        remotePath: String,
        progress: CloudProgressCallback? = nil,
        completion: @escaping CloudOperationCallback
    ) {
        let normalized = normalizePath(remotePath)

        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }

            self.http.upload(
                fileURL: localURL,
                to: self.encodePath(normalized),
                method: .put,
                progress: { completed, total in
                    progress?(CloudTransferProgress(
                        totalBytes: total,
                        transferredBytes: completed
                    ))
                }
            ) { [weak self] response in
                guard let self else { return }
                if response.isSuccess {
                    self.invalidateListCache(for: normalized)
                    completion(.success(.success("上传成功")))
                } else {
                    completion(.failure(self.mapHTTPError(response)))
                }
            }
        }
    }

    // MARK: - Delete

    override public func deleteFile(path: String, completion: @escaping CloudOperationCallback) {
        let normalized = normalizePath(path)

        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }

            self.http.request(
                url: encodePath(normalized),
                method: .delete
            ) { [weak self] response in
                guard let self else { return }
                if response.isSuccess {
                    self.invalidateListCache(for: normalized)
                    self.cache.deleteDownloadCache(
                        providerID: self.providerID, remotePath: normalized
                    )
                    completion(.success(.success("删除成功")))
                } else {
                    completion(.failure(self.mapHTTPError(response)))
                }
            }
        }
    }

    // MARK: - Move / Rename

    override public func moveFile(
        fromPath: String,
        toPath: String,
        completion: @escaping CloudOperationCallback
    ) {
        let from = normalizePath(fromPath)
        let to = normalizePath(toPath)

        // MOVE 的 Destination header 必须是完整 URL
        guard let destinationURL = buildFullURL(path: to) else {
            completion(.failure(.invalidCredential("目标路径 URL 构建失败：\(to)")))
            return
        }

        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }

            self.http.request(
                url: self.encodePath(from),
                method: .move,
                headers: [
                    "Destination": destinationURL.absoluteString,
                    "Overwrite": "T", // T = 允许覆盖目标
                ],
                acceptableStatusCodes: [201, 204]
            ) { [weak self] response in
                guard let self else { return }
                if response.isSuccess {
                    self.invalidateListCache(for: from)
                    self.invalidateListCache(for: to)
                    completion(.success(.success("移动成功")))
                } else {
                    completion(.failure(self.mapHTTPError(response)))
                }
            }
        }
    }

    // MARK: - Create Directory

    override public func createDirectory(path: String, completion: @escaping CloudOperationCallback) {
        let normalized = normalizePath(path)

        ensureAuthenticated { [weak self] result in
            guard let self else { return }
            if case let .failure(e) = result { completion(.failure(e)); return }

            self.http.request(
                url: encodePath(normalized),
                method: .mkcol,
                acceptableStatusCodes: [201]
            ) { [weak self] response in
                guard let self else { return }
                if response.isSuccess {
                    self.invalidateListCache(for: normalized)
                    completion(.success(.success("目录创建成功")))
                } else if response.statusCode == 405 {
                    completion(.failure(.serverError(405, "目录已存在")))
                } else {
                    completion(.failure(self.mapHTTPError(response)))
                }
            }
        }
    }

    // MARK: - Private: URL 工具

    /// 构建带 scheme+host 的完整 URL（仅用于需要写入 Header 的场景，如 MOVE Destination）
    private func buildFullURL(path: String) -> URL? {
        URL(string: serverURL + encodePath(normalizePath(path)))
    }

    /// 对路径每个分量做百分比编码，保留 /
    private func encodePath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    /// 规范化路径：确保以 / 开头，非根路径去除末尾 /
    private func normalizePath(_ path: String) -> String {
        var p = path.trimmingCharacters(in: .whitespaces)
        if !p.hasPrefix("/") { p = "/" + p }
        if p != "/" && p.hasSuffix("/") { p = String(p.dropLast()) }
        return p
    }

    // MARK: - Private: 解析 PROPFIND XML

    private func parseMultiStatusXML(
        data: Data,
        parentPath: String,
        completion: @escaping (Result<[CloudFile], CloudDriveError>) -> Void
    ) {
        let parser = WebDAVXMLParser(data: data)
        guard let entries = parser.parse(), parser.parseError == nil else {
            completion(.failure(.xmlParseError(
                parser.parseError?.localizedDescription ?? "解析 multistatus 失败"
            )))
            return
        }

        let normalizedParent = normalizePath(parentPath)
        let basePath = serverBasePath // ✅ 修复 bug 的关键

        let files: [CloudFile] = entries.compactMap { entry in
            // Step 1：URL 解码
            var hrefPath = entry.href.removingPercentEncoding ?? entry.href

            // Step 2：✅ 剥离服务器 base path 前缀
            //   "/dav/Documents/file.txt"  →  "/Documents/file.txt"
            if !basePath.isEmpty, hrefPath.hasPrefix(basePath) {
                hrefPath = String(hrefPath.dropFirst(basePath.count))
                if hrefPath.isEmpty { hrefPath = "/" }
            }

            // Step 3：去除末尾斜杠（目录 href 通常以 / 结尾）
            if hrefPath != "/", hrefPath.hasSuffix("/") {
                hrefPath = String(hrefPath.dropLast())
            }

            // Step 4：跳过父目录自身（PROPFIND Depth:1 会包含自身）
            if hrefPath == normalizedParent { return nil }

            // Step 5：取文件名
            let fileName = entry.displayName.isEmpty
                ? URL(fileURLWithPath: hrefPath).lastPathComponent
                : entry.displayName
            guard !fileName.isEmpty, fileName != "." else { return nil }

            return CloudFile(
                id: hrefPath,
                name: fileName,
                path: hrefPath,
                size: entry.contentLength,
                isDirectory: entry.isCollection,
                mimeType: entry.contentType,
                modifiedDate: entry.lastModified,
                createdDate: entry.creationDate,
                etag: entry.etag
            )
        }

        completion(.success(files))
    }

    // MARK: - Private: PPCloudHTTPError → CloudDriveError

    private func mapHTTPError<T>(_ response: PPCloudHTTPResponse<T>) -> CloudDriveError {
        guard let httpErr = response.error else {
            return .serverError(response.statusCode, nil)
        }
        switch httpErr {
        case .forbidden: return .permissionDenied
        case .notFound: return .fileNotFound("HTTP 404")
        case .badGateway: return .serverError(502, "Bad Gateway")
        case .timeout: return .networkError("请求超时")
        case .networkError: return .networkError("网络连接错误")
        case .invalidResponse: return .invalidResponse
        case let .serverError(code): return .serverError(code, nil)
        case let .clientError(code):
            switch code {
            case 401: return .authenticationFailed("用户名或密码错误")
            case 403: return .permissionDenied
            case 404: return .fileNotFound("HTTP 404")
            case 409: return .serverError(409, "Conflict")
            default: return .serverError(code, nil)
            }
        case let .unknown(e): return .networkError(e.localizedDescription)
        }
    }

    // MARK: - Private: 杂项

    private func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}

// MARK: - BasicAuthInterceptor（private，仅 WebDAVProvider 使用）

private final class BasicAuthInterceptor: RequestInterceptor {
    private let headerValue: String

    init(username: String, password: String) {
        let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
        headerValue = "Basic \(encoded)"
    }

    func adapt(_ urlRequest: URLRequest,
               for _: Session,
               completion: @escaping (Result<URLRequest, Error>) -> Void)
    {
        var req = urlRequest
        req.setValue(headerValue, forHTTPHeaderField: "Authorization")
        completion(.success(req))
    }
}
