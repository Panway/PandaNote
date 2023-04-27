//
//  PPWebDAVService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import FilesProvider


class PPWebDAVService: PPFilesProvider, PPCloudServiceProtocol {
    var url = ""
    var baseURL: String {
        return url
    }
    var webdav: WebDAVFileProvider?//未配置服务器地址时刷新可能为空
    
    init(url: String, username: String, password: String) {
        let userCredential = URLCredential(user: username,
                                           password: password,
                                           persistence: .permanent)
        
        guard let server = URL(string: url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) else {
            debugPrint("初始化\(url)错误", true)
            return
        }
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!//不能加`,cache: URLCache.shared`,要不然无法保存markdown！！！
        // webdav.useCache = true
        // 注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
//        let protectionSpace = URLProtectionSpace(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
//        URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        self.url = url
        
    }
    
    
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        webdav?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            if let error = error {
                let errorCode = (error as NSError).code
                
                if let error2 = error as NSError? {
                    NSLog("error %@ / %d", error2.domain, error2.code)
                }
                
//                let error as? NSError
                if error._code == 503 {
                    debugPrint("503==",errorCode)
                }
                else {
                    debugPrint("503==",error._code)
                }
            }
            let archieveArray = self.myPPFileArrayFrom(contents)
            
            DispatchQueue.main.async {
                completion(archieveArray,error)
            }
        })
    }
    

    
    
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        webdav?.contents(path: path) { contents, error in
            completion(contents,"",error)
        }
    }
    
    
    func createDirectory(_ folderName: String, _ atPath: String, completion:@escaping(_ error: Error?) -> Void) {
        webdav?.create(folder: folderName, at: atPath, completionHandler: completion)
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        webdav?.writeContents(path: path, contents: contents, completionHandler: { error in
            completion(nil, error)
        })
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {
        webdav?.moveItem(path:srcPath, to: destPath, completionHandler: completion)
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
        webdav?.removeItem(path:path, completionHandler: completion)
    }
    
    
    func searchFile(path: String, searchText: String?,completionHandler: @escaping ((_ files: [PPFileObject], _ isFromCache:Bool, _ error: Error?) -> Void)) {
        //创建谓词，默认是TRUEPREDICATE
        var query = NSPredicate(format: "TRUEPREDICATE")
        let searchFile:[URLResourceKey] = []//[.fileSizeKey,.creationDateKey]
        if let searchText = searchText {
            query = NSPredicate(format: "name CONTAINS[c] '\(searchText)'")
        }
        
        webdav?.searchFiles(path: path, recursive: true, query: query, including: searchFile, foundItemHandler: nil, completionHandler: { (files, error) in
            let archieveArray = self.myPPFileArrayFrom(files)
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(archieveArray,false,error)
                }
            }
            else {
                debugPrint(error ?? "downloadFileFromWebDAV Error")
            }
        })
            
    }
    
}
