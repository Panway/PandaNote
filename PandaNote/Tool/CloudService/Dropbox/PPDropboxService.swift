//
//  PPDropboxService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit
import FilesProvider

let dropbox_auth_url = "https://www.dropbox.com/oauth2/authorize?client_id=pjmhj9rfhownr7z&redirect_uri=filemgr://oauth-callback/dropbox&response_type=token&state=DROPBOX"


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
    
    
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        dropbox?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            DispatchQueue.main.async {
                completion(archieveArray,error)
            }
        })
    }
    
    
    
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        //let fileID = extraParams.fileID
        dropbox?.contents(path: path, completionHandler: { contents, error in
            completion(contents, "", error)
        })
    }

    
    func createDirectory(_ folderName: String, _ atPath: String, completion:@escaping(_ error: Error?) -> Void) {
        dropbox?.create(folder: folderName, at: atPath, completionHandler: completion)
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        dropbox?.writeContents(path: path, contents: contents, overwrite: true, completionHandler: { error in
            completion(nil, error)
        })
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {
        dropbox?.moveItem(path:srcPath, to: destPath, completionHandler: completion)
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
        dropbox?.removeItem(path:path, completionHandler: completion)
    }
    
    
}
