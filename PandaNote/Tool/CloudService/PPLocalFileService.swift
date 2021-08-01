//
//  PPLocalFileService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import FilesProvider


class PPLocalFileService:PPFilesProvider, PPCloudServiceProtocol {
    var url = "local"
    var baseURL: String {
        return url
    }
    var fileProvider = LocalFileProvider()
    
//    init(url: String) {
//        self.url = url
//    }
    
    
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        fileProvider.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            DispatchQueue.main.async {
                completionHandler(archieveArray,error)
            }
        })
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        fileProvider.contents(path: path, completionHandler: completionHandler)
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {
        fileProvider.create(folder: folderName, at: atPath, completionHandler: completionHandler)
    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {
        fileProvider.writeContents(path: path, contents: contents, completionHandler: completionHandler)
    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {
        fileProvider.moveItem(path:srcPath, to: dstPath, completionHandler: completionHandler)
    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {
        fileProvider.removeItem(path:path, completionHandler: completionHandler)
    }
    
    
    
}
