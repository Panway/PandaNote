//
//  PPFileManager.swift
//  PandaNote
//
//  Created by Panway on 2019/9/19.
//  Copyright © 2019 Panway. All rights reserved.
//

import Foundation
import Photos
import FilesProvider
import Alamofire
//import PINCache

class PPFileManager: NSObject,FileProviderDelegate {
    let apiCachePrefix = "APICache/api_"
    
    static let shared = PPFileManager()
    static let dateFormatter = DateFormatter()
    var webdavService : PPWebDAVService?
    var dropbox: PPDropboxService?//未配置服务器地址时刷新可能为空
    var localFileService: PPLocalFileService?
    var oneDriveService: PPOneDriveService?
    var alistService: PPAlistService?
    var aliyunDriveService: PPAliyunDriveService?
    var baiduwangpan : BaiduyunAPITool?
    var currentPath = ""
    var baiduFSID = 0
    /// 下载保存的文件路径，只读
    public var downloadPath:String {
        get {
            return "\(PPDiskCache.shared.path)/\(currentService?.baseURL.pp_md5 ?? "fileCache")"
        }
    }

    ///获取当前云服务读写文件的对象
    open internal(set) var currentService: PPCloudServiceProtocol? {
        get {
            switch PPUserInfo.shared.cloudServiceType {
            case .dropbox:
                return dropbox
            case .webdav:
                return webdavService
            case .onedrive:
                return oneDriveService
            case .baiduyun:
                return baiduwangpan
            case .alist:
                return alistService
            case .aliyundrive:
                return aliyunDriveService
            default:
                return localFileService
            }
        }
        set {
        }
    }
    override init() {
        super.init()
        PPFileManager.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        initCloudServiceSetting()//初始化服务器配置
    }
    //MARK: get file
    /// 获取文件列表对象数组然后缓存
    private func getFileListThenCache(path:String,
                                      pathID:String? = "",
                                      archieveKey:String,
                                      completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        if let pathID = pathID,pathID.length > 0 {
            currentService?.contentsOfPathID(pathID, completionHandler: { fileList, error in
                do {
                    let encoded = try JSONEncoder().encode(fileList)
                    PPDiskCache.shared.setData(encoded, key:archieveKey)
                } catch {
                    debugPrint(error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completionHandler(fileList,false,error)
                }
            })
            return
        }
        //获取本地缓存失败就去服务器获取
        currentService?.contentsOfDirectory(path, completionHandler: { fileList, error in
            if error == nil {
                let encoded = try? JSONEncoder().encode(fileList)
                PPDiskCache.shared.setData(encoded, key:archieveKey)
            }
            DispatchQueue.main.async {
                completionHandler(fileList,false,error)
            }
        })
    }
    //MARK:- 文件列表操作
    /// 获取文件列表（先取本地再获取最新）
    func pp_getFileList(path:String,pathID:String,completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        self.currentPath = path
        //先获取本地缓存数据
        let archieveKey = self.apiCachePrefix + "\(self.currentService?.baseURL ?? "")\(path)".pp_md5
        PPDiskCache.shared.fetchData(key: archieveKey, failure: { (error) in
            //哎，忘了为啥这么写
//            if let error = error {
//                //忽略文件不存在错误
//                if (error as NSError).code != NSFileReadNoSuchFileError {
//                    DispatchQueue.main.async {
//                        completionHandler([],false,error)
//                    }
//                }
//            }
        }) { (data) in
            guard let fileData = data else {
                debugPrint("获取文件数据失败")
                return
            }
            do {
                let archieveArray = try JSONDecoder().decode([PPFileObject].self, from: fileData)
                debugPrint("获取解档文件个数\(archieveArray.count)")
                DispatchQueue.main.async {
                    completionHandler(archieveArray,true,nil)
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        //获取本地缓存成功了还是去服务器获取一下,保证数据最新
        self.getFileListThenCache(path: path,pathID:pathID, archieveKey: archieveKey, completionHandler: completionHandler)
    }
    
    //MARK:- 文件操作
    /// 从WebDAV下载文件获取Data
    func downloadFile(path: String,
                      fileID: String?,
                      cacheToDisk: Bool? = false,
                      completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        // 局部闭包
        let handleResult = { (_ data:Data?,_ error:Error?) -> Void in
            if let error = error {
                debugPrint("下载失败：\(error.localizedDescription)")
                return
            }
            if let shouldCacheToDisk = cacheToDisk, shouldCacheToDisk == true {
                PPDiskCache.shared.setDataSynchronously(data, key:  PPUserInfo.shared.webDAVRemark + path)
            }
            DispatchQueue.main.async {
                completionHandler(data,false,error)
            }
        }
        
        if PPUserInfo.shared.cloudServiceType == .baiduyun {
            let downloadIfCached = path.pp_isImageFile() || path.pp_isVideoFile()
            baiduwangpan?.contents(path: path,
                                   fs_id:fileID ?? "",
                                   downloadIfCached:!downloadIfCached,
                                   completionHandler: { (data, isFromDisk, error) in
                handleResult(data,error)
            })
        }
        currentService?.contentsOfFile(path, completionHandler: { data, error in
            handleResult(data, error)
        })
            
            
    }
    
    /// 加载文件，如果本地存在就取本地的，否则就下载远程服务器的
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - completionHandler: 完成回调
    private func getRemoteOrLocalFile(path: String,
                                      fileID:String?,
                            downloadIfExist : Bool? = false,
                            onlyCheckIfFileExist : Bool? = false,
                            completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        // 1 从本地磁盘获取文件缓存
        PPDiskCache.shared.fetchData(key: PPUserInfo.shared.webDAVRemark + path,onlyCheckIfFileExist:onlyCheckIfFileExist, failure: { (error) in
            // 2-2 本地磁盘没有，就从服务器获取最新的
            self.downloadFile(path: path, fileID:fileID, cacheToDisk: true, completionHandler: completionHandler)
        }) { (data) in
            // 2-1 本地磁盘有，按需从服务器获取最新的
            debugPrint("local file loaded")
            completionHandler(data,true,nil)
            if downloadIfExist == true {//即使本地有文件也重新下载
                self.downloadFile(path: path, fileID:fileID, cacheToDisk: true, completionHandler: completionHandler)
            }
        }

    }
    
    /// 获取文件二进制Data
    /// - Parameters:
    ///   - path: 路径
    ///   - fileID: 文件ID，百度网盘是fs_id
    ///   - cacheToDisk: 缓存到本地磁盘
    ///   - downloadIfCached: 如果有缓存是否再次下载
    ///   - completionHandler: 完成的回调
    func getFileData(path: String,
                     fileID:String?,
                     downloadURL:String? = nil,
                     cacheToDisk:Bool?=false ,
                     downloadIfCached:Bool?=false ,
                     onlyCheckIfFileExist : Bool? = false,
                     completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        if let downloadURL = downloadURL,downloadURL.length > 1 {
            AF.request(downloadURL).response { response in
                var localPath = PPUserInfo.shared.webDAVRemark + "/" + path
                localPath = localPath.replacingOccurrences(of: "//", with: "/")
                PPDiskCache.shared.setData(response.data, key: localPath)
                completionHandler(response.data, false,nil)
            }
            return
        }
        getRemoteOrLocalFile(path: path,
                             fileID:fileID,
                               downloadIfExist:downloadIfCached,
                               onlyCheckIfFileExist:onlyCheckIfFileExist,
                               completionHandler: completionHandler)
    }
    /// 无法修改的图片视频等文件，缓存到本地后返回本地URL
    func getFileURL(path:String,
                    fileID:String?,
                    downloadURL:String? = nil,
                    completion: @escaping (( _ url:String) -> Void)) {
        getFileData(path: path,
                    fileID: fileID,
                    downloadURL: downloadURL,
                    cacheToDisk:true,
                    onlyCheckIfFileExist:true) { (contents: Data?,isFromCache, error) in
            if error != nil {
                return
            }
            let filePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(path)"
            completion(filePath)
        }
    }
    //MARK: add file
    /// 通过WebDAV上传到服务器
    func createFile(path: String, parentID:String? = nil,contents: Data?, completionHandler:@escaping(_ error:Error?) -> Void) {
        guard let contents = contents else {
            DispatchQueue.main.async {
                PPHUD.showHUDFromTop("空文件",isError: true)
            }
            return
        }
        currentService?.createFile(atPath: path, contents: contents, completionHandler: { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        })
    }
    /// 移动文件（夹）、重命名文件（夹）
    func moveRemoteFile(pathOld: String, pathNew: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentService?.moveItem(atPath: pathOld, toPath: pathNew, completionHandler: { error in
            DispatchQueue.main.async {
                if error != nil {
                    PPHUD.showHUDFromTop("移动文件失败",isError: true)
                    return
                }
                let downloadPath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)"
                //移动本地的文件
                if FileManager.default.fileExists(atPath: downloadPath + pathOld) {
                    try? FileManager.default.moveItem(atPath: downloadPath + pathOld,
                                                      toPath: downloadPath + pathNew)
                }
                completionHandler(error)
            }
        })
    }
    /// 通过WebDAV 新建文件夹
    func createFolder(folder folderName: String, at atPath: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentService?.createDirectory(folderName, at: atPath, completionHandler: { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        })
    }
    //删除远程服务器的文件
    func deteteFile(path: String, pathID:String? = nil,completionHandler:@escaping(_ error:Error?) -> Void) {
        if let pathID = pathID, pathID.length > 0,
            PPUserInfo.shared.cloudServiceType == .aliyundrive {
            currentService?.removeItemByID(pathID, completionHandler: completionHandler)
            return
        }
        currentService?.removeItem(atPath: path, completionHandler: { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        })
    }
    
    /// 从WebDAV下载文件获取Data
    func searchFile(path: String, searchText: String?,completionHandler: @escaping ((_ files: [PPFileObject], _ isFromCache:Bool, _ error: Error?) -> Void)) {
        //TODO:webdav
            
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
        switch PPUserInfo.shared.cloudServiceType {
        case .dropbox:
            dropbox = PPDropboxService(access_token: password)
        case .baiduyun:
            baiduwangpan = BaiduyunAPITool(access_token: password)
        case .onedrive:
            let refresh_token = PPUserInfo.shared.cloudServiceExtra
            oneDriveService = PPOneDriveService(access_token: password,
                                                refresh_token: refresh_token)
        case .alist:
            alistService = PPAlistService(url:PPUserInfo.shared.webDAVServerURL,
                                          username: user,
                                          password: password)
        case .aliyundrive:
            aliyunDriveService = PPAliyunDriveService(access_token: PPUserInfo.shared.cloudServiceToken, refresh_token: "")
        case .local:
            localFileService = PPLocalFileService()
        case .webdav:
            webdavService = PPWebDAVService(url: PPUserInfo.shared.webDAVServerURL,
                                            username: user,
                                            password: password)
        default:
            debugPrint("not init Cloud Service")
        }
        return true
    }
    //MARK: 图片（PHAsset）相关处理
    /// 从PHAsset获取NSData
    func getImageDataFromAsset(asset: PHAsset, completion: @escaping (_ data: Data?,_ fileURL:String,_ imageInfo:[String:String]) -> Void) {
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
        let imageInfoDict = ["creationDate":(asset.creationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "modificationDate":(asset.modificationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "pixelWidth":"\(asset.pixelWidth)",
                             "pixelHeight":"\(asset.pixelHeight)"]
        //如果是视频
        if asset.mediaType == .video {
            requestVideoURL(with: asset) { url in
                if let vURL = url {
                    let videoData = try? Data(contentsOf: vURL)
                    completion(videoData,url?.absoluteString ?? "",imageInfoDict)
                }
            }
            return
        }
        // 如果上传前需要压缩图片
        if PPUserInfo.pp_boolValue("pp_compressImageBeforeUpload") {
            manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: options) { (restulImage, imageInfo) in
                //https://developer.apple.com/documentation/photokit/phimagemanager/1616964-requestimage
                //这里会回调两次，第一次是低质量的图像数据，当高质量的图像准备好后，照片会再次回调到这里
                let isDegraded = (imageInfo?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                   return//降级的，低质量的图片略缩图不要 https://stackoverflow.com/a/52355835/4493393
                }
                debugPrint("pick image size:",restulImage?.size)
                var originalFilename = "noname.jpg" //默认值，实际上不会出现
                if let name = PHAssetResource.assetResources(for: asset).first?.originalFilename {
                    originalFilename = name
                }
                var compressionQuality = CGFloat(0.5)
                if let compressionQ = PPUserInfo.shared.pp_Setting["pp_imageCompressionQuality"] as? String {
                    compressionQuality = NumberFormatter().number(from: compressionQ) as? CGFloat ?? CGFloat(0.5)
                }
                //"IMG_0111.HEIC" -> "IMG_0111.jpg"
                originalFilename = String(originalFilename.split(separator: ".")[0]) + ".jpg"
                if let imageData = restulImage?.jpegData(compressionQuality: compressionQuality) {
                    completion(imageData, originalFilename, imageInfoDict)
                } else {
                    completion(nil, originalFilename, [:]) //理论上不会走
                }
            }
            return
        }
        
        // 原图上传
        manager.requestImageData(for: asset, options: options) { (imgData, string, orientation, info) -> Void in
            asset.pp_getURL { responseURL in
                var url = responseURL?.absoluteString ?? ""
                if url.length < 1 {
                    url = asset.value(forKey: "filename") as! String //理论上不会走
                }
                if let imageData = imgData {
                    completion(imageData,url,imageInfoDict)
                } else {
                    completion(nil,url,imageInfoDict)
                }
            }
        }

        
        
    }
    func requestVideoURL(with asset: PHAsset?, success: @escaping (_ videoURL: URL?) -> Void) {
        if let asset = asset {
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { avasset, audioMix, info in
                // NSLog(@"AVAsset URL: %@",myAsset.URL);
                if avasset is AVURLAsset {
                    let url = (avasset as? AVURLAsset)?.url
                        success(url)
                }
            })
        }
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
    //   let myQueue = DispatchQueue.global()
    //    group.enter()//
    //    myQueue.async(group: group, qos: .default, flags: [], execute: {
    //    for _ in 0...10 {
    //    print("耗时任务一")
    //    group.leave()//执行完之后从组队列中移除
    //    }
    //    })
    //上传多张图片
    func uploadPhotos(_ mediaItems:[PHAsset], completion: ((_ uploadedAssets:[PHAsset]) -> Void)? = nil) {
        let group = DispatchGroup()
        var assetsToDeleteFromDevice = [PHAsset]()
        let path = self.currentPath
        //多图上传
        for asset in mediaItems {
            group.enter() // 将以下任务添加进group，相当于把某个任务添加到组队列中执行
            PPFileManager.shared.getImageDataFromAsset(asset: asset, completion: { (imageData,urlString,imageInfo) in
                let uploadName = PPFileManager.imageVideoName(urlString: urlString, imageInfo: imageInfo)
                let remotePath = path + uploadName
//                debugPrint(imageLocalURL)
                
                PPFileManager.shared.createFile(path: remotePath, contents: imageData) { (error) in
                    if let error = error {
                        debugPrint("上传出错:\(error.localizedDescription)")
                        return
                    }
                    PPHUD.showHUDFromTop("上传+1")
                    assetsToDeleteFromDevice.append(asset)
                    group.leave() //本次任务完成（即本次for循环任务完成），将任务从group中移除
                }
                
            })
            
        }
        
        //当上面所有的任务执行完之后通知 (timeout: .now() + 5)
        group.notify(queue: .main) {
            PPHUD.showHUDFromTop("全部上传成功🦄")
            debugPrint("所有的上传任务执行完了")
            if let completion = completion {
                completion(assetsToDeleteFromDevice)
            }
            if PPUserInfo.pp_boolValue("deletePhotoAfterUploading") {
                PPFileManager.shared.deletePhotos(assetsToDeleteFromDevice)
            }
        }

    }
    
    /// 当前服务器配置信息的唯一标识
    func currentServerUniqueID() -> String {
        return "\(PPUserInfo.shared.webDAVServerURL)_\(PPUserInfo.shared.webDAVUserName ?? "")"
    }
    //"file:///var/mobile/Media/DCIM/119APPLE/IMG_9828.JPG" --> "IMG_9828.JPG"
    class func imageVideoName(urlString:String,imageInfo:[String:String]) -> String{
        var uploadName = urlString
        if urlString.starts(with: "/") || urlString.starts(with: "file:///") {
            let imageLocalURL = URL(fileURLWithPath: urlString)
            uploadName = imageLocalURL.lastPathComponent
        }
        //使用创建时间当文件名
        if let creationDate = imageInfo["creationDate"], PPUserInfo.pp_boolValue("uploadImageNameUseCreationDate") {
            uploadName = creationDate.replacingOccurrences(of: ":", with: ".") + "." + uploadName.split(separator: ".").last!
        }
        return uploadName
    }
    //MARK: - FileProviderDelegate（暂未使用）
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
            PPFileManager.shared.currentService?.contentsOfFile(imageURL, completionHandler: {
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
