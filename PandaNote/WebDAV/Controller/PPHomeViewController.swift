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
import YPImagePicker

class PPHomeViewController: PPBaseViewController,FileProviderDelegate,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate
    ,SKPhotoBrowserDelegate
{
    
    open var pathStr: String = ""

//    let server: URL = URL(string: "http://dav.jianguoyun.com/dav")!
//    let username = "XXXXX@qq.com"
//    let password = "XXXXXXXX"
    
    var dataSource:Array<FileObject> = []
    var tableView = UITableView()
    let cellReuseIdentifier = "cell"
//    let documentsProvider = LocalFileProvider()
    var currentImageURL: String?
    var photoBrowser: SKPhotoBrowser!
    var bottomView:UIButton!
    var renameTF:UITextField!
    var currentRenameText:String?
    @IBOutlet weak var uploadProgressView: UIProgressView?
    @IBOutlet weak var downloadProgressView: UIProgressView?
    //MARK:Life Cycle
    override func viewDidAppear(_ animated: Bool) {
        print("===appear")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let userInfo = PPUserInfoManager.sharedManager
        self.title = userInfo.webDAVRemark ?? "文件（未配置）"
        
        tableView = UITableView.init(frame: self.view.bounds)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(0);
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
        bottomView = UIButton(frame: CGRect(x: 0, y:88, width: 414, height: 144))
        bottomView.backgroundColor = UIColor.lightGray
        self.view.addSubview(bottomView)
        bottomView.isHidden = true
        bottomView.addTarget(self, action: #selector(hiddenRenameView), for: UIControl.Event.touchUpInside)
        
        renameTF = UITextField(frame: CGRect(x: 15, y: 15, width: 350, height: 44))
        renameTF.backgroundColor = UIColor.white
        renameTF.delegate = self
        renameTF.returnKeyType = UIReturnKeyType.done
        bottomView.addSubview(renameTF)
        
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更多", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
        
        
        
        if (userInfo.webDAVServerURL != nil) {
//            PPFileManager.sharedManager.initWebDAVSetting()
            getWebDAVData()
        }
        self.tableView.addRefreshHeader {
            if (PPUserInfoManager.sharedManager.webDAVServerURL != nil) {
                PPFileManager.sharedManager.initWebDAVSetting()
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
//            cell.iconImage.kf.setImage(with: "" as! Resource)
            cell.iconImage.image = UIImage.init(named: "ico_folder")
        }
        else if (isImage(fileName: fileObj.name))  {
            let imagePath = PPUserInfoManager.sharedManager.pp_mainDirectory + fileObj.path
            self.currentImageURL = imagePath
            if FileManager.default.fileExists(atPath: imagePath) {
                let imageData = try?Data(contentsOf: URL(fileURLWithPath: imagePath))
                cell.iconImage.image = UIImage.init(data: imageData!)
            }
            else {
                cell.iconImage.image = UIImage.init(named: "ico_jpg")
            }
        }
        else {
            cell.iconImage.image = UIImage.init(named: PPUserInfoManager.sharedManager.pp_fileIcon[String(fileObj.name.split(separator: ".").last!)] ?? "ico_jpg")
        }
        let dataStr = String(describing: fileObj.modifiedDate).substring(startIndex: 9, endIndex: 29)
        let sizeStr = (fileObj.size>0) ? " - "+String(fileObj.size/1000)+"KB":""
        cell.timeLabel.text = dataStr + sizeStr
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
        else if (fileObj.name.hasSuffix("md")||fileObj.name.hasSuffix("txt")||fileObj.name.hasSuffix("js")||fileObj.name.hasSuffix("html"))  {
            let vc = PPMarkdownViewController.init()
            vc.filePathStr = fileObj.path
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (isImage(fileName: fileObj.name))  {
            storeImageWithFileManager(imageURL: fileObj.path) { (imageData) in
                debugPrint(imageData)
                self.showImage(contents: imageData, image: nil, imageName: fileObj.path,imageURL:fileObj.path)
            }
        }
        else {
            PPHUD.showHUDText(message: "暂不支持ho~", view: self.view)
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let delete = UITableViewRowAction(style: .default, title: "删除") { (action, indexPath) in
            PPHUD.showHUDText(message: "未完成", view: self.view)
        }
        delete.backgroundColor = UIColor.red
        
        let complete = UITableViewRowAction(style: .default, title: "重命名") { (action, indexPath) in
            // Do you complete operation
            debugPrint("==重命名")
            PPHUD.showHUDText(message: "点击灰色区域输入框消失，以后优化", view: self.view)
            //MARK:重命名
            let fileObj = self.dataSource[indexPath.row]
            self.bottomView.isHidden = false
            self.renameTF.text = fileObj.name
            self.currentRenameText = fileObj.path
            self.renameTF.becomeFirstResponder()
//            self.renameTF.selectAll(nil)
            

        }
        complete.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)
        
        return [delete, complete]
    }
    //https://stackoverflow.com/a/58006735/4493393
    //here is how I selecte file name `Panda` from `Panda.txt`
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // if textField.text is `Panda.txt`, so offset will be 3
        let offset = String(textField.text!.split(separator: ".").last!).length
        let from = textField.position(from: textField.beginningOfDocument, offset: 0)
        let to = textField.position(from: textField.beginningOfDocument,
                                    offset:textField.text!.length - (offset+1) )
        //now `Panda` will be selected
        textField.selectedTextRange = textField.textRange(from: from!, to: to!)//danger! unwrap with `!` is not recommended  危险，不推荐用！解包
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        debugPrint("=======")
        
        if let currentRenameText = currentRenameText,let newName = textField.text {
            PPFileManager.sharedManager.webdav?.moveItem(path:currentRenameText, to: self.pathStr + newName, completionHandler: { (error) in
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    PPHUD.showHUDText(message: "修改成功！", view: self.view)
                    self.getWebDAVData()
                })
            })
            
        }
        return true
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
    @objc func hiddenRenameView()  {
        self.bottomView.isHidden = true
        self.renameTF.resignFirstResponder()
    }
    @objc func moreAction()  {
        debugPrint("======")
        //MARK:上传照片
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["从🏞添加照骗"]) { (index) in
            debugPrint(index)
            if index == 1 {
                var config = YPImagePickerConfiguration()
                config.library.maxNumberOfItems = 1
                config.showsPhotoFilters = false
                config.startOnScreen = YPPickerScreen.library
                let picker = YPImagePicker(configuration: config)
//                let picker = YPImagePicker()
                picker.didFinishPicking { [unowned picker] items, _ in
                    if let photo = items.singlePhoto {
                            PPFileManager.sharedManager.getImageDataFromAsset(asset: photo.asset!, completion: { (imageData,imageLocalURL) in
                                if let imageLocalURL = imageLocalURL {
                                    let remotePath = self.pathStr + "PP_"+imageLocalURL.lastPathComponent
                                    PPFileManager.sharedManager.webdav?.copyItem(localFile: imageLocalURL, to: remotePath, completionHandler: { (error) in
                                        if error == nil {
                                            DispatchQueue.main.async {
                                                PPHUD.showHUDText(message: "上传成功🦄", view: self.view)                                                
                                            }
                                        }
                                    })
                                }

                        })
                    }
                    picker.dismiss(animated: true, completion: nil)
                }
                self.present(picker, animated: true, completion: nil)
            }
        }
    }
    
    func isImage(fileName:String) -> Bool { if(fileName.lowercased().hasSuffix("jpg")||fileName.lowercased().hasSuffix("jpeg")||fileName.lowercased().hasSuffix("png")||fileName.lowercased().hasSuffix("gif")||fileName.lowercased().hasSuffix("webp")) {
            return true
        }
        return false
    }
    func storeImageWithFileManager(imageURL:String,completionHandler: ((Data) -> Void)? = nil) {
//        let cache = ImageCache.default//KingFisher用
        let imagePath = PPUserInfoManager.sharedManager.pp_mainDirectory + imageURL
        self.currentImageURL = imagePath
        
//        let filePath = cache.cachePath(forComputedKey: imageURL)//KingFisher用
//        let cachedData = try?Data(contentsOf: URL(fileURLWithPath: filePath))//KingFisher用
        
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
            PPFileManager.sharedManager.webdav?.contents(path: imageURL, completionHandler: {
                contents, error in
                if let contents = contents {
                    
                    if !FileManager.default.fileExists(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory + imageURL) {
                        do {
                            var array = imageURL.split(separator: "/")
                            array.removeLast()
                            let newStr:String =  array.joined(separator: "/")
                            try FileManager.default.createDirectory(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory+"/"+newStr, withIntermediateDirectories: true, attributes: nil)
                        } catch  {
                            debugPrint("==FileManager Crash")
                        }
                    }
                    
                    FileManager.default.createFile(atPath: PPUserInfoManager.sharedManager.pp_mainDirectory + imageURL, contents: contents, attributes: nil)
                    
//                    do {
//                        try contents.write(to: PPUserInfoManager.sharedManager.pp_mainDirectoryURL.appendingPathComponent(fileObj.path), options: Data.WritingOptions.atomic)
//                    } catch {
//                        print("====error")
//                    }
                    
                    if let handler = completionHandler {
                        handler(contents)
                    }
                }
            })
            
        }
    }
    
    
    @IBAction func getData(_ sender: Any) {
        getWebDAVData()
    }
    
    //MARK:获取文件列表
    func getWebDAVData() -> Void {
        PPFileManager.sharedManager.getWebDAVData(path: self.pathStr) { (contents, error) in
            if let objects = contents as? [FileObject] {
                self.dataSource.removeAll()
                self.dataSource.append(contentsOf: objects)
                self.tableView.endRefreshing()
                self.tableView.reloadData()

            }
//            let objects:[FileObject] = contents as? [FileObject]
            

        }
        
    }
    
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
