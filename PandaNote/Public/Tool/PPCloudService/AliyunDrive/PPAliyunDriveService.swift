//
//  PPAliyunDriveService.swift
//  PandaNote
//
//  Created by Panway on 2023/4/1.
//  Copyright © 2023 Panway. All rights reserved.
//
/*
 说明：由于减少代码量，目前创建文件所需的parent_file_id由获取列表时缓存，可能带来未知错误
 */
import UIKit
import Alamofire

let aliyundrive_auth_url = "https://open.aliyundrive.com/o/oauth/authorize?client_id=4ef89a333545446db34c60c090b72b7f&redirect_uri=https://testcallback.aliyundrive.com&scope=user:base,user:phone,file:all:read,file:all:write"
let aliyundrive_callback_domain = "testcallback.aliyundrive.com"

class PPAliyunDriveService: NSObject, PPCloudServiceProtocol {
    var url = "https://openapi.aliyundrive.com"
    var client_id = "4ef89a333545446db34c60c090b72b7f" //ES
    var client_secret = "48b8170e32c1487394017fa712323830" //ES
    var access_token:String
    var refresh_token = ""
    var drive_id = ""
    var parent_file_id = ""
    var baseURL: String {
        return url
    }
    
    init(access_token: String, refresh_token: String) {
        self.access_token = access_token
        super.init()
    }
    
    func updateSetting(key:String, value:String) {
        //更新
        var serverList = PPUserInfo.shared.pp_serverInfoList
        var current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
        current[key] = value
        serverList[PPUserInfo.shared.pp_lastSeverInfoIndex] = current
        PPUserInfo.shared.pp_serverInfoList = serverList
    }
    
    func getSetting(_ key:String) -> String {
        let serverList = PPUserInfo.shared.pp_serverInfoList
        let current = serverList[PPUserInfo.shared.pp_lastSeverInfoIndex]
        if let value = current[key] {
            return value
        }
        return ""
    }

    func getUserInfo(callback:((String) -> Void)? = nil) {
        let requestURL = self.url + "/adrive/v1.0/user/getDriveInfo"
        if(drive_id.length > 0) { return }

        AF.request(requestURL, method: .post, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("getUserInfo")
            jsonDic.printJSON()
            guard let default_drive_id = jsonDic["default_drive_id"] as? String  else {
                callback?("")
                return
            }
            self.drive_id = default_drive_id
            self.updateSetting(key: "drive_id", value: default_drive_id)
            // 调用回调函数
            callback?(default_drive_id)
        }
    }
    
    public class func getToken(code:String, callback:((String,String) -> Void)? = nil) {
        let requestURL = "https://openapi.aliyundrive.com/oauth/access_token"
        let parameters: [String: Any] = [
            "client_id":"4ef89a333545446db34c60c090b72b7f",
            "client_secret":"48b8170e32c1487394017fa712323830",
            "code":code,
            "grant_type":"authorization_code"
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("====authorization_code====")
            jsonDic.printJSON()
            if let refresh_token = jsonDic["refresh_token"] as? String,
               let access_token = jsonDic["access_token"] as? String {
                callback?(access_token,refresh_token)
            }
        }
    }
    
    func refreshToken() {
        let requestURL = self.url + "/oauth/access_token"
        let parameters: [String: Any] = [
            "client_id":client_id,
            "refresh_token":getSetting("PPRefreshToken"),
            "client_secret":client_secret,
            "grant_type":"refresh_token"
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("====refreshToken====")
            jsonDic.printJSON()
            if let refresh_token = jsonDic["refresh_token"] as? String,
               let access_token = jsonDic["access_token"] as? String {
                self.access_token = access_token
                self.refresh_token = refresh_token
                self.updateSetting(key: "PPAccessToken", value: self.access_token)
                self.updateSetting(key: "PPRefreshToken", value: self.refresh_token)
            }
        }
    }
    
    
    
    func getHeaders() -> HTTPHeaders{
        var headers: HTTPHeaders = [
            "User-Agent": "ESFileExplorer/2.3.2 (iPhone; iOS 16.3; Scale/3.00)",
        ]
        if (access_token.length > 0) {
            headers["authorization"] = "Bearer \(self.access_token)"
        }
        return headers
    }
    
