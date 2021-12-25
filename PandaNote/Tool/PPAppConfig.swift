//
//  PPAppConfig.swift
//  PandaNote
//
//  Created by Panway on 2021/12/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit
import GCDWebServer


class PPAppConfig: NSObject {
    static let shared = PPAppConfig()
    
    let webServer = GCDWebServer() // 必须保存示例 https://github.com/swisspol/GCDWebServer/issues/143

    func initSetting() {
        initWebServer()
    }
    
    func initWebServer() {
        webServer.addGETHandler(forBasePath: "/", directoryPath: PPDiskCache.shared.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
        webServer.start(withPort: 23333 , bonjourName: "GCD Web Server")
        print("Visit \(webServer.serverURL?.absoluteString ?? "") in your web browser")
    }
}
