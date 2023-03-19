//
//  PPAlistService.swift
//  PandaNote
//
//  Created by Panway on 2023/3/19.
//  Copyright © 2023 Panway. All rights reserved.
//



import Foundation
import Alamofire
import ObjectMapper


class PPAlistService: PPFilesProvider, PPCloudServiceProtocol {
    
    var url = ""
    var username = ""
    var password = ""
    var access_token:String?
    var refresh_token:String?
    
    var baseURL: String {
        return url
    }
    
    init(url: String, username: String, password: String) {
//        let userCredential = URLCredential(user: "anonymous",
//                                           password: access_token,
//                                           persistence: .forSession)
        self.url = url
        self.username = username
        self.password = password
        super.init()
//        login(url: url, username: username, password: password)
        self.getToken()

    }
    
    func updateToken() {
        //更新
        var serverList = PPUserInfo.shared.pp_serverInfoList
        var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
        current["PPAccessToken"] = access_token
        serverList.remove(at: PPUserInfo.shared.pp_lastSeverInfoIndex)
        serverList.insert(current, at: PPUserInfo.shared.pp_lastSeverInfoIndex)
        PPUserInfo.shared.pp_serverInfoList = serverList
    }
    
    func getToken() {
        var serverList = PPUserInfo.shared.pp_serverInfoList
        var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
        self.access_token = current["PPAccessToken"]
    }
    func login(url:String, username:String, password:String) {
        let parameters: [String: String] = [
            "username": username,
            "password": password,
            "otp_code": ""
        ]
        AF.request(url + "/api/auth/login", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
            switch response.result {
            case .success(let value):
                print(value)
                debugPrint(response.value)
                let jsonDic = response.value as? [String : Any]
                jsonDic?.printJSON()
                let data = jsonDic?["data"] as? [String : Any]
                //                    let access_token = jsonDic["access_token"] as? String
                //            guard let data = jsonDic?["data"] else { return }
                if let access_token = data?["token"] as? String {
                    debugPrint("alist token is:",access_token)
                    self.access_token = access_token
                    self.updateToken()
                }
            case .failure(let error):
                print(error)
            }
            
//                let userCredential = URLCredential(user: "anonymous",
//                                                   password: access_token,
//                                                   persistence: .forSession)
//                self.refresh_token = refresh_token
//                self.access_token = access_token
////                self.onedrive = OneDriveFileProvider(credential: userCredential)
//                print("=====refresh_token=====\n\(refresh_token)")
//                print("=====access_token=====\n\(access_token)")
//
//
//                //更新
//                var serverList = PPUserInfo.shared.pp_serverInfoList
//                var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
//                current["PPWebDAVPassword"] = access_token
//                current["PPCloudServiceExtra"] = refresh_token
//                #warning("todo")
//                serverList.remove(at: PPUserInfo.shared.pp_lastSeverInfoIndex)
//                serverList.insert(current, at: PPUserInfo.shared.pp_lastSeverInfoIndex)
//                PPUserInfo.shared.pp_serverInfoList = serverList

                
                
                
            
            
            
        }
    }
    func getNewToken() {
        let parameters: [String: String] = [
            "client_id": onedrive_client_id_es,
            "redirect_uri": onedrive_redirect_uri_es,
            "refresh_token": self.refresh_token ?? "",
            "grant_type": "refresh_token"
        ]
//        debugPrint("getNewToken==\(parameters)")
        let url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
//        AF.request(url, method: .post, parameters: parameters).responseJSON { response in
//            debugPrint(response.value)
//            let jsonDic = response.value as? [String : Any]
////                    let access_token = jsonDic["access_token"] as? String
//            if let access_token = jsonDic?["access_token"] as? String,let refresh_token = jsonDic?["refresh_token"] as? String {
//                debugPrint("microsoft access_token is:",access_token)
//                let userCredential = URLCredential(user: "anonymous",
//                                                   password: access_token,
//                                                   persistence: .forSession)
//                self.refresh_token = refresh_token
//                self.access_token = access_token
////                self.onedrive = OneDriveFileProvider(credential: userCredential)
//                print("=====refresh_token=====\n\(refresh_token)")
//                print("=====access_token=====\n\(access_token)")
//
//
//                //更新
//                var serverList = PPUserInfo.shared.pp_serverInfoList
//                var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
//                current["PPWebDAVPassword"] = access_token
//                current["PPCloudServiceExtra"] = refresh_token
////                        current["PPCloudServiceExtra"] =
//                #warning("todo")
////                        self.refresh_token = current["PPCloudServiceExtra"]!
//                serverList.remove(at: PPUserInfo.shared.pp_lastSeverInfoIndex)
//                serverList.insert(current, at: PPUserInfo.shared.pp_lastSeverInfoIndex)
//                PPUserInfo.shared.pp_serverInfoList = serverList
//
//
//
//
//            }
//
//
//        }
    }
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        contentsOfPathID(path, completionHandler: completionHandler)
    }

    func contentsOfPathID(_ pathID: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        let requestURL = self.url + "/api/fs/list"
        let headers: HTTPHeaders = [
            "authorization": "\(self.access_token ?? "")"
        ]
        let parameters: [String: Any] = [
            "path": pathID,
            "password":"",
            "page": 1,
            "per_page": 0,
            "refresh": false
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            jsonDic?.printJSON()
            if let code = jsonDic?["code"] as? Int, code == 400 {
                debugPrint("alist get list error")
                completionHandler([], CocoaError(.fileNoSuchFile,
                                                  userInfo: [NSLocalizedDescriptionKey: "unknown"]))
                //重新登录
//                self.login(url: self.url, username: self.username, password: self.password)
                return
            }

            
            guard let data = jsonDic?["data"] as? [String:Any],
                  let fileList = data["content"] as? [[String:Any]] else {
                return
            }
            
            if let modelsArray = Mapper<PPAlistFile>().mapArray(JSONObject: fileList) {
                DispatchQueue.main.async {
                    completionHandler(modelsArray,nil)
                }
            }
            
        }
        
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        let requestURL = self.url + "/api/fs/get"
        let headers: HTTPHeaders = [
            "authorization": "\(self.access_token ?? "")"
        ]
        let parameters: [String: Any] = [
            "path": path,
            "password":""
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            jsonDic?.printJSON()
            if let code = jsonDic?["code"] as? Int, code == 400 {
                debugPrint("alist get file error")
                completionHandler(nil, CocoaError(.fileNoSuchFile,
                                                  userInfo: [NSLocalizedDescriptionKey: "fileNotFound"]))
                return
            }
            guard let data = jsonDic?["data"] as? [String:Any],
                  let raw_url = data["raw_url"] as? String else {
                return
            }
            
            AF.request(raw_url).response { response in
                completionHandler(response.data, nil)
            }
        }
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {

    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {

    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {

    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {

    }
    
    
}
