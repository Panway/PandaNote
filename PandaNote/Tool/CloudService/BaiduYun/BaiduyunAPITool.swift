//
//  BaiduyunAPITool.swift
//  PandaNote
//
//  Created by panway on 2020/12/16.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import Alamofire


///PPSwiftTips: 错误的处理
public enum PPCloudServiceError: Error {
    /// 未知错误
    case unknown
    /// 文件不存在错误
    case fileNotExist
    case preCreateError
}
struct HTTPBinResponse: Decodable { let url: String; let request_id:String }

//兼容FilesProvider的类
open class BaiduyunAPITool: NSObject {

    var access_token : String = ""
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
    
    //MARK:获取文件列表
    ///获取文件列表
    func getFileList(path: String, completionHandler:@escaping(_ data:[PPFileObject],_ isFromCache:Bool,_ error:Error?) -> Void) {
        let parameters = ["access_token": access_token,
                          "desc": "1",
                          "dir": path.length>0 ? path : "/",
                          "limit": "200",
                          "method": "list",
                          "order": "time",
                          "start": "0"]
        
        AF.request(baiduURL, parameters: parameters,headers: headers).responseJSON { response in
            let result = self.hanldeResponse(response.value as? [String : Any])
            let jsonDic = result.responseJSONDic
            //有错误
            if result.errorNum != 0 {
                PPHUD.showHUDFromTop("百度云错误", isError: true)
                completionHandler([],false, CocoaError(.fileNoSuchFile,
                                                       userInfo: [NSLocalizedDescriptionKey: "Base URL is not set."]))
                return
            }
            //如果list没数据
            guard let list = jsonDic["list"] as? Array<Dictionary<String, Any>> else {
                completionHandler([],false, nil)
                return
            }
            debugPrint("百度网盘获取文件数量：\(list.count)")
            //如果list有数据，可以拿去显示了
            var dataSource = [PPFileObject]()
            for baiduFile in list {
                if let item = BDFileObject(JSON: baiduFile) {
                    let ppFile = PPFileObject(name: item.name,
                                              path: item.path,
                                              size: item.size,
                                              isDirectory: item.isDirectory,
                                              modifiedDate: item.modifiedDate?.pp_stringFromDate() ?? "",
                                              fileID: "\(item.fs_id)",
                                              serverID: "")
                    dataSource.append(ppFile)
                }
                
            }
            do {
                let encoded = try JSONEncoder().encode(dataSource)
                let archieveKey = "baidu_" + "\(self.baiduURL)\(path)".pp_md5
                PPDiskCache.shared.setData(encoded, key: archieveKey)
            } catch {
                debugPrint(error.localizedDescription)
            }
            completionHandler(dataSource,false, nil)
            
        }
    }
    
    
    //MARK:获取文件
    ///获取文件
    func contents(path: String,
                  fs_id:String,
                  downloadIfCached:Bool?=false,
                  completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) -> Void {
        if let shouldDownload = downloadIfCached, shouldDownload == false {
            //从本地缓存获取数据
//            let archieveKey = "baidu_" + "\(path)"
            PPDiskCache.shared.fetchData(key: path, failure: { (error) in
                if error != nil {
                    self.contents(path: path, fs_id: fs_id,downloadIfCached: true, completionHandler: completionHandler)
//                    if (error as NSError).code != NSFileReadNoSuchFileError {
//                    }
                }
            }) { (data) in
                completionHandler(data,true,nil)
            }
            return
        }

        let reqURL = "https://pan.baidu.com/rest/2.0/xpan/multimedia"
        let parameters = ["access_token": access_token,
                          "dlink": "1",
                          "extra": "1",
                          "fsids": "["+fs_id+"]",
                          "method": "filemetas"]

        AF.request(reqURL, parameters: parameters,headers: headers).responseJSON { response in
            let result = self.hanldeResponse(response.value as? [String : Any])
            let jsonDic = result.responseJSONDic
            //如果有错误
            if result.errorNum != 0 {
                PPHUD.showHUDFromTop("百度云错误", isError: true)
                completionHandler(nil,false, nil)
                return
            }
            //如果list没数据
            guard let list = jsonDic["list"] as? [[String:Any]] else {
                completionHandler(nil,false, nil)
                return
            }
            for baiduFile in list {
                let model = BDFileObject(JSON: baiduFile )
                AF.request(model?.downloadLink ?? "", parameters: parameters).response { response in
                    completionHandler(response.data,true, nil)
//                    let archieveKey = "baidu_" + "\(path)"
                    PPDiskCache.shared.setData(response.data, key: path)

                }
                break//只处理第一个
            }

        }
        
    }
    ///创建文件夹
    ///POST /rest/2.0/xpan/file?access_token=666666&method=create
    ///isdir=1&path=/2021/NewFolder/0322&rtype=1&size=0
    func createFolder(path: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        let parameters: [String: String] = [
            "isdir": "1",
            "path": path,
            "rtype": "1",
            "size": "0"
        ]
        let url = baiduURL + "?access_token=\(access_token)&method=create"
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseJSON { response in
            let handle = self.hanldeResponse(response.value as? [String : Any])
            completionHandler(handle.error)
        }
    }
    /// precreate文件，上传文件前的操作，md5字母小写
    func precreateFile(dir: String, md5:String, size:String, fileName:String, completionHandler:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?access_token=\(access_token)&method=precreate"
        let parameters: [String: Any] = [
            "autoinit": "1",
            "isdir":"0",
            "path":"\(dir)\(fileName)",
            "rtype": "1",
            "size": size,
            "block_list": "[\"" + md5 + "\"]"
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseJSON { response in
            let handle = self.hanldeResponse(response.value as? [String : Any])
            completionHandler(handle.error, handle.responseJSONDic)
        }
    }
    /// 创建文件
    func createFile(path: String, md5:String, size:String, uploadid:String, completionHandler:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?access_token=\(access_token)&method=create"
        let parameters: [String: String] = [
            "block_list":"[\"\(md5)\"]",
            "isdir": "0",
            "path": path,
            "rtype": "1",
            "size": size,
            "uploadid":uploadid
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseJSON { response in
            let handle = self.hanldeResponse(response.value as? [String : Any])
            completionHandler(handle.error, handle.responseJSONDic)
        }
    }
    /// 移动文件
    func moveFile(pathOld: String, pathNew: String, newName:String, completionHandler:@escaping(_ error:Error?,_ responseJSON:[String : Any]) -> Void) {
        let url = baiduURL + "?access_token=\(access_token)&method=filemanager&opera=move"
        let parameters: [String: Any] = [
            "async":"0",
            "filelist": "[{\"path\":\"\(pathOld)\",\"dest\":\"\(pathNew)\",\"newname\":\"\(newName)\",\"ondup\":\"newcopy\"}]"
//            "filelist": [["path":pathOld,"newname":newName,"ondup":"newcopy"]]
        ]
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseJSON { response in
            let handle = self.hanldeResponse(response.value as? [String : Any])
            completionHandler(handle.error, handle.responseJSONDic)
        }
    }
    ///删除百度云文件（夹）
    ///POST /rest/2.0/xpan/file?access_token=666666&method=filemanager&opera=delete
    ///async=0&filelist=%5B%22%5C/2021%5C/Useless%5C/old.html%22%5D
    func delete(path: [String], completionHandler:@escaping(_ error:Error?) -> Void) {
        //注意！ES文件浏览器里面把path数组里的字符串对象的斜杠`/`的转义成`\/`，这里没转义也可以
        let parameters: [String: Any] = [
            "async": "0",
            "filelist": "[\"" + path.joined(separator: "\",\"") + "\"]"
        ]
        let url = baiduURL + "?access_token=\(access_token)&&method=filemanager&opera=delete"
        //let enc = URLEncoding(arrayEncoding: .noBrackets)
        AF.request(url, method: .post, parameters: parameters, headers: headers).responseJSON { response in
            let handle = self.hanldeResponse(response.value as? [String : Any])
            completionHandler(handle.error)
        }
    }
    
    //上传文件
    func upload(path: String,data:Data,completionHandler:@escaping(_ error:Error?) -> Void) {
        let fileName = String(path.split(separator: "/").last ?? "new_upload_file")
        let dirNew = path.replacingOccurrences(of: fileName, with: "")
        let fileSize = String(data.count)
        // Step1 预创建
        precreateFile(dir: "/apps/ES文件浏览器/", md5: data.pp_md5().uppercased(), size: fileSize, fileName: fileName) { (error, responseJSON) in
            if let _ = error {
                completionHandler(PPCloudServiceError.preCreateError)//precreate错误
                return
            }
            guard let uploadid = responseJSON["uploadid"] as? String else {
                return
            }
            let tmpPath = "/apps/ES文件浏览器/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
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
            .responseJSON { response in
                guard let jsonDic = response.value as? [String : Any],let md5_r = jsonDic["md5"] as? String else {
                    return
                }
                // Step3 创建
                self.createFile(path: "/apps/ES文件浏览器/\(fileName)", md5: md5_r, size: fileSize, uploadid: uploadid) { (error, responseJSON) in
                    //Step4 移动
                    self.moveFile(pathOld: "/apps/ES文件浏览器/\(fileName)", pathNew: dirNew, newName: fileName) { (error, responseJSON) in
                        completionHandler(error)
                    }
                }
            }

        }
        

        
        
    }
    func hanldeResponse(_ responseJSON:[String : Any]?) -> (responseJSONDic:[String : Any],errorNum:Int,error:Error?) {
        guard let jsonDic = responseJSON else {
            return ([:], -1, PPCloudServiceError.unknown)
        }
        var errorNo = 0
        if let no = (jsonDic["errno"] as? NSNumber)?.intValue {
            errorNo = no
        }
        // let nsError = NSError(domain:"", code:2, userInfo:nil)
        //有错误
        return (jsonDic,errorNo, errorNo == 0 ? nil : PPCloudServiceError.unknown)
    }
}




