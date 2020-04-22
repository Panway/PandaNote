//
//  PPUserInfoManager.swift
//  PandaNote
//
//  Created by panwei on 2019/8/28.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation



class PPUserInfo: NSObject {
    var webDAVServerURL = ""
    var webDAVUserName:String?
    var webDAVPassword:String?
    var webDAVRemark:String = ""
    var pp_mainDirectory:String!
    var pp_mainDirectoryURL:URL!
    var pp_fileIcon = [String:String]()
    /// 本地时间相对于格林尼治时间的差距
    var pp_timezoneOffset:Int!
    var pp_JSONConfig:String!
//    var pp_Setting:Dictionary<String, Any>!
    /// The repeat count.
    public var pp_Setting:Dictionary<String, Any> = [:] {
        didSet {
            debugPrint("\(String(describing: oldValue)) --> \(String(describing: pp_Setting))")
            let data:NSData = NSKeyedArchiver.archivedData(withRootObject: pp_Setting) as NSData
            data.write(toFile: self.pp_mainDirectory+"/PP_UserPreference", atomically: true)
            if let jsonData = try? JSONSerialization.data(withJSONObject: pp_Setting, options: JSONSerialization.WritingOptions.prettyPrinted) {
                do {
                    try jsonData.write(to: URL(fileURLWithPath: self.pp_mainDirectory + "/PP_JSONConfig.json"), options: .atomic)
                } catch {
                    debugPrint(error)
                }
                                
            }
//            if oldValue != pp_Setting {
                //save to disk
                
//            }
        }
    }
    static let shared = PPUserInfo()
    
    func initConfig() -> Void {
        self.pp_mainDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]//documentDirectory
        self.pp_mainDirectory += "/PandaCache"
        self.pp_mainDirectoryURL = URL.init(fileURLWithPath: self.pp_mainDirectory)
//        FileManager.default.fileExists(atPath: self.pp_mainDirectory, isDirectory: &true)
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
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.pp_mainDirectory+"/PP_UserPreference")) {
            let dict2 = NSKeyedUnarchiver.unarchiveObject(with: data)
//            debugPrint("\(String(describing: dict2))")
            self.pp_Setting = dict2 as! Dictionary<String, Any>
//            self.pp_JSONConfig = JSONSerialization.
        }

//        self.pp_Setting = ["saveDocWhenClose":"1"]
//        self.pp_Setting.updateValue(<#T##value: Any##Any#>, forKey: <#T##String#>)
        
    }
    
    class func pp_valueForSettingDict(key : String) -> Bool {
        if let string : String = PPUserInfo.shared.pp_Setting[key] as? String {
            return string.bool
        }
        return false
    }
    class func saveObject(_ objcet:Any) {
        
    }
//    func save(_ value: String, forKey defaultName: String) -> Void {
//        UserDefaults.standard.setValue(value, forKey: defaultName)
//
//    }
    
}
