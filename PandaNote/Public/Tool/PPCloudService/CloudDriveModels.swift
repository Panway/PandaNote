//
//  CloudDriveModels.swift
//  CloudDrive
//
//  所有数据模型定义
//

import Foundation

// MARK: - CloudFile

/// 表示云存储中的一个文件或目录
public struct CloudFile: Codable, Identifiable, Equatable {
    /// 唯一标识（路径或提供商原生 ID）
    public let id: String
    /// 文件名（不含路径）
    public let name: String
    /// 在服务器上的完整路径
    public let path: String
    /// 文件大小（字节），目录通常为 0
    public let size: Int64
    /// 是否为目录
    public let isDirectory: Bool
    /// MIME 类型
    public let mimeType: String?
    /// 最后修改时间
    public let modifiedDate: Date?
    /// 创建时间
    public let createdDate: Date?
    /// ETag（用于变更检测和条件请求）
    public let etag: String?
    /// 提供商原生 ID（如 Google Drive file id）
    public let providerID: String?
    /// 本地沙盒缓存路径（仅在已下载时有值，不持久化到 SQLite）
    public var localCachePath: String?

    public init(
        id: String,
        name: String,
        path: String,
        size: Int64 = 0,
        isDirectory: Bool = false,
        mimeType: String? = nil,
        modifiedDate: Date? = nil,
        createdDate: Date? = nil,
        etag: String? = nil,
        providerID: String? = nil,
        localCachePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.mimeType = mimeType
        self.modifiedDate = modifiedDate
        self.createdDate = createdDate
        self.etag = etag
        self.providerID = providerID
        self.localCachePath = localCachePath
    }

    /// 文件扩展名（小写）
    public var fileExtension: String {
        URL(fileURLWithPath: name).pathExtension.lowercased()
    }

    /// 格式化文件大小（如 "1.2 MB"）
    public var formattedSize: String {
        guard !isDirectory else { return "--" }
        let bytes = Double(size)
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0
            ? String(format: "%.0f %@", value, units[unitIndex])
            : String(format: "%.1f %@", value, units[unitIndex])
    }

    public static func == (lhs: CloudFile, rhs: CloudFile) -> Bool {
        lhs.id == rhs.id && lhs.etag == rhs.etag
    }
}

// MARK: - CloudFileListResult

/// 文件列表返回结果，包含是否来自缓存的标识
public struct CloudFileListResult {
    /// 文件/目录列表
    public let files: [CloudFile]
    /// ✅ true = 来自 SQLite 本地缓存；false = 来自网络
    public let isCached: Bool
    /// 此次列举的目录路径
    public let path: String
    /// 结果生成时间
    public let timestamp: Date

    public init(files: [CloudFile], isCached: Bool, path: String, timestamp: Date = Date()) {
        self.files = files
        self.isCached = isCached
        self.path = path
        self.timestamp = timestamp
    }
}

// MARK: - CloudDownloadResult

/// 文件下载结果
public struct CloudDownloadResult {
    /// 本地文件 URL
    public let localURL: URL
    /// ✅ true = 命中沙盒缓存；false = 从网络下载
    public let isCached: Bool
    /// 文件大小（字节）
    public let fileSize: Int64
}

// MARK: - CloudOperationResult

/// 通用操作结果（删除/移动/上传/创建目录等）
public struct CloudOperationResult {
    public let success: Bool
    public let message: String?
    public let error: Error?

    public static func success(_ message: String? = nil) -> CloudOperationResult {
        CloudOperationResult(success: true, message: message, error: nil)
    }

    public static func failure(_ error: Error, message: String? = nil) -> CloudOperationResult {
        CloudOperationResult(success: false, message: message, error: error)
    }
}

// MARK: - CloudTransferProgress

/// 传输进度（上传/下载通用）
public struct CloudTransferProgress {
    public let totalBytes: Int64
    public let transferredBytes: Int64

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    public var percentString: String {
        String(format: "%.0f%%", fractionCompleted * 100)
    }
}

// MARK: - CloudDriveLoginState

public enum CloudDriveLoginState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
    case tokenExpired
    case error(String)

    public static func == (lhs: CloudDriveLoginState, rhs: CloudDriveLoginState) -> Bool {
        switch (lhs, rhs) {
        case (.loggedOut, .loggedOut),
             (.loggingIn, .loggingIn),
             (.loggedIn, .loggedIn),
             (.tokenExpired, .tokenExpired):
            return true
//        case (.error(let a), .error(let b)):
        case let (.error(a), .error(b)):
            return a == b
        default:
            return false
        }
    }
}
