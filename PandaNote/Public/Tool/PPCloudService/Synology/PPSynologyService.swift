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
//#if os(iOS) || os(watchOS) || os(tvOS)
//import MobileCoreServices
//#elseif os(macOS)
//import CoreServices
//#endif

class PPSynologyService: NSObject, PPCloudServiceProtocol {
    var url = "" ///< 用户输入的地址或者QC ID
    var username = ""
    var password = ""
    var otp_code = "" //两步验证码、Secure Signin双重验证

    var remoteBaseURL = "" ///< 请求使用的远程QuickConnect服务地址
    var localBaseURL = "" ///< 请求使用的局域网地址
    var getServerInfoURL = "https://global.quickconnect.cn/Serv.php"
    var useLANIP = false ///< 用来自动切换局域网和远程ip
    var forceUseRemote = false
    var sid = "" ///< Authorized session ID
    var did = "" ///< device id
    var requestCount = -1
    var retryCount = 0
    var overwriteFile = true

    private static let dateFormatter = DateFormatter()
    //    let reachabilityManager: NetworkReachabilityManager?
    private var headers: HTTPHeaders = [
        "User-Agent": "Synology-DS_file_5.17.0_iPhone_13_iOS_16.5 (iPhone; iOS 16.5)",
//        "User-Agent": "DSfile/11 CFNetwork/1408.0.4 Darwin/22.5.0",
    ]
    /// 更新完token等信息后执行的回调。你可以保存新token等信息到本地或数据库（解耦）
    var configChanged : ((_ key:String,_ value:String) -> ())?
    var baseURL: String {
        //TODO: 自动切换局域网和远程IP
        if useLANIP {
            return localBaseURL
        }
        return remoteBaseURL.length > 0 ? remoteBaseURL : localBaseURL
    }
    
    init(url: String, remoteURL: String, localURL: String, username: String, password: String, otp_code: String, sid: String, did: String) {
        self.url = url
        self.remoteBaseURL = remoteURL
        self.localBaseURL = localURL
        self.username = username
        self.password = password
        self.otp_code = otp_code
        self.sid = sid
        self.did = did
        /*
        if let localip = self.localBaseURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "").pp_split(":").first {
            self.reachabilityManager = NetworkReachabilityManager(host: localip)!
            self.reachabilityManager?.startListening { status in
                switch status {
                case .reachable(.cellular), .reachable(.ethernetOrWiFi):
                    print("\(localip) is reachable")
                    // 在这里处理服务可达
                case .notReachable:
                    print("\(localip) is not reachable")
                    // 在这里处理服务不可
                case .unknown:
                    print("\(localip) status is unknown")
                }
            }
        }
        else {
            self.reachabilityManager = nil
        }
        */
        super.init()
//        self.getServerInfo(url: url)

    }
    
