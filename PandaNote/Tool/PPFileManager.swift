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
    let apiCacheDir = "WebDAV/api_"
    
    static let shared = PPFileManager()
    var webdav: WebDAVFileProvider?//未配置服务器地址时刷新可能为空

    override init() {
        super.init()
        initWebDAVSetting()
    }
    //MARK:数据处理
    func myPPFileArrayFrom(_ contents:[FileObject]) -> [PPFileObject] {
        var fileArray = [PPFileObject]()
        var dirCount = 0
        //文件夹（目录）排在前面
        let directoryFirst = true
        for item in contents {
            let localDate = item.modifiedDate?.addingTimeInterval(TimeInterval(PPUserInfo.shared.pp_timezoneOffset))
            let dateStr = String(describing: localDate).substring(9..<25)
            
            let ppFile = PPFileObject(name: item.name,
                                      path: item.path,
                                      size: item.size,
                                      isDirectory: item.isDirectory,
                                      modifiedDate: dateStr)
            //添加到结果数组
            if item.isDirectory && directoryFirst {
                fileArray.insert(ppFile, at: dirCount)
                dirCount += 1
            }
            else {
                fileArray.append(ppFile)
            }
        }
        return fileArray
    }
    //MARK:Get获取
    /// WebDAV获取文件列表
    func getWebDAVFileList(path:String,completionHander:@escaping(_ data:[AnyObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        //先从本地缓存获取数据
        PPDiskCache.shared.fetchData(key: apiCacheDir + path.pp_md5, failure: { (error) in
            if let error = error {
                if (error as NSError).code != NSFileReadNoSuchFileError {
                    DispatchQueue.main.async {
                        completionHander([],false,error)
                    }
                }
            }
            //获取本地缓存失败就去服务器获取
            self.getWebDAVData(path: path, completionHander: completionHander)
        }) { (data) in
            do {
                let archieveArray = try JSONDecoder().decode([PPFileObject].self, from: data)
                debugPrint("WebDAV获取文件列表\(archieveArray.count)")
                DispatchQueue.main.async {
                    completionHander(archieveArray as [AnyObject],true,nil)
                }
                //获取本地缓存成功了还是去服务器获取一下保证数据最新吧
                self.getWebDAVData(path: path, completionHander: completionHander)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    ///去WebDAV服务器获取数据
    func getWebDAVData(path:String,completionHander:@escaping(_ data:[AnyObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        webdav?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            do {
                let encoded = try JSONEncoder().encode(archieveArray)
//                debugPrint(String(decoding: encoded, as: UTF8.self))
                PPDiskCache.shared.setData(encoded, key: self.apiCacheDir + path.pp_md5)
            } catch {
                debugPrint(error.localizedDescription)
            }
            DispatchQueue.main.async {
                completionHander(archieveArray as [AnyObject],false,error)
            }
//            PINCache.shared().setObject(archieveArray, forKey: "img")
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
    /// 从WebDAV下载文件获取Data
    func downloadFileFromWebDAV(path: String, cacheFile: Bool? = false,completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        webdav?.contents(path: path, completionHandler: { (data, error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(data,false,error)
                    if let shouldCache = cacheFile {
                        if shouldCache {
                            PPDiskCache.shared.setData(data, key: path)
                        }
                    }
                }
            }
            else {
                debugPrint(error ?? "downloadFileFromWebDAV Error")
            }
        })
            
            
    }
    
    /// 加载文件，如果本地存在就取本地的，否则就下载远程服务器的
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - completionHandler: 完成回调
    func loadFileFromWebDAV(path: String, downloadIfExist:Bool?=false ,completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        // 1 从本地磁盘获取文件缓存
        PPDiskCache.shared.fetchData(key: path, failure: { (error) in
            // 2-2 从本地磁盘获取文件失败也从服务器获取最新的
            self.webdav?.contents(path: path, completionHandler: { (data, error) in
                if error == nil {
                    DispatchQueue.main.async {
                        PPDiskCache.shared.setDataSynchronously(data, key: path)
                        completionHandler(data,false,error)
                    }
                }
                else {
                    debugPrint(error ?? "downloadFileFromWebDAV Error")
                }
            })
            
        }) { (data) in
            // 2-1 加载成功的话还从服务器获取最新的
            debugPrint("loading local file success")
            completionHandler(data,true,nil)
            if let down = downloadIfExist {
                if down {
                    self.downloadFileFromWebDAV(path: path, cacheFile: true, completionHandler: completionHandler)
                }
                
            }
        }

    }
    /// 通过WebDAV上传到服务器
    func uploadFileViaWebDAV(path: String, contents: Data?, completionHander:@escaping(_ error:Error?) -> Void) {
        webdav?.writeContents(path: path, contents: contents, completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHander(error)
                }
            }
            else {
                debugPrint(error ?? "uploadFileViaWebDAV Error")
            }
        })
    }
    /// 通过WebDAV修改文件
    func moveFileViaWebDAV(pathOld: String, pathNew: String, completionHander:@escaping(_ error:Error?) -> Void) {
        webdav?.moveItem(path:pathOld, to: pathNew, completionHandler: { (error) in
            DispatchQueue.main.async {
                if error == nil {
                    completionHander(error)
                }
                else {
                    PPHUD.showHUDFromTop("移动文件失败",isError: true)
                }
            }
            
        })
    }
    /// 通过WebDAV 新建文件夹
    func createFolderViaWebDAV(folder folderName: String, at atPath: String, completionHander:@escaping(_ error:Error?) -> Void) {
        webdav?.create(folder: folderName, at: atPath, completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHander(error)
                }
            }
            else {
                debugPrint(error ?? "createFolderViaWebDAV Error")
            }
        })
    }
    
    
    /// 从WebDAV下载文件获取Data
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
    
    
    
    //MARK:初始化webDAV设置
    /// 初始化WebDAV设置
    func initWebDAVSetting() -> Void {
        let currentServerIndex = PPUserInfo.shared.pp_Setting["pp_lastSeverInfoIndex"] as! Int
        PPUserInfo.shared.updateCurrentServerInfo(index: currentServerIndex)
        let server = URL(string: PPUserInfo.shared.webDAVServerURL)!
        
//        let cache = URLCache(memoryCapacity: 5 * 1024 * 1024, diskCapacity: 3 * 1024 * 1024, diskPath: nil)
//        URLCache.shared = cache
        guard let user = PPUserInfo.shared.webDAVUserName,let password = PPUserInfo.shared.webDAVPassword else {
            debugPrint("无法初始化服务器")
            return
        }
        let userCredential = URLCredential(user: user,
                                           password: password,
                                           persistence: .permanent)
        //            let protectionSpace = URLProtectionSpace.init(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        //            URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!//不能加`,cache: URLCache.shared`,要不然无法保存markdown！！！
//        webdav.useCache = true
        webdav?.delegate = self
        //注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
    }
    /// 从PHAsset获取NSData
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
         webdav.create(folder: "new folder", at: "/", completionHandler: nil)
         */
    }
    
    @IBAction func createFile(_ sender: Any) {
        /*
         let data = "Hello world from sample.txt!".data(using: .utf8, allowLossyConversion: false)
         webdav.writeContents(path: "sample.txt", contents: data, atomically: true, completionHandler: nil)//?.writeContents(path: "sample.txt", content: data, atomically: true, completionHandler: nil)
         */
    }
    
    
    
    @IBAction func remove(_ sender: Any) {
        //        webdav.removeItem(path: "sample.txt", completionHandler: nil)
    }
    
    @IBAction func download(_ sender: Any) {
        /*
         let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
         let remotePath = "fileprovider.png"
         
         let progress = webdav.copyItem(path: remotePath, toLocalURL: localURL, completionHandler: nil)
         downloadProgressView?.observedProgress = progress
         */
    }
    
    @IBAction func upload(_ sender: Any) {
        /*
         let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
         let remotePath = "/fileprovider.png"
         
         let progress = webdav.copyItem(localFile: localURL, to: remotePath, completionHandler: nil)
         uploadProgressView?.observedProgress = progress
         */
    }
    
    
    
    
}
