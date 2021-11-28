//
//  PPOneDriveService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/2.
//  Copyright © 2021 Panway. All rights reserved.
//
let onedrive_client_id_es = "dedcda2a-3acf-44bb-8baa-17f9ed544d64"
let onedrive_redirect_uri_es = "https://login.microsoftonline.com/common/oauth2/nativeclient"
let onedrive_client_id_pandanote = "064f5b62-97a8-4dae-b5c1-aaf44439939d"
let onedrive_redirect_uri_pandanote = "pandanote://msredirect"
let onedrive_login_url_es = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=dedcda2a-3acf-44bb-8baa-17f9ed544d64&scope=User.Read%20offline_access%20files.readwrite.all&redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient&response_type=code"

import UIKit
import FilesProvider
import Alamofire

class PPOneDriveService: PPFilesProvider, PPCloudServiceProtocol {
    
    var url = "https://graph.microsoft.com"
    var access_token = ""
    var refresh_token = ""
    var baseURL: String {
        return url
    }
    var onedrive: OneDriveFileProvider
    
    init(access_token: String,refresh_token: String) {
        let userCredential = URLCredential(user: "anonymous",
                                           password: access_token,
                                           persistence: .forSession)
        self.access_token = access_token
        self.refresh_token = refresh_token
        onedrive = OneDriveFileProvider(credential: userCredential)
    }
    
    func getNewToken() {
        let parameters: [String: String] = [
            "client_id": onedrive_client_id_es,
            "redirect_uri": onedrive_redirect_uri_es,
            "refresh_token": self.refresh_token,
            "grant_type": "refresh_token"
        ]
//        debugPrint("getNewToken==\(parameters)")
        let url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
        AF.request(url, method: .post, parameters: parameters).responseJSON { response in
            debugPrint(response.value)
            let jsonDic = response.value as? [String : Any]
//                    let access_token = jsonDic["access_token"] as? String
            if let access_token = jsonDic?["access_token"] as? String,let refresh_token = jsonDic?["refresh_token"] as? String {
                debugPrint("microsoft access_token is:",access_token)
                let userCredential = URLCredential(user: "anonymous",
                                                   password: access_token,
                                                   persistence: .forSession)
                self.refresh_token = refresh_token
                self.access_token = access_token
                self.onedrive = OneDriveFileProvider(credential: userCredential)
                print("=====refresh_token=====\n\(refresh_token)")
                print("=====access_token=====\n\(access_token)")

                
                //更新
                var serverList = PPUserInfo.shared.pp_serverInfoList
                var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
                current["PPWebDAVPassword"] = access_token
                current["PPCloudServiceExtra"] = refresh_token
//                        current["PPCloudServiceExtra"] =
                #warning("todo")
//                        self.refresh_token = current["PPCloudServiceExtra"]!
                serverList.remove(at: PPUserInfo.shared.pp_lastSeverInfoIndex)
                serverList.insert(current, at: PPUserInfo.shared.pp_lastSeverInfoIndex)
                PPUserInfo.shared.pp_serverInfoList = serverList

                
                
                
            }
            
            
        }
        return
    }
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        contentsOfPathID(path, completionHandler: completionHandler)
    }

    func contentsOfPathID(_ pathID: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        var requestURL = "https://graph.microsoft.com/v1.0/me/drive/items/\(pathID)/children?%24expand=thumbnails&%24top=200"
        if pathID == "/" {
            requestURL = "https://graph.microsoft.com/v1.0/me/drive/root/children?%24expand=thumbnails&%24top=200"
        }
        let headers: HTTPHeaders = [
            "Authorization": "bearer " + self.access_token
        ]
        AF.request(requestURL, method: .get,headers: headers).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            if response.response?.statusCode == 401 {
                self.getNewToken()
                return
            }
            
            if let fileList = jsonDic?["value"] as? [[String:Any]] {
                var dataSource = [PPFileObject]()
                
                for oneDriveFile in fileList {
//                    debugPrint("----------\(oneDriveFile)")
                    if let item = PPOneDriveFile(JSON: oneDriveFile) {
                        item.downloadURL = oneDriveFile["@microsoft.graph.downloadUrl"] as? String ?? ""
                        if item.folder != nil {
                            item.isDirectory = true
                        }
                        dataSource.append(item)
                    }
                    //@microsoft.graph.downloadUrl  name   size   lastModifiedDateTime
                    
                }
                
                DispatchQueue.main.async {
                    completionHandler(dataSource,nil)
                }
            }
            
            
            
        }
        
        
        /*
        onedrive.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            DispatchQueue.main.async {
                completionHandler(archieveArray,error)
            }
        })
         */
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        AF.request(path).response { response in
            completionHandler(response.data, nil)
        }
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {
        onedrive.create(folder: folderName, at: atPath, completionHandler: completionHandler)
    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {
        onedrive.writeContents(path: path, contents: contents, overwrite: true, completionHandler: completionHandler)
    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {
        onedrive.moveItem(path:srcPath, to: dstPath, completionHandler: completionHandler)
    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {
        onedrive.removeItem(path:path, completionHandler: completionHandler)
    }
    
    
}
