//
//  BaiduyunAPITool.swift
//  PandaNote
//
//  Created by Panway on 2020/12/16.
//  Copyright © 2020 Panway. All rights reserved.
//  官方文档：https://pan.baidu.com/union/doc/al0rwqzzl
//  重要说明：个人app没有上传权限！！！

import Foundation
import Alamofire

fileprivate let app_name = "ES文件浏览器"
fileprivate let client_id = "4CXtrIz7T0yEYsLC8majw1ff42Uh64Yw" //我的
fileprivate let redirect_uri = "pandanote://baiduwangpan" //我的
//let baiduwangpan_auth_url = "https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=\(client_id)&redirect_uri=\(redirect_uri)&scope=basic,netdisk&display=mobile&state=pandanotestate&qrcode=1&qrcodeH=320&qrcodeW=320"
//ES文件浏览器：
let baiduwangpan_auth_url = "https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=NqOMXF6XGhGRIGemsQ9nG0Na&redirect_uri=http://www.estrongs.com&scope=basic,netdisk&display=mobile&state=STATE&force_login=1&qrcode=1&qrcodeW=320&qrcodeH=320"
//FE文件管理器
//let baiduwangpan_auth_url = "https://openapi.baidu.com/oauth/2.0/authorize?response_type=code&client_id=b6QUc7beo6dxyq0jsYgYva6M&redirect_uri=http%3A%2F%2Fwww.skyjos.cn%2Foauth_redirect&scope=basic,netdisk&display=mobile&qrcode=1&force_login=1&qrloginfrom=pc"

