//
//  PPFileManager.swift
//  PandaNote
//
//  Created by panwei on 2019/9/19.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation
import Photos
import FilesProvider
import PINCache

class PPFileManager: NSObject,FileProviderDelegate {
    
    
    static let sharedManager = PPFileManager()
    var webdav: WebDAVFileProvider?

    override init() {
        super.init()
        initWebDAVSetting()
    }
    func getWebDAVData(path:String,completionHander:@escaping(_ data:[AnyObject],_ error:Error?) -> Void) {
        webdav?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            
            DispatchQueue.main.async {
                completionHander(contents,error)
            }
//            PINCache.shared().setObject(contents, forKey: "img")

//            let key = (PPUserInfo.shared.webDAVServerURL ?? " ") + path
//            let cacheData = Data.init(contents)
//            PPDiskCache.shared.setData(cacheData, key: key)
            /*
             for file in contents {
             print("Name: \(file.name)")
             print("Size: \(file.size)")
             print("Creation Date: \(String(describing: file.creationDate))")
             print("Modification Date: \(String(describing: file.modifiedDate))")
             }
             */
        })
    }

    func downloadFileViaWebDAV(path: String, completionHandler: @escaping ((_ contents: Data?, _ error: Error?) -> Void)) {
        PPFileManager.sharedManager.webdav?.contents(path: path, completionHandler: { (data, error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(data,error)
                }
            }
            else {
                debugPrint(error ?? "downloadFileViaWebDAV Error")
            }
        })
            
    }
    func uploadFileViaWebDAV(path: String, contents: Data?, completionHander:@escaping(_ error:Error?) -> Void) {
        PPFileManager.sharedManager.webdav?.writeContents(path: path, contents: contents, completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHander(error)
                }
            }
            else {
                debugPrint(error ?? "uploadFileViaWebDAV Error")
            }
        })
//        PPFileManager.sharedManager.webdav?.copyItem(localFile: imageLocalURL, to: remotePath, completionHandler: { (error) in
//        })

        
    }
    func fileproviderSucceed(_ fileProvider: FileProviderOperations, operation: FileOperationType) {
        
    }
    
    func fileproviderFailed(_ fileProvider: FileProviderOperations, operation: FileOperationType, error: Error) {
        
    }
    
    func fileproviderProgress(_ fileProvider: FileProviderOperations, operation: FileOperationType, progress: Float) {
        
    }
    //MARK:初始化webDAV设置
    func initWebDAVSetting() -> Void {
        let userInfo = PPUserInfo.shared
        var server:URL
        if let serverTMP: URL = URL(string: userInfo.webDAVServerURL ?? "") {
            server = serverTMP
        }
        else {
            return
        }
        
        
        //        let server: URL = URL(string: userInfo.webDAVServerURL!) ?? NSURL.init() as URL
        //        }
        //        if let server: URL = URL(string: PPUserInfo.shared.webDAVServerURL ?? "") {
        
        let userCredential = URLCredential(user: userInfo.webDAVUserName ?? "",
                                           password: userInfo.webDAVPassword ?? "",
                                           persistence: .permanent)
        //            let protectionSpace = URLProtectionSpace.init(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        //            URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!
        webdav?.delegate = self
        //注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
        //            webdav?.useCache = true
//        self.perform(Selector(("getData:")), with: self, afterDelay: 1)
        
    }
    /// 获取NSData
    func getImageDataFromAsset(asset: PHAsset, completion: @escaping (_ data: NSData?,_ fileURL:URL?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
//        if #available(iOS 13, *) {
//            manager.requestImageDataAndOrientation(for: asset, options: options) { (imgData, string, orientation, info) in
//                var url : URL
//                if ((info?["PHImageFileURLKey"]) != nil) {
//                    url = info?["PHImageFileURLKey"] as! URL
//                }
//                else {
//                    url = URL(fileURLWithPath: info?["PHImageFileUTIKey"] as! String)
//                }
//
//                if let imageData = imgData {
//                    completion(imageData as NSData,url)
//                } else {
//                    completion(nil,url)
//                }
//            }
//        } else {
        manager.requestImageData(for: asset, options: options) { (imgData, string, orientation, info) -> Void in
            var url : URL
            if ((info?["PHImageFileURLKey"]) != nil) {
                url = info?["PHImageFileURLKey"] as! URL
            }
            else {
                url = URL(fileURLWithPath: asset.value(forKey: "filename") as! String)
            }
            
            if let imageData = imgData {
                completion(imageData as NSData,url)
            } else {
                completion(nil,url)
            }
        }
//        }
        
        
    }
    
    func getImageDataFromPHAsset(asset: PHAsset) -> Data {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        
        return Data()
    }
}
