//
//  WKWebViewTool.swift
//  PandaNote
//
//  Created by topcheer on 2022/9/4.
//  Copyright © 2022 WeirdPan. All rights reserved.
//

import UIKit
import WebKit

class WKWebViewTool: NSObject {
    //清除所有的WebView缓存数据 /Library/Webkit/com.xxx.xxx/WebsiteData 和/Library/Caches/com.xxx.xxx/Webkit
    //可以调用fetchDataRecordsOfTypes方法获取浏览记录,然后通过对域名的筛选决定如何删除缓存
    class func pp_clearAllWebsiteData() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let sinceDate = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: sinceDate) {
            debugPrint("清除record完成")
        }
    }
    //清除缓存
    class func pp_clearWebViewCache() {
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
    }
}