//兼容FilesProvider的类
open class BaiduyunAPITool: NSObject, PPCloudServiceProtocol {
    var baseURL: String {
        return baiduURL
    }
    var access_token = ""
    let host = "https://pan.baidu.com"
    let path = "/rest/2.0/xpan/file"
    let baiduURL = "https://pan.baidu.com/rest/2.0/xpan/file"
    let headers: HTTPHeaders = [
        "User-Agent": "pan.baidu.com"
    ]
    public init(access_token: String) {
        self.access_token = access_token
        super.init()
    }
    public required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: 获取文件列表
    ///获取文件列表
    func getFileList(path: String, completion:@escaping(_ data:[PPFileModel],_ isFromCache:Bool,_ error:Error?) -> Void) {
        let parameters = ["access_token": access_token,
                          "desc": "1",
                          "dir": path.length>0 ? path : "/",
                          "limit": "200",
                          "method": "list",
                          "order": "time",
                          "start": "0"]
        
        AF.request(baiduURL, parameters: parameters,headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            let jsonDic = result.responseJSONDic
//            jsonDic.printJSON()
            //有错误
            if result.errorNum != 0 {
                if (result.errorNum == -6) {
                    debugPrint("百度网盘身份验证失败，需要强制登录")
                    completion([],false, PPCloudServiceError.forcedLoginRequired)
                    return
                }
                completion([],false, PPCloudServiceError.unknown)
                return
            }
            //如果list没数据
            guard let list = jsonDic["list"] as? Array<Dictionary<String, Any>> else {
                completion([],false, nil)
                return
            }
            debugPrint("百度网盘获取文件数量：\(list.count)")
            //如果list有数据，可以拿去显示了
            var dataSource = [PPFileModel]()
            for baiduFile in list {
                if let item = BDFileObject(JSON: baiduFile) {
                    item.modifiedDate = item.server_ctime?.pp_stringFromDate() ?? ""
                    item.pathID = "\(item.fs_id)"
                    /*
                    let ppFile = PPFileObject(name: item.name,
                                              path: item.path,
                                              size: item.size,
                                              isDirectory: item.isDirectory,
                                              modifiedDate: item.modifiedDate?.pp_stringFromDate() ?? "",
                                              fileID: "\(item.fs_id)",
                                              serverID: "")
                     */
                    dataSource.append(item)
                }
                
            }
            do {
                let encoded = try JSONEncoder().encode(dataSource)
                let archieveKey = "baidu_" + "\(self.baiduURL)\(path)".pp_md5
                PPDiskCache.shared.setData(encoded, key: archieveKey)
            } catch {
                debugPrint(error.localizedDescription)
            }
            completion(dataSource,false, nil)
            
        }
    }
    
    
    //MARK: 获取文件Data
    ///获取文件
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void) {
        let fileID = extraParams
        let reqURL = "https://pan.baidu.com/rest/2.0/xpan/multimedia"
        let parameters = [
            "method": "filemetas",
            "dlink": "1",
            "extra": "1",
            "fsids": "["+fileID+"]",
            "access_token": access_token
        ]

        AF.request(reqURL, parameters: parameters,headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            let jsonDic = result.responseJSONDic
            // jsonDic.printJSON()

            //如果有错误
            if result.errorNum != 0 {
                PPHUD.showHUDFromTop("百度云错误", isError: true)
                completion(nil,"", PPCloudServiceError.fileNotExist)
                return
            }
            //如果list没数据
            guard let list = jsonDic["list"] as? [[String:Any]] else {
                completion(nil,"", PPCloudServiceError.fileNotExist)
                return
            }
            for baiduFile in list {
                let model = BDFileObject(JSON: baiduFile )
                if let dlink = model?.downloadLink {
                    completion(nil, "\(dlink)&access_token=\(self.access_token)", nil)
                }
//                AF.request(model?.downloadLink ?? "", parameters: parameters).response { response in
//                }
                break//只处理第一个
            }

        }
        
    }
    ///创建文件夹
    ///POST /rest/2.0/xpan/file?access_token=666666&method=create
    ///isdir=1&path=/2021/NewFolder/0322&rtype=1&size=0
    func createFolder(path: String, completion:@escaping(_ error:Error?) -> Void) {
        let parameters: [String: String] = [
            "isdir": "1",
            "path": path,
            "rtype": "1",
            "size": "0"
        ]
        let url = baiduURL + "?access_token=\(access_token)&method=create"
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            completion(result.error)
        }
    }
    /// precreate文件，上传文件前的操作，md5字母小写
    func precreateFile(dir: String, md5:String, size:String, fileName:String, completion:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?method=precreate&access_token=\(access_token)"
        let parameters: [String: Any] = [
            "autoinit": "1",
            "isdir":"0",
            "path":"\(dir)\(fileName)",
            "rtype": "1", //文件命名策略。1 表示当path冲突时，进行重命名。2 表示当path冲突且block_list不同时，进行重命名。3 当云端存在同名文件时，对该文件进行覆盖
            "size": size,
            "block_list": "[\"" + md5 + "\"]"
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            completion(result.error, result.responseJSONDic)
        }
    }
    /// 创建文件
    func createFile(path: String, md5:String, size:String, uploadid:String, completion:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?method=create&access_token=\(access_token)"
        let parameters: [String: String] = [
            "block_list":"[\"\(md5)\"]",
            "isdir": "0",
            "path": path,
            "rtype": "1",
            "size": size,
            "uploadid":uploadid
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            completion(result.error, result.responseJSONDic)
        }
    }
    /// 移动文件
    func moveFile(pathOld: String, pathNew: String, newName:String, completion:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?method=filemanager&opera=move&access_token=\(access_token)"
        //fail（默认：冲突时失败）overwrite（冲突时覆盖） newcopy（冲突时重命名）
//        let ondup = "newcopy"
        let parameters: [String: Any] = [
            "async": "0",
//            "ondup": ondup,
            "filelist": "[{\"path\":\"\(pathOld)\",\"dest\":\"\(pathNew)\",\"newname\":\"\(newName)\",\"ondup\":\"newcopy\"}]"
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            completion(result.error, result.responseJSONDic)
        }
    }
    
    //上传文件
    func upload(path: String,data:Data,completion:@escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        let fileName = String(path.split(separator: "/").last ?? "new_upload_file")
        let dirNew = path.replacingOccurrences(of: fileName, with: "")
        let fileSize = String(data.count)
        // Step1 预创建
        precreateFile(dir: "/apps/\(app_name)/", md5: data.pp_md5().uppercased(), size: fileSize, fileName: fileName) { (error, responseJSON) in
            if let _ = error {
                completion(nil, PPCloudServiceError.preCreateError)//precreate错误
                return
            }
            guard let uploadid = responseJSON["uploadid"] as? String else {
                return
            }
            let tmpPath = "/apps/\(app_name)/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
            let uploadid_encode = uploadid.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed) ?? uploadid
            let url = "https://d.pcs.baidu.com/rest/2.0/pcs/superfile2?access_token=\(self.access_token)&method=upload&partseq=0&path=\(tmpPath)&type=tmpfile&uploadid=\(uploadid_encode)"
            debugPrint(url)
            // Step2 上传
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(data, withName: "file",fileName: fileName)
                //连同表单file一起的附加参数（可选）
                // for (key, value) in parameters {multipartFormData.append((value as AnyObject).data(using: String.Encoding.utf8.rawValue)!, withName: key)}
            },
            to:url, headers: self.headers)
            .responseData { response in
                guard let json = response.data?.pp_JSONObject() else { return }
                debugPrint("=========",json,response)
                guard let md5_r = json["md5"] as? String else {
                    completion(nil, PPCloudServiceError.permissionDenied)
                    return
                }
                // Step3 创建
                self.createFile(path: "/apps/\(app_name)/\(fileName)", md5: md5_r, size: fileSize, uploadid: uploadid) { (error, responseJSON) in
                    //Step4 移动
                    self.moveFile(pathOld: "/apps/\(app_name)/\(fileName)", pathNew: dirNew, newName: fileName) { (error, responseJSON) in
                        completion(nil, error)
                    }
                }
            }

        }
        

        
        
    }
    func hanldeResponse(_ response:AFDataResponse<Data>) -> (responseJSONDic:[String : Any],errorNum:Int,error:Error?) {
        guard let jsonDic = response.data?.pp_JSONObject() else { return ([:], -1, PPCloudServiceError.unknown) }
        var errorNo = 0
        if let no = (jsonDic["errno"] as? NSNumber)?.intValue {
            errorNo = no
        }
        // let nsError = NSError(domain:"", code:2, userInfo:nil)
        //有错误
        return (jsonDic,errorNo, errorNo == 0 ? nil : PPCloudServiceError.unknown)
    }
    
    //MARK:PPCloudServiceProtocol
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void) {
        self.getFileList(path: path) { fileList, isCache, error in
            completion(fileList,error)
        }
    }

    
    
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        self.createFolder(path: folderName, completion: completion)
    }
    
    /// 单步上传（适合2GB以下的文件）
    func upload_singlestep(path: String,data:Data, completion:@escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        let fileName = String(path.split(separator: "/").last ?? "new_upload_file")
        let tmpPath = "/apps/\(app_name)/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
        let dirNew = path.replacingOccurrences(of: fileName, with: "")

        let url = "https://d.pcs.baidu.com/rest/2.0/pcs/file?method=upload&access_token=\(self.access_token)&path=\(tmpPath)&ondup=overwrite"
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(data, withName: "file",fileName: fileName)
        },
        to:url, headers: self.headers)
        .responseData { response in
            guard let json = response.data?.pp_JSONObject() else { return }
//            debugPrint("baidu upload:",json)
            if let error_code = json["error_code"] as? Int,
                  error_code == 4 || error_code == 31064 {
                completion(nil, PPCloudServiceError.permissionDenied)
                return
            }
            // 删除当前目录的文件A，再把临时目录的件A移动过来
            self.removeItem(path, "") { error in
                if error != nil {
                    completion(nil, error)
                    return
                }
                self.moveFile(pathOld: "/apps/\(app_name)/\(fileName)", pathNew: dirNew, newName: fileName) { (error, responseJSON) in
                    completion(nil, error)
                }
            }
            
        }
    }
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void) {
        upload_singlestep(path: path, data: contents, completion: completion)
    }
    
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void) {
        let fileName = String(destPath.split(separator: "/").last ?? "new_file")
        let dirNew = destPath.replacingOccurrences(of: fileName, with: "")
        self.moveFile(pathOld: srcPath, pathNew: dirNew, newName: fileName, completion: { (error, _) in
            completion(error)
        })
    }
    ///删除 POST /rest/2.0/xpan/file?access_token=666666&method=filemanager&opera=delete
    ///async=0&filelist=%5B%22%5C/2021%5C/Useless%5C/old.html%22%5D
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void) {
        //注意！ES文件浏览器里面把path数组里的字符串对象的斜杠`/`的转义成`\/`，这里没转义也可以
        let parameters: [String: Any] = [
            "async": "0",
            "filelist": "[\"\([path].joined(separator: "\",\""))\"]"
        ]
        let url = baiduURL + "?access_token=\(access_token)&&method=filemanager&opera=delete"
        //let enc = URLEncoding(arrayEncoding: .noBrackets)
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseData { response in
            let result = self.hanldeResponse(response)
            completion(result.error)
        }
    }
}




