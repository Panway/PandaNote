//
//  PPSynologyService.swift
//  PandaNote
//
//  Created by Panway on 2023/8/15.
//  Copyright © 2023 Panway. All rights reserved.
//  https://github.com/alexiscn/SynologyKit
//  https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/FileStation/All/enu/Synology_File_Station_API_Guide.pdf

import Foundation
import Alamofire

class PPSynologyService: NSObject, PPCloudServiceProtocol {
    var url = "" ///< 用户输入的
    var username = ""
    var password = ""
    var access_token:String?
    var baseURL = "" ///< 请求使用的
    var sid = "" ///< Authorized session ID
    var did = "" ///< device id
    /// 更新完token等信息后执行的回调。你可以保存新token等信息到本地或数据库（解耦）
    var configChanged : ((_ key:String,_ value:String) -> ())?
    
    
    init(url: String, username: String, password: String, sid: String, did: String) {
        self.url = url
        self.username = username
        self.password = password
        self.sid = sid
        self.did = did
        super.init()
//        login(url: url, username: username, password: password)
        self.getServerInfo(url: url)

    }
    
    func getServerInfo(url: String) {
        var serverID = ""
        if !url.hasPrefix("http") {
            serverID = url //QuickConnect ID
        }
        else {
            //局域网URL直接登录
            
            return
        }
        let headers: HTTPHeaders = [
            "User-Agent": "DSfile/11 CFNetwork/1408.0.4 Darwin/22.5.0",
        ]

        let parameters: Parameters = [
            "get_ca_fingerprints": true,
            "id": "dsm",
            "serverID": serverID,
            "command": "get_server_info",
            "version": "1"
        ]
        let requestURL = "https://global.quickconnect.cn/Serv.php"
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseData { response in

            switch response.result {
            case .success(_):
                // 使用解码后的对象

                debugPrint("alist response:")
                guard let jsonDict = response.data?.pp_JSONObject() as? [String:Any] else { return }
                guard let service = jsonDict["service"] as? [String:Any] else { return }
                guard let relay_ip = service["relay_ip"] as? String, let relay_port = service["relay_port"] as? Int else { return }
                self.baseURL = "http://\(relay_ip):\(relay_port)"
                service.printJSON()
                if (self.sid.length == 0) {
                    self.login(username: self.username, password: self.password)
                }
                else {
                    
                }
            case .failure(let error):
                // 处理错误
                debugPrint("alist error:",error)
            }
        }
    }
    func login(username:String, password:String) {
            let parameters: Parameters = [
                "account": username,
                "api": "SYNO.API.Auth",
                "method": "login",
                "passwd": password,
                "session": "FileStation",
                "version": "3"
            ]
            
            let headers: HTTPHeaders = [
                "User-Agent": "DSfile/11 CFNetwork/1408.0.4 Darwin/22.5.0",
            ]
            
            AF.request(baseURL + "/webapi/auth.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(_):
                    // 使用解码后的对象
                    let res = response.data?.pp_JSONObject()
/* 响应体：
{
  "data" : {
    "did" : "AAAAAAAAAA",
    "sid" : "BBBBBBBBBB"
  },
  "success" : true
}
*/
                    res?.printJSON()
                    guard let data_ = res?["data"] as? [String:Any] else { return }
                    guard let sid = data_["sid"] as? String, let did = data_["did"] as? String else { return }

                    self.sid = sid
                    self.did = did
                    debugPrint("DSfile response:" , response)
                    guard let responseHeader = response.response?.headers else {return}
                    guard let cookie = responseHeader["Set-Cookie"] else { return }

                    self.access_token = cookie
                    self.configChanged?("PPAccessToken", cookie)
                    self.configChanged?("sid", sid)
                    self.configChanged?("did", did)
                case .failure(let error):
                    // 处理错误
                    debugPrint("DSfile error:",error)
                }
            }
        }
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping ([PPFileObject], Error?) -> Void) {

        let headers: HTTPHeaders = [
            "User-Agent": "DSfile/11 CFNetwork/1408.0.4 Darwin/22.5.0",
        ]

        let parameters: [String: Any] = [
            "_sid": self.sid,
            "additional": "[\"size\", \"time\", \"type\"]",
            "api": "SYNO.FileStation.List",
            "limit": 0,
            "method": "list_share",
            "offset": 0,
            "sort_by": "name",
            "sort_direction": "asc",
            "version": 2
        ]

//        let url = "http://192.168.1.46:5000/webapi/entry.cgi"

        AF.request(baseURL + "/webapi/entry.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData
        { response in
            switch response.result {
            case .success(_):
                // 使用解码后的对象
                let res = response.data?.pp_JSONObject()
                res?.printJSON()
                guard let data_ = res?["data"] as? [String:Any] else { return }
                guard let shares = data_["shares"] as? [[String:Any]] else { return }
                let files = PPSynologyFile.toModelArray(shares)

                completion(files, nil)
            case .failure(let error):
                // 处理错误
                debugPrint("DSfile error:",error)
            }
        }

    }
    
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (Data?, String, Error?) -> Void) {
        
    }
    
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping ([String : String]?, Error?) -> Void) {
        
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (Error?) -> Void) {
        
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping (Error?) -> Void) {
        
    }
    
    
}
