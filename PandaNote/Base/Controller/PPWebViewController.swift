//
//  PPWebViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/4/4.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  bug:https://stackoverflow.com/a/28676439/4493393
//  WKWebView时序图  https://www.jianshu.com/p/55f5ac1ab817

import UIKit
import WebKit.WKWebView

class PPWebViewController: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler, UIScrollViewDelegate {
    
    let Show_BottomToolbar = true
    
    var wkWebView: WKWebView!
    var fileURLStr: String?
    var urlString: String?
    var fileName: String?
    var titleStr: String?
    var markdownStr: String?
    var markdownName: String?
    ///Main Bundle里预加载的js
    var preloadJSNameInBundle: String?
    /// 是否注册scheme来拦截http资源
    var registerHTTPSchemeForCustomProtocol = false
    var lastOffsetY : CGFloat = 0.0
    var bottomView : PPWebViewBottomToolbar!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
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
            self.title = result as? String
        }
        if let markdown = self.markdownStr {
            let hash = self.markdownName?.hash ?? 0
            let js = "document.getElementById('content').innerHTML = ppmarked('\(markdown.pp_replaceEscapeCharacter())');setFileHash(\(hash));"
            webView.evaluateJavaScript(js, completionHandler: { result, error in
                debugPrint(error)
            })
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
    //MARK:Public
    //清除所有的WebView缓存数据 /Library/Webkit/com.xxx.xxx/WebsiteData 和/Library/Caches/com.xxx.xxx/Webkit
    //可以调用fetchDataRecordsOfTypes方法获取浏览记录,然后通过对域名的筛选决定如何删除缓存
    class func clearAllWebsiteData() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let sinceDate = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: sinceDate) {
            debugPrint("清除record完成")
        }
    }
    class func registerHTTPScheme() {
        for scheme in ["http", "https"] {
            URLProtocol.self.wk_registerScheme(scheme)
        }
    }
    class func unregisterHTTPScheme() {
        for scheme in ["http", "https"] {
            URLProtocol.self.wk_registerScheme(scheme)
        }
    }
    //MARK:Private
    //MARK: 是否可以跳转
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
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["提取本页面资源","刷新","复制当前网址URL"]) { (index) in
            debugPrint(index)
            if index == 1 {
                let vc = PPWebFileViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }
            else if index == 2 {
                self.wkWebView.reload()
            }
            else if index == 3 {
                UIPasteboard.general.string = self.wkWebView.url?.absoluteString
            }
        }
    }

}



//MARK: - User 自己的业务逻辑
extension PPWebViewController {
    func handleMyStartLoad(_ urlString:String) -> Bool {
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
        else if urlString.hasPrefix("http://www.estrongs.com") {
            let urlWithToken = urlString.removingPercentEncoding?.replacingOccurrences(of: "www.estrongs.com/#", with: "www.estrongs.com?")
            let access_token = urlWithToken?.pp_valueOf("access_token")
            debugPrint(access_token)
            
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = "baiduyun"
            vc.serverURL = "https://pan.baidu.com/rest/2.0/xpan/file"
            vc.remark = "百度云"
            vc.password = access_token ?? ""
            self.navigationController?.pushViewController(vc, animated: true)
        }
        return true
    }
}
