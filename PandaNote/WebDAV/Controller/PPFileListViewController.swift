//
//  XDHomeViewController.swift
//  TeamDisk
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//

import UIKit
//import FilesProvider
import SKPhotoBrowser
import Kingfisher
import YPImagePicker
import PopMenu

class PPFileListViewController: PPBaseViewController,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate
    ,SKPhotoBrowserDelegate
    ,PopMenuViewControllerDelegate
{
    
    open var pathStr: String = ""

//    let server: URL = URL(string: "http://dav.jianguoyun.com/dav")!
//    let username = "XXXXX@qq.com"
//    let password = "XXXXXXXX"
    
    var dataSource:Array<PPFileObject> = []
    var tableView = UITableView()
    let cellReuseIdentifier = "cell"
//    let documentsProvider = LocalFileProvider()
    var currentImageURL: String?
    var photoBrowser: SKPhotoBrowser!
    ///如果是展示最近访问的列表
    var isRecentFiles = false
    @IBOutlet weak var uploadProgressView: UIProgressView?
    @IBOutlet weak var downloadProgressView: UIProgressView?
    //---------------搜索功能↓---------------
    /// 展示在本控制器的上面的控制器 Search controller to help us with filtering items in the table view.
    var searchController: UISearchController!
    /// 展示在本控制器的上面的控制器的列表 Search results table view.
    var resultsTableController: PPResultsTableController!
    //---------------搜索功能↑---------------
    //---------------移动文件（夹）到其他文件夹功能↓---------------
    var isMovingMode = false
    var leftButton : UIButton!
    var rightButton : UIButton!
    var filePathToBeMove = ""
    //---------------移动文件（夹）到其他文件夹功能↑---------------
    var titleViewButton : UIButton!
    //MARK:Life Cycle
//    convenience init() {
//        self.init(nibName:nil, bundle:nil)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        tableView = UITableView.init(frame: self.view.bounds)//稚嫩的写法
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(0);
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
        
        
        if self.navigationController?.viewControllers.count ?? 0 > 1 {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更多", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
        }
        else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "添加☁️", style: UIBarButtonItem.Style.plain, target: self, action: #selector(addCloudService))

        }
        
        
        getWebDAVData()
        
        setNavTitle()
        

        self.tableView.addRefreshHeader {
            self.getWebDAVData()
        }
        setupSearchController()
        if isMovingMode {//移动文件模式
            setupMoveUI()
        }
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isRecentFiles {
            self.getWebDAVData()//最近访问列表实时刷新
        }
    }
    //MARK: - UITableViewDataSource UITableViewDelegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.dataSource[indexPath.row]
        cell.updateUIWithData(fileObj as AnyObject)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fileObj = self.dataSource[indexPath.row]
