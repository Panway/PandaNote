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
        self.access_token = access_token//"EwBoA8l6BAAUwihrrCrmQ4wuIJX5mbj7rQla6TUAAW/MktkjZEo4HOKg/fD0hXlCKnXG12Gxn2U/SNZzFpjAQiKFV20h3bje8+4lTWqg9FzIEg6aYt4lCfAisWgnZirmDeQYKTpfm3wUtK5Hje1PYYHlQhgsSiIVlWDgyhDGVkkrRYujmkxswd83rlziy63ALbdHj4mBSDwGX4Vialmd2quhS69K0pyJxqddegO2+DRo+wPaVFKS4ZLSlr8bVLt7wLHSCj7WSEZ9qYbGcbLSwo/mE6WNCkqmPYhlHEYHcLnGYx36I6oq/1QJEFFrX4VZso/h0uq+mwzg+i/H5TPGV5CCc273Oop+ART4HU3k46GlH1kxg8tFUSue+Mgv9UQDZgAACFw0dEnICpadOAL1DODpGrVs8Al/K52SEbV0+9BtkK2ka3KseFOVyjqc5fPZg5zNLFRYbexPEwKCr/z5RpvpGN9c9r8Yzqpo8y5GzY8XwTNBhAjMVEpOnD8B/ZJvKmH9WEnW0np9Lt0ildc/Jx77/fLFyQmPUKUBEQzyqXhzWY+2wNcVLgSVN3qEndrVOTjGWhFlO9hy46MsD2NV797waEBPVZZYRNBbjhE+AHe3Gho/pnApOo7pyHd+p3yVrQFJAaVfBd5f3mhX1TBcDx3AZ8SgYUm96Gdx+d5BD/M/6kBY4WYtejo24bVZSVNAz+wYJ7DYDbutkY8ppdljK2bM3ma6OZZfTlCRZMXDm3y/1vEx7yL+H1ov4qnOFVB7fFJKKfCgAml/+XdO2eEVXl8WuAhSvV8fkiVAae3ialfRxNnEVw/eoDilRCQ0HBuLbQtXBNCeM7OTPKQqFKajyowkDOeiaWq+u5/YOtwAbDzxcAWyGzX7I2vhucGI1FGQtmPF1FxdOR/6sKu2/lGLmarbsQmeYXIqiMw/9eXQVV3LjrV4Ujg7WWWIe/qAbyJx/ZaLkg1paK14l0JLBUzJNcKshtK885eb8/Mj7+RlgLBUotlZ+x7b/LFS0VNYXywRyc2aF4eBJIDeSlY+yoxJO4P8kv1HLq52JpNKkm4DOV22XVIiYZnf/S2yBMnk6NoqvPdDc+13gYfq8nh22+JZCkG+8bTPqMmHUz452V7OzqET+UB2nFTC5l0fdyWasS6GRVMv4QnSdQI="