    /// 获取远程ip和端口、局域网ip和端口
    /// - Parameters:
    ///   - url: QuickConnect ID
    ///   - optionalURL: global.quickconnect.cn 获取不到远程ip的话换个域名重新获取远程ip
    func getServerInfo(url: String, callback:((String) -> Void)? = nil) {
        var serverID = ""
        if !url.hasPrefix("http") {
            serverID = url //QuickConnect ID
        }
        else {
            // TODO: 局域网URL直接登录
            self.localBaseURL = url
            self.configChanged?("PPLocalBaseURL", url)
            if (self.sid.length == 0) {
                self.login(username: self.username, password: self.password, otp_code: self.otp_code, callback: callback)
            }
            return
        }

        let parameters: Parameters = [
            "get_ca_fingerprints": true,
            "id": "dsm",
            "serverID": serverID,
            "command": "get_server_info",
            "version": "1"
        ]
        PPCloudHTTP.shared.request(getServerInfoURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseData { response in
            switch response.result {
            case .success(_):
                // 注意：国外IP不可访问
                debugPrint("Synology getServerInfo:",response)
                response.data?.pp_JSONObject()?.printJSON()
                guard let jsonDict = response.data?.pp_JSONObject() as? [String:Any] else { return }
                let getInfoSuccess = self.handleServerInfo(jsonDict)
                if getInfoSuccess {
                    if (self.sid.length == 0) {
                        self.login(username: self.username, password: self.password ,otp_code: self.otp_code, callback: callback)
                    }
                }
                else {
                    if let command = jsonDict["command"] as? String,
                       let sites = jsonDict["sites"] as? [String],
                       command == "get_server_info",
                       sites.count > 0 {
                        self.getServerInfoURL = "https://" + (sites.first ?? "") + "/Serv.php"
                        self.getServerInfo(url: url, callback: callback)
                    }
                    if let env = jsonDict["env"] as? [String:Any],
                       let control_host = env["control_host"] as? String {
                        self.getServerInfoCN(url: "https://" + control_host + "/Serv.php", serverID: serverID, callback: callback)
                    }
                }

               
            case .failure(let error):
                // 处理错误
                debugPrint("SynologyService getServerInfo error:",error)
            }
        }
    }
    func getServerInfoCN(url: String, serverID: String, callback:((String) -> Void)? = nil) {
        let parameters: Parameters = [
            "location": "zh_CN",
            "id": "dsm",
            "platform": "iPhone14,5",
            "serverID": serverID,
            "command": "request_tunnel",
            "version": "1"
        ]
        PPCloudHTTP.shared.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseData { response in
            switch response.result {
            case .success(_):
                // 注意：国外IP不可访问
                debugPrint("SynologyService getServerInfoCN:",response)
                response.data?.pp_JSONObject()?.printJSON()
                guard let jsonDict = response.data?.pp_JSONObject() as? [String:Any] else { return }
                let getInfoSuccess = self.handleServerInfo(jsonDict)
                if (getInfoSuccess && self.sid.length == 0) {
                    self.login(username: self.username, password: self.password ,callback: callback)
                }
                
               
            case .failure(let error):
                // 处理错误
                debugPrint("SynologyService getServerInfo error:",error)
            }
        }
    }
    
    func handleServerInfo(_ jsonDict: [String:Any]) -> Bool {
        guard let service = jsonDict["service"] as? [String:Any] ,
              let server = jsonDict["server"] as? [String:Any] else { return false}
        guard let relay_ip = service["relay_ip"] as? String,
              let relay_port = service["relay_port"] as? Int,
              let local_port = service["port"] as? Int else { return false}
        
        self.remoteBaseURL = "http://\(relay_ip):\(relay_port)"
        self.configChanged?("PPServerURL", self.remoteBaseURL)
        //service.printJSON()
        guard let interface = server["interface"] as? [[String:Any]],
              let firstIP = interface.first,
              let localIP = firstIP["ip"] as? String else { return false }
        self.configChanged?("PPLocalBaseURL", "http://\(localIP):\(local_port)")
        return true
    }
    
    func login(username:String, password:String, otp_code:String? = nil, callback:((String) -> Void)? = nil) {
        var parameters: Parameters = [
            "account": username,
            "api": "SYNO.API.Auth",
            "method": "login",
            "passwd": password,
            "session": "FileStation",
            "version": "3"
        ]
        if let otp_code = otp_code, otp_code.length > 0 {
            parameters["otp_code"] = otp_code
        }
        PPCloudHTTP.shared.request(baseURL + "/webapi/auth.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).responseData { response in
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
                if let error = res?["error"] as? [String:Any] {
                    let errorObj = PPCSError(fromDictionary: error)
                    if errorObj.code == 403 || errorObj.code == 404 {
                        // 403:2-step verification code required。404:Failed to authenticate 2-step verification code
                        callback?("twoFactorAuthCodeError")
                    }
                    else if errorObj.code == 400 {
                        callback?("twoFactorAuthCodeError")
                    }
                    return
                }
                guard let data_ = res?["data"] as? [String:Any] else { return }
                guard let sid = data_["sid"] as? String, let did = data_["did"] as? String else { return }
                
                self.sid = sid
                self.did = did
                debugPrint("SynologyService login response:" , response)
                self.configChanged?("sid", sid)
                self.configChanged?("did", did)
                //                    guard let responseHeader = response.response?.headers else {return}
                //                    guard let cookie = responseHeader["Set-Cookie"] else { return }
                callback?("success")
                
            case .failure(let error):
                // 处理错误
                debugPrint("SynologyService login error:",error)
                callback?("forcedLoginRequired")
            }
        }
    }
    // 每隔3次请求检查本地网络可用性
    func checkLANStatus() {
//        requestCount += 1
//        if requestCount % 3 != 0 {
//            return
//        }
        let url = self.localBaseURL + "/webman/pingpong.cgi?quickconnect=true"

        PPCloudHTTP.shared.request(url, method: .get, headers: headers){ $0.timeoutInterval = 3 }.response { response in
//            debugPrint("checkLANStatus",response.response)
            if let statusCode = response.response?.statusCode,
               statusCode == 200 {
                self.useLANIP = true
            }
            else {
                self.useLANIP = false
            }
        }
        
    }
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping ([PPFileObject], Error?) -> Void) {
        self.checkLANStatus()
        var path_ = path
        if(path_.hasSuffix("/")) {
            path_ = String(path_.dropLast())
        }
        if self.sid.length == 0 {
            self.getServerInfo(url: self.url) { res in
                if res == "twoFactorAuthCodeError" {
                    completion([], PPCloudServiceError.twoFactorAuthCodeError)
                    return
                }
                if res != "success" && res.length > 0 {
                    completion([], res == "forcedLoginRequired" ? PPCloudServiceError.forcedLoginRequired :PPCloudServiceError.unknown)
                    return
                }
                self.contentsOfDirectory(path, pathID, completion: completion)
            }
            return
        }
        var parameters: [String: Any] = [
            "_sid": self.sid,
//            "additional": "[\"real_path\",\"size\",\"owner\",\"perm\",\"time\",\"worm_share\"]", //iOS DS file
            "additional": "[\"size\", \"time\", \"type\"]",
            "api": "SYNO.FileStation.List",
//            "limit": 0,
            "method": "list",
//            "offset": 0,
            "folder_path": "\"\(path_)\"",
            "sort_by": "name",
            "sort_direction": "asc",
            "version": 2
        ]

        if(path == "/") {
            parameters["folder_path"] = nil
            parameters["method"] = "list_share"
        }
//        parameters.printJSON()
//        let url = "http://192.168.1.46:5000/webapi/entry.cgi"

        PPCloudHTTP.shared.request(baseURL + "/webapi/entry.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData
        { response in
//            debugPrint("DSfile response:" , response)
            switch response.result {
            case .success(_):
                // 使用解码后的对象
                let res = response.data?.pp_JSONObject()
                res?.printJSON()
                var files = [[String:Any]]()
                guard let data_ = res?["data"] as? [String:Any] else {
                    if let code = response.response?.statusCode, code == 400, self.retryCount < 3 {
                        self.getServerInfo(url: self.url) { sid in
                            self.retryCount += 1 //自动刷新、防止死循环
                            self.contentsOfDirectory(path, pathID, completion: completion)
                        }
                    }
                    if let error = res?["error"] as? [String:Any] {
                        error.printJSON()
                        let errorObj = PPCSError(fromDictionary: error)
                        if errorObj.code == 119 {
                            self.sid = "" //SID not found, empty it
                        }
                        self.getServerInfo(url: self.url) { res in
                            if res == "twoFactorAuthCodeError" {
                                completion([], PPCloudServiceError.twoFactorAuthCodeError)
                                return
                            }
                            self.retryCount += 1 //自动刷新、防止死循环
                            self.contentsOfDirectory(path, pathID, completion: completion)
                        }
                        completion([], PPCloudServiceError.unknown)
                    }
                    debugPrint("SynologyService filelist response:" , response)
                    return
                }
                if(path == "/") {
                    guard let shares = data_["shares"] as? [[String:Any]] else { return }
                    files = shares
                }
                else {
                    guard let files_ = data_["files"] as? [[String:Any]] else { return }
                    files = files_
                }
                PPSynologyService.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                let synologyFiles = PPSynologyFile.toModelArray(files, PPSynologyService.dateFormatter, self.baseURL + "/webapi/entry.cgi?api=SYNO.FileStation.Thumb&method=get&version=2" + "&_sid=\(self.sid)")
                completion(synologyFiles, nil)
            case .failure(let error):
                // 处理错误
                debugPrint("SynologyService filelist error:",error,response,response.response?.statusCode)
                self.useLANIP = false
                self.getServerInfo(url: self.url) { s in
                    if self.retryCount < 3 {
                        self.retryCount += 1 //自动刷新、防止死循环
                        self.contentsOfDirectory(path, pathID, completion: completion)
                    }
                }
                completion([], PPCloudServiceError.serverUnreachable)
            }
        }
        


    }
    
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (Data?, String, Error?) -> Void) {
        guard let data = path.data(using: .utf8) else {
            return
        }
        let filename = path.pp_split("/").last ?? ""

        let dlink = "\"" + data.map { String(format: "%02.2hhx", $0) }.joined().uppercased() + "\""
        let nameEncoded = URLEncoding.default.escape(filename)
        let dlinkEncoded = URLEncoding.default.escape(dlink)
        let sidEncoded = URLEncoding.default.escape(sid)
        let urlString = "\(self.baseURL)/fbdownload/\(nameEncoded)?dlink=\(dlinkEncoded)&_sid=\(sidEncoded)&mime=1"
        completion(nil, urlString, nil)

    }
    
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        var path_ = atPath
        if(path_.hasSuffix("/")) {
            path_ = String(path_.dropLast())
        }
        let parameters: Parameters = [
            "_sid": self.sid,
            "api": "SYNO.FileStation.CreateFolder",
            "method": "create",
            "folder_path": "\"\(path_)\"",
            "name": "\"\(folderName)\"",
            "version": "2"
        ]
        parameters.printJSON()
        PPCloudHTTP.shared.request(baseURL + "/webapi/entry.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                completion(self.getResponseError(response))
            }
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping ([String : String]?, Error?) -> Void) {
        struct PPUploadParam {
            var key: String
            var value: String
        }
        
        let filename = path.pp_split("/").last ?? ""
        let dest_folder_path = path.replacingOccurrences(of: "/" + filename, with: "")
                
        let urlString = self.baseURL.appending("/webapi/entry.cgi?api=SYNO.FileStation.Upload&method=upload&version=2")
        let uploadURL = urlString.appending("&_sid=\(sid)")
        
        var parameters: [PPUploadParam] = []
        parameters.append(PPUploadParam(key: "path", value: dest_folder_path))
        parameters.append(PPUploadParam(key: "create_parents", value: "true"))
        parameters.append(PPUploadParam(key: "overwrite", value: "\(overwriteFile)")) //上传时覆盖

        let multipart: (MultipartFormData) -> Void = { formData in
            for param in parameters {
                formData.append(Data(param.value.utf8), withName: param.key)
            }
            //let mimeType = self.mimeType(forFileName: filename)
            formData.append(contents, withName: "file", fileName: filename) //,mimeType: mimeType)
        }
        // headers.add(name: "Cookie", value: self.access_token ?? "")
        AF.upload(multipartFormData: multipart, to: uploadURL, method: .post, headers: headers)
            .responseData { response in
                completion(nil, self.getResponseError(response))
            }
    }
    /// 暂未使用
    func mimeType(forFileName filename: String) -> String {
//        if filename.contains(".") {
//            let pathExtension = String(filename.split(separator: ".").last!)
//            if let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
//                let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
//            {
//                return contentType as String
//            }
//        }
        return "application/octet-stream"
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (Error?) -> Void) {
        //rename
        let filename = destPath.pp_split("/").last ?? ""
        // path/to/file.jpg --> path/to
        let dest_folder_path = destPath.replacingOccurrences(of: "/" + filename, with: "")
        var parameters: Parameters = [:]
        if isRename {
            parameters = [
                "api": "SYNO.FileStation.Rename",
                "method": "rename",
                "name": "\"\(filename)\"",
                "path": "\"\(srcPath)\"",
                "version": "2"
            ]
        }
        else {
            parameters = [
                "api": "SYNO.FileStation.CopyMove",
                "dest_folder_path": "\"\(dest_folder_path)\"",
                "method": "start",
                "overwrite": "true",
                "remove_src": "true",
                "path": "[\"\(srcPath)\"]",
                "version": "2"
            ]
        }
        PPCloudHTTP.shared.request(baseURL + "/webapi/entry.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                completion(self.getResponseError(response))
            }
    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping (Error?) -> Void) {
        let parameters: Parameters = [
            "api": "SYNO.FileStation.Delete",
            "method": "start",
            "path": "[\"\(path)\"]",
            "version": "2"
        ]
        PPCloudHTTP.shared.request(baseURL + "/webapi/entry.cgi", method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers)
            .responseData { response in
                completion(self.getResponseError(response))
            }
    }
    
    func getResponseError(_ response:AFDataResponse<Data>) -> Error? {
        //debugPrint("DSfile response:" , response)
        switch response.result {
        case .success(_):
            guard let json = response.data?.pp_JSONObject() else { return PPCloudServiceError.unknown }
            if let success = json["success"] as? Bool, success == true {
                return nil
            }
            else {
                json.printJSON()
                return PPCloudServiceError.unknown
            }
        case .failure(let error):
            return error
        }
    }
    
}
