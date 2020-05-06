//
//  NSURLProtocol+WebKitSupport.h
//  NSURLProtocol+WebKitSupport
//
//  Created by yeatse on 2016/10/11.
//  Copyright © 2016年 Yeatse. All rights reserved.
//  https://github.com/Yeatse/NSURLProtocol-WebKitSupport
//  https://github.com/DingSoung/Extension/blob/master/Sources/WebKit/WKWebView%2BregisterScheme.swift

#import <Foundation/Foundation.h>

@interface NSURLProtocol (WebKitSupport)

+ (void)wk_registerScheme:(NSString*)scheme;

+ (void)wk_unregisterScheme:(NSString*)scheme;

@end
