//
//  PPAppConfig.swift
//  PandaNote
//
//  Created by Panway on 2021/12/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit
import GCDWebServer
import Kingfisher
import Alamofire


class PPAppConfig: NSObject {
    static let shared = PPAppConfig()
    let iCloudContainerId = "iCloud.com.agolddata.pandanotex"
    
    // https://github.com/swisspol/GCDWebServer/issues/143
    var fileViewMode = 0 //文件列表显示方式，列表或图标
    var fileListOrder = PPFileListOrder.nameAsc //文件列表排序方式
    var showMarkdownOnly = false ///< 最近文件仅显示markdown
    private var config = [String:String]()
    /// 沙盒Sandbox/Library/PandaCache
    private var pp_mainDirectory:String!
    let cacheDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    
    private let webServer = GCDWebServer() // 必须保存实例防止对象被释放
    let utcDateFormatter = DateFormatter() ///< yyyy-MM-dd'T'HH:mm:ss.SSSZ
    let dateFormatter = DateFormatter() ///< yyyy-MM-dd HH:mm:ss
    let popMenu = PPPopMenu()
    var downColor = PPDownColorCollection()
    var downFont = PPDownFontCollection()
    var outlineMaxWidth = 300.0 // markdown编辑器目录(大纲)最大宽度
    func initSetting() {
        //将其格式选项中加入带小数秒的选项，并将时区设置为当前时区
        //dateFormatter.formatOptions.insert(.withFractionalSeconds)
        utcDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        utcDateFormatter.timeZone = TimeZone.current

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current

        initWebServer()
        self.pp_mainDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        self.pp_mainDirectory += "/PandaNote"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/PandaNote_AppSetting.json")) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                self.config = json as! Dictionary<String, String>
            }
        }

        if let path = Bundle.main.path(forResource: "MarkdownSample", ofType:"md"),
           !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Documents/MarkdownSample.md") {
            try? FileManager.default.copyItem(atPath: path, toPath: NSHomeDirectory() + "/Documents/MarkdownSample.md")
        }
        self.fileListOrder = PPFileListOrder(rawValue: getIntItem("fileListOrder")) ?? .type
        showMarkdownOnly = getIntItem("showMarkdownOnly") == 1 ? true : false
        if PPUserInfo.pp_boolValue("appLock") {
            // 开启应用锁就跳转
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let appAuth = PPAppAuthenticationVC()
                appAuth.modalPresentationStyle = .fullScreen
                UIViewController.pp_topViewController()?.present(appAuth, animated: true)
            }
        }
        let manager = KingfisherManager.shared
        manager.cache.diskStorage.config.expiration = .days(30) //删除所有超过默认七天的缓存
        manager.cache.cleanExpiredDiskCache()
//        let cache = ImageCache.default
//        cache.diskStorage.config.autoExtAfterHashedFileName = true
    }
    func initSettingAfterLoadMainUI() {
#if DEBUG
        FLEXManager.shared.showExplorer() //调试期间开启FLEX工具
#endif
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
    
    func getIntItem(_ key:String) -> Int {
        return Int(config[key] ?? "") ?? 0
    }
    
    func getFloat(_ key:String) -> CGFloat {
        return config[key]?.toCGFloat() ?? 0.0
    }
    
    func setItem(_ key:String, _ value:String) {
        config[key] = value
        saveToJSONFile()
    }
    
    func saveToJSONFile() {
        if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: JSONSerialization.WritingOptions.prettyPrinted) {
            do {
                try jsonData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/PandaNote_AppSetting.json"), options: .atomic)
            } catch {
                debugPrint(error)
            }
        }
    }
    
    func initWebServer() {
        webServer.addGETHandler(forBasePath: "/", directoryPath: PPDiskCache.shared.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
        webServer.start(withPort: 23333 , bonjourName: "PandaNoteServer")
        print("Visit \(webServer.serverURL?.absoluteString ?? "") in your web browser")
    }
    //下载字体到沙盒Documents
    func downloadFontAndSaveToDocuments(url: String, name: String) {
        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent(name)
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        AF.download(url, to: destination).response { response in
            self.loadAndUseDownloadedFont(name: name)
        }
    }
    func loadAndUseDownloadedFont(name: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let downloadedFontURL = documentsURL.appendingPathComponent(name)
        
        do {
            let fontData = try Data(contentsOf: downloadedFontURL)
            if let fontDataProvider = CGDataProvider(data: fontData as CFData),
               let font = CGFont(fontDataProvider) {
                CTFontManagerRegisterGraphicsFont(font, nil)
            }
        } catch {
            print("Error loading downloaded font:", error)
        }
    }
}
