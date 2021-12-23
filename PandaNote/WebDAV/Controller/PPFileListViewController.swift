//
//  XDHomeViewController.swift
//  TeamDisk
//
//  Created by Panway on 2019/8/1.
//  Copyright © 2019 Panway. All rights reserved.
//

import UIKit
//import FilesProvider
import SKPhotoBrowser
import Kingfisher
#if USE_YPImagePicker
import YPImagePicker
#endif
import PopMenu
import Photos
import MonkeyKing


class PPFileListViewController: PPBaseViewController,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate
    ,SKPhotoBrowserDelegate
    ,PopMenuViewControllerDelegate
{
    
    var pathStr = "/"
    var pathID = ""
    var dataSource:Array<PPFileObject> = []
    var imageArray = [PPFileObject]()
    var tableView = UITableView()

    var currentImageURL = ""
    var photoBrowser: SKPhotoBrowser!
    ///如果是展示最近访问的列表
    var isRecentFiles = false
    var isCachedFile = false
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
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
        
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更多", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
        
        
        getFileListData()
        
        setNavTitle()
        

        self.tableView.addRefreshHeader {
            self.getFileListData()
        }
        setupSearchController()
        if isMovingMode {//移动文件模式
            setupMoveUI()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isRecentFiles || PPUserInfo.shared.refreshFileList {
            self.getFileListData()//最近访问列表实时刷新
            PPUserInfo.shared.refreshFileList = false
        }
    }
    //MARK: - UITableViewDataSource UITableViewDelegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.dataSource[indexPath.row]
        cell.updateUIWithData(fileObj as AnyObject)
        cell.updateCacheStatus(self.isCachedFile)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fileObj = self.dataSource[indexPath.row]
//        debugPrint("文件：\(fileObj.path)")
        PPUserInfo.shared.insertToRecentFiles(fileObj)
        
        if fileObj.isDirectory {
            let vc = PPFileListViewController()
            vc.pathStr = getPathNotEmpty(fileObj) + "/"
            vc.pathID = fileObj.pathID
            vc.isMovingMode = self.isMovingMode
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.isTextFile())  {
            let vc = PPMarkdownViewController()
            vc.filePathStr = getPathNotEmpty(fileObj)
            vc.fileID = fileObj.pathID
            vc.downloadURL = fileObj.downloadURL
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.pp_isImageFile())  {
            loadAndCacheImage(fileObj) { (imageData,imageLocalPath) in
                self.showImage(contents: imageData, image: nil, imageName: fileObj.path,imageURL:imageLocalPath) {
                    tableView.reloadRows(at: [indexPath], with: .none)//下载成功后再刷新
                }
            }
        }
        else if (fileObj.name.hasSuffix("pdf"))  {
            if #available(iOS 11.0, *) {
                let vc = PPPDFViewController()
                vc.filePathStr = getPathNotEmpty(fileObj)
                vc.fileID = fileObj.pathID
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                PPHUD.showHUDFromTop("抱歉，暂不支持iOS11以下系统预览PDF哟")
            }
        }
        else if (fileObj.name.hasSuffix("mp3")||fileObj.name.lowercased().hasSuffix("mp4"))  {
            PPFileManager.shared.getFileData(path: getPathNotEmpty(fileObj), fileID: fileObj.pathID,cacheToDisk:true,onlyCheckIfFileExist:true) { (contents: Data?,isFromCache, error) in
                if error != nil {
                    return
                }
                let vc = PlayerViewController()
                let filePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(self.getPathNotEmpty(fileObj))"
                vc.localFileURL = URL(fileURLWithPath: filePath)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        else {
            PPAlertAction.showAlert(withTitle: "暂不支持", msg: "是否以纯文本方式打开", buttonsStatement: ["打开","不了"]) { (index) in
                if index == 0 {
                    let vc = PPMarkdownViewController()
                    vc.filePathStr = self.getPathNotEmpty(fileObj)
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
            PPFileManager.shared.deteteRemoteFile(path: fileObj.path) { (error) in
                if let errorNew = error {
                    PPHUD.showHUDFromTop("删除失败: \(String(describing: errorNew))", isError: true)
                }
                else {
                    PPHUD.showHUDFromTop("文件删除成功")// (message: "删除成功哟！", view: self.view)
                    PPUserInfo.shared.removeFileInRecentFiles(fileObj)
                    self.getFileListData()
                }
            }
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
            let message = MonkeyKing.Message.weChat(.session(info: (
                title: "Session",
                description: "Hello Session",
                thumbnail: nil,
                media: .image(underlyingImage)
            )))
            
            MonkeyKing.deliver(message) { success in
                print("shareURLToWeChatSession success: \(success)")
            }
//            PPShareManager.shared().weixinShareImage(underlyingImage, type: PPSharePlatform.weixinSession.rawValue)
        }
        else if buttonIndex == 1 {
//            let photo = photoBrowser.photos[photoIndex]
//            guard let underlyingImage = photo.underlyingImage else {
//                return
//            }
//            let imagePath = ImageCache.default.cachePath(forKey: self.currentImageURL ?? "")
//            let imageData = try?Data(contentsOf: URL(fileURLWithPath: self.currentImageURL ?? ""))
            guard let imageData = FileManager.default.contents(atPath: self.currentImageURL) else {
                return
            }
            let message = MonkeyKing.Message.weChat(.session(info: (
                title: nil,
                description: nil,
                thumbnail: UIImage(data: imageData),
                media: .gif(imageData)
            )))
            
            MonkeyKing.deliver(message) { success in
                print("分享Gif表情到微信 shareGifToWeChatSession result: \(success)")
            }
//            PPShareManager.shared().weixinShareEmoji(imageData ?? Data.init(), type: PPSharePlatform.weixinSession.rawValue)
        }
    }
    
    //在滑到第index页的时候，下载当前页的图片并且让SKPhotoBrowser刷新
    func didScrollToIndex(_ browser: SKPhotoBrowser, index: Int) {
        debugPrint(index)
        let obj = self.imageArray[index];
        loadAndCacheImage(obj) { data, url in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                let obj2 = browser.photos[index]
                obj2.loadUnderlyingImageAndNotify()
                // browser.reloadData()
            })
        }
    }
    //根据参数加载显示图片 Load photo according to the parameters
    func showImage(contents:Data,image:UIImage?,imageName:String,imageURL:String,completion: (() -> Void)? = nil) -> Void {
        var photos = [SKPhoto]()
        let imageToSKPhoto = imageArray.map { imageObj -> SKPhoto in
            let path2 = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(getPathNotEmpty(imageObj))"
            let url2 = URL(fileURLWithPath: path2)
            let photo2 = SKPhoto.photoWithImageURL(url2.absoluteString)
            photo2.caption = imageObj.path
            return photo2
        }
        photos.append(contentsOf: imageToSKPhoto)
        self.photoBrowser = SKPhotoBrowser(photos: photos)

        var clickIndex = 0//点击的图片是第几张 The sequence number of the clicked photo
        for i in 0..<imageArray.count {
            let fileObj = imageArray[i]
            if imageURL.contains(fileObj.path) {
                clickIndex = i
                break
            }
        }
        
        self.photoBrowser.initializePageIndex(clickIndex)
        self.photoBrowser.delegate = self
        SKPhotoBrowserOptions.actionButtonTitles = ["微信原图分享","微信表情(Gif)分享😄","UIActivityViewController分享"]
        
        self.present(self.photoBrowser, animated: true, completion: {})
        if let completion = completion {
            completion()
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
            PPFileManager.shared.moveRemoteFile(pathOld: pathPrefix+fileObj.name, pathNew: pathPrefix + newName) { (error) in
                PPHUD.showHUDFromTop("修改成功")
                let fileNew = fileObj
                fileNew.name = newName
                fileNew.path = pathPrefix + newName
                if let index = PPUserInfo.shared.pp_RecentFiles.firstIndex(of: fileObj) {
                    PPUserInfo.shared.pp_RecentFiles.remove(at: index)
                    PPUserInfo.shared.insertToRecentFiles(fileNew)
                }
                self.getFileListData()
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    @objc func moreAction()  {
        var menuTitile = ["从🏞添加照骗","新建文本文档📃","新建文件夹📂"]
        if self.navigationController?.viewControllers.count == 1 {
            menuTitile.append("添加云服务")
        }
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: menuTitile) { (index) in
            debugPrint(index)
            if index == 1 {
                self.showImagePicker { selectedAssets in
                    PPFileManager.shared.uploadPhotos(selectedAssets, completion: { photoAssets in
                        self.getFileListData()
                    })
                }
            }
            else if index == 2 {
                self.newTextFile()
            }
            else if index == 3 {
                self.newTextFile(isDir: true)
            }
            else if index == 4 {
                self.addCloudService()
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
                        self.getFileListData()
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
                    self.getFileListData()
                }
            }
                
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    /// 加载图片并保存，如果本地不存在就从服务器获取
    func loadAndCacheImage(_ file:PPFileModel,completionHandler: ((Data,String) -> Void)? = nil) {
//        let cache = ImageCache.default//KingFisher用
        let imageURL = file.path
        let fileID = file.pathID
        
        // /Library/Caches/PandaCache/OneDrive/path/to/example.png
        let imagePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(imageURL)"
        self.currentImageURL = imagePath
        
//        let filePath = cache.cachePath(forComputedKey: imageURL)//KingFisher用
//        let cachedData = try?Data(contentsOf: URL(fileURLWithPath: filePath))//KingFisher用
        
        PPFileManager.shared.getFileData(path: getPathNotEmpty(file), fileID: fileID,downloadURL:file.downloadURL,cacheToDisk:true) { (contents: Data?,isFromCache, error) in
            guard let contents = contents else { return }
            if let handler = completionHandler {
                DispatchQueue.main.async {
                    handler(contents,imagePath)
                }
            }
        }        
    }
    
    func getPathNotEmpty(_ fileObj:PPFileModel) -> String {
        if fileObj.path.length < 1 {
            return self.pathStr + fileObj.name
        }
        else {
            return fileObj.path
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
    func getFileListData() -> Void {
        if isRecentFiles {
            self.dataSource.removeAll()
            self.dataSource.append(contentsOf: PPUserInfo.shared.pp_RecentFiles)
            self.imageArray = self.dataSource.filter{$0.name.pp_isImageFile()}
            self.tableView.endRefreshing()
            self.tableView.reloadData()
            PPHUD.showHUDFromTop("暂无最近文件")
            return
        }
        
        if (PPUserInfo.shared.webDAVServerURL.length < 1) {
            PPFileManager.shared.initCloudServiceSetting()
        }
        
        PPFileManager.shared.pp_getFileList(path: self.pathStr, pathID:self.pathID) { (contents,isFromCache, error) in
            self.isCachedFile = isFromCache
            if error != nil {
                PPHUD.showHUDFromTop("加载失败，请配置服务器", isError: true)
                self.tableView.endRefreshing()
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "已加载缓存":"已加载最新")

            self.dataSource.removeAll()
            self.dataSource.append(contentsOf: contents)
            self.imageArray = self.dataSource.filter{$0.name.pp_isImageFile()}
            self.tableView.endRefreshing()
            self.tableView.reloadData()
            

        }
        
    }
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    

}

