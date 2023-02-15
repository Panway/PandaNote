//
//  PPMarkdownViewController.swift
//  TeamDisk
//
//  Created by panwei on 2019/6/8.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//
import UIKit
import Foundation
import FilesProvider
import Down

typealias PPPTextView = UITextView

@objc enum PPSplitMode : UInt8 {
    case none
    case leftAndRight
    case upAndDown
}
//UITextViewDelegate
class PPMarkdownViewController: PPBaseViewController,
                                UITextViewDelegate,
                                PPEditorToolBarDelegate {
    
    
//    let markdownParser = MarkdownParser()
    var markdownStr = "I support a *lot* of custom Markdown **Elements**, even `code`!"
    var historyList = [String]()
    var textView = PPPTextView()
    let backgroundImage  = UIImageView()
    ///文件相对路径
    var filePathStr: String = ""
    ///文件ID（仅百度网盘）
    var fileID = ""
    var downloadURL = ""
//    var webdav: WebDAVFileProvider?
    var closeAfterSave : Bool = false
    var textChanged : Bool = false//文本改变的话就不需要再比较字符串了
    var splitMode = PPSplitMode.none //上次的分栏模式 last mode
    var theme : PPThemeModel!
    //MARK: Life Cycle
    override func viewDidLoad() {
        initStyle()
        pp_initView()
        self.title = self.filePathStr.split(string: "/").last
        PPFileManager.shared.getFileData(path: filePathStr,
                                         fileID: fileID,
                                         downloadURL:downloadURL,
                                         cacheToDisk:true,
                                         downloadIfCached:true) { (contents: Data?,isFromCache, error) in
            guard let contents = contents else {
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "已加载缓存文件":"已加载最新的")
//            debugPrint(String(data: contents, encoding: .utf8)!) // "hello world!"
            if let text_encoded = String(textData: contents) {
                self.markdownStr = text_encoded
            }
            else {
                PPHUD.showHUDFromTop("此文本无法用 UTF8 编码", isError:true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.navigationController?.popViewController(animated: true)
                }
                return
            }
            
            //markdown解析的方式
            if let selectedIndex = PPUserInfo.shared.pp_Setting["pp_markdownParseMethod"] {
                let method = selectedIndex as! String
                if method == "NSAttributedString+Markdown" {
                    //NSAttributedString+Markdown 解析
                    self.textView.attributedText = NSAttributedString(markdownRepresentation: self.markdownStr, attributes: [.font : UIFont.systemFont(ofSize: 17.0), .foregroundColor: self.theme.baseTextColor.pp_HEXColor()])
                    self.textView.linkTextAttributes = [.foregroundColor:self.theme.linkTextColor.pp_HEXColor()]

                }
                else if method == "Down" {
                    //MARK:Down渲染
                    let down = Down(markdownString: self.markdownStr)
                    //DownAttributedStringRenderable 31行
                    let attributedString = try? down.toAttributedString(DownOptions.default, stylesheet: "* {font-family: Helvetica } code, pre { font-family: Menlo } code {position: relative;background-color: #f6f8fa;border-radius: 6px;} img {max-width: 100%;display: block;margin-left: auto;margin-right: auto;}")
                    self.textView.attributedText = attributedString
                    
                }
                else {
                    self.textView.text = self.markdownStr//none
                }
            }
            else {//没设置
                self.textView.text = self.markdownStr
            }
            
            //定位到上次滚动的位置
            let offsetKey = PPFileManager.shared.currentServerUniqueID().pp_md5
            let offsetY = PPCacheManeger.shared.get(offsetKey).toCGFloat()
            if offsetY > 0 {
                //为0的时候设置好像有时候文字不显示？？？
                self.textView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            }
            
        }

        
        
        self.view.backgroundColor = UIColor.white

    }
    deinit {
        self.switchSplitMode(.none)//好像不加也行
    }
    func pp_initView() {
        self.view.addSubview(backgroundImage)
        self.pp_viewEdgeEqualToSafeArea(backgroundImage)

        self.view.addSubview(textView)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)//Padding,内边距
        self.pp_viewEdgeEqualToSafeArea(textView)
        textView.font = UIFont.systemFont(ofSize: 16.0)
        
        textView.delegate = self
        
        
        
        let editorToolBar = PPMarkdownEditorToolBar(frame: CGRect(x: 0,y: 0,width: self.view.frame.size.width,height: 40))
        editorToolBar.delegate = self
        textView.inputAccessoryView = editorToolBar
        
        let topToolView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 120, height: 40))
        
        topToolView.addSubview(button0)
        topToolView.addSubview(button1)
        topToolView.addSubview(button2)
        
        let rightBarItem = UIBarButtonItem.init(customView: topToolView)
        
        self.navigationItem.rightBarButtonItem = rightBarItem
        
        self.setLeftBarButton()
    }
    func changed() -> Bool {
        return self.textView.text == self.markdownStr
    }
    override func pp_backAction() {
        self.textView.resignFirstResponder()
        //心疼CPU，文本有修改的话就不全部比较了>_<
        if !self.textChanged || changed() {
            debugPrint("未修改,直接退出")
            self.navigationController?.popViewController(animated: true)
            return
        }
        if (PPUserInfo.pp_valueForSettingDict(key: "saveMarkdownWhenClose")) {
            self.closeAfterSave = true
            self.saveTextAction(sender: nil)
        } else {
            PPAlertAction.showAlert(withTitle: "是否保存已修改的文字", msg: "", buttonsStatement: ["不保存","要保存"]) { (index) in
                debugPrint("\(index)")
                if (index == 0) {
                    self.navigationController?.popViewController(animated: true)
                }
                else {
                    self.closeAfterSave = true
                    self.saveTextAction(sender: nil)
                }
            }
            
        }
    }
    // MARK:UITextViewDelegate 文本框代理
    func textViewDidChange(_ textView: PPPTextView) {
//        debugPrint(textView.text)
        if splitMode != .none {
            PPUserInfo.shared.webViewController.renderMardownWithJS(self.textView.text)
        }
    }
    func textViewShouldBeginEditing(_ textView: PPPTextView) -> Bool {
        debugPrint("====Start")
        return true
    }
    func textView(_ textView: PPPTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textChanged = true
        let newRange = Range(range, in: textView.text)!
        let mySubstring = textView.text![newRange]
        let myString = String(mySubstring)
        debugPrint("===shouldChangeTextIn \(myString)")
        return true
    }
    func textViewDidEndEditing(_ textView: PPPTextView) {
//        debugPrint("===textViewDidEndEditing \(textView.attributedText.markdownRepresentation)")
        historyList.append(self.textView.text)
        debugPrint("historyList= \(historyList.count)")
    }
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        debugPrint("\(URL)")
        return true
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let offsetKey = PPFileManager.shared.currentServerUniqueID().pp_md5
        debugPrint("滚动偏移量:\(scrollView.contentOffset.y)")
        PPCacheManeger.shared.set("\(scrollView.contentOffset.y)", key: offsetKey)
        if splitMode != .none {
            self.scrollToSameTextAsTextView()
        }
    }
    ///结束拖动更新y偏移量
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        debugPrint("scrollViewDidEndDragging")
        if splitMode != .none {
            self.scrollToSameTextAsTextView()
        }
    }
    //MARK: - Private 私有方法
    
    ///定位到与 TextView 相同的文本
    func scrollToSameTextAsTextView() {
        let range = Range(self.textView.pp_visibleRange())!
        let visibleTextTop = self.textView.text.substring(range)
        let array = visibleTextTop.split(separator: "\n")
        if array.count > 0 {
            let firstLineTextOfScreen = String(array[0])
            debugPrint("屏幕第一行文字-->\(firstLineTextOfScreen)")
            PPUserInfo.shared.webViewController.scrollToText(firstLineTextOfScreen) { offsetYFromJS in
                if offsetYFromJS != 0 {
                    debugPrint("JS没滚动到指定位置，滚动到百分比")
                    let percentage = self.textView.contentOffset.y / self.textView.contentSize.height
                    PPUserInfo.shared.webViewController.scrollToProportion(proportion: max(percentage,0))
                }
            }
        }
    }
    ///分栏模式
    @objc func switchSplitMode(_ mode: PPSplitMode)  {
        if splitMode == mode {
            return
        }
        splitMode = mode
        let webVC = PPUserInfo.shared.webViewController
        if splitMode == .none {
            self.pp_updateEdgeToSafeArea(textView)
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.view.frame = self.view.bounds
            webVC.removeFromParent()
            return
        }
        else if splitMode == .leftAndRight {
            self.textView.snp.remakeConstraints { maker in
                maker.top.equalTo(self.pp_safeLayoutGuideTop())
                if #available(iOS 11.0, *) {
                    maker.left.equalTo(self.view.safeAreaLayoutGuide.snp.left)
                    maker.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                    maker.width.equalTo(self.view.safeAreaLayoutGuide).multipliedBy(0.5)
                } else {
                    maker.width.equalTo(self.view).multipliedBy(0.5)
                }
            }

        }
        else if splitMode == .upAndDown {
            self.textView.snp.remakeConstraints { maker in
                maker.top.equalTo(self.pp_safeLayoutGuideTop())
                if #available(iOS 11.0, *) {
                    maker.left.right.equalTo(self.view.safeAreaLayoutGuide)
                    maker.height.equalTo(self.view.safeAreaLayoutGuide.layoutFrame.height/2)
                } else {
                    maker.left.right.equalTo(self.view)
                    maker.height.equalTo(self.view).multipliedBy(0.5)
                }
            }
            
        }
        
        var path = ""
        if self.filePathStr.hasSuffix("html") {//HTML文件直接显示
            path = PPDiskCache.shared.path + self.filePathStr
            webVC.fileURLStr = path
        }
        else {
            path = Bundle.main.url(forResource: "markdown", withExtension:"html")?.absoluteString ?? ""
            webVC.markdownStr = self.textView.text
            webVC.urlString = path // file:///....
            webVC.markdownName = self.filePathStr
        }

        self.addChild(webVC)
        self.view.addSubview(webVC.view)
        webVC.view.frame = self.view.frame
        webVC.didMove(toParent: self)
        let width = self.view.frame.size.width
        let height = self.view.frame.size.height
        if splitMode == .leftAndRight {
            webVC.view.frame = CGRect(x: width/2, y: 0, width: width/2, height: height)
//            webVC.view.snp.remakeConstraints { maker in
//                maker.top.right.bottom.equalTo(self.view)
//                maker.width.equalTo(self.view).multipliedBy(0.5)
//            }
        }
        else if splitMode == .upAndDown {
            webVC.view.frame = CGRect(x: 0, y: self.view.frame.size.height/2, width: self.view.frame.size.width, height: self.view.frame.size.height/2)
            // 不能用自动布局，不然再次push进入webVC就是一片黑,webVC.view不会复原
//            webVC.view.snp.remakeConstraints { maker in
//                maker.bottom.left.right.equalTo(self.view)
//                maker.height.equalTo(self.view).multipliedBy(0.5)
//            }
        }
        
        PPUserInfo.shared.webViewController.markdownStr = self.textView.text
        PPUserInfo.shared.webViewController.loadURL()
        
    }

    /// 预览markdown
    @objc func previewAction(sender:UIButton)  {
//        self.splitMode = .none
        self.switchSplitMode(.none)
        self.textView.resignFirstResponder()
        let webVC = PPUserInfo.shared.webViewController//PPWebViewController()
        var path = ""
        if self.filePathStr.hasSuffix("html") {//HTML文件直接显示
            path = PPDiskCache.shared.path + self.filePathStr
            webVC.fileURLStr = path
        }
        else {
            path = Bundle.main.url(forResource: "markdown", withExtension:"html")?.absoluteString ?? ""
            webVC.markdownStr = self.textView.text
            webVC.urlString = path // file:///....
//            webVC.urlString = "http://127.0.0.1:8083/markdown.html"//调试用 for Debug use
            webVC.markdownName = self.filePathStr
            let lastPath = (self.filePathStr as NSString).lastPathComponent
            webVC.imageRootPath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)\(self.filePathStr.replacingOccurrences(of: lastPath, with: ""))"
            webVC.imageRootPath = URL(fileURLWithPath: webVC.imageRootPath ?? "").absoluteString//主要是为了转码路径的中文
        }
        