//        self.access_token = "EwBoA8l6BAAUwihrrCrmQ4wuIJX5mbj7rQla6TUAAW/MktkjZEo4HOKg/fD0hXlCKnXG12Gxn2U/SNZzFpjAQiKFV20h3bje8+4lTWqg9FzIEg6aYt4lCfAisWgnZirmDeQYKTpfm3wUtK5Hje1PYYHlQhgsSiIVlWDgyhDGVkkrRYujmkxswd83rlziy63ALbdHj4mBSDwGX4Vialmd2quhS69K0pyJxqddegO2+DRo+wPaVFKS4ZLSlr8bVLt7wLHSCj7WSEZ9qYbGcbLSwo/mE6WNCkqmPYhlHEYHcLnGYx36I6oq/1QJEFFrX4VZso/h0uq+mwzg+i/H5TPGV5CCc273Oop+ART4HU3k46GlH1kxg8tFUSue+Mgv9UQDZgAACFw0dEnICpadOAL1DODpGrVs8Al/K52SEbV0+9BtkK2ka3KseFOVyjqc5fPZg5zNLFRYbexPEwKCr/z5RpvpGN9c9r8Yzqpo8y5GzY8XwTNBhAjMVEpOnD8B/ZJvKmH9WEnW0np9Lt0ildc/Jx77/fLFyQmPUKUBEQzyqXhzWY+2wNcVLgSVN3qEndrVOTjGWhFlO9hy46MsD2NV797waEBPVZZYRNBbjhE+AHe3Gho/pnApOo7pyHd+p3yVrQFJAaVfBd5f3mhX1TBcDx3AZ8SgYUm96Gdx+d5BD/M/6kBY4WYtejo24bVZSVNAz+wYJ7DYDbutkY8ppdljK2bM3ma6OZZfTlCRZMXDm3y/1vEx7yL+H1ov4qnOFVB7fFJKKfCgAml/+XdO2eEVXl8WuAhSvV8fkiVAae3ialfRxNnEVw/eoDilRCQ0HBuLbQtXBNCeM7OTPKQqFKajyowkDOeiaWq+u5/YOtwAbDzxcAWyGzX7I2vhucGI1FGQtmPF1FxdOR/6sKu2/lGLmarbsQmeYXIqiMw/9eXQVV3LjrV4Ujg7WWWIe/qAbyJx/ZaLkg1paK14l0JLBUzJNcKshtK885eb8/Mj7+RlgLBUotlZ+x7b/LFS0VNYXywRyc2aF4eBJIDeSlY+yoxJO4P8kv1HLq52JpNKkm4DOV22XVIiYZnf/S2yBMnk6NoqvPdDc+13gYfq8nh22+JZCkG+8bTPqMmHUz452V7OzqET+UB2nFTC5l0fdyWasS6GRVMv4QnSdQI="
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
        debugPrint("1==========\(parameters)")
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
                self.onedrive = OneDriveFileProvider(credential: userCredential)
                debugPrint("2==========\n\(refresh_token)")
                debugPrint("2==========access_token\(access_token)")

                
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
        var requestURL = "https://graph.microsoft.com/v1.0/me/drive/items/\(path)/children?%24expand=thumbnails&%24top=200"
        if path == "/" {
            requestURL = "https://graph.microsoft.com/v1.0/me/drive/root/children?%24expand=thumbnails&%24top=200"
        }
//        let parameters: [String: String] = [
//            "client_id": onedrive_client_id_es,
//            "redirect_uri": onedrive_redirect_uri_es,
//            "refresh_token": self.refresh_token,
//            "grant_type": "refresh_token"
//        ]
//        debugPrint("1==========\(parameters)")
//        let url = "https://graph.microsoft.com/v1.0/me/drive/items/1F2FE956E16FEC61!106/children?%24expand=thumbnails&%24top=200"
        let headers: HTTPHeaders = [
            "Authorization": "bearer " + self.access_token
        ]
        AF.request(requestURL, method: .get,headers: headers).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            if response.response?.statusCode == 401 {
                self.getNewToken()
                return
            }
            
            if let fileList = jsonDic?["value"] as? Array<[String:Any]> {
                var dataSource = [PPFileObject]()
                
                for oneDriveFile in fileList {
                    debugPrint("----------\(oneDriveFile)")
                    if let item = PPOneDriveFileObject(JSON: oneDriveFile) {
                        item.downloadLink = oneDriveFile["@microsoft.graph.downloadUrl"] as? String ?? ""
                        debugPrint("-----2222-----\(item)")
                        var isDir = false;
                        var path_ = item.downloadLink
                        if item.folder != nil {
                            isDir = true
                            path_ = item.fs_id
                        }
                        let ppFile = PPFileObject(name: item.name,
                                                  path: path_,
                                                  size: item.size,
                                                  isDirectory: isDir,
                                                  modifiedDate: item.modifiedDate ?? "",
                                                  fileID: "\(item.fs_id)",
                                                  serverID: "")
                        dataSource.append(ppFile)
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
//                    let archieveKey = "baidu_" + "\(path)"
//            PPDiskCache.shared.setData(response.data, key: path)

        }
//        onedrive.contents(path: path, completionHandler: completionHandler)
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