//        debugPrint("文件：\(fileObj.path)")
        PPUserInfo.shared.insertToRecentFiles(fileObj)
        
        if fileObj.isDirectory {
            let vc = PPFileListViewController()
            vc.pathStr = fileObj.path + "/"
            vc.isMovingMode = self.isMovingMode
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.isTextFile())  {
            let vc = PPMarkdownViewController()
            vc.filePathStr = fileObj.path
            vc.fileID = fileObj.fileID
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.pp_isImageFile())  {
            loadAndSaveImage(imageURL: fileObj.path,fileID: fileObj.fileID) { (imageData) in
//                debugPrint(imageData)
                self.showImage(contents: imageData, image: nil, imageName: fileObj.path,imageURL:fileObj.path)
            }
        }
        else if (fileObj.name.hasSuffix("pdf"))  {
            if #available(iOS 11.0, *) {
                let vc = PPPDFViewController()
                vc.filePathStr = fileObj.path
                vc.fileID = fileObj.fileID
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                PPHUD.showHUDFromTop("抱歉，暂不支持iOS11以下系统预览PDF哟")
            }
        }
        else if (fileObj.name.hasSuffix("mp3")||fileObj.name.lowercased().hasSuffix("mp4"))  {
            PPFileManager.shared.loadFileFromWebDAV(path: fileObj.path, downloadIfExist: false) { (contents,isFromCache, error) in
                
                if error != nil {
                    return
                }
                let vc = PlayerViewController()
                vc.localFileURL = URL(fileURLWithPath: PPDiskCache.shared.path + fileObj.path)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        else {
            PPAlertAction.showAlert(withTitle: "暂不支持", msg: "是否以纯文本方式打开", buttonsStatement: ["打开","不了"]) { (index) in
                if index == 0 {
                    let vc = PPMarkdownViewController()
                    vc.filePathStr = fileObj.path
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if self.isMovingMode {
            return []
        }
        let delete = UITableViewRowAction(style: .default, title: "删除") { (action, indexPath) in
            let fileObj = self.dataSource[indexPath.row]
            if (self.isRecentFiles) {
                self.dataSource.remove(at: indexPath.row)
                PPUserInfo.shared.removeFileInRecentFiles(fileObj)
                self.tableView.reloadData()
                PPHUD.showHUDFromTop("已删除访问记录")
                return
            }
            //相对路径
            PPFileManager.shared.webdav?.removeItem(path:fileObj.path, completionHandler: { (error) in
                if let errorNew = error {
                    DispatchQueue.main.async {
                        PPHUD.showHUDFromTop("删除失败: \(String(describing: errorNew))", isError: true)
                    }
                }
                else {
                    DispatchQueue.main.async {
                        PPHUD.showHUDFromTop("文件删除成功")// (message: "删除成功哟！", view: self.view)
                        PPUserInfo.shared.removeFileInRecentFiles(fileObj)
                        self.getWebDAVData()
                    }
                }
                
            })
        }
        delete.backgroundColor = UIColor.red
        
        let complete = UITableViewRowAction(style: .default, title: "重命名") { (action, indexPath) in
            // Do you complete operation
            debugPrint("==重命名")
            //MARK:重命名
            let fileObj = self.dataSource[indexPath.row]
            self.renameFile(fileObj)

        }
        complete.backgroundColor = PPCOLOR_GREEN
        let move = UITableViewRowAction(style: .default, title: "移动") { (action, indexPath) in
            debugPrint("移动")
            let fileObj = self.dataSource[indexPath.row]
            let popVC = PPFileListViewController()
            popVC.isMovingMode = true
            popVC.filePathToBeMove = fileObj.path
            let nav = UINavigationController(rootViewController: popVC)
            self.present(nav, animated: true, completion: nil)
        }
        move.backgroundColor = UIColor(hexRGBValue: 0x98acf8)
        return [delete, move ,complete]
    }
    //https://stackoverflow.com/a/58006735/4493393
    //here is how I selecte file name `Panda` from `Panda.txt`
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let nameParts = textField.text!.split(separator: ".")
        var offset = 0
        if nameParts.count > 1 {
            // if textField.text is `Panda.txt`, so offset will be 3+1=4
            offset = String(textField.text!.split(separator: ".").last!).length + 1
        }
        let from = textField.position(from: textField.beginningOfDocument, offset: 0)
        let to = textField.position(from: textField.beginningOfDocument,
                                    offset:textField.text!.length - offset)
        //now `Panda` will be selected
        textField.selectedTextRange = textField.textRange(from: from!, to: to!)//danger! unwrap with `!` is not recommended  危险，不推荐用！解包
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 2333 {//区分新建文本TextField
            return true
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
    
    /// 重命名文件
    func renameFile(_ fileObj:PPFileObject) {
        // 把 /Notes/ATest.md 变成 /Notes/
        let pathPrefix = fileObj.path.replacingOccurrences(of: fileObj.name, with: "")
        let alertController = UIAlertController(title: "修改文件（夹）名", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "输入文件名"
            textField.text = fileObj.name
            textField.delegate = self
            textField.tag = 2333
        }
        let saveAction = UIAlertAction(title: "保存", style: UIAlertAction.Style.default, handler: { alert -> Void in
            let firstTextField = alertController.textFields![0] as UITextField
            //let secondTextField = alertController.textFields![1] as UITextField
            if let tips = self.fileNameInvalidResult(firstTextField.text) {
                PPHUD.showHUDFromTop(tips, isError: true)
                return
            }
            guard let newName = firstTextField.text else { return }
            PPFileManager.shared.moveFileViaWebDAV(pathOld: pathPrefix+fileObj.name, pathNew: pathPrefix + newName) { (error) in
                PPHUD.showHUDFromTop("修改成功")
                var fileNew = fileObj
                fileNew.name = newName
                fileNew.path = pathPrefix + newName
                if let index = PPUserInfo.shared.pp_RecentFiles.firstIndex(of: fileObj) {
                    PPUserInfo.shared.pp_RecentFiles.remove(at: index)
                    PPUserInfo.shared.insertToRecentFiles(fileNew)
                }
                self.getWebDAVData()
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    @objc func moreAction()  {
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["从🏞添加照骗","新建文本文档📃","新建文件夹📂"]) { (index) in
            debugPrint(index)
            if index == 1 {
                self.showImagePicker()
            }
            else if index == 2 {
                self.newTextFile()
            }
            else if index == 3 {
                self.newTextFile(isDir: true)
            }
        }
    }
    //MARK:新建文本文档 & 上传照片
    func newTextFile(isDir:Bool = false) {
        let alertController = UIAlertController(title: isDir ? "新建文件夹" :"新建纯文本(格式任意)", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "输入文件名"
            textField.text = isDir ? "新建文件夹" :"新建文档.md"
            textField.delegate = self
            textField.tag = 2333
        }
//        alertController.addTextField { (textField : UITextField!) -> Void in
//            textField.placeholder = "文件格式"
//        }
        
        let saveAction = UIAlertAction(title: "保存", style: UIAlertAction.Style.default, handler: { alert -> Void in
            let firstTextField = alertController.textFields![0] as UITextField
//            let secondTextField = alertController.textFields![1] as UITextField
            guard let newName = firstTextField.text else { return }
            if let tips = self.fileNameInvalidResult(newName) {
                PPHUD.showHUDFromTop(tips, isError: true)
                return
            }
            if isDir {
                PPFileManager.shared.createFolderViaWebDAV(folder: newName, at: self.pathStr) { (error) in
                    if error == nil {
                        PPHUD.showHUDFromTop("新建成功")
                        self.getWebDAVData()
                    }
                    else {
                        PPHUD.showHUDFromTop("新建失败", isError: true)
                    }
                }
            }
            else {
            PPFileManager.shared.uploadFileViaWebDAV(path: self.pathStr+newName, contents: "# 标题".data(using:.utf8)) { (error) in
                if error != nil {
                    PPHUD.showHUDFromTop("新建失败", isError: true)
                }
                else {
                    PPHUD.showHUDFromTop("新建成功")
                    self.getWebDAVData()
                }
            }
                
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    func showImagePicker() {
        var config = YPImagePickerConfiguration()
        config.library.maxNumberOfItems = 1
        config.showsPhotoFilters = false
        config.startOnScreen = YPPickerScreen.library
        let picker = YPImagePicker(configuration: config)
        //                let picker = YPImagePicker()
        picker.didFinishPicking { [unowned picker] items, _ in
            guard let photo = items.singlePhoto else {
                return
            }
            if photo.fromCamera == true {
                debugPrint("====\(photo.originalImage.imageOrientation.rawValue)")
                return
            }
            PPFileManager.shared.getImageDataFromAsset(asset: photo.asset!, completion: { (imageData,imageLocalURL) in
                guard let imageLocalURL = imageLocalURL else {
                    return
                }
                let remotePath = self.pathStr + "PP_"+imageLocalURL.lastPathComponent
                debugPrint(imageLocalURL)
                PPFileManager.shared.uploadFileViaWebDAV(path: remotePath, contents: imageData as Data?) { (error) in
                    PPHUD.showHUDText(message: "上传成功🦄", view: self.view)
                    self.getWebDAVData()
                }
                
            })
            picker.dismiss(animated: true, completion: nil)
        }
        self.present(picker, animated: true, completion: nil)
    }
    /// 加载图片并保存，如果本地不存在就从服务器获取
    func loadAndSaveImage(imageURL:String,fileID:String,completionHandler: ((Data) -> Void)? = nil) {
//        let cache = ImageCache.default//KingFisher用
        let imagePath = PPUserInfo.shared.pp_mainDirectory + imageURL
        self.currentImageURL = imagePath
        
//        let filePath = cache.cachePath(forComputedKey: imageURL)//KingFisher用
//        let cachedData = try?Data(contentsOf: URL(fileURLWithPath: filePath))//KingFisher用
        PPFileManager.shared.getFileData(path: imageURL, fileID: fileID,cacheToDisk:true) { (contents: Data?,isFromCache, error) in
            guard let contents = contents else { return }
            if let handler = completionHandler {
                handler(contents)
            }
        }        
    }
    
    
    func fileNameInvalidResult(_ fileName:String?) -> String? {
        guard let fileName = fileName else {
            return "亲，名字不能为空"
        }
        if fileName.length < 1 {
            return "亲，名字不能为空"
        }
        let existedFile = self.dataSource.filter{$0.name == fileName}
        if existedFile.count > 0 {
            return "亲，文件已存在哦"
        }
        return nil
    }
    //MARK:获取文件列表
    func getWebDAVData() -> Void {
        if isRecentFiles {
            self.dataSource.removeAll()
            self.dataSource.append(contentsOf: PPUserInfo.shared.pp_RecentFiles)
            self.tableView.endRefreshing()
            self.tableView.reloadData()
            return
        }
        
        if (PPUserInfo.shared.webDAVServerURL.length < 1) {
            PPFileManager.shared.initWebDAVSetting()
        }
        PPFileManager.shared.pp_getFileList(path: self.pathStr) { (contents,isFromCache, error) in
            if error != nil {
                PPHUD.showHUDFromTop("加载失败，请配置服务器", isError: true)
                self.tableView.endRefreshing()
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "已加载缓存":"已加载最新")

            self.dataSource.removeAll()
            self.dataSource.append(contentsOf: contents)
            self.tableView.endRefreshing()
            self.tableView.reloadData()
            

        }
        
    }
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    

}
