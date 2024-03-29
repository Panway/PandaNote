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
    /// 当前选择的是哪个服务器
    var pp_lastSeverInfoIndex = 0
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
                try? encodedData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/PP_CloudServerSetting.json"))
                updateRemarkIndexMap()
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
    //获取当前服务器设置
    func getCurrentServerInfo(_ key:String) -> String {
        let current = pp_serverInfoList[pp_lastSeverInfoIndex]
        if let value = current[key] {
            return value
        }
        return ""
    }
    //更新当前服务器设置
    func updateCurrentServerInfo(key:String, value:String) {
        var serverList = pp_serverInfoList
        var current = serverList[pp_lastSeverInfoIndex]
        current[key] = value
        serverList[pp_lastSeverInfoIndex] = current
        pp_serverInfoList = serverList
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
        
        
        if let recentFileData = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/PP_RecentFiles.json")) {
            let archieveArray = try? JSONDecoder().decode([PPFileObject].self, from: recentFileData)
            self.recentFiles = archieveArray ?? []
        }
        
    }
    
    //MARK:更新云盘服务设置(切换云盘服务时force为false)
    func updateCurrentServerInfo(index:Int) {
        PPUserInfo.shared.pp_lastSeverInfoIndex = index
        let webDAVInfoArray = PPUserInfo.shared.pp_serverInfoList
        if webDAVInfoArray.count < 1 || index > webDAVInfoArray.count - 1 {
            return
        }
        let webDAVInfo = webDAVInfoArray[index]

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
