//
//  PPWebViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/4/4.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  bug:https://stackoverflow.com/a/28676439/4493393

import UIKit
import WebKit.WKWebView

class PPWebViewController: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler {
    
    
    var wkWebView: WKWebView!
    var fileURLStr: String?
    var urlString: String?
    var fileName: String?
    var xd_titleStr: String?
    var markdownStr: String?
    ///预加载的Bundle里的自定义js
    var jsNameInBundle: String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        if let xd_titleStr = self.xd_titleStr {
            self.title = xd_titleStr
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "pppanda")
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
    

    //MARK: Delegate
    //WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //    decisionHandler(WKNavigationActionPolicyAllow);
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

    //MARK:Private
    func shouldStartLoad(with request: URLRequest?) -> Bool {
        //获取当前调转页面的URL
//        let requestUrl = request?.url?.absoluteString
        guard let requestUrl = request?.url?.absoluteString else { return false }
        //    NSLog(@"requestUrl==%@",requestUrl);
        //    NSString *actionName = [requestUrl lastPathComponent];
        //    actionName = [actionName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if request?.url?.scheme?.caseInsensitiveCompare("pppanda") == .orderedSame {
            wkWebView.evaluateJavaScript("jsReceiveData('loginSucceed', 'success')", completionHandler: { response, error in
                
            })
            return false
        }
        else if let _ = self.markdownStr, !requestUrl.hasPrefix("file://") {
            let vc = PPWebViewController()
            vc.urlString = requestUrl
            navigationController?.pushViewController(vc, animated: true)
            return false
        }
        return true
    }
}
