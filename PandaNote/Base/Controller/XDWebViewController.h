//
//  XDWebViewController.h
//  YiJian
//
//  Created by liyang on 2018/12/13.
//  Copyright © 2018 xiudian. All rights reserved.
//

//#import "UIViewController.h"
@import WebKit;
@import UIKit;
NS_ASSUME_NONNULL_BEGIN

@interface XDWebViewController : UIViewController
@property (nonatomic, strong) WKWebView  *wkWebView;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *xd_titleStr;
@property (nonatomic, copy) NSString *markdownStr;

///预加载的Bundle里的自定义js
@property (nonatomic, copy) NSString *jsNameInBundle;
@end

NS_ASSUME_NONNULL_END
