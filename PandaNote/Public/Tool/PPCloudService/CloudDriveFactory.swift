//
//  CloudDriveFactory.swift
//  CloudDrive
//
//  工厂类：根据 CloudDriveCredential 创建对应的提供商实例
//

import Foundation

public final class CloudDriveFactory {
    private init() {}

    /// 根据凭据类型自动创建对应的提供商
    /// - Parameters:
    ///   - credential: 凭据（含提供商类型和参数）
    ///   - providerID: 可选的自定义 ID（用于多账号区分）
    public static func makeProvider(
        for credential: CloudDriveCredential,
        providerID: String? = nil
    ) -> CloudDriveProvider {
        switch credential.type {
        case .webDAV:
            return WebDAVProvider(credential: credential, providerID: providerID)
        case .googleDrive:
            return OAuthProvider(credential: credential, providerID: providerID)
        case .dropbox:
            return OAuthProvider(credential: credential, providerID: providerID)
        case .oneDrive:
            return OAuthProvider(credential: credential, providerID: providerID)
        case .awsS3:
            // AWSS3Provider 待实现，暂时返回占位 OAuthProvider
            fatalError("AWSS3Provider 尚未实现，请自行继承 CloudDriveProvider 实现")
        case .custom:
            fatalError("自定义提供商请直接实例化子类")
        }
    }
}

// MARK: ─────────────────────────────────────────────────

// MARK: OAuthProvider（OAuth 类型提供商的通用骨架）

// MARK: 继承此类实现 Google Drive、Dropbox、OneDrive 等

// MARK: ─────────────────────────────────────────────────

import Alamofire

/// OAuth 提供商基类（Google Drive / Dropbox / OneDrive 均可继承）
/// 封装了 WebView 授权、Token 换取和自动刷新逻辑的通用框架
open class OAuthProvider: CloudDriveProvider {
    // MARK: - Computed Credential Shortcuts

    public var apiBaseURL: String {
        credential[CloudCredentialKey.apiBaseURL] ?? ""
    }

    public var clientID: String {
        credential[CloudCredentialKey.clientID] ?? ""
    }

    public var clientSecret: String {
        credential[CloudCredentialKey.clientSecret] ?? ""
    }

    public var redirectURI: String {
        credential[CloudCredentialKey.redirectURI] ?? ""
    }

    public var tokenURL: String {
        credential[CloudCredentialKey.tokenURL] ?? ""
    }

    public var scope: String {
        credential[CloudCredentialKey.scope] ?? ""
    }

    private var accessToken: String? {
        get { credential[CloudCredentialKey.accessToken] }
        set { credential[CloudCredentialKey.accessToken] = newValue }
    }

    private var refreshToken: String? {
        get { credential[CloudCredentialKey.refreshToken] }
        set { credential[CloudCredentialKey.refreshToken] = newValue }
    }

    private var tokenExpiry: Date? {
        get {
            guard let str = credential[CloudCredentialKey.tokenExpiry],
                  let ts = Double(str) else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            credential[CloudCredentialKey.tokenExpiry] = newValue.map {
                String($0.timeIntervalSince1970)
            }
        }
    }

    // MARK: - OAuth Login URL

