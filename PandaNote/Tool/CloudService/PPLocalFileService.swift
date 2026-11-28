//
//  PPLocalFileService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation

/// 本地文件服务：把 App 沙盒里的 Documents 目录当成一个云盘来用
/// 以前所有文件操作都委托给 FilesProvider 的 LocalFileProvider，现在直接改用 FileManager 实现，
/// 这样本地服务不再依赖第三方库，也不会被它那套路径规范化规则牵着走（它会把 path 开头的斜杠削掉）
class PPLocalFileService: NSObject, PPCloudServiceProtocol {
    var url = "local"
    var baseURL: String {
        return url
    }

    /// 本地服务的根目录，也就是沙盒里的 Documents，和以前 LocalFileProvider 默认的 baseURL 保持一致
    private let rootURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    /// 把协议里的路径转成磁盘上的绝对路径
    /// 协议里的 path 都是「相对 Documents、以 / 开头」的写法，比如 /notes/a.md，这里要先去掉开头的斜杠再拼，
    /// 因为 appendingPathComponent 遇到 "/xxx" 会把它当成一个整体路径段，拼出来就不是 Documents 下面的文件了
    private func fileURL(for path: String) -> URL {
        var relativePath = path
        while relativePath.hasPrefix("/") {
            relativePath.removeFirst()
        }
        guard relativePath.isEmpty == false else {
            return rootURL
        }
        return rootURL.appendingPathComponent(relativePath)
    }

    /// 反过来，把磁盘上的绝对路径转成协议里的路径，统一带上前导斜杠
    /// 缓存 key 是「云服务备注 + path」直接拼出来的，少了前导斜杠会拼成 localdilireba.jpg，和读的时候拼的 PandaCache/local/dilireba.jpg 对不上，
    /// 表现就是文本能打开、图片打不开，所以这个方法返回的路径必须带斜杠
    private func relativePath(of fileURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let fullPath = fileURL.standardizedFileURL.path
        guard fullPath.hasPrefix(rootPath) else {
            return fullPath
        }
        var relativePath = String(fullPath.dropFirst(rootPath.count))
        if relativePath.hasPrefix("/") == false {
            relativePath = "/" + relativePath
        }
        return relativePath
    }

    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping ([PPFileObject], Error?) -> Void) {
        let directoryURL = fileURL(for: path)
        // 列目录要读磁盘，丢到后台队列做，文件夹里文件多的时候不会卡住列表滚动
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: .skipsSubdirectoryDescendants
                )
                var directories = [PPFileObject]()
                var files = [PPFileObject]()
                for fileURL in fileURLs {
                    let file = PPFileObject()
                    // 列目录的时候就把需要的属性一起取回来，比先拿文件名再逐个查 attributes 少一轮磁盘 IO
                    let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    file.name = fileURL.lastPathComponent
                    file.path = self.relativePath(of: fileURL)
                    file.isDirectory = values?.isDirectory ?? false
                    file.size = Int64(values?.fileSize ?? 0)
                    file.modifiedDate = values?.contentModificationDate?.toString() ?? ""
                    // 以前 PPFileObject.toPPFileObjects 会把文件夹插到数组最前面，这里保持同样的展示顺序
                    if file.isDirectory {
                        directories.append(file)
                    } else {
                        files.append(file)
                    }
                }
                let result = directories + files
                // 回主线程再交给 UI，调用方就不用自己再切一次
                DispatchQueue.main.async {
                    completion(result, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }

    /// 读取文件的全部二进制内容
    /// 注意回调在后台队列，和以前 FilesProvider 的行为一致，调用方要更新 UI 得自己切主线程
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (Data?, String, Error?) -> Void) {
        let fileURL = self.fileURL(for: path)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                completion(data, "", nil)
            } catch {
                completion(nil, "", error)
            }
        }
    }

    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        let directoryURL = fileURL(for: atPath).appendingPathComponent(folderName, isDirectory: true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // withIntermediateDirectories 传 true 时父目录不存在会自动建，和原来 FilesProvider 的行为一致
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping ([String: String]?, Error?) -> Void) {
        let fileURL = self.fileURL(for: path)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // .atomic 是先写临时文件再改名，写到一半失败也不会留下半截内容，和以前 FilesProvider 的写法一致
                try contents.write(to: fileURL, options: .atomic)
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (Error?) -> Void) {
        let sourceURL = fileURL(for: srcPath)
        let destinationURL = fileURL(for: destPath)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // moveItem 要求目标不存在，目标已经有同名文件会抛 fileWriteFileExists，
                // 和以前 FilesProvider 的 overwrite 默认 false 保持一致，不会悄悄覆盖用户文件
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func removeItem(_ path: String, _ fileID: String, completion: @escaping (Error?) -> Void) {
        let fileURL = self.fileURL(for: path)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // removeItem 对文件夹是递归删除，和以前 FilesProvider 的行为一致
                try FileManager.default.removeItem(at: fileURL)
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}
