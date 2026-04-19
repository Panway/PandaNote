//
//  CloudDriveError.swift
//  CloudDrive
//
//  所有错误类型定义
//

import Foundation

public enum CloudDriveError: LocalizedError, Equatable {
    case notAuthenticated
    case authenticationFailed(String)
    case tokenRefreshFailed(String)
    case invalidCredential(String)
    case networkError(String)
    case serverError(Int, String?) // (HTTP状态码, 消息)
    case fileNotFound(String)
    case permissionDenied
    case invalidResponse
    case xmlParseError(String)
    case jsonParseError(String)
    case cacheError(String)
    case downloadFailed(String)
    case uploadFailed(String)
    case unsupportedOperation(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录，请先完成认证"
        case let .authenticationFailed(msg):
            return "认证失败：\(msg)"
        case let .tokenRefreshFailed(msg):
            return "Token 刷新失败：\(msg)"
        case let .invalidCredential(msg):
            return "凭据无效：\(msg)"
        case let .networkError(msg):
            return "网络错误：\(msg)"
        case let .serverError(code, msg):
            return "服务器错误 \(code)：\(msg ?? "未知")"
        case let .fileNotFound(path):
            return "文件不存在：\(path)"
        case .permissionDenied:
            return "权限被拒绝"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case let .xmlParseError(msg):
            return "XML 解析失败：\(msg)"
        case let .jsonParseError(msg):
            return "JSON 解析失败：\(msg)"
        case let .cacheError(msg):
            return "缓存错误：\(msg)"
        case let .downloadFailed(msg):
            return "下载失败：\(msg)"
        case let .uploadFailed(msg):
            return "上传失败：\(msg)"
        case let .unsupportedOperation(op):
            return "不支持的操作：\(op)"
        case let .unknown(msg):
            return "未知错误：\(msg)"
        }
    }

    /// 是否是认证相关错误（可触发重新登录）
    public var isAuthError: Bool {
        switch self {
        case .notAuthenticated, .authenticationFailed, .tokenRefreshFailed:
            return true
        case let .serverError(code, _):
            return code == 401 || code == 403
        default:
            return false
        }
    }

    public static func == (lhs: CloudDriveError, rhs: CloudDriveError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }

    /// 从 Alamofire 错误和 HTTP 状态码构建
    public static func from(statusCode: Int, message: String? = nil) -> CloudDriveError {
        switch statusCode {
        case 401: return .authenticationFailed(message ?? "Unauthorized")
        case 403: return .permissionDenied
        case 404: return .fileNotFound(message ?? "Not Found")
        case 409: return .serverError(statusCode, message ?? "Conflict")
        case 500 ... 599: return .serverError(statusCode, message ?? "Internal Server Error")
        default: return .serverError(statusCode, message)
        }
    }
}
