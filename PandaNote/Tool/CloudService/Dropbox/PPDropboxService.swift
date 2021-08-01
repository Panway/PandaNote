//
//  PPDropboxService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit
import FilesProvider

class PPDropboxService: PPFilesProvider, PPCloudServiceProtocol {
    var url = "https://api.dropboxapi.com/2/"
    var baseURL: String {
        return url
    }
    var dropbox: DropboxFileProvider?//未配置服务器地址时刷新可能为空
    
    init(access_token: String) {
        let userCredential = URLCredential(user: "dropbox",
                                           password: access_token,
                                           persistence: .permanent)
        dropbox = DropboxFileProvider(credential: userCredential)
    }
    
    
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        dropbox?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            DispatchQueue.main.async {
                completionHandler(archieveArray,error)
            }
        })
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        dropbox?.contents(path: path, completionHandler: completionHandler)
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {
        dropbox?.create(folder: folderName, at: atPath, completionHandler: completionHandler)
    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {
        dropbox?.writeContents(path: path, contents: contents, completionHandler: completionHandler)
    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {
        dropbox?.moveItem(path:srcPath, to: dstPath, completionHandler: completionHandler)
    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {
        dropbox?.removeItem(path:path, completionHandler: completionHandler)
    }
    
    
}
