//
//  PPWebViewController.swift
//  PandaNote
//
//  Created by Panway on 2020/4/4.
//  Copyright © 2020 Panway. All rights reserved.
//  bug:https://stackoverflow.com/a/28676439/4493393
//  WKWebView时序图  https://www.jianshu.com/p/55f5ac1ab817

import UIKit
import WebKit.WKWebView
import PDFKit

class PPWebViewController: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler, UIScrollViewDelegate {
    
    let Show_BottomToolbar = true
    
    var wkWebView: WKWebView!
    var fileURLStr: String?
    var urlString: String?
    var fileName: String?
    var titleStr: String?
    var markdownStr: String?
    var imageRootPath: String? //markdown 图片资源绝对路径 file:///path/to/image
    var markdownName: String?
    ///Main Bundle里预加载的js
    var preloadJSNameInBundle: String?
    /// 是否注册scheme来拦截http资源
    var registerHTTPSchemeForCustomProtocol = false
    var shouldGetAssets = false /// 获取网页静态资源
    var lastOffsetY : CGFloat = 0.0
    var bottomView : PPWebViewBottomToolbar!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        if let titleStr = self.titleStr {
            self.title = titleStr
        }
        if registerHTTPSchemeForCustomProtocol {
            PPWebViewController.registerHTTPScheme()
        }
        else {
            PPWebViewController.unregisterHTTPScheme()
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "pppanda")
        //不允许任何web资源写入文件系统
//        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        if let preloadJSNameInBundle = self.preloadJSNameInBundle {
            let path = Bundle.main.path(forResource: preloadJSNameInBundle, ofType: nil, inDirectory: "web")
            var consolejs: String? = nil
            do {
                consolejs = try String(contentsOfFile: path ?? "", encoding: .utf8)
            } catch {
            }
            
            let usrScript = WKUserScript(source: consolejs ?? "", injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(usrScript)
        }
        wkWebView = WKWebView(frame: view.bounds, configuration: config)
        view.addSubview(wkWebView)
        wkWebView.frame = view.bounds
        self.pp_viewEdgeEqualToSafeArea(wkWebView)
        if #available(macCatalyst 16.4, iOS 16.4, *) {
            wkWebView.isInspectable = true
        }
        
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        //    self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.wkWebView];
        //    [self.bridge setWebViewDelegate:self];
        
        bottomView = PPWebViewBottomToolbar()
