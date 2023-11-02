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
import SnapKit

fileprivate let tag_newfile = 2333
fileprivate let tag_rename = 2334
let tag_search = 2335


class PPFileListViewController: PPBaseViewController,
                                UITextFieldDelegate,
                                UITableViewDelegate,
                                UICollectionViewDelegate,
                                UICollectionViewDataSource,
                                UICollectionViewDelegateFlowLayout,
                                SKPhotoBrowserDelegate,
                                PopMenuViewControllerDelegate,
                                PPFileListCellDelegate,
                                PPFileListToolBarDelegate,
                                PPDocumentDelegate
{
    var pathStr = "/"
    /// 当前路径唯一ID，百度网盘及阿里云盘等云存储需要
    var pathID = ""
    var rawDataSource:Array<PPFileObject> = [] ///< 原始数据源，筛选过滤时用到
    var dataSource:Array<PPFileObject> = []
    var imageArray = [PPFileObject]()
    let topToolBar = PPFileListToolBar()
    var topToolBarHeight: Constraint? = nil
    var collectionView : UICollectionView!
    var multipleSelectionMode = false
    var cellStyle = PPFileListCellViewMode.list
    var lastResizeWidth = 300.0
    lazy var dropdown : PPDropDown = {
        let drop = PPDropDown()
        return drop
    }()

    var currentImageURL = ""
    var photoBrowser: SKPhotoBrowser!
    var currentImageIndex = -1 // 防止多次调用didShowPhotoAtIndex
    ///如果是展示最近访问的列表
    var isRecentFiles = false
    var isCachedFile = false
    //---------------搜索功能↓---------------
    /// 展示在本控制器的上面的控制器 Search controller to help us with filtering items in the table view.
    var searchController: UISearchController!
    /// 展示在本控制器的上面的控制器的列表 Search results table view.
    var resultsTableController: PPResultsTableController!
    let searchField = UITextField()
    //---------------搜索功能↑---------------
    //---------------移动文件（夹）到其他文件夹功能↓---------------
    var isMovingMode = false
    var leftButton : UIButton!
    var rightButton : UIButton!
    var srcPathForMove = "" ///< 移动文件时的原始目录
    var srcFileIDForMove = "" ///< 移动文件时的原始ID
    //---------------移动文件（夹）到其他文件夹功能↑---------------
    var isSelectFileMode = false
    var titleViewButton : UIButton!
    var showSideBarBtn : UIButton!
    var documentPicker: PPFilePicker! //必须强引用

    //MARK:Life Cycle
//    convenience init() {
//        self.init(nibName:nil, bundle:nil)
//    }
    
        
    // iOS & mac catalyst window resize event
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        debugPrint("new size: \(size)")
        if(abs(lastResizeWidth - size.width) > 20) { //窗口宽度变化大于20才刷新，不要太频繁
            lastResizeWidth = size.width
            self.collectionView?.reloadData()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        self.initSubViews()
        self.cellStyle = PPFileListCellViewMode(rawValue: PPAppConfig.shared.getIntItem("fileViewMode")) ?? .list
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "更多", style: .plain, target: self, action: #selector(moreAction))
        
        if !isRecentFiles {
            getFileListData() //最近页面在viewWillAppear里获取
        }
        
        setNavTitle()
        

        self.collectionView.addRefreshHeader {
            self.getFileListData()
        }
        setupSearchController()
        if isMovingMode {//移动文件模式
            setupMoveUI(title: "移动到", rightText: "完成")
        }
        if isSelectFileMode {
            setupMoveUI(title: "请选择文件", rightText: "选取")
            multipleSelectionMode = true
            collectionView.allowsMultipleSelection = false
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isRecentFiles || PPUserInfo.shared.refreshFileList {
            self.getFileListData()//最近访问列表实时刷新
            PPUserInfo.shared.refreshFileList = false
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

    }
    
    //MARK: - UI
    func initSubViews() {
        setupSearchUI()

        self.view.addSubview(topToolBar)
        topToolBar.delegate = self
        topToolBar.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom)//(self.pp_safeLayoutGuideTop())
            make.left.right.equalTo(self.view)
            //https://snapkit.github.io/SnapKit/docs/#:~:text=1.-,References,-You%20can%20hold
            self.topToolBarHeight = make.height.equalTo(44+14).constraint
        }
        
        let layout = UICollectionViewFlowLayout();
        layout.scrollDirection = .vertical;
        layout.minimumLineSpacing = 0;
        layout.minimumInteritemSpacing = 0;
        
        collectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        self.view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(topToolBar.snp.bottom)
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.pp_safeLayoutGuideBottom());
        }
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PPFileListCell.self, forCellWithReuseIdentifier: kPPCollectionViewCellID)
        collectionView.allowsMultipleSelection = true
    }
    //MARK: - UICollectionView 数据源及回调
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: kPPCollectionViewCellID,
            for: indexPath) as! PPFileListCell
        //        cell.backgroundColor = .black
        // Configure the cell
        let fileObj = self.dataSource[indexPath.row]
        if fileObj.path.length == 0 {
            fileObj.path = pathStr + fileObj.name
        }
        cell.cellIndex = indexPath.row
        cell.updateLayout(self.cellStyle)
        cell.updateUIWithData(fileObj as AnyObject)
        cell.updateCacheStatus(self.isCachedFile)
        cell.remarkLabel.isHidden = !isRecentFiles
        cell.delegate = self
        return cell
    }
    // 1 告诉布局给定单元格的大小
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: kPPCollectionViewCellID,
            for: indexPath) as! PPFileListCell
        let width = view.frame.size.width
        return cell.getSize(self.cellStyle, width)
    }
    // 3 返回单元格、页眉和页脚之间的间距
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int
//    ) -> UIEdgeInsets {
//        return sectionInsets
//    }
    
    // 4 每行之间的间距
    func collectionView(_ collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0
    }
    var deleteTasks: [DispatchWorkItem] = []
    @objc func cancelDelete() {
        // 取消所有的打印任务
        for task in deleteTasks {
            task.cancel()
        }
        deleteTasks.removeAll()
        PPHUD.shared.deleteBGView.removeFromSuperview()
    }
    func didClickMoreBtn(cellIndex: Int, sender:UIButton) {
        debugPrint("==\(cellIndex)")
        if self.isMovingMode {
            return
        }
        self.dropdown.dataSource = ["删除","重命名","移动","打开为文本","多选","预览","浏览器打开"]
        self.dropdown.selectionAction = { (index: Int, item: String) in
            let fileObj = self.dataSource[cellIndex]
            if item == "删除" {
                let printTask = DispatchWorkItem {
                    self.deleteFile(cellIndex)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: printTask)
                self.deleteTasks.append(printTask)
                
                PPHUD.shared.showDelayTaskHUD()
                PPHUD.shared.revokeBtn.addTarget(self, action: #selector(self.cancelDelete), for: .touchUpInside)
            }
            else if item == "重命名" {
                self.renameFile(fileObj)
            }
            else if item == "移动" {
                debugPrint("移动")
                let popVC = PPFileListViewController()
                popVC.isMovingMode = true
                popVC.srcPathForMove = fileObj.path
                popVC.srcFileIDForMove = fileObj.pathID
                let nav = UINavigationController(rootViewController: popVC)
                self.present(nav, animated: true, completion: nil)
            }
            else if item == "多选" {
                self.multipleSelectionMode = true
//                self.topToolBarHeight?.updateOffset(amount: 99)
            }
            else if item == "预览" {
                self.fileQuickLookPreview(fileObj)
            }
            else if item == "打开为文本" {
                self.openAsTextFile(fileObj)
            }
        }
        self.dropdown.anchorView = sender
        self.dropdown.show()
    }
    //MARK: 顶部工具条
    func didClickFileListToolBar(index: Int, title: String, button:UIButton) {
        debugPrint("点击顶部工具条:\(index)\(title)")
        if index == 1 {
            let dataS = ["列表（小）","列表（中）","列表（大）","图标（小）","图标（中）","图标（大）"]
            let selectStr = dataS[PPAppConfig.shared.getIntItem("fileViewMode")];
            self.dropdown.dataSource = dataS.map({$0 == selectStr ? "\($0) ✅" : $0});
            self.dropdown.selectionAction = { (index: Int, item: String) in
                self.cellStyle = PPFileListCellViewMode(rawValue: index) ?? .list
                PPAppConfig.shared.setItem("fileViewMode","\(index)")
                self.collectionView.reloadData()
            }
            self.dropdown.anchorView = button
            self.dropdown.show()
        }
        else if index == 0 {
            showSortPopMenu(anchorView: button)
        }
        else if index == 2 {
            self.multipleSelectionMode = true
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "取消选择", style: .plain, target: self, action: #selector(self.cancelMultiSelect))
        }
        else if index == 3 {
            self.getFileListData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if multipleSelectionMode {
            let cell = collectionView.cellForItem(at: indexPath)
            cell?.backgroundColor = .clear
        }
    }
    //MARK: 点击文件 click file cell
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let cell = collectionView.cellForItem(at: indexPath)
        guard let cell = collectionView.cellForItem(at: indexPath) as? PPFileListCell else {
            return
        }

        let fileObj = self.dataSource[indexPath.row]
        if multipleSelectionMode {
            cell.backgroundColor = "4abf8a66".pp_HEXColor()
                        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .right)
            if (!collectionView.allowsMultipleSelection) {
                if fileObj.isDirectory {
                    let vc = PPFileListViewController()
                    vc.pathStr = getPathNotEmpty(fileObj) + "/"
                    vc.pathID = fileObj.pathID
                    vc.isSelectFileMode = self.isSelectFileMode
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            return
        }
        collectionView.deselectItem(at: indexPath, animated: true)
        insertToRecentFiles(fileObj,isRecentFiles)
        let objIndex = Int(fileObj.associatedServerID) ?? 0
        if(objIndex != PPUserInfo.shared.pp_lastSeverInfoIndex) {
            PPUserInfo.shared.updateCurrentServerInfo(index: objIndex)
            PPFileManager.shared.initCloudServiceSetting()
        }


//        debugPrint("文件：\(fileObj.path)")
        
        if fileObj.isDirectory {
            let vc = PPFileListViewController()
            vc.pathStr = getPathNotEmpty(fileObj) + "/"
            vc.pathID = fileObj.pathID
            vc.isMovingMode = self.isMovingMode
            if(vc.isMovingMode) {
                vc.srcFileIDForMove = self.srcFileIDForMove
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.isTextFile())  {
            let vc = PPMarkdownViewController()
            vc.filePathStr = getPathNotEmpty(fileObj)
            vc.fileID = fileObj.pathID
            vc.downloadURL = fileObj.downloadURL
            self.pushDetail(vc)
        }
        else if (fileObj.name.pp_isImageFile())  {
            cell.iconImage.contentMode = .scaleAspectFit
            cell.downloadFile(fileObj) { localFilePath in
                self.showImage(fromView:cell, imageName: fileObj.path, imageURL:localFilePath) {
                    fileObj.downloadProgress = 1.0
                    collectionView.reloadItems(at: [indexPath]) //下载成功后再刷新
                }
            }
        }
        else if (fileObj.name.hasSuffix("pdf"))  {
            PPFileManager.shared.getLocalURL(path: getPathNotEmpty(fileObj), fileID: fileObj.pathID) { filePath in
                if #available(iOS 11.0, *) {
                    let vc = PPPDFViewController()
                    vc.filePathStr = filePath
                    self.navigationController?.pushViewController(vc, animated: true)
                } else {
                    PPHUD.showHUDFromTop("暂不支持iOS11以下系统预览PDF")
                }
            }
        }
        else if (fileObj.name.pp_isVideoAudioFile())  {
            PPFileManager.shared.getLocalURL(path: self.getPathNotEmpty(fileObj), fileID: fileObj.pathID, downloadURL: fileObj.downloadURL) { filePath in
                let vc = PlayerViewController()
                vc.localFileURL = URL(fileURLWithPath: filePath)
                vc.name = fileObj.name
                self.pushDetail(vc)
            }
        }
        else {
            cell.updateUIWithData(fileObj)
            cell.downloadFile(fileObj) { url in
                self.fileQuickLookPreview(fileObj)
            }
        }
        
    }
// MARK: - UITextFieldDelegate
    //https://stackoverflow.com/a/58006735/4493393
    //here is how I selecte file name `Panda` from `Panda.txt`
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let string = textField.text else { return }
        if textField.tag == tag_rename {
            textField.selectNamePartOfFileName()
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        debugPrint("textFieldShouldReturn")
        return true
    }
    
    func deleteFile(_ index:Int) {
        let fileObj = self.dataSource[index]
        debugPrint("开始删除文件:",fileObj)
        if (self.isRecentFiles) {
            self.dataSource.remove(at: index)
            removeFromRecentFiles(fileObj)
            self.collectionView.reloadData()
            PPHUD.showHUDFromTop("已删除访问记录，文件未删除")
            return
        }
        //相对路径
        PPFileManager.shared.deteteFile(path: fileObj.path, pathID: fileObj.pathID) { (error) in
            if let errorNew = error {
                PPHUD.showHUDFromTop("删除失败: \(String(describing: errorNew))", isError: true)
            }
            else {
                PPHUD.showHUDFromTop("文件删除成功")
                self.removeFromRecentFiles(fileObj)
                self.getFileListData()
            }
        }
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
    // 仅在self.present(self.photoBrowser的时候执行
    func viewForPhoto(_ browser: SKPhotoBrowser, index: Int) -> UIView? {
        if (currentImageIndex != -1) {
            return nil
        }
        let obj = self.imageArray[index];
        let indexPath = IndexPath(item: obj.cellIndex, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? PPFileListCell else { return nil }
        return cell.iconImage
    }
    //照片浏览器消失
    func didDismissAtPageIndex(_ index: Int) {
        currentImageIndex = -1
        

    }
    // 滑动和点击左右都会执行。在滑到第index页的时候，下载当前页的图片并且让SKPhotoBrowser刷新
    func didShowPhotoAtIndex(_ browser: SKPhotoBrowser, index: Int) {
        //debugPrint("didShowPhotoAtIndex",index,browser.currentPageIndex)
        if(currentImageIndex != index) {
            currentImageIndex = index
            let obj = self.imageArray[index];
            let indexPath = IndexPath(item: obj.cellIndex, section: 0)
            guard let cell = collectionView.cellForItem(at: indexPath) as? PPFileListCell else {
                return
            }
            cell.downloadFile(obj) { localFilePath in
                obj.downloadProgress = 1.0
                self.collectionView.reloadItems(at: [indexPath])
                let obj2 = browser.photos[index]
                obj2.loadUnderlyingImageAndNotify()//刷新图像
            }
        }
    }
    
    //根据参数加载显示图片 Load photo according to the parameters
    func showImage(fromView: UIView?,imageName:String,imageURL:String,completion: (() -> Void)? = nil) -> Void {
        var photos = [SKLocalPhoto]()
        let imageToSKPhoto = imageArray.map { imageObj -> SKLocalPhoto in
            let path2 = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(getPathNotEmpty(imageObj))".replacingOccurrences(of: "//", with: "/")
            let photo2 = SKLocalPhoto.photoWithImageURL(path2)//SKPhoto.photoWithImageURL(url2.absoluteString)
            photo2.caption = imageObj.path
            return photo2
        }
        photos.append(contentsOf: imageToSKPhoto)
//        self.photoBrowser = SKPhotoBrowser(originImage: UIImage(), photos: photos, animatedFromView: fromView)
        self.photoBrowser = SKPhotoBrowser(photos: photos)
        self.photoBrowser.shouldAutoHideControlls = false
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
            textField.tag = tag_rename
        }
        let saveAction = UIAlertAction(title: "保存", style: UIAlertAction.Style.default, handler: { alert -> Void in
            let firstTextField = alertController.textFields![0] as UITextField
            //let secondTextField = alertController.textFields![1] as UITextField
            if let tips = self.fileNameInvalidResult(firstTextField.text) {
                PPHUD.showHUDFromTop(tips, isError: true)
                return
            }
            guard let newName = firstTextField.text else { return }
            PPFileManager.shared.moveFile(srcPath: pathPrefix + fileObj.name,
                                          destPath: pathPrefix + newName,
                                          srcFileID: fileObj.pathID,
                                          destFileID: fileObj.pathID,
                                          isRename: true) { error in
                PPHUD.showHUDFromTop("修改成功")
                let fileNew = fileObj
                fileNew.name = newName
                fileNew.path = pathPrefix + newName
                self.insertToRecentFiles(fileNew, self.isRecentFiles)
                self.getFileListData()
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func moreAction(_ sender:UIButton)  {
        var menuTitile = ["添加文件","从相册添加图片","新建文本文档","新建文件夹"]
        if self.navigationController?.viewControllers.count == 1 {
            menuTitile.append("添加云服务")
            menuTitile.append("编辑云服务")
        }
        if isRecentFiles {
            menuTitile = ["清空访问历史"]
        }
        self.dropdown.dataSource = menuTitile
        self.dropdown.selectionAction = { (index: Int, title: String) in
            if title == "从相册添加图片" {
                self.showImagePicker { selectedAssets in
                    PPFileManager.shared.uploadPhotos(selectedAssets, completion: { photoAssets in
                        self.getFileListData()
                    })
                }
            }
            else if title == "新建文本文档" {
                self.newTextFile()
            }
            else if title == "添加文件" {
                self.documentPicker = PPFilePicker(presentationController: self, delegate: self)
                self.documentPicker.showFilePicker()
            }
            else if title == "新建文件夹" {
                self.newTextFile(isDir: true)
            }
            else if title == "添加云服务" {
                self.addCloudService()
            }
            else if title == "编辑云服务" {
                self.editCloudService()
            }
            else if title == "清空访问历史" {
                PPUserInfo.shared.recentFiles.removeAll()
                self.getFileListData()
            }
        }
        
        self.dropdown.anchorView = sender
        self.dropdown.show()
    }
    @objc func cancelMultiSelect() {
        multipleSelectionMode = false //取消多选
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "更多", style: .plain, target: self, action: #selector(moreAction(_:)))
    }
    //MARK:新建文本文档 & 上传照片
    func newTextFile(isDir:Bool = false) {
        let alertController = UIAlertController(title: isDir ? "新建文件夹" :"新建纯文本(格式任意)", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "输入文件名"
            textField.text = isDir ? "新建文件夹" :"新建文档.md"
            textField.delegate = self
            textField.tag = tag_newfile
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
                PPFileManager.shared.createFolder(folder: newName, at: self.pathStr, parentID: self.pathID) { (error) in
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
                PPFileManager.shared.createFile(path: self.pathStr+newName,parentID: self.pathID, contents: "# 标题".data(using:.utf8)) { (result, error) in
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
    //MARK: 添加文件回调
    func didPickDocuments(documents: [PPDocument]?) {
        debugPrint(documents)
        guard let documents = documents else { return }//为空返回
        for obj in documents {
            guard let objData = try? Data(contentsOf: obj.fileURL) else { return }//为空返回
            var fileName = obj.fileURL.lastPathComponent
            if obj.fileURL.absoluteString.pp_isMediaFile() &&
                PPUserInfo.pp_boolValue("uploadImageNameUseCreationDate") {
                fileName = obj.fileURL.path.pp_getFileModificationDate().pp_stringWithoutColon() + "." + obj.fileURL.pathExtension
            }
            PPFileManager.shared.createFile(path: self.pathStr + fileName, contents: objData) { (result, error) in
                if error != nil {
                    PPHUD.showHUDFromTop("新建失败", isError: true)
                }
                else {
                    PPHUD.showHUDFromTop("新建成功")
                    self.getFileListData()
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
    func fileQuickLookPreview(_ fileObj:PPFileObject) {
        PPFileManager.shared.getLocalURL(path: self.getPathNotEmpty(fileObj),
                                         fileID: fileObj.pathID,
                                         downloadURL: fileObj.downloadURL) { progress in
            debugPrint("fileQuickLookPreview Download Progress: \(progress.fractionCompleted)")
            fileObj.downloadProgress = progress.fractionCompleted
//            self.reloadCellDownloadProgress()
        } completion: { filePath in
            fileObj.downloadProgress = 1.0
            let vc = PPPreviewController() //QuickLook框架预览
            vc.filePathArray = [filePath]
            self.present(vc, animated: true)
        }
    }
    //MARK: 获取文件列表
    func getFileListData() -> Void {
        if isRecentFiles {
            self.rawDataSource = PPUserInfo.shared.recentFiles
            self.dataSource = self.sort(array: self.rawDataSource, orderBy: PPAppConfig.shared.fileListOrder, basePath: self.pathStr);
            self.imageArray = self.rawDataSource.filter{$0.name.pp_isImageFile()}
            self.collectionView.endRefreshing()
            self.sortRecentFileList()
            self.collectionView.reloadData()
            PPHUD.showHUDFromTop("暂无最近文件")
            return
        }
        
//        if (PPUserInfo.shared.webDAVServerURL.length < 1) {
//            PPFileManager.shared.initCloudServiceSetting()
//        }
        
        PPFileManager.shared.pp_getFileList(path: self.pathStr, pathID:self.pathID) { (contents,isFromCache, error) in
            self.isCachedFile = isFromCache
            if error != nil {
                self.collectionView.endRefreshing()
                if case let myError as PPCloudServiceError = error {
                    if myError == .forcedLoginRequired {
                        PPHUD.showHUDFromTop("登录状态已失效，请重新登录", isError: true)
                        debugPrint(PPUserInfo.shared.pp_serverInfoList[PPUserInfo.shared.pp_lastSeverInfoIndex])
                        let serviceType = PPUserInfo.shared.getCurrentServerInfo("PPCloudServiceType")
                        PPAddCloudServiceViewController.addCloudService(serviceType, self)
                    }
                    else if myError == .certificateInvalid {
                        PPHUD.showHUDFromTop("服务器证书过期或无效", isError: true)
                    }
                }
                else {
                    PPHUD.showHUDFromTop("加载失败，请检查服务器配置", isError: true)
                }
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "":"已加载最新\(self.dataSource.count)项")
            self.rawDataSource = contents
            self.dataSource = self.sort(array: contents, orderBy: PPAppConfig.shared.fileListOrder, basePath: self.pathStr);
            self.imageArray = self.rawDataSource.filter{$0.name.pp_isImageFile()}
            self.collectionView.endRefreshing()
            self.collectionView.reloadData()
        }
        
    }
    
    func openAsTextFile(_ fileObj:PPFileObject) {
        if(fileObj.size > 2048*1024) {
            PPAlertAction.showAlert(withTitle: "当前文件过大", msg: "是否继续", buttonsStatement: ["确定","取消"]) { index in
                if index == 0 {
                    let vc = PPMarkdownViewController()
                    vc.filePathStr = self.getPathNotEmpty(fileObj)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
        else {
            let vc = PPMarkdownViewController()
            vc.filePathStr = self.getPathNotEmpty(fileObj)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    

}

