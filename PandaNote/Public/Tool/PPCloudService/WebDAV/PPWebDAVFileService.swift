//
//  PPWebDAVFileService.swift
//  PandaNote
//
//  Created by pan on 2026/4/19.
//  Copyright © 2026 Panway. All rights reserved.
//

import Foundation

class PPWebDAVFileService: NSObject, PPCloudServiceProtocol {
    var url = ""
    var baseURL: String {
        return url
    }

    var drive: CloudDriveProvider?
    init(url: String, username: String, password: String, id: String) {
        // 1 构建凭据（不同网盘只需换凭据，接口方法名完全一致）
        let credential = CloudDriveCredential.webDAV(
            serverURL: url,
            username: username,
            password: password
        )
        // 2 通过工厂创建提供商（也可直接 WebDAVProvider(credential:)）
        drive = CloudDriveFactory.makeProvider(for: credential, providerID: id)

        // 3 开关缓存
        drive?.enableListCache = true // SQLite 文件列表缓存
        drive?.enableDownloadCache = true // 下载沙盒缓存
        // 4 登录
        drive?.login { result in
            switch result {
            case .success:
                debugPrint("✅ 登录成功")
//                        self.demoListFiles(drive: drive)
            case let .failure(error):
                debugPrint("❌ 登录失败：\(error.localizedDescription)")
            }
        }

        self.url = url
    }

    func contentsOfDirectory(_ path: String, _: String, completion: @escaping (_ data: [PPFileObject], _ error: Error?) -> Void) {
        drive?.listFiles(path: path) { result in
            switch result {
            case let .success(listResult):
                let source = listResult.isCached ? "📦 缓存" : "🌐 网络"
                debugPrint("\(source) 获取到 \(listResult.files.count) 个文件")

                for file in listResult.files {
                    let icon = file.isDirectory ? "📁" : "📄"
                    debugPrint("  \(icon) \(file.name)  \(file.formattedSize)")
                }

                if !listResult.isCached {
                    // 网络数据回来后可刷新 UI
                    let archieveArray = PPFileObject.toPPFileArray(listResult.files)

                    DispatchQueue.main.async { /* tableView.reloadData() */
                        completion(archieveArray, nil)
                    }
                }
            case let .failure(error):
                completion([], error)
            }
        }
    }

    func getFileData(_ path: String, _: String, completion: @escaping (_ data: Data?, _ url: String, _ error: Error?) -> Void) {
        drive?.downloadFile(remotePath: path) { result in
            debugPrint("==========", result)
            switch result {
            case .success(let download):
                let source = download.isCached ? "📦 沙盒缓存" : "🌐 网络下载"
                debugPrint("\(source)：\(download.localURL.path)  \(download.fileSize) bytes")
//                let data = try? Data(contentsOf: download.localURL)
                completion(nil, download.localURL.path, nil)
            case .failure(let error):
                completion(nil, "", error)
                debugPrint("❌ 下载失败：\(error.localizedDescription)")
            }
            
        }
    }

    func createDirectory(_ folderName: String, _ atPath: String, _: String, completion: @escaping (Error?) -> Void) {
        drive?.createDirectory(path: atPath + folderName, completion: { res in
            completion(self.getError(res))
        })
    }

    func createFile(_ path: String, _: String, contents: Data, completion: @escaping (_ result: [String: String]?, _ error: Error?) -> Void) {
        // 如果目录没创建，先创建
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(path)
        if !FileManager.default.fileExists(atPath: tempURL.path.pp_directoryPath) {
            try? FileManager.default.createDirectory(atPath: tempURL.path.pp_directoryPath, withIntermediateDirectories: true, attributes: nil)
        }
        // 先写到临时目录
        try? contents.write(to: tempURL)
        drive?.uploadFile(localURL: tempURL, remotePath: path) { res in
            completion(nil, self.getError(res))
            // 删除临时文件
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    func moveItem(srcPath: String, destPath: String, srcItemID _: String, destItemID _: String, isRename _: Bool, completion: @escaping (_ error: Error?) -> Void) {
        drive?.moveFile(fromPath: srcPath, toPath: destPath) { res in
            completion(self.getError(res))
        }
    }

    func removeItem(_ path: String, _: String, completion: @escaping (_ error: Error?) -> Void) {
        drive?.deleteFile(path: path) { res in
            completion(self.getError(res))
        }
    }

    func getError(_ res: Result<CloudOperationResult, CloudDriveError>) -> Error? {
        switch res {
        case let .success(operationResult):
            debugPrint("操作成功: \(operationResult)")
            return nil

        case let .failure(error):
            debugPrint("操作失败: \(error)")
            return error
        }
    }
}
