//
//  PPMarkdownViewController.swift
//
//
//  Created by Panway on 2019/6/8.
//  Copyright © 2019 Panway. All rights reserved.
//
import UIKit
import Foundation
import FilesProvider
import Down
import Highlightr


//typealias PPPTextView = PPPPTextView

fileprivate let TopToolBarTag = 1
fileprivate let BottomToolBarTag = 2
fileprivate let tocTag = 3

@objc enum PPSplitMode : UInt8 {
    case none
    case leftAndRight
    case upAndDown
}

//UITextViewDelegate
final class PPMarkdownViewController: PPBaseViewController,
                                PPEditorToolBarDelegate,
                                PPFindReplaceDelegate,
                                PPMDTextViewDelegate,
                                UISearchBarDelegate,
                                UITextViewDelegate
{
//    let markdownParser = MarkdownParser()
    var markdownStr = "I support a *lot* of custom Markdown **Elements**, even `code`!"
//    var historyList = [String]()
    var textView : PPMDTextView!
    let backgroundImage  = UIImageView()
    ///文件相对路径
    var filePathStr: String = ""
    ///文件ID（仅百度网盘）
    var fileID = ""
    var fileExtension = ""
    var downloadURL = ""
    var cacheDir = ""
//    var webdav: WebDAVFileProvider?
    var closeAfterSave : Bool = false
    var textChanged : Bool = false//文本改变的话就不需要再比较字符串了
    var splitMode = PPSplitMode.none //上次的分栏模式 last mode
    var theme : PPThemeModel!
    var highlightrThemes = [String]()
    var highlightr: Highlightr? = nil
    let tocTable = XDFastTableView()
    var showTOC = false
    let imagePreviewer = PPImagePreviewer()
    lazy var dropdown : PPDropDown = {
        let drop = PPDropDown()
        return drop
    }()
    let topToolView = PPMarkdownEditorToolBar(frame: CGRect(x: 0,y: 0,width: 40*3,height: 40), images: ["preview","done", "toolbar_more"])
    let menuBtn = PPMarkdownEditorToolBar(frame: CGRect(x: 0,y: 0,width: 40*3,height: 40), images: ["menu"])

    var findReplaceView: PPFindReplaceView!

    
    //MARK: - Life Cycle
    override func viewDidLoad() {
        PPAppConfig.shared.downColor = PPDownColorCollection()
        PPAppConfig.shared.downColor.codeBlockBackground = "#dddddd".pp_HEXColor().withAlphaComponent(0.3)
        navigationController?.view.backgroundColor = .white
        if self.filePathStr.length < 1 {
            return //使用UISplitViewController的时候，没路径显示空白
        }
        
        cacheDir = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)\(filePathStr.replacingOccurrences(of: filePathStr.pp_split("/").last ?? "", with: ""))"
            .replacingOccurrences(of: "//", with: "/")
        textView = PPMDTextView(frame: self.view.bounds)
        textView.cacheDir = cacheDir
        initStyle()
        pp_initView()
        if filePathStr.isMarkdownFile() {
            initTOC()
            textView.markdownDelegate = self
        }
        self.title = self.filePathStr.split(string: "/").last
        PPFileManager.shared.getFileData(path: filePathStr,
                                         fileID: fileID,
                                         downloadURL:downloadURL,
                                         alwaysDownload:true) { (contents: Data?,isFromCache, error) in
            guard let contents = contents else {
                PPHUD.showHUDFromTop("获取内容失败，请进入文件夹刷新",isError: true)
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "已加载缓存内容":"已加载最新")
//            debugPrint(String(data: contents, encoding: .utf8)!) // "hello world!"
            guard let text_encoded = String(textData: contents) else {
                PPHUD.showHUDFromTop("此文本无法用 UTF8 编码", isError:true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.navigationController?.popViewController(animated: true)
                }
                return
            }
            self.markdownStr = text_encoded
            
            if isFromCache {
                self.textView.text = text_encoded
                return
            }
            //如果是代码文件
            if let suffix = self.filePathStr.pp_split(".").last,
               suffix.isTextFile() == true {
                self.fileExtension = suffix
                //目前不支持txt
                self.fileExtension = suffix == "txt" ? "md" : suffix
            }
            //markdown解析的方式
            let method = PPAppConfig.shared.getItem("pp_markdownParseMethod")
            self.textView.renderMethod = method
            if method != "" {
                if method == "NSAttributedString+Markdown" && self.filePathStr.isMarkdownFile() {
                    //NSAttributedString+Markdown 解析
                    self.textView.attributedText = NSAttributedString(markdownRepresentation: self.markdownStr, attributes: [.font : UIFont.systemFont(ofSize: 17.0), .foregroundColor: self.theme.baseTextColor.pp_HEXColor()])
                    self.textView.linkTextAttributes = [.foregroundColor:self.theme.linkTextColor.pp_HEXColor()]

                }
                else if method == "Down" && self.filePathStr.isMarkdownFile(){
                    //MARK: Down渲染
                    self.textView.text = self.markdownStr
                    if(!self.textView.didRender) {
                        self.textView.render()
                    }
                    self.textView.backgroundColor = .clear
//                    let down = Down(markdownString: self.markdownStr)
                    //DownAttributedStringRenderable 31行
//                    let attributedString = try? down.toAttributedString(DownOptions.default, stylesheet: "* {font-family: Helvetica } code, pre { font-family: Menlo } code {position: relative;background-color: #f6f8fa;border-radius: 6px;} img {max-width: 100%;display: block;margin-left: auto;margin-right: auto;}")
//                    self.textView.attributedText = attributedString
                    
                }
                else if method == "Highlightr" || !self.filePathStr.isMarkdownFile() {
                    // 获取bundle中所有以min.css结尾的文件路径
                    self.highlightr = Highlightr()
                    let bundle = Bundle(for: Highlightr.self)
                    let cssURLs = bundle.urls(forResourcesWithExtension: "min.css", subdirectory: nil) ?? []
                    self.highlightrThemes.removeAll()
                    // 将URL转化为文件路径，并添加到数组中
                    for url in cssURLs {
                        self.highlightrThemes.append(url.lastPathComponent.pp_split(".").first ?? "")
                    }
                    self.highlightrThemes.sort()

                    let userTheme = PPAppConfig.shared.getItem("PPHighlightTheme")
                    self.highlightr?.setTheme(to: userTheme.length > 0 ? userTheme : "atom-one-light")
                    self.highlightr?.theme.setCodeFont(RPFont(name: "Courier", size: 18)!)
                    let textStorage = CodeAttributedString(highlightr: self.highlightr!)
                    textStorage.language = self.fileExtension
                    let layoutManager = NSLayoutManager()
                    textStorage.addLayoutManager(layoutManager)
                    // 高度为.greatestFiniteMagnitude才可滑动 enable scroll
                    let textContainer = NSTextContainer(size: CGSize(width: self.view.bounds.width, height: .greatestFiniteMagnitude))
                    layoutManager.addTextContainer(textContainer)

                    self.textView = PPMDTextView(frame: self.view.bounds)//, textContainer: textContainer)
                    self.view.addSubview(self.textView)
                    self.pp_viewEdgeEqualToSafeArea(self.textView)
                    
                    let highlightedCode = self.highlightr?.highlight(self.markdownStr, as: self.fileExtension)
                    self.textView.attributedText = highlightedCode
                    self.textView.backgroundColor = self.highlightr?.theme.themeBackgroundColor
                }
                else {
                    self.textView.text = self.markdownStr
                }
            }
            else {//没设置
                self.textView.text = self.markdownStr
            }
            
            //定位到上次滚动的位置
            let offsetKey = "\(PPFileManager.shared.currentServerUniqueID())\(self.filePathStr)".pp_md5
            let offsetY = PPCacheManeger.shared.get(offsetKey).toCGFloat()
            if offsetY > 0 {
                //为0的时候设置好像有时候文字不显示？？？
                self.textView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            }
            
            self.findReplaceView = PPFindReplaceView(frame: CGRect(x: 0, y: 0, width: 320, height: 30))
            self.view.addSubview(self.findReplaceView)
            self.findReplaceView.snp.makeConstraints { make in
                make.top.left.right.equalToSuperview()
                make.height.equalTo(30)
            }
            self.findReplaceView.initSearchText(self.textView.text)
            self.findReplaceView.delegate = self
            self.findReplaceView.isHidden = true
            
        }

        
        
        self.view.backgroundColor = .white

    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !changed() {
            debugPrint("文本未修改",self.filePathStr)
            return
        }
        if (UIDevice.current.userInterfaceIdiom != .phone) {
            self.closeAfterSave = false
            self.saveTextAction()
        }
    }
    deinit {
//        self.switchSplitMode(.none)//好像不加也行
    }
    func pp_initView() {
        self.edgesForExtendedLayout = []
        self.view.addSubview(backgroundImage)
        self.pp_viewEdgeEqualToSafeArea(backgroundImage)

        self.view.addSubview(textView)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)//Padding,内边距
        self.pp_viewEdgeEqualToSafeArea(textView)
        textView.font = UIFont.systemFont(ofSize: 16.0)
        
        textView.delegate = self
        
        
        
        let editorToolBar = PPMarkdownEditorToolBar(frame: CGRect(x: 0,y: 0,width: 40*2,height: 40), images: ["editor_image", "btn_down"])
        editorToolBar.delegate = self
        textView.inputAccessoryView = editorToolBar
        
        topToolView.delegate = self
        topToolView.tag = TopToolBarTag

        
        
        let rightBarItem = UIBarButtonItem(customView: topToolView)
        
        self.navigationItem.rightBarButtonItem = rightBarItem
        
        self.setLeftBarButton()
    }
    func changed() -> Bool {
        let textWithoutReplacementCharacter = self.textView.text.replacingOccurrences(of: "￼", with: "")
        let textDidChanged = textWithoutReplacementCharacter != self.markdownStr
        debugPrint("文本改变:",textDidChanged)
        return textDidChanged
    }
    override func pp_backAction() {
        self.textView.resignFirstResponder()
        //心疼CPU，文本有修改的话就不全部比较了>_<
        if changed() == false {
            debugPrint("未修改,直接退出")
            self.navigationController?.popViewController(animated: true)
            return
        }
        let isMaciPad = UIDevice.current.userInterfaceIdiom != .phone
        if (isMaciPad || PPUserInfo.pp_valueForSettingDict(key: "saveMarkdownWhenClose")) {
            self.closeAfterSave = true
            self.saveTextAction()
        } else {
            self.dropdown.dataSource = ["是否保存已修改的文字？","不保存","要保存"]
            self.dropdown.selectionAction = { (index: Int, item: String) in
                debugPrint("\(index)")
                if (index == 1) {
                    self.navigationController?.popViewController(animated: true)
                }
                else if (index == 2) {
                    self.closeAfterSave = true
                    self.saveTextAction()
                }
            }
            // self.dropdown.anchorView = sender
            self.dropdown.show()
            
        }
    }

    // MARK: - UITextViewDelegate 文本框代理
    func textViewDidChange(_ textView: UITextView) {
//        debugPrint(textView.text)
        if splitMode != .none {
            PPUserInfo.shared.webViewController.renderMardownWithJS(self.textView.text)
        }
    }
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        debugPrint("====Start")
        return true
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textChanged = true
        guard let newRange = Range(range, in: textView.text) else { return true }
        let mySubstring = textView.text![newRange]
        let myString = String(mySubstring)
        debugPrint("===shouldChangeTextIn \(myString)")
        return true
    }
    func textViewDidEndEditing(_ textView: UITextView) {
//        debugPrint("===textViewDidEndEditing \(textView.attributedText.markdownRepresentation)")
    }
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        debugPrint("\(URL)")
        // 处理链接点击事件
        if URL.scheme == "pandanote" && URL.host == "openimage" {
            // 预览图片
            imagePreviewer.showImage(fromView: nil, imageName: "name", localPath: URL.absoluteString.pp_split("openimage?path=").last ?? "")
            return false
        }
        return true
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let offsetKey = "\(PPFileManager.shared.currentServerUniqueID())\(self.filePathStr)".pp_md5
        debugPrint("滚动偏移量:\(scrollView.contentOffset.y)")
        PPCacheManeger.shared.set("\(scrollView.contentOffset.y)", key: offsetKey)
        if splitMode != .none {
            self.scrollToSameTextAsTextView()
        }
    }
    ///结束拖动更新y偏移量
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//        debugPrint("scrollViewDidEndDragging")
        if splitMode != .none {
            self.scrollToSameTextAsTextView()
        }
    }
    func didUpdateHeading(_ headings: [NSMutableAttributedString]) {
        tocTable.dataSource = headings
        tocTable.tableView.reloadData()
    }
    //MARK: - Private 私有方法
    func initTOC() {
        menuBtn.delegate = self
        menuBtn.tag = tocTag
        self.view.addSubview(menuBtn)
        menuBtn.snp.makeConstraints { make in
            make.right.top.equalTo(self.view)
            make.size.equalTo(CGSize(width: 40.0, height: 40.0))
        }

        self.view.addSubview(tocTable)
        // 限制 tocTable 的宽度不大于 400，同时仍然保持其宽度为父视图宽度的一半
        tocTable.snp.makeConstraints { (make) in
            make.top.equalTo(self.view).offset(40)
            make.right.equalTo(self.view)
            make.width.height.equalTo(self.view).multipliedBy(0.5).priority(.high)
            make.width.lessThanOrEqualTo(400) // 添加这行限制宽度不大于 400
        }
        tocTable.isHidden = true
        tocTable.registerCellClass(PPMarkdownMiniMapCell.self)
        tocTable.dataSource = []
        tocTable.backgroundColor = UIColor(white: 1.0, alpha: 0.6)
        tocTable.tableView.backgroundColor = .clear
        tocTable.didSelectRowAtIndexHandler = {(index: Int) ->Void in
            if let obj = self.tocTable.dataSource[index] as? NSMutableAttributedString {
                self.textView.pp_scrollSubstringToTop(obj.string, animated: true)
            }
        }
        tocTable.layer.cornerRadius = 10.0
        tocTable.layer.shadowOpacity = 0.5
        tocTable.layer.shadowOffset = CGSize(width: 0, height: 2)
        tocTable.layer.shadowRadius = 4
    }

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
            webVC.fileURLStr = self.filePathStr.pp_fileCachePath()
        }
        else {
            path = Bundle.main.url(forResource: "markdown", withExtension:"html")?.absoluteString ?? ""
            webVC.markdownStr = textWithoutUselessChar()
            webVC.urlString = path // file:///....
//            webVC.urlString = "http://192.168.123.162:8081/markdown.html"
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
        
        PPUserInfo.shared.webViewController.markdownStr = textWithoutUselessChar()
        PPUserInfo.shared.webViewController.loadURL()
        
    }

    /// 预览markdown
    @objc func previewAction()  {
//        self.splitMode = .none
        self.switchSplitMode(.none)
        self.textView.resignFirstResponder()
        let webVC = PPUserInfo.shared.webViewController//PPWebViewController()
        var path = ""
        if self.filePathStr.hasSuffix("html") {//HTML文件直接显示
            let urlStr = self.filePathStr.pp_fileCachePath()
            webVC.fileURLStr = urlStr
        }
        else {
            path = Bundle.main.url(forResource: "markdown", withExtension:"html")?.absoluteString ?? ""
            webVC.markdownStr = textWithoutUselessChar()
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
        if let ppc = shareSheet.popoverPresentationController {
            ppc.sourceView = self.view;
        }
        present(shareSheet, animated: true)
    }
    func textWithoutUselessChar() -> String {
        // 去除16进制为`EFBFBC`的REPLACEMENT CHARACTER（替代字符）
        let textWithoutReplacementCharacter = self.textView.text.replacingOccurrences(of: "￼", with: "")
        //            .replacingOccurrences(of: "\u{FFFD}", with: "")//, options: NSString.CompareOptions.literal, range: nil)
        return textWithoutReplacementCharacter
    }
    
    @objc func saveTextAction()  {
        textView.render()
        let stringToUpload = textWithoutUselessChar()
        if stringToUpload.length < 1 {
            PPHUD.showHUDFromTop("不支持保存空文件")
            return
        }
//        print("保存的是==========\n\(stringToUpload)\n=========="  )
        //MARK: 保存
//        self.textView.resignFirstResponder()
        PPFileManager.shared.createFile(path: self.filePathStr, contents: stringToUpload.data(using: .utf8), completionHandler: { (result, error) in
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
    @objc func moreAction()  {
        var menuTitile = ["分享文本","搜索","左右分栏模式","上下分栏模式","关闭分栏","保存链接为Markdown"]
        let method = PPAppConfig.shared.getItem("pp_markdownParseMethod")

        if method == "Highlightr" {
            menuTitile.append("更换主题")            
        }
        menuTitile.append("去掉换行符")
        self.dropdown.dataSource = menuTitile
        self.dropdown.width = "左右分栏模式".pp_calcTextWidth() + 30
        self.dropdown.selectionAction = { (index: Int, item: String) in
             debugPrint(index, item)
            if item == "分享文本" {
                self.shareTextAction(sender: nil)
            }
            else if item == "搜索" {
                self.findReplaceView.isHidden = false
                self.findReplaceView.searchField.becomeFirstResponder()
            }
            else if item == "左右分栏模式" {
                self.switchSplitMode(.leftAndRight)
            }
            else if item == "上下分栏模式" {
                self.switchSplitMode(.upAndDown)
            }
            else if item == "关闭分栏" {
                self.switchSplitMode(.none)
            }
            else if item == "保存链接为Markdown" {
                PPAlertTool.presentInputAlert(inViewController: self, title: "输入文章链接", placeholder: "公众号或博客文章") { res in
                    if let urlStr = res {
                        PPPasteboardTool.parseArticleContent(url: urlStr) { attributedString in
                            self.textView.insertAttributedString(attributedString)
                            self.textView.render()
                        }
                    }
                }
            }
            else if item == "更换主题" {
                PPAppConfig.shared.popMenu.showWithCallback(sourceView:self.dropdown,
                                                            stringArray: self.highlightrThemes,
                                                            sourceVC: self) { index, string in
                    debugPrint(string)
                    self.highlightr?.setTheme(to: string)
                    let highlightedCode = self.highlightr?.highlight(self.markdownStr, as: self.fileExtension)
                    self.textView.attributedText = highlightedCode
                    self.textView.backgroundColor = self.highlightr?.theme.themeBackgroundColor
                    PPAppConfig.shared.setItem("PPHighlightTheme", string)
                }
                PPAppConfig.shared.popMenu.dismissOnSelection = false
            }
            else if item == "去掉换行符" {
                self.textView.text = self.textView.text.replacingOccurrences(of: "\n", with: "")
            }
        }
        self.dropdown.anchorView = topToolView
        self.dropdown.show()
    }
    //初始化样式
    func initStyle() {
        let theme = PPAppConfig.shared.getItem("pp_markdownEditorStyle")
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


    // MARK: PPEditorToolBarDelegate
    func didClickEditorToolBar(toolBar: PPMarkdownEditorToolBar, index: Int,totalCount: Int) {
        debugPrint("didClickEditorToolBar:\(index)")
        if toolBar.tag == TopToolBarTag {
            if index == 0 {
                previewAction()
            }
            else if index == 1 {
                saveTextAction()
            }
            else if index == 2 {
                moreAction()
            }
            return
        }
        else if toolBar.tag == tocTag {
            //是否显示目录
            showTOC = !showTOC
            tocTable.isHidden = !showTOC
            return
        }
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
    //MARK: 查找与替换
    func didFind(range: NSRange, msg: String) {
        textView.becomeFirstResponder()
        textView.selectedRange = range
        textView.scrollRangeToVisible(range)
    }
// https://developer.apple.com/documentation/uikit/mac_catalyst/handling_key_presses_made_on_a_physical_keyboard/
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        
        var didHandleEvent = false
        var pressCommandKey = false
        for press in presses {
            guard let key = press.key else { continue }
            let keyName = key.charactersIgnoringModifiers
            debugPrint("用户按下：\(keyName)")
            if key.modifierFlags.contains(.command) {
                pressCommandKey = true
                print("用户按下command")
                if let num = Int(keyName),
                   num > 0 && num < 6 {
                    self.textView.updateCurrentLineWithHeadingLevel(num)
                }
            }
            if pressCommandKey {
                if keyName == "s" {
                    saveTextAction() //保存
                }
                else if keyName == "f" {
                    self.findReplaceView.isHidden = false
                    self.findReplaceView.searchField.becomeFirstResponder()
                }
                
            }
        }
        
        if didHandleEvent == false {
            // Didn't handle this key press, so pass the event to the next responder.
            super.pressesBegan(presses, with: event)
        }
    }
}

