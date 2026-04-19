//
//  CloudDriveCredential.swift
//  CloudDrive
//
//  灵活的凭据容器，支持所有云存储类型。
//  使用字典存储参数，便于后期扩展新的提供商无需修改模型。
//

import Foundation

// MARK: - CloudDriveType

/// 支持的云存储提供商类型
public enum CloudDriveType: String, Codable, CaseIterable {
    case webDAV = "webdav"
    case googleDrive = "google_drive"
    case dropbox
    case oneDrive = "onedrive"
    case awsS3 = "aws_s3"
    case custom

    public var displayName: String {
        switch self {
        case .webDAV: return "WebDAV"
        case .googleDrive: return "Google Drive"
        case .dropbox: return "Dropbox"
        case .oneDrive: return "OneDrive"
        case .awsS3: return "Amazon S3"
        case .custom: return "Custom"
        }
    }

    /// 是否需要通过 OAuth WebView 登录
    public var usesOAuthWebView: Bool {
        switch self {
        case .googleDrive, .dropbox, .oneDrive: return true
        default: return false
        }
    }
}

// MARK: - CloudCredentialKey

/// 凭据参数键名常量（避免魔法字符串）
public enum CloudCredentialKey {
    // 通用
    public static let serverURL = "server_url"
    public static let apiBaseURL = "api_base_url"
    public static let accessToken = "access_token"
    public static let refreshToken = "refresh_token"
    public static let tokenExpiry = "token_expiry"

    // Basic Auth（WebDAV）
    public static let username = "username"
    public static let password = "password"

    // OAuth
    public static let clientID = "client_id"
    public static let clientSecret = "client_secret"
    public static let authURL = "auth_url"
    public static let tokenURL = "token_url"
    public static let redirectURI = "redirect_uri"
    public static let scope = "scope"

    // AWS S3
    public static let accessKeyID = "access_key_id"
    public static let secretAccessKey = "secret_access_key"
    public static let region = "region"
    public static let bucketName = "bucket_name"
}

// MARK: - CloudDriveCredential

/// 灵活的凭据模型，支持所有提供商类型
public struct CloudDriveCredential {
    public let type: CloudDriveType
    /// 参数字典，key 使用 CloudCredentialKey 中的常量
    public var params: [String: String]

    public init(type: CloudDriveType, params: [String: String] = [:]) {
        self.type = type
        self.params = params
    }

    public subscript(key: String) -> String? {
        get { params[key] }
        set { params[key] = newValue }
    }
}

// MARK: - Convenience Factories

public extension CloudDriveCredential {
    /// WebDAV：服务器地址 + Basic Auth
    static func webDAV(serverURL: String,
                       username: String,
                       password: String) -> CloudDriveCredential
    {
        CloudDriveCredential(type: .webDAV, params: [
            CloudCredentialKey.serverURL: serverURL,
            CloudCredentialKey.username: username,
            CloudCredentialKey.password: password,
        ])
    }

    /// OneDrive / Google Drive / Dropbox：OAuth 授权
    /// authURL 用于在 WebView 中展示登录页
    static func oauth(type: CloudDriveType,
                      clientID: String,
                      clientSecret: String,
                      authURL: String,
                      tokenURL: String,
                      redirectURI: String,
                      apiBaseURL: String,
                      scope: String = "") -> CloudDriveCredential
    {
        CloudDriveCredential(type: type, params: [
            CloudCredentialKey.clientID: clientID,
            CloudCredentialKey.clientSecret: clientSecret,
            CloudCredentialKey.authURL: authURL,
            CloudCredentialKey.tokenURL: tokenURL,
            CloudCredentialKey.redirectURI: redirectURI,
            CloudCredentialKey.apiBaseURL: apiBaseURL,
            CloudCredentialKey.scope: scope,
        ])
    }

    /// AWS S3
    static func awsS3(accessKeyID: String,
                      secretAccessKey: String,
                      region: String,
                      bucketName: String) -> CloudDriveCredential
    {
        CloudDriveCredential(type: .awsS3, params: [
            CloudCredentialKey.accessKeyID: accessKeyID,
            CloudCredentialKey.secretAccessKey: secretAccessKey,
            CloudCredentialKey.region: region,
            CloudCredentialKey.bucketName: bucketName,
        ])
    }
}
