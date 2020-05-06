//
//  PPWebViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/4/4.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  bug:https://stackoverflow.com/a/28676439/4493393

import UIKit
import WebKit.WKWebView

class PPWebViewController: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler, UIScrollViewDelegate {
    
    
    var wkWebView: WKWebView!
    var fileURLStr: String?
    var urlString: String?
    var fileName: String?
    var xd_titleStr: String?
    var markdownStr: String?
    ///预加载的Bundle里的自定义js
    var jsNameInBundle: String?
    var lasOffsetY : CGFloat = 0.0
    var bottomView : PPWebViewBottomToolbar!
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now()+22) {
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            let sinceDate = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: sinceDate) {
                debugPrint("清除record完成")
            }
        }
        self.view.backgroundColor = UIColor.white
        if let xd_titleStr = self.xd_titleStr {
            self.title = xd_titleStr
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "pppanda")
        //不允许任何web资源写入文件系统
//        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        //预加载的Bundle里的自定义js
        if let jsNameInBundle = self.jsNameInBundle {
            let path = Bundle.main.path(forResource: jsNameInBundle, ofType: nil, inDirectory: "web")
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
        //    [self.wkWebView mas_makeConstraints:^(MASConstraintMaker *make) {
        //        make.edges.equalTo(self.view);
        //    }];
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
//        webView.evaluateJavaScript("document.title") { (result, error) in
//            self.title = result
//
//        }
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
            var markdownStr = markdown.replacingOccurrences(of: "\\", with: "\\\\")
            markdownStr = markdownStr.replacingOccurrences(of: "`", with: "\\`")
            let js = "document.getElementById('content').innerHTML = marked(`\(markdownStr)`);"
            webView.evaluateJavaScript(js, completionHandler: { result, error in
                debugPrint("\(String(describing: result))")
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
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
    }
    //MARK:UIScrollViewDelegate
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        //    debugPrint("SSSSS\(offsetY)")
        lasOffsetY = offsetY
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let offsetY = scrollView.contentOffset.y
        if lasOffsetY < offsetY {
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
    func shouldStartLoad(with request: URLRequest) -> Bool {
        //获取当前调转页面的URL
//        let requestUrl = request?.url?.absoluteString
        guard let urlString = request.url?.absoluteString else { return false }
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
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["提取本页面资源","2"]) { (index) in
            debugPrint(index)
            if index == 1 {
                let vc = PPWebFileViewController()
                self.navigationController?.pushViewController(vc, animated: true)
            }
            else if index == 2 {
                
            }
        }
    }

}



class PPWebViewBottomToolbar: UIView {
    var backButton : UIButton!
    var forwardButton : UIButton!
    override init(frame: CGRect) {
        super.init(frame: frame)
        pp_addSubviews()
    }
    func pp_addSubviews() {
        backButton = UIButton.init(type: UIButton.ButtonType.custom)
        self.addSubview(backButton)
        backButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        backButton.setTitle("⬅️", for: UIControl.State.normal)
        backButton.setTitle("", for: .disabled)
        backButton.snp.makeConstraints { (make) in
            make.top.equalTo(self)
            make.right.equalTo(self.snp.centerX).offset(-5)
            make.width.equalTo(44)
            make.height.equalTo(44)
        }
        
        forwardButton = UIButton.init(type: UIButton.ButtonType.custom)
        self.addSubview(forwardButton)
        forwardButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        forwardButton.setTitle("➡️", for: UIControl.State.normal)
        forwardButton.setTitle("", for: .disabled)
        forwardButton.snp.makeConstraints { (make) in
            make.top.equalTo(self)
            make.left.equalTo(self.snp.centerX).offset(5)
            make.size.equalTo(backButton)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
