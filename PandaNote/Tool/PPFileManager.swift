//
//  PPFileManager.swift
//  PandaNote
//
//  Created by Panway on 2019/9/19.
//  Copyright © 2019 Panway. All rights reserved.
//

import Foundation
import Photos
import Alamofire
//import PINCache

class PPFileManager: NSObject {
    let apiCachePrefix = "APICache/api_"
    
    static let shared = PPFileManager()
    static let dateFormatter = DateFormatter()
    var webdavService : PPWebDAVService?
    var dropbox: PPDropboxService?//未配置服务器地址时刷新可能为空
    var localFileService: PPLocalFileService?
    var oneDriveService: PPOneDriveService?
    var iCloudService: PPiCloudDriveService?
    var alistService: PPAlistService?
    var synologyService: PPSynologyService?
    var aliyunDriveService: PPAliyunDriveService?
    var baiduwangpan : BaiduyunAPITool?
    private var currentPath = ""
    var currentPathID = "" ///< 阿里云盘等需要
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
            case .synology:
                return synologyService
            case .aliyundrive:
                return aliyunDriveService
            case .icloud:
                return iCloudService
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
    //MARK: - 文件列表操作
    /// 获取文件列表（先取本地再获取最新）
    func pp_getFileList(path:String, pathID:String, disableCache:Bool = false,completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        self.currentPath = path
        self.currentPathID = pathID
        //禁用缓存的话直接取远程数据
        if disableCache ||
            PPUserInfo.shared.cloudServiceType == .local ||
            PPUserInfo.shared.cloudServiceType == .icloud {
            currentService?.contentsOfDirectory(path, pathID, completion: { fileList, error in
                completionHandler(fileList,false,error)
            })
            return
        }
        //获取本地缓存成功了还是去服务器获取一下,保证数据最新
        //先获取本地缓存数据
        let archieveKey = self.apiCachePrefix + "\(self.currentService?.baseURL ?? "")\(path)".pp_md5
        PPDiskCache.shared.fetchData(key: archieveKey) { (data) in
            guard let fileData = data else {
                debugPrint("获取文件数据失败")
                return
            }
            do {
                let archieveArray = try JSONDecoder().decode([PPFileObject].self, from: fileData)
                debugPrint("[path]\(path):\(archieveArray.count)")
                DispatchQueue.main.async {
                    completionHandler(archieveArray,true,nil)
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        } failure: { error in
            
        }
        //获取本地缓存成功了还是去服务器获取一下,保证数据最新
        let validPathID = (pathID.isEmpty == false) ? pathID : ""
//        获取远程服务器文件列表数据然后缓存
        currentService?.contentsOfDirectory(path, validPathID, completion: { fileList, error in
            if error == nil {
                let encoded = try? JSONEncoder().encode(fileList)
                PPDiskCache.shared.setData(encoded, key:archieveKey)
            }
            DispatchQueue.main.async {
                completionHandler(fileList,false,error)
            }
        })
    }
    
    //MARK:- 文件操作
    func downloadThenCache(url:String,
                           path:String,
                           progress: ((Progress) -> Void)? = nil,
                           completion: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)){
        debugPrint("download:\(url)")
//        PPHUD.showBarProgress()
        // 我不知道为什么会有缓存，操
        guard let url_ = URL(string: url) else {
            debugPrint("URL is WRONG:\(url)")
            return
        }
        let urlRequest = URLRequest(url: url_)
        URLCache.shared.removeCachedResponse(for: urlRequest)
        AF.download(url).downloadProgress { p in
            //debugPrint("downloadThenCache Progress: \(p.fractionCompleted)")
            if let progress = progress {
                progress(p)
            }
//            PPHUD.updateBarProgress(Float(progress.fractionCompleted))
        }
        .responseData { response in
            guard let data = response.value else { return }
            var localPath = PPUserInfo.shared.webDAVRemark + "/" + path
            localPath = localPath.replacingOccurrences(of: "//", with: "/")
            if(response.response?.statusCode != 200) {
                completion(nil, false, PPCloudServiceError.unknown)
                return
            }
            PPDiskCache.shared.setData(data, key: localPath)
            completion(data, false, nil)
        }
    }
    /// 从服务器下载文件
    func downloadFile(path: String,
                      fileID: String?,
                      downloadURL:String? = nil,
                      cacheToDisk: Bool? = false,
                      progress: ((Progress) -> Void)? = nil,
                      completion: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        if let downloadURL = downloadURL, downloadURL.length > 1 {
            downloadThenCache(url: downloadURL, path: path, progress: progress, completion: completion)
            return
        }
        // 局部闭包
        let handleResult = { (_ data:Data?,_ error:Error?) -> Void in
            if let error = error {
                debugPrint("下载失败：\(error.localizedDescription)")
                return
            }
            if data == nil {return}
            if let shouldCacheToDisk = cacheToDisk, shouldCacheToDisk == true {
                PPDiskCache.shared.setDataSynchronously(data, key:  PPUserInfo.shared.webDAVRemark + path)
            }
            DispatchQueue.main.async {
                completion(data,false,error)
            }
        }
        let type = PPUserInfo.shared.cloudServiceType
        if type == .baiduyun || type == .alist || type == .aliyundrive || type == .synology {
            currentService?.getFileData(path, fileID ?? "", completion: { data, url, error in
                self.downloadThenCache(url: url, path: path, progress: progress, completion: completion)
            })
            return
        }
        currentService?.getFileData(path, fileID ?? "", completion: { data, url, error in
            handleResult(data, error)
        })
        
            
            
    }
    
    /// 获取文件二进制Data，如果本地存在就取本地的，否则就下载远程服务器的
    /// - Parameters:
    ///   - path: 路径
    ///   - fileID: 文件ID，百度网盘是fs_id
    ///   - cacheToDisk: 缓存到本地磁盘
    ///   - alwaysDownload: 总是下载，有缓存也下载
    ///   - completion: 完成的回调
    public func getFileData(path: String,
                            fileID: String?,
                            downloadURL:String? = nil,
                            alwaysDownload : Bool? = false,
                            returnURL : Bool? = false,
                            progress: ((Progress) -> Void)? = nil,
                            completion: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) {
        // 1 从本地磁盘获取文件缓存
        PPDiskCache.shared.fetchData(key: PPUserInfo.shared.webDAVRemark + path) { data in
            // 2 本地磁盘有，按需从服务器获取最新的
//            debugPrint("getFileData exist")
            completion(data,true,nil) //先给本地的
            if alwaysDownload == true {
                self.downloadFile(path: path, fileID:fileID, downloadURL:downloadURL, cacheToDisk: true, progress: progress, completion: completion) // 即使本地有文件也下载
            }
        } failure: { error in
            // 3 本地磁盘没有，就从服务器获取最新的
            self.downloadFile(path: path, fileID:fileID,downloadURL:downloadURL, cacheToDisk: true, progress: progress, completion: completion)
        }
    }
    
    
    /// 图片视频等不可修改的文件缓存到本地后返回本地URL
    func getLocalURL(path:String,
                     fileID:String?,
                     downloadURL:String? = nil,
                     progress: ((Progress) -> Void)? = nil,
                     completion: @escaping (( _ url:String) -> Void)) {
        getFileData(path: path, fileID: fileID, downloadURL: downloadURL, alwaysDownload: false, returnURL: true, progress: progress) { contents, isFromCache, error in
            if error != nil {
                return
            }
            let filePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(path)"
            completion(filePath.replacingOccurrences(of: "//", with: "/"))
        }
    }
    func getRemoteURL(path:String,
                    fileID:String?,
                     completion: @escaping (( _ url:String) -> Void)) {
        let type = PPUserInfo.shared.cloudServiceType
        if type == .baiduyun || type == .alist {
            currentService?.getFileData(path, fileID ?? "", completion: { data, url, error in
                completion(url)
            })
        }
        else {
            completion("")
        }
    }
    //MARK: 新建文件 new file
    /// 通过WebDAV上传到服务器
    func createFile(path: String, parentID:String? = nil,contents: Data?, completionHandler:@escaping(_ res:[String:String]?,_ error:Error?) -> Void) {
        guard let contents = contents else {
            DispatchQueue.main.async {
                PPHUD.showHUDFromTop("空文件",isError: true)
            }
            return
        }
        if PPUserInfo.pp_boolValue("uploadFileSortByYearMonth") {
            PPFileManager.shared.pp_getFileList(path: path.pp_directoryPath, pathID: parentID ?? "", disableCache: true) { data, isFromCache, error in
                // 过滤出目录且等于path
                let fileName = path.pp_getFileName()
                let yearMonth = fileName.pp_extractYearMonth()
                let dirs = data.filter { (item) -> Bool in
                    return item.isDirectory && item.path == path.pp_directoryPath + "/" + yearMonth
                }
                // 如果dirs为0，就创建目录
                let newPath = path.pp_directoryPath + "/" + yearMonth + "/" + fileName
                if dirs.count == 0 {
                    PPFileManager.shared.createFolder(folder: yearMonth, at: path.pp_directoryPath, parentID: parentID ?? "") { (error) in
                        if error == nil {
                            PPHUD.showHUDFromTop("新建成功")
                            self.currentService?.createFile(newPath, parentID ?? "", contents: contents, completion: { res,error in
                                DispatchQueue.main.async {
                                    completionHandler(res, error)
                                }
                            })
                        }
                        else {
                            PPHUD.showHUDFromTop("新建失败", isError: true)
                        }
                    }
                }
                else {
                    self.currentService?.createFile(newPath, parentID ?? "", contents: contents, completion: { res,error in
                        DispatchQueue.main.async {
                            completionHandler(res, error)
                        }
                    })
                }
                
            }
            return
//            PPFileManager.shared.pp_getFileList(path: path, parentID) { (contents,isFromCache, error) in
//            }
//            path = PPAppConfig.shared.currentYearMonth + "/" + path

        }
//        let localPath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)"
        // 将数据写入文件，就算接口请求失败本地也有缓存
//        try? contents.write(to: URL(fileURLWithPath: localPath + path))
        currentService?.createFile(path, parentID ?? "", contents: contents, completion: { res,error in
            DispatchQueue.main.async {
                completionHandler(res, error)
            }
        })
    }
    /// 移动文件（夹）、重命名文件（夹）
    func moveFile(srcPath: String,
                  destPath: String,
                  srcFileID: String? = nil,
                  destFileID: String? = nil,
                  isRename: Bool,
                  completionHandler:@escaping(_ error:Error?) -> Void) {
        // 局部闭包
        let handleResult = { (_ error:Error?) -> Void in
            DispatchQueue.main.async {
                completionHandler(error)
                if error != nil {
                    PPHUD.showHUDFromTop("移动或重命名失败",isError: true)
                    return
                }
                let downloadPath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)"
                //移动本地的文件
                if FileManager.default.fileExists(atPath: downloadPath + srcPath) {
                    try? FileManager.default.moveItem(atPath: downloadPath + srcPath,
                                                      toPath: downloadPath + destPath)
                }
            }
        }
        currentService?.moveItem(srcPath: srcPath,
                                 destPath: destPath,
                                 srcItemID: srcFileID ?? "",
                                 destItemID: destFileID ?? "",
                                 isRename: isRename, completion: { error in
            handleResult(error)
        })


    }
    /// 新建文件夹
    func createFolder(folder folderName: String, at atPath: String, parentID: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        currentService?.createDirectory(folderName, atPath, parentID, completion: { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        })
    }
    //删除远程服务器的文件
    func deteteFile(path: String, pathID:String? = nil,completionHandler:@escaping(_ error:Error?) -> Void) {
        currentService?.removeItem(path, pathID ?? "", completion: { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        })
    }
    
