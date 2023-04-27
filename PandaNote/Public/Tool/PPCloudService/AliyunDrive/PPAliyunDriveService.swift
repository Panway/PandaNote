//
//  PPAliyunDriveService.swift
//  PandaNote
//
//  Created by Panway on 2023/4/1.
//  Copyright © 2023 Panway. All rights reserved.
//
/*
 阿里云盘开放平台文档：https://www.yuque.com/aliyundrive/zpfszx/zqkqp6
 说明：由于减少代码量，目前创建文件所需的parent_file_id由获取列表时缓存，可能带来未知错误
 参数check_name_mode：
    ignore：允许同名文件；默认为 ignore
    auto_rename：当发现同名文件时，云端自动重命名，默认为追加当前时间点，如 xxx_20060102_150405；
    refuse：当云端存在同名文件时，拒绝创建新文件，返回客户端已存在同名文件的详细信息。
 文档1：https://next.api.aliyun.com/document/pds/2022-03-01/CreateFile
 http://apsara-doc.oss-cn-hangzhou.aliyuncs.com/apsara-pdf/enterprise/v_3_14_0_20210519/pds/zh/development-guide.pdf
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
    var retryCount = 0
    var deleteFileWithSameName = true ///< 阿里云盘同级目录允许存在多个同样名字的文件，在编辑文本时新增完删除旧的同名文件
    var currentDirFiles = [PPFileObject]()
    var currentDirID = ""
    //更新完token等信息通知后使用的地方保存到本地
    var configChanged : ((_ key:String,_ value:String) -> ())?
    
    var baseURL: String {
        return url
    }
    
    init(access_token: String, refresh_token: String, drive_id: String) {
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.drive_id = drive_id
        super.init()
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
            self.configChanged?("drive_id", default_drive_id)
            // 调用回调函数
            callback?(default_drive_id)
        }
    }
    //初次登录时调用，使用`code`获取`access_token`和`refresh_token`
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
            debugPrint("aliyundrive getToken for the first time")
            jsonDic.printJSON()
            if let refresh_token = jsonDic["refresh_token"] as? String,
               let access_token = jsonDic["access_token"] as? String {
                callback?(access_token,refresh_token)
            }
        }
    }
    
    func refreshToken(callback:((String,String) -> Void)? = nil) {
        let requestURL = self.url + "/oauth/access_token"
        let parameters: [String: Any] = [
            "client_id":client_id,
            "refresh_token": refresh_token,
            "client_secret":client_secret,
            "grant_type":"refresh_token"
        ]
        debugPrint("aliyundrive refreshToken param:",parameters)
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("aliyundrive refreshToken finished")
            jsonDic.printJSON()
            if let refresh_token = jsonDic["refresh_token"] as? String,
               let access_token = jsonDic["access_token"] as? String {
                self.access_token = access_token
                self.refresh_token = refresh_token
                self.configChanged?("PPAccessToken", self.access_token)
                self.configChanged?("PPRefreshToken", self.refresh_token)
                callback?(access_token, refresh_token)
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

    //MARK: 文件列表 file list
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        if drive_id.length == 0 {
            getUserInfo(callback: { driveID in
                if driveID.length == 0 {
                    completion([],PPCloudServiceError.unknown)
                    // self.refreshToken()
                } else {
                    if self.retryCount < 4 {
                        self.retryCount += 1 //自动刷新、防止死循环
                        self.contentsOfDirectory(path, pathID, completion: completion)
                    }
                }
            })
            return
        }
        currentDirID = pathID
        //我：将下面的curl命令换成Swift的请求库Alamofire实现。 ChatGPT：
        let requestURL = self.url + "/adrive/v1.0/openFile/list"
        parent_file_id = path == "/" ? "root" : pathID
        let parameters: [String: Any] = [
            "drive_id": drive_id, //必填
            "parent_file_id": parent_file_id, //必填
//            "marker": "",
            "fields": "*", // 当填 * 时，返回文件所有字段；
            "order_direction": "DESC",
            "order_by": "updated_at",
            "limit":100, //返回文件数量，默认 50，最大 100
            "type": "all"
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            jsonDic.printJSON(true)
            
            if let code = jsonDic["code"] as? String
//               let message = jsonDic["message"] as? String
            {
                if code == "ForbiddenDriveNotValid" { //message == "not valid driveId"{
                    self.drive_id = "" //出错了就重置，以便刷新token
                    self.getUserInfo()
                }
                if code == "A403JE" || code == "AccessTokenInvalid" || code == "AccessTokenExpired" {
                    debugPrint("token过期 token expired")
                    self.refreshToken { a, r in
                        if self.retryCount < 3 {
                            self.retryCount += 1 //自动刷新、防止死循环
                            self.contentsOfDirectory(path, pathID, completion: completion)
                        }
                    }

                }
                debugPrint("aliyundrive get list error")
                completion([], PPCloudServiceError.fileNotExist)
                return
            }

            
            guard let items = jsonDic["items"] as? [[String:Any]] else { return }
            let files = PPAliyunDriveFile.toModelArray(items)
            if self.deleteFileWithSameName {
                self.currentDirFiles = files
            }
            completion(files, nil)

        }
        
    }
    
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        //let fileID = extraParams.fileID
    }
    //MARK: 新建文件夹
    func createDirectory(_ folderName: String, _ atPath: String, completion:@escaping(_ error: Error?) -> Void) {
        let requestURL = self.url + "/adrive/v1.0/openFile/create"
        let parameters: [String: Any] = [
            "parent_file_id": parent_file_id,
            "check_name_mode": "ignore",//auto_rename参数会创建filename(1).md、filename(2).md
            "name": folderName,
            "type": "folder",
            "drive_id": drive_id
        ]

        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("createDirectory")
            jsonDic.printJSON()
            completion(response.error)


        }
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
    
    //MARK: 新建文件
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        let requestURL = self.url + "/adrive/v1.0/openFile/create";        let filename = path.pp_split("/").last ?? ""
        let parameters: [String: Any] = [
            "parent_file_id": parent_file_id,
            "check_name_mode": "ignore",//auto_rename参数会创建filename(1).md、filename(2).md
            "name": filename,
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
                    completion(nil, error)
                    return
                }
                // 3.完成
                self.completeUpload(file_id,upload_id) { err in
                    completion(["fileID":file_id], err)
                    if self.deleteFileWithSameName {
                        let result = self.currentDirFiles.filter { $0.name == filename }
                        if result.count > 0 {
                            let sameNameFile = result[result.count - 1] //删除最旧的一个
                            debugPrint("删除同名文件",sameNameFile)
                            self.removeItem("", sameNameFile.pathID) { error in
                                self.contentsOfDirectory("", self.currentDirID) { files, error in
                                    self.currentDirFiles = files
                                }
                            }
                        }
                    }
                }
                debugPrint(response)
            }

        }
    }
    
    
    
    //MARK: 移动/重命名
    /// 移动或重命名
    /// - Parameters:
    ///   - srcPath: 源路径（获取文件名及判断是否是重命名时用）
    ///   - destPath: 目标路径（获取文件名及判断是否是重命名时用）
    ///   - srcItemID: 移动文件时`file_id`对应的值
    ///   - destItemID: 重命名时`file_id`对应的值，移动文件时父目录对应的值
    ///   - completion: 完成回调
    func moveItem(srcPath: String,
                  destPath: String,
                  srcItemID: String,
                  destItemID: String,
                  isRename: Bool,
                  completion:@escaping(_ error:Error?) -> Void) {
        var requestURL = ""
        var parameters: [String: Any] = [:]
        let filename = destPath.pp_split("/").last ?? ""
        //如果是从 "/App/aaa.md" 移动到 "/App/bbb.md"，发送重命名请求
        
        if isRename == true || srcPath.replacingOccurrences(of: filename, with: "") ==
            destPath.replacingOccurrences(of: filename, with: "") {
            requestURL = self.url + "/adrive/v1.0/openFile/update"
            parameters = [
                "drive_id": drive_id,
                "file_id": srcItemID,
                "name": filename
            ]
        }
        else {
            requestURL = self.url + "/adrive/v1.0/openFile/move"
            parameters = [
                "to_parent_file_id": destItemID,
                "check_name_mode": "ignore",
                "file_id": srcItemID,
                "drive_id": drive_id
            ]
        }
        parameters.printJSON()
        
        AF.request(requestURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: getHeaders()).responseJSON { response in
            // 处理响应
            guard let jsonDic = response.value as? [String : Any] else { return }
            debugPrint("moveItem")
            jsonDic.printJSON()
            switch response.result {
            case .success(let value):
                debugPrint("moveItem success",value)
                completion(nil)
            case .failure(let error):
                debugPrint("moveItem fail",error)
                completion(error)
            }
            
        }
    }
    
    
    //MARK: 删除
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
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
            completion(response.error)
        }
        
    }
    
}