    /// 构造 WebView 展示的授权 URL
    /// 调用方应在 WebView 中打开此 URL，监听 redirectURI 跳转后调用 handleOAuthCallback
    override public func oauthLoginURL() -> URL? {
        guard !clientID.isEmpty,
              let authURLStr = credential[CloudCredentialKey.authURL],
              var components = URLComponents(string: authURLStr)
        else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"), // Google Drive 需要
        ]
        return components.url
    }

    // MARK: - Login（打开 WebView）

    override public func login(completion: @escaping CloudLoginCallback) {
        guard let _ = oauthLoginURL() else {
            completion(.failure(.invalidCredential("无法构建 OAuth 授权 URL，请检查 clientID/authURL")))
            return
        }
        // 提示调用方在 WebView 中展示授权页
        setLoginState(.loggingIn)
        // 实际登录通过 handleOAuthCallback 完成
        // 这里可通过通知或 delegate 告知 UI 打开 WebView
        NotificationCenter.default.post(
            name: .cloudDriveNeedsOAuthWebView,
            object: self,
            userInfo: ["provider": self]
        )
    }

    // MARK: - Handle OAuth Callback

    /// WebView 检测到 redirectURI 跳转后调用此方法
    override public func handleOAuthCallback(url: URL, completion: @escaping CloudLoginCallback) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            completion(.failure(.authenticationFailed("未找到授权 code，URL: \(url)")))
            return
        }
        exchangeCodeForToken(code: code, completion: completion)
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String, completion: @escaping CloudLoginCallback) {
        let params: Parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": clientSecret,
        ]

        AF.request(tokenURL, method: .post, parameters: params,
                   encoding: URLEncoding.httpBody)
            .validate()
            .responseDecodable(of: OAuthTokenResponse.self) { [weak self] response in
                guard let self else { return }
                switch response.result {
                case let .success(tokenResp):
                    self.applyTokenResponse(tokenResp)
                    self.setLoginState(.loggedIn)
                    completion(.success(()))
                case let .failure(error):
                    self.setLoginState(.loggedOut)
                    completion(.failure(.authenticationFailed(error.localizedDescription)))
                }
            }
    }

    // MARK: - Token Refresh

    override public func refreshTokenIfNeeded(completion: @escaping CloudLoginCallback) {
        // Token 未过期，直接通过
        if let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60) {
            completion(.success(()))
            return
        }
        guard let refresh = refreshToken, !refresh.isEmpty else {
            setLoginState(.tokenExpired)
            completion(.failure(.tokenRefreshFailed("无 Refresh Token，请重新登录")))
            return
        }

        let params: Parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID,
            "client_secret": clientSecret,
        ]

        AF.request(tokenURL, method: .post, parameters: params,
                   encoding: URLEncoding.httpBody)
            .validate()
            .responseDecodable(of: OAuthTokenResponse.self) { [weak self] response in
                guard let self else { return }
                switch response.result {
                case let .success(tokenResp):
                    self.applyTokenResponse(tokenResp)
                    self.setLoginState(.loggedIn)
                    completion(.success(()))
                case let .failure(error):
                    self.setLoginState(.tokenExpired)
                    completion(.failure(.tokenRefreshFailed(error.localizedDescription)))
                }
            }
    }

    // MARK: - Logout

    override public func logout(completion: @escaping CloudOperationCallback) {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        setLoginState(.loggedOut)
        clearAllCache()
        completion(.success(.success("已退出登录")))
    }

    // MARK: - Helpers

    private func applyTokenResponse(_ resp: OAuthTokenResponse) {
        accessToken = resp.accessToken
        if let rt = resp.refreshToken { refreshToken = rt }
        if let exp = resp.expiresIn {
            tokenExpiry = Date().addingTimeInterval(Double(exp))
        }
        // 更新 session header
        session = makeOAuthSession(token: resp.accessToken)
    }

    private func makeOAuthSession(token: String) -> Session {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return Session(
            configuration: config,
            interceptor: BearerTokenInterceptor(token: token)
        )
    }

    // MARK: - OAuth 请求通用方法（子类可调用）

    func apiRequest(
        path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        completion: @escaping (Result<Data, CloudDriveError>) -> Void
    ) {
        let url = apiBaseURL + path
        session.request(url, method: method, parameters: parameters, encoding: encoding)
            .validate()
            .responseData { response in
                switch response.result {
                case let .success(data):
                    completion(.success(data))
                case let .failure(error):
                    let code = response.response?.statusCode ?? 0
                    completion(.failure(.from(statusCode: code, message: error.localizedDescription)))
                }
            }
    }
}

// MARK: - OAuth Token Response Model

private struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - BearerTokenInterceptor

private final class BearerTokenInterceptor: RequestInterceptor {
    private let token: String
    init(token: String) { self.token = token }

    func adapt(
        _ urlRequest: URLRequest,
        for _: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var req = urlRequest
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        completion(.success(req))
    }
}

// MARK: - Notification Name

public extension Notification.Name {
    /// 需要展示 OAuth WebView 时发出此通知
    static let cloudDriveNeedsOAuthWebView = Notification.Name("CloudDriveNeedsOAuthWebView")
}
