
//
//  XDWebViewController.m
//  YiJian
//
//  Created by liyang on 2018/12/13.
//  Copyright © 2018 xiudian. All rights reserved.
//

#import "XDWebViewController.h"
@interface XDWebViewController ()<WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler>

@end

@implementation XDWebViewController
#pragma mark - LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.xd_titleStr) {
        self.title = self.xd_titleStr;
    }
    
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"yijianapp"];
    //预加载的Bundle里的自定义js
    if (self.jsNameInBundle.length >0) {
        NSString *path = [[NSBundle mainBundle] pathForResource:self.jsNameInBundle ofType:nil inDirectory:@"web"];
        NSString *consolejs = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];

        WKUserScript *usrScript = [[WKUserScript alloc] initWithSource:consolejs injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [config.userContentController addUserScript:usrScript];
    }
    self.wkWebView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:self.wkWebView];
    self.wkWebView.frame = self.view.bounds;
//    [self.wkWebView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(self.view);
//    }];
    self.wkWebView.navigationDelegate = self;
    self.wkWebView.UIDelegate = self;
//    self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.wkWebView];
//    [self.bridge setWebViewDelegate:self];
    
    if (self.urlString && self.urlString.length > 0) {
        [self.wkWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.urlString]]];
    }
    else if (self.fileName.length > 0) {
        NSURL *fileUrl = [[NSBundle mainBundle] URLForResource:self.fileName withExtension:nil];
        [self.wkWebView loadRequest:[NSURLRequest requestWithURL:fileUrl]];
    }
    
    

}




#pragma mark - Public

#pragma mark - Private
/// MARK: Delegate
#pragma mark - WKNavigationDelegate
//WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
//    XDLog(@"==%@",navigation);
    [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
//        XDLog(@"==%@",result);
        self.title = result;
    }];
    
    if (self.markdownStr.length > 0) {
        self.markdownStr = [self.markdownStr stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        self.markdownStr = [self.markdownStr stringByReplacingOccurrencesOfString:@"`" withString:@"\\`"];
        NSString *js = [NSString stringWithFormat:@"document.getElementById('content').innerHTML = marked(`%@`);",self.markdownStr];
        [webView evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            //        XDLog(@"==%@",result);
//            self.title = result;
        }];
    }
}
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler();
                                                      }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
}
/// MARK: Action
#pragma mark - Getter

#pragma mark - Setter
@end
