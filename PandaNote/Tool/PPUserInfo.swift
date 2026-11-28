//
//  PPUserInfoManager.swift
//  PandaNote
//
//  Created by Panway on 2019/8/28.
//  Copyright © 2019 Panway. All rights reserved.
//  App公有设置和用户私有设置混在一起，后期优化

import Foundation



public enum PPCloudServiceType : String {
    case webdav = "webdav"
    case icloud = "icloud"
    case local = "local"
    case dropbox = "Dropbox"
    case baiduyun = "baiduyun"
    case synology = "synology"
    case onedrive = "OneDrive"
    case alist = "alist"
    case aliyundrive = "AliyunDrive"
}

class PPUserInfo: NSObject {
    static let shared = PPUserInfo()

    var webDAVServerURL = ""
    var webDAVUserName:String?
    var webDAVPassword:String?
    var webDAVRemark = ""
    var cloudServiceToken = "" //access token
    var cloudServiceExtra = ""//额外的字段
    /// 坚果云、Drpbox等
    var cloudServiceType:PPCloudServiceType = .webdav
    /// 沙盒 Sandbox 里面的：`/Library/PandaCache`
    var pp_mainDirectory:String!
    var pp_mainDirectoryURL:URL!
    var pp_fileIcon = [String:String]()
    /// 本地时间相对于格林尼治时间的差距
    var pp_timezoneOffset:Int!
    /// App设置，不包含用户私密信息
    var pp_JSONConfig:String!
    /// webview资源
    var pp_WebViewResource = [String]()
    /// 当前选择的是哪个服务器。
    /// 只允许通过 selectServerIndex(_:) 改：这个值和 pp_serverInfoList 是分开存的，删配置、切服务、启动读旧值都可能让两边对不上，
    /// 一旦越界，后面每次按下标取当前配置都会当场崩（Index out of range），把写入口收起来就不用满项目找哪一处漏了校验
    private(set) var pp_lastSeverInfoIndex = 0
    /// App配置备份到服务器的位置
    var appSettingLocationInServer = ""
    /// 强制刷新文件列表的时候设为true（添加完服务器配置）
    var refreshFileList = false

