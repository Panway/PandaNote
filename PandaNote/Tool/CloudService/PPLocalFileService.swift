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
    
    
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        fileProvider.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            DispatchQueue.main.async {
                completion(archieveArray,error)
            }
        })
    }
    

    
    
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        //let fileID = extraParams.fileID
        fileProvider.contents(path: path) { contents, error in
            completion(contents,"",error)
        }
    }
    
    func createDirectory(_ folderName: String, _ atPath: String, completion:@escaping(_ error: Error?) -> Void) {
        fileProvider.create(folder: folderName, at: atPath, completionHandler: completion)
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        fileProvider.writeContents(path: path, contents: contents, overwrite: true) { error in
            completion(nil, error)
        }
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {
        fileProvider.moveItem(path:srcPath, to: destPath, completionHandler: completion)
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
        fileProvider.removeItem(path:path, completionHandler: completion)
    }
    
    
    
}
