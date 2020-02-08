//
//  PPUserInfoManager.swift
//  PandaNote
//
//  Created by panwei on 2019/8/28.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation



class PPUserInfo: NSObject {
    var webDAVServerURL:String?
    var webDAVUserName:String?
    var webDAVPassword:String?
    var webDAVRemark:String?
    var pp_mainDirectory:String!
    var pp_mainDirectoryURL:URL!
    var pp_fileIcon = [String:String]()
    var pp_timezoneOffset:Int!
    var pp_Pref:Dictionary<String, Any>!
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
        self.webDAVServerURL = UserDefaults.standard.string(forKey: "PPWebDAVServerURL")
        self.webDAVUserName = UserDefaults.standard.string(forKey: "PPWebDAVUserName")
        self.webDAVPassword = UserDefaults.standard.string(forKey: "PPWebDAVPassword")
        self.webDAVRemark = UserDefaults.standard.string(forKey: "PPWebDAVRemark")
        self.pp_timezoneOffset = TimeZone.current.secondsFromGMT()

    }
    
    
    func save(_ value: String, forKey defaultName: String) -> Void {
        UserDefaults.standard.setValue(value, forKey: defaultName)

    }
    
}