    /// 从WebDAV下载文件获取Data
    func searchFile(path: String, searchText: String?,completionHandler: @escaping ((_ files: [PPFileObject], _ isFromCache:Bool, _ error: Error?) -> Void)) {
        //TODO:webdav
            
    }
    
    
    
    //MARK: - 云服务设置
    /// 初始化WebDAV等云服务设置
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
            let a = PPUserInfo.shared.getCurrentServerInfo("PPAccessToken")
            alistService = PPAlistService(url:PPUserInfo.shared.webDAVServerURL,
                                          username: user,
                                          password: password,
                                          access_token: a)
            alistService?.configChanged = {key,value in
                PPUserInfo.shared.updateCurrentServerInfo(key: key, value: value)
            }
        case .synology:
            let sid = PPUserInfo.shared.getCurrentServerInfo("sid")
            let did = PPUserInfo.shared.getCurrentServerInfo("did")
            let url = PPUserInfo.shared.getCurrentServerInfo("PPWebDAVServerURL")
            let remoteURL = PPUserInfo.shared.getCurrentServerInfo("PPRemoteBaseURL")
            let localURL = PPUserInfo.shared.getCurrentServerInfo("PPLocalBaseURL")
            let otp_code = PPUserInfo.shared.getCurrentServerInfo("PPOptCode")
            synologyService = PPSynologyService(url:url,
                                                remoteURL: remoteURL,
                                                localURL: localURL,
                                                username: user,
                                                password: password,
                                                otp_code: otp_code,
                                                sid: sid,
                                                did: did)
            synologyService?.configChanged = {key,value in
                PPUserInfo.shared.updateCurrentServerInfo(key: key, value: value)
            }
        case .aliyundrive:
            let a = PPUserInfo.shared.getCurrentServerInfo("PPAccessToken")
            let b = PPUserInfo.shared.getCurrentServerInfo("PPRefreshToken")
            let c = PPUserInfo.shared.getCurrentServerInfo("drive_id")
            aliyunDriveService = PPAliyunDriveService(access_token: a, refresh_token: b, drive_id:c)
            
