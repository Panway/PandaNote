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
//            PPDiskCache.shared.setData(contents, key: path)
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

    func downloadFileViaWebDAV(path: String, cacheFile: Bool? = false,completionHandler: @escaping ((_ contents: Data?, _ error: Error?) -> Void)) {
        PPFileManager.sharedManager.webdav?.contents(path: path, completionHandler: { (data, error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(data,error)
                    if let shouldCache = cacheFile {
                        if shouldCache {
                            PPDiskCache.shared.setData(data, key: path)
                        }
                    }
                }
            }
            else {
                debugPrint(error ?? "downloadFileViaWebDAV Error")
            }
        })
            
            
    }
    
    /// 加载文件，如果本地存在就取本地的，负责下载远程的
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - completionHandler: 完成回调
    func loadFile(path: String, downloadIfExist:Bool?=false ,completionHandler: @escaping ((_ contents: Data?, _ error: Error?) -> Void)) {
        PPDiskCache.shared.fetchData(key: path, failure: { (error) in
            
            PPFileManager.sharedManager.webdav?.contents(path: path, completionHandler: { (data, error) in
                if error == nil {
                    DispatchQueue.main.async {
                        PPDiskCache.shared.setDataSynchronously(data, key: path)
                        completionHandler(data,error)
                    }
                }
                else {
                    debugPrint(error ?? "downloadFileViaWebDAV Error")
                }
            })
            
        }) { (data) in
            debugPrint("loading local file success")
            completionHandler(data,nil)
            if let down = downloadIfExist {
                if down {
                    self.downloadFileViaWebDAV(path: path, cacheFile: true, completionHandler: completionHandler)
                }
                
            }
        }

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
//        let cache = URLCache(memoryCapacity: 5 * 1024 * 1024, diskCapacity: 3 * 1024 * 1024, diskPath: nil)
//        URLCache.shared = cache
        let userCredential = URLCredential(user: userInfo.webDAVUserName ?? "",
                                           password: userInfo.webDAVPassword ?? "",
                                           persistence: .permanent)
        //            let protectionSpace = URLProtectionSpace.init(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        //            URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential,cache: URLCache.shared)!
        webdav?.useCache = true
        webdav?.delegate = self
        //注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
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
    //MARK:FileProviderDelegate
    func fileproviderSucceed(_ fileProvider: FileProviderOperations, operation: FileOperationType) {
        switch operation {
        case .copy(source: let source, destination: let dest):
            print("\(source) copied to \(dest).")
        case .remove(path: let path):
            print("\(path) has been deleted.")
        default:
            if let destination = operation.destination {
                print("\(operation.actionDescription) from \(operation.source) to \(destination) succeed.")
            } else {
                print("\(operation.actionDescription) on \(operation.source) succeed.")
            }
        }
    }
    
    func fileproviderFailed(_ fileProvider: FileProviderOperations, operation: FileOperationType, error: Error) {
        switch operation {
        case .copy(source: let source, destination: let dest):
            print("copying \(source) to \(dest) has been failed.")
        case .remove:
            print("file can't be deleted.")
        default:
            if let destination = operation.destination {
                print("\(operation.actionDescription) from \(operation.source) to \(destination) failed.")
            } else {
                print("\(operation.actionDescription) on \(operation.source) failed.")
            }
        }
    }
    
    func fileproviderProgress(_ fileProvider: FileProviderOperations, operation: FileOperationType, progress: Float) {
        switch operation {
        case .copy(source: let source, destination: let dest) where dest.hasPrefix("file://"):
            print("Downloading \(source) to \((dest as NSString).lastPathComponent): \(progress * 100) completed.")
        case .copy(source: let source, destination: let dest) where source.hasPrefix("file://"):
            print("Uploading \((source as NSString).lastPathComponent) to \(dest): \(progress * 100) completed.")
        case .copy(source: let source, destination: let dest):
            print("Copy \(source) to \(dest): \(progress * 100) completed.")
        default:
            break
        }
    }
    @IBAction func createFolder(_ sender: Any) {
        /*
         webdav?.create(folder: "new folder", at: "/", completionHandler: nil)
         */
    }
    
    @IBAction func createFile(_ sender: Any) {
        /*
         let data = "Hello world from sample.txt!".data(using: .utf8, allowLossyConversion: false)
         webdav?.writeContents(path: "sample.txt", contents: data, atomically: true, completionHandler: nil)//?.writeContents(path: "sample.txt", content: data, atomically: true, completionHandler: nil)
         */
    }
    
    
    
    @IBAction func remove(_ sender: Any) {
        //        webdav?.removeItem(path: "sample.txt", completionHandler: nil)
    }
    
    @IBAction func download(_ sender: Any) {
        /*
         let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
         let remotePath = "fileprovider.png"
         
         let progress = webdav?.copyItem(path: remotePath, toLocalURL: localURL, completionHandler: nil)
         downloadProgressView?.observedProgress = progress
         */
    }
    
    @IBAction func upload(_ sender: Any) {
        /*
         let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
         let remotePath = "/fileprovider.png"
         
         let progress = webdav?.copyItem(localFile: localURL, to: remotePath, completionHandler: nil)
         uploadProgressView?.observedProgress = progress
         */
    }
    
    
    
    
}
