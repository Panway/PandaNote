//
//  CloudDriveProvider.swift
//  CloudDrive
//
//  ┌─────────────────────────────────────────────────────┐
//  │   CloudDriveProvider（抽象基类）                     │
//  │   所有具体提供商继承此类，实现相同的接口方法名         │
//  └─────────────────────────────────────────────────────┘
//
//  约定：
//  - 标注 "ABSTRACT" 的方法，子类必须 override，否则运行时 fatalError
//  - 基类提供共享工具方法（缓存读取、沙盒路径、认证保障等）
//

import Alamofire
import Foundation

class Parent {
    func mustOverride() {
        fatalError("子类必须 override \(#function)")
    }
}

class Child: Parent {
//    override func mustOverride() {
//        print("Child 实现了 mustOverride")
//    }
}

// MARK: - Callback Type Aliases

public typealias CloudLoginCallback = (Result<Void, CloudDriveError>) -> Void
public typealias CloudFileListCallback = (Result<CloudFileListResult, CloudDriveError>) -> Void
public typealias CloudDownloadCallback = (Result<CloudDownloadResult, CloudDriveError>) -> Void
// Result<Success, Failure> 是 Swift 标准库类型，用于表示“要么成功，要么失败”。Success 类型是 CloudOperationResult。Failure 类型是 CloudDriveError
public typealias CloudOperationCallback = (Result<CloudOperationResult, CloudDriveError>) -> Void
public typealias CloudProgressCallback = (CloudTransferProgress) -> Void

// MARK: - CloudDriveProvider

open class CloudDriveProvider {
    // MARK: - Public Properties

    /// 提供商类型
    public let type: CloudDriveType

    /// 提供商实例唯一 ID，作为 SQLite 缓存的 namespace key
    /// 建议包含 type + serverURL，避免不同账号数据混淆
    public let providerID: String

    /// 登录凭据（可变，支持 Token 刷新后更新）
    public var credential: CloudDriveCredential

    /// 当前登录状态
    public private(set) var loginState: CloudDriveLoginState = .loggedOut

    /// ✅ 是否开启文件列表 SQLite 缓存（默认开启）
    public var enableListCache: Bool = true

    /// ✅ 是否开启下载文件沙盒缓存（默认开启）
    public var enableDownloadCache: Bool = true

    /// 缓存管理器（内部使用）
    let cache = CloudDriveCacheManager.shared

