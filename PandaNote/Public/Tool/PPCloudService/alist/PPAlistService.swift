//
//  PPAlistService.swift
//  PandaNote
//
//  Created by Panway on 2023/3/19.
//  Copyright © 2023 Panway. All rights reserved.
//



import Foundation
import Alamofire


class PPAlistService: NSObject, PPCloudServiceProtocol {

    var url = ""
    var username = ""
    var password = ""
    var access_token:String?
    var refresh_token:String?
    
    var baseURL: String {
        return url
    }
    
    init(url: String, username: String, password: String) {
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
        let serverList = PPUserInfo.shared.pp_serverInfoList
        let current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
        self.access_token = current["PPAccessToken"]
        if access_token == nil || access_token?.length == 0 {
            login(url: url, username: username, password: password)
        }
    }
    func headers () -> HTTPHeaders{
        return ["authorization": "\(self.access_token ?? "")"]
    }
    func login(url:String, username:String, password:String) {
        let parameters: [String: String] = [
            "username": username,
            "password": password,
            "otp_code": ""
        ]
        AF.request(url + "/api/auth/login", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseDecodable(of: AlistResponse.self) { response in
            let rr = response
            switch response.result {
            case .success(let res):
                // 使用解码后的对象
                debugPrint("alist response:",res)
                self.access_token = res.data.token
                self.updateToken()
            case .failure(let error):
                // 处理错误
                debugPrint("alist error:",error)
            }
        }
        /*
        .responseJSON { response in
            switch response.result {
            case .success(let value):
                print(value)
                debugPrint(response.value)
                let jsonDic = response.value as? [String : Any]
                jsonDic?.printJSON()
                let data = jsonDic?["data"] as? [String : Any]
                if let access_token = data?["token"] as? String {
                    debugPrint("alist token is:",access_token)
                    self.access_token = access_token
                    self.updateToken()
                }
            case .failure(let error):
                print(error)
            }
        }
        */
    }
    //MARK: ls file list 文件列表


    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        let requestURL = self.url + "/api/fs/list"
        let parameters: [String: Any] = [
            "path": path,
            "password":"",
            "page": 1,
            "per_page": 0,
            "refresh": false
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            jsonDic?.printJSON()
            if let code = jsonDic?["code"] as? Int, code != 200 {
                debugPrint("alist get list error")
                completion([], PPCloudServiceError.unknown)
                //本来是要重新登录的，考虑到这个类只负责获取数据，就不搞其他的了
//                self.login(url: self.url, username: self.username, password: self.password)
                return
            }

            
            guard let data = jsonDic?["data"] as? [String:Any],
                  let fileList = data["content"] as? [[String:Any]] else {
                return
            }
            completion(PPAlistFile.toModelArray(fileList), nil)
            
        }
        
    }
    
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        //let fileID = extraParams.fileID
        var requestURL = self.url + "/api/fs/get"
        var parameters: [String: Any] = [
            "path": path,
            "password":""
        ]
        if path.hasSuffix(".mp4") {
            parameters["method"] = "video_preview"
            requestURL = self.url + "/api/fs/other"
        }
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseJSON { response in
            let jsonDic = response.value as? [String : Any]
            jsonDic?.printJSON()
            if let code = jsonDic?["code"] as? Int, code != 200 {
                debugPrint("alist get file error")
                completion(nil, "", PPCloudServiceError.fileNotExist)
                return
            }
            if let data = jsonDic?["data"] as? [String:Any],
               let video_preview_play_info = data["video_preview_play_info"] as? [String:Any],
               let live_transcoding_task_list = video_preview_play_info["live_transcoding_task_list"] as? [[String:Any]] {
                var maxW = 0
                var urlHD = ""
                live_transcoding_task_list.forEach { e in
                    if let width = e["template_width"] as? Int64,
//                       let width = Int(template_width),
                       let murl = e["url"] as? String
                    {
                        if width > maxW {
                            maxW = Int(width)
                            urlHD = murl
                        }
                    }
                }
                completion(nil, urlHD, nil)
            }
            if let data = jsonDic?["data"] as? [String:Any],
               let raw_url = data["raw_url"] as? String {
                completion(nil, raw_url, nil)
            }
            
//            AF.request(raw_url).response { response in
//                completionHandler(response.data, nil)
//            }
        }
    }

    
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {

    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {

    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {

    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {

    }
    
    
}
