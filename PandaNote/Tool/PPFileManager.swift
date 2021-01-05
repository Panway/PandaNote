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
    let apiCachePrefix = "APICache/api_"
    
    static let shared = PPFileManager()
    static let dateFormatter = DateFormatter()
    var webdav: WebDAVFileProvider?//未配置服务器地址时刷新可能为空
    var dropbox: DropboxFileProvider?//未配置服务器地址时刷新可能为空
    var baiduwangpan : BaiduyunAPITool?
    var baiduFSID = 0
    ///获取当前云服务读写文件的对象
    open internal(set) var currentFileProvider: HTTPFileProvider? {
        get {
            switch PPUserInfo.shared.cloudServiceType {
            case .dropbox:
                return dropbox
//            case .baiduyun:
//                return nil
//            case .onedrive:
//                return onedrive
            default:
                return webdav
            }
        }
        set {
        }
    }
    override init() {
        super.init()
        PPFileManager.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        initCloudServiceSetting()
    }
    //MARK:- 数据处理
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
    //MARK:- 文件操作
    /// 获取文件列表（先取本地再获取最新）
    func pp_getFileList(path:String,completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        //先从本地缓存获取数据
        var archieveKey = self.apiCachePrefix + "\(self.currentFileProvider?.baseURL?.absoluteString ?? "")\(path)".pp_md5
        if PPUserInfo.shared.cloudServiceType == .baiduyun {
            archieveKey = "baidu_" + "\(baiduwangpan?.baiduURL ?? "")\(path)".pp_md5
        }
        PPDiskCache.shared.fetchData(key: archieveKey, failure: { (error) in
            if let error = error {
                //忽略文件不存在错误
                if (error as NSError).code != NSFileReadNoSuchFileError {
                    DispatchQueue.main.async {
                        completionHandler([],false,error)
                    }
                }
            }
            //获取本地缓存失败就去服务器获取
            self.getRemoteFileList(path: path, completionHandler: completionHandler)
        }) { (data) in
            do {
                let archieveArray = try JSONDecoder().decode([PPFileObject].self, from: data)
                debugPrint("获取解档文件个数\(archieveArray.count)")
                DispatchQueue.main.async {
                    completionHandler(archieveArray,true,nil)
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
            //获取本地缓存成功了还是去服务器获取一下,保证数据最新
            self.getRemoteFileList(path: path, completionHandler: completionHandler)
        }
    }
    ///去WebDAV服务器获取数据
    func getWebDAVFileList(path:String,completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        currentFileProvider?.contentsOfDirectory(path: path, completionHandler: {
            contents, error in
            let archieveArray = self.myPPFileArrayFrom(contents)
            do {
                let encoded = try JSONEncoder().encode(archieveArray)
//                debugPrint(String(decoding: encoded, as: UTF8.self))
                let archieveKey = self.apiCachePrefix + "\(self.currentFileProvider?.baseURL?.absoluteString ?? "")\(path)".pp_md5
                PPDiskCache.shared.setData(encoded, key:archieveKey)
            } catch {
                debugPrint(error.localizedDescription)
            }
            DispatchQueue.main.async {
                completionHandler(archieveArray,false,error)
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
    ///去服务器获取数据
    func getRemoteFileList(path:String,completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        if PPUserInfo.shared.cloudServiceType == .baiduyun {
            baiduwangpan?.getFileList(path: path, completionHandler: completionHandler)
        }
        else {
            getWebDAVFileList(path: path, completionHandler: completionHandler)
        }
    }
    /// 从WebDAV下载文件获取Data
    func downloadFileFromWebDAV(path: String, cacheToDisk: Bool? = false,completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        currentFileProvider?.contents(path: path, completionHandler: { (data, error) in
            if let error = error {
                debugPrint("下载失败：\(error.localizedDescription)")
                return
            }
            if let shouldCacheToDisk = cacheToDisk, shouldCacheToDisk == true {
                PPDiskCache.shared.setData(data, key:  PPUserInfo.shared.webDAVRemark + path)
            }
            DispatchQueue.main.async {
                completionHandler(data,false,error)
            }
        })
            
            
    }
    
    /// 加载文件，如果本地存在就取本地的，否则就下载远程服务器的
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - completionHandler: 完成回调
    func loadFileFromWebDAV(path: String, downloadIfExist:Bool?=false ,completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        // 1 从本地磁盘获取文件缓存
        PPDiskCache.shared.fetchData(key: PPUserInfo.shared.webDAVRemark + path, failure: { (error) in
            // 2-2 本地磁盘没有，就从服务器获取最新的
            self.downloadFileFromWebDAV(path: path, cacheToDisk: true, completionHandler: completionHandler)
            
        }) { (data) in
            // 2-1 本地磁盘有，按需从服务器获取最新的
            debugPrint("loading local file success")
            completionHandler(data,true,nil)
            if let down = downloadIfExist,down == true {
                self.downloadFileFromWebDAV(path: path, cacheToDisk: true, completionHandler: completionHandler)
            }
        }

    }
    
    /// 获取文件内容
    /// - Parameters:
    ///   - path: 路径
    ///   - fileID: 文件ID，百度网盘是fs_id
    ///   - cacheToDisk: 缓存到本地磁盘
    ///   - downloadIfCached: 如果有缓存是否再次下载
    ///   - completionHandler: 完成的回调
    func getFileData(path: String,
                     fileID:String?,
                     cacheToDisk:Bool?=false ,
                     downloadIfCached:Bool?=false ,
                     completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        if PPUserInfo.shared.cloudServiceType == .baiduyun {
            let downloadIfCached = path.pp_isImageFile() || path.pp_isVideoFile()
            baiduwangpan?.contents(path: path,
                                   fs_id:fileID ?? "",
                                   downloadIfCached:!downloadIfCached,
                                   completionHandler: { (data, isFromDisk, error) in
                if let error = error {
                    debugPrint("下载失败：\(error.localizedDescription)")
                    return
                }
                if let shouldCacheToDisk = cacheToDisk, shouldCacheToDisk == true {
                    let archieveKey = "baidu_" + "\(self.baiduwangpan?.baiduURL ?? "")\(path)".pp_md5
                    PPDiskCache.shared.setData(data, key: archieveKey)
                }
                DispatchQueue.main.async {
                    completionHandler(data,false,error)
                }
            })
        }
        else {
            loadFileFromWebDAV(path: path, completionHandler: completionHandler)
        }
    }
    /// 通过WebDAV上传到服务器
    func uploadFileViaWebDAV(path: String, contents: Data?, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentFileProvider?.writeContents(path: path, contents: contents, completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
            }
            else {
                debugPrint(error ?? "uploadFileViaWebDAV Error")
            }
        })
    }
    /// 通过WebDAV修改文件
    func moveFileViaWebDAV(pathOld: String, pathNew: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentFileProvider?.moveItem(path:pathOld, to: pathNew, completionHandler: { (error) in
            DispatchQueue.main.async {
                if error == nil {
                    completionHandler(error)
                }
                else {
                    PPHUD.showHUDFromTop("移动文件失败",isError: true)
                }
            }
            
        })
    }
    /// 通过WebDAV 新建文件夹
    func createFolderViaWebDAV(folder folderName: String, at atPath: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentFileProvider?.create(folder: folderName, at: atPath, completionHandler: { (error) in
            if error == nil {
                DispatchQueue.main.async {
                    completionHandler(error)
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
    
    
    
    //MARK:- webDAV、云服务设置
    /// 初始化WebDAV设置
    @discardableResult
    func initCloudServiceSetting() -> Bool {
        PPUserInfo.shared.updateCurrentServerInfo(index: PPUserInfo.shared.pp_lastSeverInfoIndex)
        
//        let cache = URLCache(memoryCapacity: 5 * 1024 * 1024, diskCapacity: 3 * 1024 * 1024, diskPath: nil)
//        URLCache.shared = cache
        guard let user = PPUserInfo.shared.webDAVUserName,let password = PPUserInfo.shared.webDAVPassword else {
            debugPrint("无法初始化服务器")
            PPHUD.showHUDFromTop("无法初始化服务器,请添加", isError: true)
            return false
        }
        let userCredential = URLCredential(user: user,
                                           password: password,
                                           persistence: .permanent)
        if PPUserInfo.shared.cloudServiceType == .dropbox {
            dropbox = DropboxFileProvider(credential: userCredential)
        }
        else if PPUserInfo.shared.cloudServiceType == .baiduyun {
            baiduwangpan = BaiduyunAPITool(access_token: password)
        }
        else {
            let server = URL(string: PPUserInfo.shared.webDAVServerURL)!
        //            let protectionSpace = URLProtectionSpace.init(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        //            URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!//不能加`,cache: URLCache.shared`,要不然无法保存markdown！！！
//        webdav.useCache = true
        webdav?.delegate = self
        //注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
            currentFileProvider = webdav
        }
        return true
    }
    /// 从PHAsset获取NSData
    func getImageDataFromAsset(asset: PHAsset, completion: @escaping (_ data: NSData?,_ fileURL:URL?,_ imageInfo:[String:String]) -> Void) {
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
            let imageInfo = ["creationDate":(asset.creationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "modificationDate":(asset.modificationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "pixelWidth":"\(asset.pixelWidth)",
                             "pixelHeight":"\(asset.pixelHeight)"]
            if let imageData = imgData {
                completion(imageData as NSData,url,imageInfo)
            } else {
                completion(nil,url,imageInfo)
            }
        }
//        }
        
        
    }
    //https://stackoverflow.com/a/59869659
    ///删除相册图片
    func deletePhotos(_ assetsToDeleteFromDevice:[PHAsset]) {
        let assetIdentifiers = assetsToDeleteFromDevice.map({ $0.localIdentifier })
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        })
    }
    func getImageDataFromPHAsset(asset: PHAsset) -> Data {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        
        return Data()
    }
    //MARK:- FileProviderDelegate
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
    
    //MARK:- deprecated废弃的方法
    func loadAndSaveImage(imageURL:String,completionHandler: ((Data) -> Void)? = nil) {
        let imagePath = PPUserInfo.shared.pp_mainDirectory + imageURL

        if FileManager.default.fileExists(atPath: imagePath) {
            let imageData = try?Data(contentsOf: URL(fileURLWithPath: imagePath))
            if let handler = completionHandler {
                    handler(imageData!)
            }
            
            /*
            if ((cachedData) == nil) {//KingFisher用
                //DefaultCacheSerializer会对大图压缩后缓存，所以这里用自定义序列化类实现缓存原始图片数据
                cache.store(UIImage.init(data: imageData! )!, original: imageData, forKey: imageURL, processorIdentifier: "", cacheSerializer: PandaCacheSerializer.default, toDisk: true) {
                }
                //cache.store(UIImage.init(data: imageData! )!, original: imageData, forKey:fileObj.path )
            }
 */
        }
        else {
            PPFileManager.shared.currentFileProvider?.contents(path: imageURL, completionHandler: {
                contents, error in
                guard let contents = contents else {
                    return
                }
                if !FileManager.default.fileExists(atPath: PPUserInfo.shared.pp_mainDirectory + imageURL) {
                    do {
                        var array = imageURL.split(separator: "/")
                        array.removeLast()
                        let newStr:String = array.joined(separator: "/")
                        try FileManager.default.createDirectory(atPath: PPUserInfo.shared.pp_mainDirectory+"/"+newStr, withIntermediateDirectories: true, attributes: nil)
                    } catch  {
                        debugPrint("==FileManager Crash")
                    }
                }
                
                FileManager.default.createFile(atPath: PPUserInfo.shared.pp_mainDirectory + imageURL, contents: contents, attributes: nil)
                
                if let handler = completionHandler {
                    handler(contents)
                }
                
            })
            
        }
    }
    
}
