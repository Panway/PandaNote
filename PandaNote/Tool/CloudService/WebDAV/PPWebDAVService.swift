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
        
        let server = URL(string: url)!
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!//不能加`,cache: URLCache.shared`,要不然无法保存markdown！！！
        // webdav.useCache = true
        // 注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
//        let protectionSpace = URLProtectionSpace(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
//        URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        self.url = url
        
    }
    
    
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        webdav?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            
            DispatchQueue.main.async {
                completionHandler(archieveArray,error)
            }
        })
    }
    
    func contentsOfPathID(_ pathID: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        webdav?.contents(path: path, completionHandler: completionHandler)
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {
        webdav?.create(folder: folderName, at: atPath, completionHandler: completionHandler)
    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {
        webdav?.writeContents(path: path, contents: contents, completionHandler: completionHandler)
    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {
        webdav?.moveItem(path:srcPath, to: dstPath, completionHandler: completionHandler)
    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {
        webdav?.removeItem(path:path, completionHandler: completionHandler)
    }
    
    
    func searchFileViaWebDAV(path: String, searchText: String?,completionHandler: @escaping ((_ files: [PPFileObject], _ isFromCache:Bool, _ error: Error?) -> Void)) {
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