//        let fileURL = URL.init(fileURLWithPath: <#T##String#>)
        self.navigationController?.pushViewController(webVC, animated: true)
        
    }
    @objc func shareTextAction(sender:UIButton?)  {
        let fileURL = URL(fileURLWithPath: PPDiskCache.shared.path + self.filePathStr)
        let shareSheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        present(shareSheet, animated: true)
    }
    @objc func saveTextAction(sender:UIButton?)  {
        let stringToUpload = self.textView.text ?? ""
        if stringToUpload.length < 1 {
            PPHUD.showHUDFromTop("不支持保存空文件")
            return
        }
        debugPrint("保存的是===\(stringToUpload)")
        //MARK:保存
        self.textView.resignFirstResponder()
        PPFileManager.shared.createFile(path: self.filePathStr, contents: stringToUpload.data(using: .utf8), completionHandler: { (error) in
            if error != nil {
                PPHUD.showHUDFromTop("保存失败", isError: true)
                return
            }
            PPHUD.showHUDFromTop("保存成功")
            self.textChanged = false
            if (self.closeAfterSave) {
                self.navigationController?.popViewController(animated: true)
            }
        })

        

    }
    @objc func moreAction(sender:UIButton?)  {
        let menuTitile = ["分享文本","左右分栏模式","上下分栏模式","关闭分栏"]
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: menuTitile) { (index) in
            debugPrint(index)
            if index == 1 {
                self.shareTextAction(sender: nil)
            }
            else if index == 2 {
                self.switchSplitMode(.leftAndRight)
            }
            else if index == 3 {
                self.switchSplitMode(.upAndDown)
            }
            else if index == 4 {
                self.switchSplitMode(.none)
            }
            
        }
    }
    //初始化样式
    func initStyle() {
        if let theme = PPUserInfo.shared.pp_Setting["pp_markdownEditorStyle"] as? String {
            if theme == "锤子便签" {
                useTheme("chuizi.json")
            }
            if theme == "Vue" {
                useTheme("vue.json")
            }
            else {
                useTheme("default.json")
            }
        }
        else {
            useTheme("default.json")
        }
    }
    //选择主题样式
    func useTheme(_ configJSONFile:String) {
        guard let themeConfig = Bundle.main.url(forResource: configJSONFile, withExtension: nil) else { return }
        guard let data = try? Data(contentsOf: themeConfig) else { return }
        guard let themeObj = data.pp_JSONObject() else { return }
        guard let theme = PPThemeModel(JSON: themeObj) else { return }
        self.theme = theme
        if let data = try? Data(contentsOf: URL(fileURLWithPath: PPUserInfo.shared.pp_mainDirectory+"/"+theme.backgroundImageName)) {
            backgroundImage.image = UIImage(data: data)
            textView.backgroundColor = .clear
        }
        else {
            textView.backgroundColor = theme.backgroundColor.pp_HEXColor()
        }
        textView.textColor = theme.baseTextColor.pp_HEXColor()
        
        
    }
    lazy var button0 : UIButton = {
        let button0 = UIButton.init(type: UIButton.ButtonType.custom)
        button0.frame = CGRect.init(x: 0, y: 0, width: 40, height: 40)
        button0.setImage(UIImage.init(named: "preview"), for: UIControl.State.normal)
        button0.addTarget(self, action: #selector(previewAction(sender:)), for: UIControl.Event.touchUpInside)
        return button0
    }()
    
    lazy var button1 : UIButton = {
        let button1 = UIButton(type: .custom)
        button1.frame = CGRect(x: 40, y: 0, width: 40, height: 40)
        button1.setImage(UIImage(named: "done"), for: .normal)
        button1.addTarget(self, action: #selector(saveTextAction(sender:)), for: .touchUpInside)
        return button1
    }()
    lazy var button2 : UIButton = {
        let button2 = UIButton(type: .custom)
        button2.frame = CGRect(x: 80, y: 0, width: 40, height: 40)
        button2.setImage(UIImage(named: "toolbar_more"), for: .normal)
        button2.addTarget(self, action: #selector(moreAction(sender:)), for: .touchUpInside)
        return button2
    }()
    // MARK: PPEditorToolBarDelegate
    func didClickEditorToolBar(sender: UIButton, index: Int,totalCount: Int) {
        debugPrint("didClickEditorToolBar:\(index)")
        if index == 0 {
            self.showImagePicker { selectedAssets in
                PPFileManager.shared.uploadPhotos(selectedAssets, completion: { photoAssets in
                    debugPrint(photoAssets)
                    for asset in photoAssets {
                        PPFileManager.shared.getImageDataFromAsset(asset: asset, completion: { (imageData,urlString,imageInfo) in
                            let uploadName = PPFileManager.imageVideoName(urlString: urlString, imageInfo: imageInfo)
                            debugPrint("uploadName:",uploadName)
                            self.textView.insertText("![ ](./\(uploadName))\n")
                        })
                    }
                })
            }
        }
        if totalCount - 1 == index {
            self.textView.resignFirstResponder()
        }
    }
    
}