    /// Alamofire Session（子类可在 init 中替换为带拦截器的版本）
    lazy var session: Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return Session(configuration: config)
    }()

    // MARK: - Init

    public init(credential: CloudDriveCredential, providerID: String? = nil) {
        self.credential = credential
        type = credential.type
        // 默认 providerID = type + serverURL 或随机 UUID
        self.providerID = providerID
            ?? [credential.type.rawValue,
                credential[CloudCredentialKey.serverURL]
                    ?? credential[CloudCredentialKey.apiBaseURL]
                    ?? UUID().uuidString]
            .joined(separator: "_")
    }
    // 只保留字母和数字，其它全部丢弃
    func keepAlphaNumeric(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return input.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
    }
    // MARK: - ⚠️ ABSTRACT: 子类必须 Override

    /// 登录认证
    /// - WebDAV：用账号密码向服务器发 PROPFIND 验证
    /// - OAuth 类型：可在此返回 authURL，由调用方在 WebView 中打开
    open func login(completion _: @escaping CloudLoginCallback) {
        fatalError("[\(type.displayName)] 必须实现 login(completion:)")
    }

    /// 处理 OAuth WebView 回调 URL（OAuth 提供商实现）
    open func handleOAuthCallback(url _: URL, completion _: @escaping CloudLoginCallback) {
        // 默认不处理；仅 OAuth 提供商需 override
    }

    /// 获取 OAuth 登录页 URL（OAuth 提供商实现）
    open func oauthLoginURL() -> URL? {
        return nil
    }

    /// 登出（清除 Token / Session）
    open func logout(completion _: @escaping CloudOperationCallback) {
        fatalError("[\(type.displayName)] 必须实现 logout(completion:)")
    }

    /// 刷新 Access Token（Token 即将过期时由基类自动调用）
    open func refreshTokenIfNeeded(completion: @escaping CloudLoginCallback) {
        // 默认：无需刷新（Basic Auth 等不需要刷新）
        completion(.success(()))
    }

    /// 获取文件列表
    ///
    /// 调用逻辑：
    /// 1. 若有 SQLite 缓存 → 立即以 `isCached: true` 回调
    /// 2. 再从网络拉取最新数据 → 以 `isCached: false` 再次回调
    ///
    /// 调用方可根据 `isCached` 判断是否需要刷新 UI
    open func listFiles(path _: String, completion _: @escaping CloudFileListCallback) {
        fatalError("[\(type.displayName)] 必须实现 listFiles(path:completion:)")
    }

    /// 下载文件到本地沙盒
    /// - Parameters:
    ///   - remotePath: 云端文件路径
    ///   - useCache: true = 优先使用沙盒缓存，无缓存才下载
    ///   - progress: 下载进度回调（主线程）
    ///   - completion: 完成回调，包含本地 URL 和是否来自缓存
    open func downloadFile(
        remotePath _: String,
        useCache _: Bool = true,
        progress _: CloudProgressCallback? = nil,
        completion _: @escaping CloudDownloadCallback
    ) {
        fatalError("[\(type.displayName)] 必须实现 downloadFile(...)")
    }

    /// 上传本地文件到云端
    /// - Parameters:
    ///   - localURL: 本地文件 URL
    ///   - remotePath: 目标云端路径（含文件名）
    ///   - progress: 上传进度回调
    ///   - completion: 完成回调
    open func uploadFile(
        localURL _: URL,
        remotePath _: String,
        progress _: CloudProgressCallback? = nil,
        completion _: @escaping CloudOperationCallback
    ) {
        fatalError("[\(type.displayName)] 必须实现 uploadFile(...)")
    }

    /// 删除文件或目录
    open func deleteFile(path _: String, completion _: @escaping CloudOperationCallback) {
        fatalError("[\(type.displayName)] 必须实现 deleteFile(path:completion:)")
    }

    /// 移动/重命名文件或目录
    open func moveFile(
        fromPath _: String,
        toPath _: String,
        completion _: @escaping CloudOperationCallback
    ) {
        fatalError("[\(type.displayName)] 必须实现 moveFile(fromPath:toPath:completion:)")
    }

    /// 创建目录
    open func createDirectory(path _: String, completion _: @escaping CloudOperationCallback) {
        fatalError("[\(type.displayName)] 必须实现 createDirectory(path:completion:)")
    }

    // MARK: - Shared Utilities（子类可直接使用）

    /// 本提供商的下载缓存根目录
    public func localDownloadDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PandaCache", isDirectory: true)
            .appendingPathComponent(providerID, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// 根据远端路径构建本地沙盒文件 URL
    public func localFileURL(for remotePath: String) -> URL {
        let fileName = URL(fileURLWithPath: remotePath).lastPathComponent
        // 使用 remotePath 的哈希前缀防止同名文件冲突
        let prefix = String(remotePath.hashValue & 0xFFFF, radix: 16)
        return localDownloadDirectory().appendingPathComponent("\(prefix)_\(fileName)")
    }

    /// 检查远端文件是否有沙盒缓存且文件仍然存在
    /// 若 DB 记录存在但文件已被删除，自动清理 DB
    public func cachedLocalURL(for remotePath: String) -> URL? {
        guard enableDownloadCache else { return nil }
        guard let cached = cache.loadDownloadCache(providerID: providerID, remotePath: remotePath) else {
            return nil
        }
        let url = URL(fileURLWithPath: cached.localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        // 文件已被用户删除，清理 DB 记录
        cache.deleteDownloadCache(providerID: providerID, remotePath: remotePath)
        return nil
    }

    /// 使某目录的列表缓存失效（删除/移动操作后调用）
    public func invalidateListCache(for path: String) {
        let parentPath = URL(fileURLWithPath: path)
            .deletingLastPathComponent().path
        cache.invalidateFileList(providerID: providerID, parentPath: parentPath)
    }

    /// 清除本提供商的所有 SQLite 缓存
    public func clearAllCache() {
        cache.clearAllCache(providerID: providerID)
    }

    // MARK: - Internal Helpers

    /// 更新登录状态（子类调用）
    func setLoginState(_ state: CloudDriveLoginState) {
        loginState = state
    }

    /// 确保已认证后再执行操作
    /// 若 Token 已过期，自动尝试刷新
    func ensureAuthenticated(
        then action: @escaping (Result<Void, CloudDriveError>) -> Void
    ) {
        switch loginState {
        case .loggedIn:
            refreshTokenIfNeeded(completion: action)
        case .tokenExpired:
            refreshTokenIfNeeded { [weak self] result in
                switch result {
                case .success:
                    self?.setLoginState(.loggedIn)
                    action(.success(()))
                case let .failure(error):
                    self?.setLoginState(.error(error.localizedDescription ?? ""))
                    action(.failure(error))
                }
            }
        case .loggedOut:
            action(.failure(.notAuthenticated))
        case .loggingIn:
            // 稍后重试（简化处理，实际可实现队列等待）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.ensureAuthenticated(then: action)
            }
        case let .error(msg):
            action(.failure(.authenticationFailed(msg)))
        }
    }

    /// 解析 HTTP 状态码并抛出对应错误
    func errorFromResponse(_ response: HTTPURLResponse?, error: Error?) -> CloudDriveError {
        if let code = response?.statusCode {
            return CloudDriveError.from(statusCode: code, message: error?.localizedDescription)
        }
        return .networkError(error?.localizedDescription ?? "Unknown")
    }
}
