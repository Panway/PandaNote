//
//  PPiCloudDriveService.swift
//  PandaNote
//
//  Created by Panway on 2023/7/23.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

import FilesProvider
import Alamofire

class PPiCloudDriveService: NSObject, PPCloudServiceProtocol {
//    var baseURL: String
    var url = ""
    var baseURL: String {
        return url
    }
    var icloudFileProvider: CloudFileProvider!
    
    init(containerId: String) {
        icloudFileProvider = CloudFileProvider(containerId: containerId, scope: .documents)
    }
    
    
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping ([PPFileObject], Error?) -> Void) {
        if let icloudFileProvider = icloudFileProvider {
            icloudFileProvider.contentsOfDirectory(path: path) { contents, error in
                let archieveArray = PPFileObject.toPPFileObjects(contents)
                DispatchQueue.main.async {
                    completion(archieveArray,error)
                }
            }
        }
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.icloudFileProvider.contentsOfDirectory(path: path) { contents, error in
                    let archieveArray = PPFileObject.toPPFileObjects(contents)
                    DispatchQueue.main.async {
                        completion(archieveArray,error)
                    }
                }
            }
        }
    }
    
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (Data?, String, Error?) -> Void) {
        
    }
    
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping ([String : String]?, Error?) -> Void) {
        icloudFileProvider.writeContents(path: path, contents: contents, overwrite: true) { error in
            completion(nil, error)
        }
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (Error?) -> Void) {
        
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping (Error?) -> Void) {
        
    }
    
    
    
}