    func contentsOfDirectory(_ path: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        if drive_id.length == 0 {
            getUserInfo(callback: { driveID in
                if driveID.length == 0 {
                    completionHandler([],CocoaError(.fileNoSuchFile,
                                                    userInfo: [NSLocalizedDescriptionKey: "unknown"]))
                    self.refreshToken()
                } else {
                    self.contentsOfPathID(path, completionHandler: completionHandler)
                }
            })
        }
        else {
            contentsOfPathID(path, completionHandler: completionHandler)
        }
    }

    //MARK: ls file list 文件列表
    func contentsOfPathID(_ pathID: String, completionHandler: @escaping ([PPFileObject], Error?) -> Void) {
        //我：将下面的curl命令换成Swift的请求库Alamofire实现。 ChatGPT：
        let requestURL = self.url + "/adrive/v1.0/openFile/list"
        parent_file_id = pathID == "/" ? "root" : pathID
        let parameters: [String: Any] = [
            "marker": "",
            "drive_id": drive_id,
            "fields": "*",
            "order_direction": "DESC",
            "order_by": "updated_at",
            "parent_file_id": parent_file_id,
            "type": "all"
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            jsonDic.printJSON(true)
            
            //"A403JE" is token expired
            if let code = jsonDic["code"] as? String, code == "A403JE" {
                debugPrint("aliyundrive get list error")
                self.drive_id = "" //出错了就重置，以便刷新token
                completionHandler([], CocoaError(.fileNoSuchFile,
                                                  userInfo: [NSLocalizedDescriptionKey: "unknown"]))
                return
            }

            
            guard let fileList = jsonDic["items"] as? [[String:Any]] else { return }
            completionHandler(PPAliyunDriveFile.toModelArray(fileList), nil)

        }
        
    }
    
    func contentsOfFile(_ path: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        
    }
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler: @escaping (Error?) -> Void) {

    }
    
    func completeUpload(_ file_id:String, _ upload_id:String, callback:((Error?) -> Void)? = nil) {
        let requestURL = self.url + "/adrive/v1.0/openFile/complete"
        let parameters: [String: Any] = [
            "drive_id":drive_id,
            "file_id":file_id,
            "upload_id":upload_id
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("complete")
            jsonDic.printJSON()
            switch response.result {
            case .success(let value):
                debugPrint("complete2",value)
                callback?(nil)
            case .failure(let error):
                callback?(error)
            }
            
        }
    }
    
    func createFile(atPath path: String, contents: Data, completionHandler: @escaping (Error?) -> Void) {
        let requestURL = self.url + "/adrive/v1.0/openFile/create"
        let parameters: [String: Any] = [
            "parent_file_id": parent_file_id,
            "check_name_mode": "ignore",
            "name": path.split(string: "/").last ?? "",
            "type": "file",
            "drive_id": drive_id
        ]
        // 1. create
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("openFile/create")
            jsonDic.printJSON()
            guard let file_id = jsonDic["file_id"] as? String,
                  let upload_id = jsonDic["upload_id"] as? String,
                  let part_info_list = jsonDic["part_info_list"] as? [[String:Any]],
                  let upload_url = part_info_list[0]["upload_url"] as? String else { return }
            // 2. 上传
            // https://github.com/Alamofire/Alamofire/issues/2811#issuecomment-490370829
            let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: [200, 204, 205]) // Default is [204, 205]
            AF.upload(contents, to: upload_url, method: .put).response(responseSerializer: dataResponseSerializer) { response in
                //.responseData { response in
                if let error = response.error {
                    completionHandler(error)
                    return
                }
                // 3.完成
                self.completeUpload(file_id,upload_id) { res in
                    completionHandler(res)
                }
                debugPrint(response)
            }

        }
    }
    
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler: @escaping (Error?) -> Void) {
        
    }
    
    func removeItem(atPath path: String, completionHandler: @escaping (Error?) -> Void) {
    }
    
    func removeItemByID(_ fileID: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        let requestURL = self.url + "/adrive/v1.0/openFile/recyclebin/trash"
        let parameters: [String: Any] = [
            "drive_id": drive_id,
            "file_id": fileID
        ]
        
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("removeItem")
            jsonDic.printJSON()
            completionHandler(response.error)
        }
        
    }
    
}
