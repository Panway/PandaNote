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
    
    // https://github.com/swisspol/GCDWebServer/issues/143
    var fileViewMode = 0 //文件列表显示方式，列表或图标
    var fileListOrder = PPFileListOrder.nameAsc //文件列表排序方式
    private var config = [String:String]()
    /// 沙盒Sandbox/Library/PandaCache
    private var pp_mainDirectory:String!
    private let webServer = GCDWebServer() // 必须保存实例防止对象被释放

    
    func initSetting() {
#if DEBUG
        FLEXManager.shared.showExplorer() //调试期间开启FLEX工具
#endif

        initWebServer()
        self.pp_mainDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        self.pp_mainDirectory += "/PandaNote"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/Panda_AppConfig.json")) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                self.config = json as! Dictionary<String, String>
            }
        }

        if let path = Bundle.main.path(forResource: "MarkdownSample", ofType:"md") {
            try? FileManager.default.copyItem(atPath: path, toPath: NSHomeDirectory() + "/Documents/MarkdownSample.md")
        }
        self.fileListOrder = PPFileListOrder(rawValue: getItem("fileListOrder")) ?? .type
    }
    
    func initDataBase() {
//        let dbModel = PPPriceDBModel()
//        let sqliteManager = PPSQLiteManager(delegate: dbModel)
////        let sqliteManager = PPSQLiteManager.shared
//        sqliteManager.createDB()
//        let sql = "create table if not exists pp_price(id integer primary key autoincrement,code varchar(20) not null,price varchar(20) default 0,name varchar(50), whole_price varchar(20) ,remark varchar(20),category varchar(20) )"
//        
//        sqliteManager.operation(process: sql, value: [])
    }
    func getItem(_ key:String) -> String {
        return config[key] ?? ""
    }
    func getItem(_ key:String) -> Int {
        return Int(config[key] ?? "") ?? 0
    }
    
    func setItem(_ key:String, _ value:String) {
        config[key] = value
        saveToJSONFile()
    }
    
    func saveToJSONFile() {
        if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: JSONSerialization.WritingOptions.prettyPrinted) {
            do {
                try jsonData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/Panda_AppConfig.json"), options: .atomic)
            } catch {
                debugPrint(error)
            }
        }
    }
    
    func initWebServer() {
        webServer.addGETHandler(forBasePath: "/", directoryPath: PPDiskCache.shared.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
        webServer.start(withPort: 23333 , bonjourName: "GCD Web Server")
        print("Visit \(webServer.serverURL?.absoluteString ?? "") in your web browser")
    }
}
