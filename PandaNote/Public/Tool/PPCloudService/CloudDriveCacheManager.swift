//
//  CloudDriveCacheManager.swift
//  CloudDrive
//
//  基于原生 SQLite3 的缓存管理器
//  负责：文件列表缓存 + 下载文件本地路径缓存
//
//  依赖：系统内置 libsqlite3（无需额外 Pod）
//

import CryptoKit
import Foundation
import SQLite3

// MARK: - CloudDriveCacheManager

public final class CloudDriveCacheManager {
    // MARK: Singleton

    public static let shared = CloudDriveCacheManager()

    // MARK: Private Properties

    private var db: OpaquePointer?

    /// 并发读写队列（barrier 写，并发读）
    private let dbQueue = DispatchQueue(
        label: "com.clouddrive.cache.sqlite",
        attributes: .concurrent
    )

    // SQLite TRANSIENT 析构器常量（让 SQLite 自己复制字符串）
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: Init

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let path = Self.databasePath()
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            print("❌ [CloudDriveCache] 无法打开数据库: \(path)")
            return
        }
        // WAL 模式：支持并发读
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        // 适度降低同步频率，提升性能
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        // 缓存页数
        sqlite3_exec(db, "PRAGMA cache_size=2000;", nil, nil, nil)
    }

    /// SQLite 数据库文件路径
    public static func databasePath() -> String {
//        let dir = FileManager.default
//            .urls(for: .documentDirectory, in: .userDomainMask)[0]
//            .appendingPathComponent("CloudDriveCache", isDirectory: true)
        // 数据库文件路径 Library/PandaNote/cloud_drive.sqlite
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PandaNote", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true, attributes: nil
        )
        return dir.appendingPathComponent("cloud_drive.sqlite").path
    }

    private func createTables() {
        // 文件列表缓存表
        let filesCacheSQL = """
        CREATE TABLE IF NOT EXISTS cached_files (
            id                TEXT NOT NULL,
            provider_id       TEXT NOT NULL,
            provider_type     TEXT NOT NULL,
            parent_path       TEXT NOT NULL,
            name              TEXT NOT NULL,
            path              TEXT NOT NULL,
            size              INTEGER DEFAULT 0,
            is_directory      INTEGER DEFAULT 0,
            mime_type         TEXT,
            modified_date     REAL,
            created_date      REAL,
            etag              TEXT,
            file_provider_id  TEXT,
            cached_at         REAL NOT NULL,
            PRIMARY KEY (provider_id, path)
        );
        """
        // 目录缓存元信息（记录各目录最后缓存时间，便于失效判断）
        let dirMetaSQL = """
        CREATE TABLE IF NOT EXISTS directory_cache_meta (
            provider_id  TEXT NOT NULL,
            path         TEXT NOT NULL,
            cached_at    REAL NOT NULL,
            PRIMARY KEY (provider_id, path)
        );
        """
        // 下载文件本地路径缓存表
        let downloadCacheSQL = """
        CREATE TABLE IF NOT EXISTS download_cache (
            id            TEXT PRIMARY KEY,
            provider_id   TEXT NOT NULL,
            remote_path   TEXT NOT NULL,
            local_path    TEXT NOT NULL,
            file_size     INTEGER DEFAULT 0,
            etag          TEXT,
            downloaded_at REAL NOT NULL,
            UNIQUE(provider_id, remote_path)
        );
        """
        // 为常用查询字段创建索引
        let indexSQL = [
            "CREATE INDEX IF NOT EXISTS idx_cached_files_parent ON cached_files(provider_id, parent_path);",
            "CREATE INDEX IF NOT EXISTS idx_download_cache_remote ON download_cache(provider_id, remote_path);",
        ]

        sqlite3_exec(db, filesCacheSQL, nil, nil, nil)
        sqlite3_exec(db, dirMetaSQL, nil, nil, nil)
        sqlite3_exec(db, downloadCacheSQL, nil, nil, nil)
        indexSQL.forEach { sqlite3_exec(db, $0, nil, nil, nil) }
    }

    // MARK: - File List Cache (Write)

    /// 保存某目录的文件列表到缓存
    /// - Parameters:
    ///   - files: 文件列表
    ///   - providerID: 提供商唯一标识
    ///   - providerType: 提供商类型
    ///   - parentPath: 父目录路径
    public func saveFileList(
        _ files: [CloudFile],
        providerID: String,
        providerType: CloudDriveType,
        parentPath: String
    ) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self, let db = self.db else { return }

            sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)

            // 先删除该目录的旧缓存
            let deleteSql = "DELETE FROM cached_files WHERE provider_id=? AND parent_path=?;"
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSql, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delStmt, 1, providerID, -1, self.SQLITE_TRANSIENT)
                sqlite3_bind_text(delStmt, 2, parentPath, -1, self.SQLITE_TRANSIENT)
                sqlite3_step(delStmt)
                sqlite3_finalize(delStmt)
            }

            // 批量插入新记录
            let insertSql = """
            INSERT OR REPLACE INTO cached_files
            (id, provider_id, provider_type, parent_path, name, path,
             size, is_directory, mime_type, modified_date, created_date,
             etag, file_provider_id, cached_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
            """
            var stmt: OpaquePointer?
            let now = Date().timeIntervalSince1970

            if sqlite3_prepare_v2(db, insertSql, -1, &stmt, nil) == SQLITE_OK {
                for file in files {
                    self.bindFileToStatement(stmt!, file: file,
                                             providerID: providerID,
                                             providerType: providerType,
                                             parentPath: parentPath,
                                             now: now)
                    sqlite3_step(stmt)
                    sqlite3_reset(stmt)
                }
                sqlite3_finalize(stmt)
            }

            // 更新目录元信息
            let metaSql = """
            INSERT OR REPLACE INTO directory_cache_meta (provider_id, path, cached_at)
            VALUES (?,?,?);
            """
            var metaStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, metaSql, -1, &metaStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(metaStmt, 1, providerID, -1, self.SQLITE_TRANSIENT)
                sqlite3_bind_text(metaStmt, 2, parentPath, -1, self.SQLITE_TRANSIENT)
                sqlite3_bind_double(metaStmt, 3, now)
                sqlite3_step(metaStmt)
                sqlite3_finalize(metaStmt)
            }

            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    private func bindFileToStatement(
        _ stmt: OpaquePointer,
        file: CloudFile,
        providerID: String,
        providerType: CloudDriveType,
        parentPath: String,
        now: Double
    ) {
        sqlite3_bind_text(stmt, 1, file.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, providerID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, providerType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, parentPath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, file.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, file.path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 7, file.size)
        sqlite3_bind_int(stmt, 8, file.isDirectory ? 1 : 0)

        if let mime = file.mimeType {
            sqlite3_bind_text(stmt, 9, mime, -1, SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 9) }

        if let mod = file.modifiedDate {
            sqlite3_bind_double(stmt, 10, mod.timeIntervalSince1970)
        } else { sqlite3_bind_null(stmt, 10) }

        if let cre = file.createdDate {
            sqlite3_bind_double(stmt, 11, cre.timeIntervalSince1970)
        } else { sqlite3_bind_null(stmt, 11) }

        if let etag = file.etag {
            sqlite3_bind_text(stmt, 12, etag, -1, SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 12) }

        if let pid = file.providerID {
            sqlite3_bind_text(stmt, 13, pid, -1, SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 13) }

        sqlite3_bind_double(stmt, 14, now)
    }

    // MARK: - File List Cache (Read)

    /// 读取某目录的文件列表缓存，不存在则返回 nil
    public func loadFileList(providerID: String, parentPath: String) -> [CloudFile]? {
        var result: [CloudFile]?
        dbQueue.sync {
            guard let db = self.db else { return }
            let sql = """
            SELECT id, name, path, size, is_directory, mime_type,
                   modified_date, created_date, etag, file_provider_id
            FROM cached_files
            WHERE provider_id=? AND parent_path=?
            ORDER BY is_directory DESC, name ASC;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, providerID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, parentPath, -1, SQLITE_TRANSIENT)

            var files: [CloudFile] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = string(from: stmt!, column: 0)
                let name = string(from: stmt!, column: 1)
                let path = string(from: stmt!, column: 2)
                let size = sqlite3_column_int64(stmt, 3)
                let isDir = sqlite3_column_int(stmt, 4) != 0
                let mime = optionalString(from: stmt!, column: 5)
                let modDate = optionalDate(from: stmt!, column: 6)
                let creDate = optionalDate(from: stmt!, column: 7)
                let etag = optionalString(from: stmt!, column: 8)
                let fpid = optionalString(from: stmt!, column: 9)

                files.append(CloudFile(
                    id: id, name: name, path: path, size: size,
                    isDirectory: isDir, mimeType: mime,
                    modifiedDate: modDate, createdDate: creDate,
                    etag: etag, providerID: fpid
                ))
            }
            result = files.isEmpty ? nil : files
        }
        return result
    }

    /// 获取某目录的最后缓存时间
    public func cacheTimestamp(providerID: String, path: String) -> Date? {
        var result: Date?
        dbQueue.sync {
            guard let db = self.db else { return }
            let sql = "SELECT cached_at FROM directory_cache_meta WHERE provider_id=? AND path=?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, providerID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, path, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
            }
        }
        return result
    }

    // MARK: - File List Cache (Invalidate)

    /// 使某目录的缓存失效
    public func invalidateFileList(providerID: String, parentPath: String) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self, let db = self.db else { return }
            sqlite3_exec(db, "BEGIN;", nil, nil, nil)
            self.execute(db: db,
                         sql: "DELETE FROM cached_files WHERE provider_id=? AND parent_path=?;",
                         params: [providerID, parentPath])
            self.execute(db: db,
                         sql: "DELETE FROM directory_cache_meta WHERE provider_id=? AND path=?;",
                         params: [providerID, parentPath])
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    /// 清除某提供商所有缓存
    public func clearAllCache(providerID: String) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self, let db = self.db else { return }
            sqlite3_exec(db, "BEGIN;", nil, nil, nil)
            for table in ["cached_files", "download_cache", "directory_cache_meta"] {
                self.execute(db: db,
                             sql: "DELETE FROM \(table) WHERE provider_id=?;",
                             params: [providerID])
            }
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    // MARK: - Download Cache (Write)

    /// 记录已下载文件的本地沙盒路径
    public func saveDownloadCache(
        providerID: String,
        remotePath: String,
        localPath: String,
        fileSize: Int64,
        etag: String?
    ) {
        let cacheID = "\(providerID):\(remotePath)".stableHash
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = """
            INSERT OR REPLACE INTO download_cache
            (id, provider_id, remote_path, local_path, file_size, etag, downloaded_at)
            VALUES (?,?,?,?,?,?,?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, cacheID, -1, self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, providerID, -1, self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, remotePath, -1, self.SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, localPath, -1, self.SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 5, fileSize)
            if let etag { sqlite3_bind_text(stmt, 6, etag, -1, self.SQLITE_TRANSIENT) }
            else { sqlite3_bind_null(stmt, 6) }
            sqlite3_bind_double(stmt, 7, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Download Cache (Read)

    /// 查询已下载文件的本地路径，不存在则返回 nil
    public func loadDownloadCache(
        providerID: String,
        remotePath: String
    ) -> (localPath: String, fileSize: Int64, etag: String?)? {
        var result: (String, Int64, String?)?
        dbQueue.sync {
            guard let db = self.db else { return }
            let sql = "SELECT local_path, file_size, etag FROM download_cache WHERE provider_id=? AND remote_path=?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, providerID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, remotePath, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_ROW {
                let localPath = string(from: stmt!, column: 0)
                let size = sqlite3_column_int64(stmt, 1)
                let etag = optionalString(from: stmt!, column: 2)
                result = (localPath, size, etag)
            }
        }
        return result
    }

    // MARK: - Download Cache (Delete)

    public func deleteDownloadCache(providerID: String, remotePath: String) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self, let db = self.db else { return }
            self.execute(db: db,
                         sql: "DELETE FROM download_cache WHERE provider_id=? AND remote_path=?;",
                         params: [providerID, remotePath])
        }
    }

    // MARK: - Private Helpers

    /// 执行带参数的 SQL（仅适用于不返回结果的语句）
    @discardableResult
    private func execute(db: OpaquePointer, sql: String, params: [String]) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        for (i, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), param, -1, SQLITE_TRANSIENT)
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func string(from stmt: OpaquePointer, column: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, column) else { return "" }
        return String(cString: cStr)
    }

    private func optionalString(from stmt: OpaquePointer, column: Int32) -> String? {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL,
              let cStr = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: cStr)
    }

    private func optionalDate(from stmt: OpaquePointer, column: Int32) -> Date? {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(stmt, column))
    }
}

// MARK: - String Hash Helper

private extension String {
    /// 用于生成缓存 ID，使用 MD5
    var stableHash: String {
        let data = Data(utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