    /// 最近访问文件列表
     var recentFiles:Array<PPFileObject> = [] {
        didSet {
            do {
                let encodedData = try JSONEncoder().encode(recentFiles)
                try? encodedData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/PP_RecentFiles.json"))
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    
    /// 保存服务器配置（坚果云、Dropbox等）
    var pp_serverInfoList : [[String : String]] = [] {
        didSet {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted // 设置美化选项
                let encodedData = try encoder.encode(pp_serverInfoList)
//                pp_serverInfoList.last?.printJSON(true)
                try? encodedData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/PP_CloudServerSetting.json"))
                updateRemarkIndexMap()
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    //获取当前服务器类型
    func getCurrentServerInfo(_ key:String) -> String {
        return currentServerInfo[key] ?? ""
    }
    //更新当前服务器设置
    func updateCurrentServerInfo(key:String, value:String) {
        guard pp_serverInfoList.isEmpty == false else { return }
        var serverList = pp_serverInfoList
        let safeIndex = min(max(pp_lastSeverInfoIndex, 0), serverList.count - 1)
        var current = serverList[safeIndex]
        current[key] = value
        serverList[safeIndex] = current
        pp_serverInfoList = serverList
    }

    /// 当前选中的那条配置。
    /// 索引比数组长（删了配置）或者数组为空（配置文件被清空）时分别收敛到最后一个 / 空字典，
    /// 调用方拿到的永远是能用的值，不用自己判越界
    var currentServerInfo:[String : String] {
        guard pp_serverInfoList.isEmpty == false else { return [:] }
        return pp_serverInfoList[min(max(pp_lastSeverInfoIndex, 0), pp_serverInfoList.count - 1)]
    }

    /// 选中某条配置，唯一合法的索引写入口。
    /// 传进来的序号一律收敛到合法范围并立刻持久化，不然杀掉 App 之后 pp_lastSeverInfoIndex 那份旧值会在下次启动时被读回来
    func selectServerIndex(_ index:Int) {
        let safeIndex = pp_serverInfoList.isEmpty ? 0 : min(max(index, 0), pp_serverInfoList.count - 1)
        pp_lastSeverInfoIndex = safeIndex
        PPAppConfig.shared.setItem("pp_lastSeverInfoIndex", "\(safeIndex)")
    }

    /// 覆盖指定位置的配置。索引越界就忽略这次写入，不崩也不写坏数据
    func setServerInfo(_ newServer:[String : String], at index:Int) {
        guard index >= 0, index < pp_serverInfoList.count else { return }
        pp_serverInfoList[index] = newServer
    }

    /// 覆盖当前配置。数组为空或者索引异常时不写，调用方不用自己做边界判断
    func setCurrentServerInfo(_ newServer:[String : String]) {
        guard pp_serverInfoList.isEmpty == false else { return }
        setServerInfo(newServer, at: min(max(pp_lastSeverInfoIndex, 0), pp_serverInfoList.count - 1))
    }
    //服务器配置对应的序号映射
    var serverNameIndexMap : [String : String] = [:]
    
    func initConfig() -> Void {
        self.pp_mainDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]//documentDirectory
        self.pp_mainDirectory += "/PandaNote"
        self.pp_mainDirectoryURL = URL.init(fileURLWithPath: self.pp_mainDirectory)
        pp_fileIcon = ["pdf":"ico_pdf",
                       "mp3":"ico_music",
                       "zip":"ico_zip",
                       "md":"ico_txt",
                       "txt":"ico_txt",
                       "html":"ico_code",
                       "css":"ico_code",
                       "js":"ico_code",
                       "py":"ico_code",
                       "json":"ico_code",
                       "MP4":"ico_video",
                       "mp4":"ico_video",
                       "mov":"ico_video",
                       "pdf2":"ico_pdf"]
        do {
            if !FileManager.default.fileExists(atPath: self.pp_mainDirectory) {
                try FileManager.default.createDirectory(atPath: self.pp_mainDirectory, withIntermediateDirectories: true, attributes: nil)
            }
        }
        catch {}
        self.pp_timezoneOffset = TimeZone.current.secondsFromGMT()
        
        self.pp_lastSeverInfoIndex = PPAppConfig.shared.getIntItem("pp_lastSeverInfoIndex")
        
        //服务器配置
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/PP_CloudServerSetting.json")) {
            //allowFragments选项表示解析器允许JSON数据中的顶级元素是非JSON对象（比如字符串、数字、布尔值、null等），而不仅仅是JSON对象（包括字典和数组）
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                self.pp_serverInfoList = json as! [[String : String]]
                updateRemarkIndexMap()
            }
        }
        else {
            debugPrint("no server config found 初次安装无数据，默认使用本地文件列表")
            let newServer = ["PPWebDAVUserName":"本地",
                             "PPWebDAVRemark":"本地",
                             "PPCloudServiceType":PPCloudServiceType.local.rawValue]
            self.pp_serverInfoList = [newServer]
        }

        // 上面读索引和读数组是两步，索引还单独存在 UserDefaults 里，历史版本删配置时又会漏改。
        // 这里统一修一次：数组空了补回「本地」，索引越界回到 0，避免脏值被带进运行期后按下去就崩
        if self.pp_serverInfoList.isEmpty {
            self.pp_serverInfoList = [["PPWebDAVUserName":"本地",
                                       "PPWebDAVRemark":"本地",
                                       "PPCloudServiceType":PPCloudServiceType.local.rawValue]]
        }
        if self.pp_lastSeverInfoIndex < 0 || self.pp_lastSeverInfoIndex >= self.pp_serverInfoList.count {
            selectServerIndex(0)
        }
        
        
        if let recentFileData = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/PP_RecentFiles.json")) {
            let archieveArray = try? JSONDecoder().decode([PPFileObject].self, from: recentFileData)
            self.recentFiles = archieveArray ?? []
        }
        
    }
    
    //MARK:更新云盘服务设置(切换云盘服务时force为false)
    func updateCurrentServerInfo(index:Int) {
        // 先校验再改索引：以前是先写 pp_lastSeverInfoIndex 再判断越界，越界值留在属性上，下一次取当前配置就崩
        let webDAVInfoArray = PPUserInfo.shared.pp_serverInfoList
        guard webDAVInfoArray.isEmpty == false else { return }
        let safeIndex = min(max(index, 0), webDAVInfoArray.count - 1)
        selectServerIndex(safeIndex)
        let webDAVInfo = webDAVInfoArray[safeIndex]

        PPUserInfo.shared.webDAVServerURL = webDAVInfo["PPWebDAVServerURL"] ?? "" //后期删除
        PPUserInfo.shared.webDAVUserName = webDAVInfo["PPWebDAVUserName"] ?? "" //后期删除
        PPUserInfo.shared.webDAVPassword = webDAVInfo["PPWebDAVPassword"] ?? "" //后期删除
        PPUserInfo.shared.webDAVRemark = webDAVInfo["PPWebDAVRemark"] ?? ""
        if(PPUserInfo.shared.webDAVUserName?.length == 0) {
            PPUserInfo.shared.webDAVUserName = webDAVInfo["PPUserName"] ?? ""
        }
        if(PPUserInfo.shared.webDAVPassword?.length == 0) {
            PPUserInfo.shared.webDAVPassword = webDAVInfo["PPPassword"] ?? ""
        }
        if(PPUserInfo.shared.webDAVRemark.length == 0) {
            PPUserInfo.shared.webDAVRemark = webDAVInfo["PPRemark"] ?? ""
        }
        if(PPUserInfo.shared.webDAVServerURL.length == 0) {
            PPUserInfo.shared.webDAVServerURL = webDAVInfo["PPServerURL"] ?? ""
        }
        PPUserInfo.shared.cloudServiceExtra = webDAVInfo["PPCloudServiceExtra"] ?? ""
        PPUserInfo.shared.cloudServiceToken = webDAVInfo["PPAccessToken"] ?? ""
        PPUserInfo.shared.cloudServiceType = PPCloudServiceType(rawValue: webDAVInfo["PPCloudServiceType"] ?? "") ?? .webdav
    }
    class func pp_valueForSettingDict(key : String) -> Bool {
        return self.pp_boolValue(key)
    }
    class func pp_boolValue(_ keyInSettingDict : String) -> Bool {
        let string = PPAppConfig.shared.getItem(keyInSettingDict)
        return string.bool
    }
    class func saveObject(_ objcet:Any) {
        
    }
    func updateRemarkIndexMap() {
        for i in 0..<pp_serverInfoList.count {
            let obj = pp_serverInfoList[i]
            if let remark = obj["PPWebDAVRemark"] {
                serverNameIndexMap[remark] = "\(i)"
            }
        }
    }
    ///共享的网页单例，提高网页显示速度
    lazy var webViewController: PPWebViewController = {
        let webVC = PPWebViewController()
//        webVC.urlString = "https://tophub.today"
        return webVC
    }()
//    func save(_ value: String, forKey defaultName: String) -> Void {
//        UserDefaults.standard.setValue(value, forKey: defaultName)
//
//    }
    
}
