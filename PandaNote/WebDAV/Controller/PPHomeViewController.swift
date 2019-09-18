//
//  XDHomeViewController.swift
//  TeamDisk
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//

import UIKit
import FilesProvider
import SKPhotoBrowser
import Kingfisher

class PPHomeViewController: PPBaseViewController,FileProviderDelegate,UITableViewDataSource,UITableViewDelegate
    ,SKPhotoBrowserDelegate
{
    
    open var pathStr: String = ""

//    let server: URL = URL(string: "http://dav.jianguoyun.com/dav")!
//    let username = "XXXXX@qq.com"
//    let password = "XXXXXXXX"
    
    var webdav: WebDAVFileProvider?
    var dataSource:Array<FileObject> = []
    var tableView = UITableView()
    let cellReuseIdentifier = "cell"
//    let documentsProvider = LocalFileProvider()
    var currentImageURL: String?
    var photoBrowser: SKPhotoBrowser!
    @IBOutlet weak var uploadProgressView: UIProgressView?
    @IBOutlet weak var downloadProgressView: UIProgressView?
    override func viewDidAppear(_ animated: Bool) {
        print("===appear")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let userInfo = PPUserInfoManager.sharedManager
        self.title = userInfo.webDAVRemark ?? "文件（未配置）"
        
        tableView = UITableView.init(frame: self.view.bounds)
        self.view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.tableFooterView = UIView.init()
        
        if (userInfo.webDAVServerURL != nil) {
            self.initWebDAVSetting()
        }
        self.tableView.addRefreshHeader {
            if (self.webdav == nil && PPUserInfoManager.sharedManager.webDAVServerURL != nil) {
                self.initWebDAVSetting()
            }
            self.getData((Any).self)
        }
//        let server: URL = URL(string: PPUserInfoManager.shared().webDAVServerURL)
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.dataSource[indexPath.row]
        cell.titleLabel.text = fileObj.name
        if fileObj.isDirectory {
            cell.iconImage.image = UIImage.init(named: "ico_folder")
        }
        else {
            cell.iconImage.image = UIImage.init(named: PPUserInfoManager.sharedManager.pp_fileIcon[String(fileObj.name.split(separator: ".").last!)] ?? "ico_jpg")
        }
        cell.timeLabel.text = String(describing: fileObj.modifiedDate).substring(startIndex: 9, endIndex: 29)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fileObj = self.dataSource[indexPath.row]
        if fileObj.isDirectory {
            print("You tapped cell number \(fileObj.path).")
            let vc = PPHomeViewController.init()
            vc.pathStr = fileObj.path + "/"
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.hasSuffix("md")||fileObj.name.hasSuffix("txt"))  {
            let vc = PPMarkdownViewController.init()
            vc.filePathStr = fileObj.path
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.lowercased().hasSuffix("jpg")||fileObj.name.lowercased().hasSuffix("jpeg")||fileObj.name.lowercased().hasSuffix("png")||fileObj.name.lowercased().hasSuffix("gif"))  {
            let cache = ImageCache.default
            let imagePath = PPUserInfoManager.sharedManager.pp_mainDirectory + fileObj.path//FileManager.default.contents(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory + fileObj.path)
            self.currentImageURL = imagePath
            if FileManager.default.fileExists(atPath: imagePath) {
//            if (cache.retrieveImageInDiskCache(forKey: fileObj.path) != nil) {
//                let imagePath = cache.cachePath(forKey: fileObj.path)
                let imageData = try?Data(contentsOf: URL(fileURLWithPath: imagePath))
                self.showImage(contents: imageData!, image: nil, imageName: fileObj.name,imageURL:fileObj.path)
            }
            else {
                webdav?.contents(path: fileObj.path, completionHandler: {
                    contents, error in
                    if let contents = contents {
                        
                        if !FileManager.default.fileExists(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory + fileObj.path) {
                            do {
                                var array = fileObj.path.split(separator: "/")
                                array.removeLast()
                                let newStr:String =  array.joined(separator: "/")
                                try FileManager.default.createDirectory(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory+"/"+newStr, withIntermediateDirectories: true, attributes: nil)
                            } catch  {
                                print("====")
                            }
                        }
                        
                        FileManager.default.createFile(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory + fileObj.path, contents: contents, attributes: nil)
                        
                        do {
                            try contents.write(to: PPUserInfoManager.sharedManager.pp_mainDirectoryURL.appendingPathComponent(fileObj.path), options: Data.WritingOptions.atomic)
                        } catch {
                            print("====error")
                        }
                        
                        cache.store(UIImage.init(data: contents)!, original: contents, forKey:fileObj.path )
                        self.showImage(contents: contents, image: nil, imageName: fileObj.name,imageURL:fileObj.path)
                        // print(contents)
                        
                    }
                })
                
            }

            

            
            
        }
        else {
            PPHUD.showHUDText(message: "暂不支持ho~", view: self.view)
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    //MARK:照片分享代理
    func didDismissActionSheetWithButtonIndex(_ buttonIndex: Int, photoIndex: Int) {
        print("buttonIndex==\(buttonIndex)")
//        print("photoIndex==\(photoIndex)")
        if buttonIndex == 2 {
            photoBrowser.popupShare()
        }
        else if buttonIndex == 0 {
            let photo = photoBrowser.photos[photoIndex]
            guard let underlyingImage = photo.underlyingImage else {
                return
            }
            PPShareManager.shared().weixinShareImage(underlyingImage, type: PPSharePlatform.weixinSession.rawValue)
        }
        else if buttonIndex == 1 {
//            let photo = photoBrowser.photos[photoIndex]
//            guard let underlyingImage = photo.underlyingImage else {
//                return
//            }
//            let imagePath = ImageCache.default.cachePath(forKey: self.currentImageURL ?? "")
//            let imageData = try?Data(contentsOf: URL(fileURLWithPath: self.currentImageURL ?? ""))
            let imageData = FileManager.default.contents(atPath: self.currentImageURL ?? "")
            PPShareManager.shared().weixinShareEmoji(imageData ?? Data.init(), type: PPSharePlatform.weixinSession.rawValue)
        }
    }
    func showImage(contents:Data,image:UIImage?,imageName:String,imageURL:String) -> Void {
        DispatchQueue.main.async {
            if let image_down = UIImage.init(data: contents) {
                // 1. create SKPhoto Array from UIImage
                var images = [SKPhoto]()
                let photo = SKPhoto.photoWithImage(image_down)// add some UIImage
                photo.caption = imageName
                photo.photoURL = imageURL
                images.append(photo)
                
                // 2. create PhotoBrowser Instance, and present from your viewController.
                self.photoBrowser = SKPhotoBrowser(photos: images)
                self.photoBrowser.initializePageIndex(0)
                self.photoBrowser.delegate = self
                SKPhotoBrowserOptions.actionButtonTitles = ["微信原图分享","作为微信表情分享😄","UIActivityViewController分享"]
                
                self.present(self.photoBrowser, animated: true, completion: {})
                
                
                /*
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    for subview in self.photoBrowser.view.subviews {
                        if subview is UIScrollView {
                            for subsubview in subview.subviews {
//                                print(subsubview)
                                if subsubview is UIScrollView {
                                    for subsubsubview in subsubview.subviews {
                                        print(subsubsubview)
                                        if subsubsubview is UIImageView {
                                            let imageShow:UIImageView = subsubsubview as! UIImageView
                                            imageShow.kf.setImage(with: <#T##Resource?#>, placeholder: <#T##Placeholder?#>, options: <#T##KingfisherOptionsInfo?#>, progressBlock: <#T##DownloadProgressBlock?##DownloadProgressBlock?##(Int64, Int64) -> Void#>, completionHandler: <#T##CompletionHandler?##CompletionHandler?##(Image?, NSError?, CacheType, URL?) -> Void#>)
                                            print("i found it ")
                                            print(subsubsubview)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                })
                */
                
                
            }
        }
    }
    //MARK:初始化webDAV设置
    func initWebDAVSetting() -> Void {
        let userInfo = PPUserInfoManager.sharedManager
        let server: URL = URL(string: userInfo.webDAVServerURL!) ?? NSURL.init() as URL
        //        }
        //        if let server: URL = URL(string: PPUserInfoManager.sharedManager.webDAVServerURL ?? "") {
        if self.pathStr.length < 1 {
            self.pathStr = "/"
        }
        else {
            self.title = String(self.pathStr.split(separator: "/").last ?? "File")
        }
        let userCredential = URLCredential(user: userInfo.webDAVUserName ?? "",
                                           password: userInfo.webDAVPassword ?? "",
                                           persistence: .permanent)
        //            let protectionSpace = URLProtectionSpace.init(host: "dav.jianguoyun.com", port: 443, protocol: "https", realm: "Restricted", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        //            URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        webdav = WebDAVFileProvider(baseURL: server, credential: userCredential)!
        webdav?.delegate = self as FileProviderDelegate
        //注意：不修改鉴权方式，会导致每次请求两次，一次401失败，一次带token成功
        webdav?.credentialType = URLRequest.AuthenticationType.basic
        //            webdav?.useCache = true
        self.perform(Selector(("getData:")), with: self, afterDelay: 1)

    }
    //MARK:获取文件列表
    @IBAction func getData(_ sender: Any) {
        webdav?.contentsOfDirectory(path: self.pathStr, completionHandler: {
            contents, error in
            self.dataSource.removeAll()
            self.dataSource.append(contentsOf: contents)
            DispatchQueue.main.async {
                self.tableView.endRefreshing()
                self.tableView.reloadData()
            }
            for file in contents {
                print("Name: \(file.name)")
                print("Size: \(file.size)")
                print("Creation Date: \(String(describing: file.creationDate))")
                print("Modification Date: \(String(describing: file.modifiedDate))")
            }
        })
        //        webdav?.attributesOfItem(path: "/", completionHandler: { (attributes, error) in
        //            if let attributes = attributes {
        //                print("File Size: \(attributes.size)")
        //                print("Creation Date: \(String(describing: attributes.creationDate))")
        //                print("Modification Date: \(String(describing: attributes.modifiedDate))")
        //                print("Is Read Only: \(attributes.isReadOnly)")
        //            }
        //        })
        //        webdav?.contents(path: "/", completionHandler: {
        //            contents, error in
        //            if let contents = contents {
        //                print(String(data: contents, encoding: .utf8) as Any)
        //            }
        //        })
    }
    
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func createFolder(_ sender: Any) {
        webdav?.create(folder: "new folder", at: "/", completionHandler: nil)
    }
    
    @IBAction func createFile(_ sender: Any) {
        let data = "Hello world from sample.txt!".data(using: .utf8, allowLossyConversion: false)
        webdav?.writeContents(path: "sample.txt", contents: data, atomically: true, completionHandler: nil)//?.writeContents(path: "sample.txt", content: data, atomically: true, completionHandler: nil)
    }
    
    
    
    @IBAction func remove(_ sender: Any) {
        webdav?.removeItem(path: "sample.txt", completionHandler: nil)
    }
    
    @IBAction func download(_ sender: Any) {
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
        let remotePath = "fileprovider.png"
        
        let progress = webdav?.copyItem(path: remotePath, toLocalURL: localURL, completionHandler: nil)
        downloadProgressView?.observedProgress = progress
    }
    
    @IBAction func upload(_ sender: Any) {
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("fileprovider.png")
        let remotePath = "/fileprovider.png"
        
        let progress = webdav?.copyItem(localFile: localURL, to: remotePath, completionHandler: nil)
        uploadProgressView?.observedProgress = progress
    }
    
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