            aliyunDriveService?.configChanged = {key,value in
                PPUserInfo.shared.updateCurrentServerInfo(key: key, value: value)
            }
        case .local:
            localFileService = PPLocalFileService()
        case .icloud:
            self.iCloudService = PPiCloudDriveService(containerId: PPAppConfig.shared.iCloudContainerId)
        case .webdav:
            webdavService = PPWebDAVService(url: PPUserInfo.shared.webDAVServerURL,
                                            username: user,
                                            password: password)
//        default:
//            debugPrint("not init Cloud Service")
        }
        return true
    }
    //MARK: 图片（PHAsset）相关处理
    func getAssetsInfo(_ asset: PHAsset) -> [String:String]{
        let imageInfoDict = ["creationDate":(asset.creationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "modificationDate":(asset.modificationDate != nil) ? asset.creationDate!.pp_stringFromDate() : "",
                             "pixelWidth":"\(asset.pixelWidth)",
                             "pixelHeight":"\(asset.pixelHeight)"]
        return imageInfoDict
    }
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
            PPPhotoTool.requestVideoURL(with: asset) { url in
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
                debugPrint("pick image size:",restulImage?.size ?? "")
                var originalFilename = "noname.jpg" //默认值，实际上不会出现
                if let name = PHAssetResource.assetResources(for: asset).first?.originalFilename {
                    originalFilename = name
                }
                let compressionQuality = PPAppConfig.shared.getFloat("pp_imageCompressionQuality")
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
    func uploadPhotos(toDir: String,_ mediaItems:[PHAsset], completion: ((_ uploadedAssets:[PHAsset]) -> Void)? = nil) {
        let group = DispatchGroup()
        var assetsToDeleteFromDevice = [PHAsset]()
//        let path = self.currentPath
        //多图上传
        for asset in mediaItems {
            group.enter() // 将以下任务添加进group，相当于把某个任务添加到组队列中执行
            if PPPhotoTool.isLivePhoto(asset) {
                let imageInfo = getAssetsInfo(asset)
                PPPhotoTool.exportLivePhotoData(for: asset) { imgData, videoData, imgName, videoName, error in
                    // 1先上传图片
                    let uploadName = PPFileManager.imageVideoName(urlString: imgName, imageInfo: imageInfo)
                    let remotePath = toDir + uploadName
                    PPFileManager.shared.createFile(path: remotePath, parentID: self.currentPathID, contents: imgData) { (result, error) in
                        if let error = error {
                            debugPrint("上传出错:\(error.localizedDescription)")
                            return
                        }
                        // 2再上传视频
                        let uploadName = PPFileManager.imageVideoName(urlString: videoName, imageInfo: imageInfo)
                        let vPath = toDir + uploadName
                        PPFileManager.shared.createFile(path: vPath, parentID: self.currentPathID, contents: videoData) { (result, error) in
                            if let error = error {
                                debugPrint("上传出错:\(error.localizedDescription)")
                                return
                            }
                            PPHUD.showHUDFromTop("上传+1")
                            assetsToDeleteFromDevice.append(asset)
                            group.leave() //本次任务完成（即本次for循环任务完成），将任务从group中移除
                        }
                        
                    }
                }
            }
            else {
            PPFileManager.shared.getImageDataFromAsset(asset: asset, completion: { (imageData,urlString,imageInfo) in
                let uploadName = PPFileManager.imageVideoName(urlString: urlString, imageInfo: imageInfo)
                let remotePath = toDir + uploadName
                debugPrint("start_upload_file\(uploadName) -> \(toDir)")
                
                PPFileManager.shared.createFile(path: remotePath, parentID: self.currentPathID, contents: imageData) { (result, error) in
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
            currentService?.getFileData(imageURL, "", completion: { data, url, error in
                guard let contents = data else {
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


extension String {
    func pp_fileCachePath() -> String {
        let filePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(self)"
        return filePath
    }
}
