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
    var access_token = ""

    /// 更新完token等信息后执行的回调。你可以保存新token等信息到本地或数据库（解耦）
    var configChanged : ((_ key:String,_ value:String) -> ())?
    
    var baseURL: String {
        return url
    }
    
    init(url: String, username: String, password: String, access_token: String) {
        self.url = url
        self.username = username
        self.password = password
        self.access_token = access_token
        super.init()
    }
    
    func headers() -> HTTPHeaders{
        return ["authorization": self.access_token]
    }
    
    func login(url:String, username:String, password:String) {
        let parameters: [String: String] = [
            "username": username,
            "password": password,
            "otp_code": ""
        ]
        AF.request(url + "/api/auth/login", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseDecodable(of: AlistResponse.self) { response in
            switch response.result {
            case .success(let res):
                // 使用解码后的对象
                debugPrint("alist response:",res)
                let t = res.data.token
                self.access_token = t
                self.configChanged?("PPAccessToken", t)
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
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseData { response in
            let jsonDic = response.data?.pp_JSONObject() as? [String : Any]
//            jsonDic?.printJSON()
            if let code = jsonDic?["code"] as? Int, code != 200 {
                debugPrint("alist get list error")
                completion([], PPCloudServiceError.unknown)
                //本来是要重新登录的，考虑到这个类只负责获取数据，就不搞其他的了
//                self.login(url: self.url, username: self.username, password: self.password)
                if code == 401 {
                    self.login(url: self.url, username: self.username, password: self.password)
                }
                return
            }

            guard let data = jsonDic?["data"] as? [String:Any],
                  let fileList = data["content"] as? [[String:Any]] else {
                return
            }
            completion(PPAlistFile.toModelArray(fileList, self.baseURL), nil)
        }
        if self.access_token.length == 0 {
            login(url: self.url, username: self.username, password: self.password)
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
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseData { response in
            let jsonDic = response.data?.pp_JSONObject() as? [String : Any]
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
        let requestURL = self.url + "/api/fs/mkdir"
        let parameters: [String: Any] = [
            "path": atPath + folderName
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseData { response in
            completion(self.getResponseError(response))
        }
    }
    
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        let requestURL = self.url + "/api/fs/put"
        let headers: HTTPHeaders = [
            "authorization": self.access_token,
            "file-path": path.pp_encodedURL()
        ]
        // 使用Alamofire发送PUT请求
        AF.upload(contents, to: requestURL, method: .put, headers:headers)
            .responseData { response in
                completion(nil, self.getResponseError(response))
            }
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {
        let filename = destPath.pp_split("/").last ?? ""
        
        let requestURL = self.url + "/api/fs/rename"
        let parameters: [String: Any] = [
            "path": srcPath,
            "name": filename, //支持一次删除多个文件，这里暂时没写
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseData { response in
            completion(self.getResponseError(response))
        }

    }
    
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
        let filename = path.pp_split("/").last ?? ""
        let dir = path.pp_split(filename).first ?? ""

        let requestURL = self.url + "/api/fs/remove"
        let parameters: [String: Any] = [
            "dir": dir,
            "names":[filename], //支持一次删除多个文件，这里暂时没写
        ]
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers()).responseData { response in
            completion(self.getResponseError(response))
        }
        
    }
    
    func getResponseError(_ response:AFDataResponse<Data>) -> Error? {
        switch response.result {
        case .success(_):
//            debugPrint("alist response: \(response)")
            guard let json = response.data?.pp_JSONObject() else { return PPCloudServiceError.unknown }
            if let message = json["message"] as? String,
               let code = json["code"] as? Int {
                if(message == "success") {
                    return nil
                }
                else if code == 403 {
                    return PPCloudServiceError.permissionDenied
                }
            }
        case .failure(let error):
            debugPrint("alist error: \(error)")
            return error
        }
        return PPCloudServiceError.unknown
    }
}