//        bottomView.backgroundColor = UIColor.green
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.pp_safeLayoutGuideBottom())
            make.height.equalTo(44)
        }
        bottomView.isHidden = true
        bottomView.backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        bottomView.forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        
        self.wkWebView.scrollView.delegate = self
        self.wkWebView.scrollView.addRefreshHeader {
            self.loadURL()
        }
        loadURL()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更多", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let _ = self.markdownStr {
            self.loadURL()
        }
    }
    //MARK: Public 公开方法
    func loadURL() {
        if let urlString = self.urlString {
            if let url = URL(string: urlString) {
                wkWebView.load(URLRequest(url: url))
            }
        }
        else if let fileURLStr = self.fileURLStr {
            let fileURL = URL(fileURLWithPath: fileURLStr)
            wkWebView.load(URLRequest(url: fileURL))
//            wkWebView.loadFileURL(<#T##URL: URL##URL#>, allowingReadAccessTo: <#T##URL#>)
        }
        else if let fileName = self.fileName {
            let fileUrl = Bundle.main.url(forResource: fileName, withExtension: nil)
            if let fileUrl = fileUrl {
                wkWebView.load(URLRequest(url: fileUrl))
            }
        }
        
        
    }
    ///滚动到总高度的某个比例
    func scrollToProportion(proportion:CGFloat) {
        let offsetY = wkWebView.scrollView.contentSize.height * proportion
        wkWebView.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
    }
    ///JS滚动到第一个搜索到的文本，返回0代表失败或没匹配到
    func scrollToText(_ text: String,completionHandler:((_ videoURL: Int) -> Void)? = nil) {
        let js = "scrollToText('\(text)');"
        wkWebView.evaluateJavaScript(js, completionHandler: { result, error in
            if let completionHandler = completionHandler {
                if let result_number = result as? Int {
                    completionHandler(result_number)
                }
            }
        })
    }
    ///用JS渲染Markdown文本
    func renderMardownWithJS(_ markdown:String) {
        let hash = self.markdownName?.hash ?? 0
        let markdown2JS = markdown.pp_replaceEscapeCharacter()
        let js = """
        document.getElementById('content').innerHTML = ppmarked('\(markdown2JS)');
        document.getElementById('ppTOCContent').innerHTML = ppGenerateTOC('\(markdown2JS)');
        setFileHash(\(hash));
        replaceImgPath('\(self.imageRootPath ?? "")')
        """
        wkWebView.evaluateJavaScript(js, completionHandler: { result, error in
            debugPrint(error)
        })
    }
    override func didReceiveMemoryWarning() {
        debugPrint("==内存警告！")
    }

    //MARK: WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //    decisionHandler(WKNavigationActionPolicyAllow);
        PPUserInfo.shared.pp_WebViewResource.removeAll()//资源提取
        let should = shouldStartLoad(with: navigationAction.request)
        if should {
            decisionHandler(WKNavigationActionPolicy.allow)
        } else {
            decisionHandler(WKNavigationActionPolicy.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.wkWebView.scrollView.endRefreshing()
        debugPrint(self.wkWebView.canGoBack)
        self.bottomView.backButton.isEnabled = self.wkWebView.canGoBack
        self.bottomView.forwardButton.isEnabled = self.wkWebView.canGoForward
        if self.bottomView.backButton.isEnabled || self.bottomView.forwardButton.isEnabled {
            self.bottomView.isHidden = false
        }
        webView.evaluateJavaScript("document.title") { (result:Any?, error) in
            self.navigationItem.title = result as? String
        }
        if let markdown = self.markdownStr {
            self.renderMardownWithJS(markdown)
        }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { action in
            completionHandler()
        }))
        present(alertController, animated: true) {
        }
    }
    ///接收的js发来的消息
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        debugPrint("didReceive JS message = \n \(message.name)\n \(message.body)")
    }
    //MARK:UIScrollViewDelegate
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        //    debugPrint("SSSSS\(offsetY)")
        lastOffsetY = offsetY
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let offsetY = scrollView.contentOffset.y
        if lastOffsetY < offsetY {
            self.bottomView.isHidden = true
        }
        else {
            self.bottomView.isHidden = false
        }
    }
    //MARK: - Public

    class func registerHTTPScheme() {
        for scheme in ["http", "https"] {
            URLProtocol.self.wk_registerScheme(scheme)
        }
    }
    class func unregisterHTTPScheme() {
        for scheme in ["http", "https"] {
            URLProtocol.self.wk_unregisterScheme(scheme)
        }
    }
    //MARK: Private
    //MARK: 是否可以跳转 PPNavigationActionPolicy
    func shouldStartLoad(with request: URLRequest) -> Bool {
        //获取当前调转页面的URL
//        let requestUrl = request?.url?.absoluteString
        guard let urlString = request.url?.absoluteString else { return false }
        debugPrint("shouldStartLoad==\(urlString)")
        //    NSLog(@"requestUrl==%@",requestUrl);
        //    NSString *actionName = [requestUrl lastPathComponent];
        //    actionName = [actionName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if request.url?.scheme?.caseInsensitiveCompare("pppanda") == .orderedSame {
            wkWebView.evaluateJavaScript("jsReceiveData('loginSucceed', 'success')", completionHandler: { response, error in
                
            })
            return false
        }
//        else if let markdown = self.markdownStr {
//            if markdown.length>1 && !urlString.hasPrefix("file://") {
//                let vc = PPWebViewController()
//                vc.urlString = urlString
//                navigationController?.pushViewController(vc, animated: true)
//                return false
//            }
//        }
        else if urlString.contains("www.zhihu.com") {
            let path = Bundle.main.path(forResource: "zhihu_unfold", ofType:"js")
            var consolejs: String? = ""
            do {
                consolejs = try String(contentsOfFile: path ?? "", encoding: .utf8)
            } catch {
            }
            wkWebView.evaluateJavaScript(consolejs ?? "", completionHandler: { response, error in
                
            })
        }
        else if urlString.contains("m.weibo.cn") && !self.urlString!.contains("m.weibo.cn") {
            let vc = PPWebViewController()
            vc.urlString = urlString
            navigationController?.pushViewController(vc, animated: true)
            return false
        }
        else if urlString.contains("markdown.html#") {
            //跳转到目录的某个位置后隐藏
            wkWebView.evaluateJavaScript("displayTOC()", completionHandler: nil)
        }
        else {
            return handleMyStartLoad(urlString)
        }
        return true
    }
    @objc func goBack() {
        if self.wkWebView.canGoBack {
            self.wkWebView.goBack()
        }
    }
    @objc func goForward() {
        if self.wkWebView.canGoForward {
            self.wkWebView.goForward()
        }
    }
    @objc func moreAction()  {
        let items = ["提取本页面资源","刷新","复制当前网址URL","导出为PDF"]
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: items) { (index) in
            debugPrint(index)
            if index == 1 {
                if (!self.registerHTTPSchemeForCustomProtocol || PPUserInfo.shared.pp_WebViewResource.count < 1) {
                    self.getWebAssets()
                    return
                }
                let vc = PPWebFileViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }
            else if index == 2 {
                self.wkWebView.reload()
            }
            else if index == 3 {
                UIPasteboard.general.string = self.wkWebView.url?.absoluteString
            }
            else if index == 4 {
                self.wkWebView.exportToPdf { data in
                    let shareSheet = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                    if let ppc = shareSheet.popoverPresentationController {
                        ppc.sourceView = self.view;
                    }
                    self.present(shareSheet, animated: true)
                }
            }
        }
    }
    
    func getWebAssets() {
        PPAlertAction.showAlert(withTitle: "当前页面需要重新加载才能提取资源", msg: "是否继续", buttonsStatement: ["确定","取消"]) { index in
            if index == 0 {
                self.shouldGetAssets = true
                PPWebViewController.registerHTTPScheme()
                WKWebViewTool.pp_clearWebViewCache()
                self.wkWebView.reload()
            }
        }
    }

}



//MARK: - Private 自己的业务逻辑
extension PPWebViewController {
    func handleMyStartLoad(_ urlString:String) -> Bool {
        debugPrint("handleMyStartLoad",urlString)
        //获取Dropbox的access_token
        if urlString.hasPrefix("filemgr://oauth-callback") {
            let urlWithToken = urlString.removingPercentEncoding?.replacingOccurrences(of: "#access_token", with: "?access_token")
            let access_token = urlWithToken?.pp_valueOf("access_token")
//            let account_id = urlWithToken?.pp_valueOf("account_id")
            debugPrint(access_token)
            
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = "Dropbox"
            vc.serverURL = ""
            vc.remark = "Dropbox"
            vc.password = access_token ?? ""
            self.navigationController?.pushViewController(vc, animated: true)
        }
        //获取百度网盘的access_token
        else if urlString.hasPrefix("http://www.estrongs.com") || urlString.hasPrefix("pandanote://baiduwangpan"){
            var urlWithToken = urlString.removingPercentEncoding?.replacingOccurrences(of: "www.estrongs.com/#", with: "www.estrongs.com?")//早期用ES的配置，现在实际上没用了
            urlWithToken = urlString.removingPercentEncoding?.replacingOccurrences(of: "pandanote://baiduwangpan#", with: "pandanote://baiduwangpan?")
            let access_token = urlWithToken?.pp_valueOf("access_token")
            debugPrint(access_token)
            
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = PPCloudServiceType.baiduyun.rawValue
            vc.showServerURL = false
            vc.showUserName = false
            vc.remark = "百度网盘"
            vc.password = access_token ?? ""
            self.navigationController?.pushViewController(vc, animated: true)
        }
        //获取了OneDrive的带code的回调URL
        else if urlString.hasPrefix("https://login.microsoftonline.com/common/oauth2/nativeclient?code=") {
//            var code = urlString.pp_valueOf("code")
            PPAddCloudServiceViewController.handleCloudServiceRedirect(URL(string: urlString)!)
        }
        else if urlString.hasPrefix("https://" + aliyundrive_callback_domain) {
            PPAddCloudServiceViewController.handleCloudServiceRedirect(URL(string: urlString)!)
        }
        
        #if DEBUG
//        fakeData(urlString)
        #endif
        return true
    }
    func fakeData(_ urlString:String) {
        //测试代码！！！
        if urlString.contains("www.dropbox.com/oauth2/authorize") {
//            self.urlString = "filemgr://oauth-callback/dropbox#access_token=AAAAAA&token_type=bearer&state=DROPBOX&uid=666666&account_id=dbid%XXXXXX"
//            DispatchQueue.main.asyncAfter(deadline: .now()+5) {
//                self.loadURL()
//            }
        }
        if urlString.contains("openapi.baidu.com/oauth/2.0/authorize") {
            self.urlString = "http://www.estrongs.com/#expires_in=2592000&access_token=AAAAAA&session_secret=&session_key=&scope=basic+netdisk&state=STATE"
            DispatchQueue.main.asyncAfter(deadline: .now()+5) {
                self.loadURL()
            }
        }
    }
}
