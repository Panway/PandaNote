//
//  BaiduyunAPITool.swift
//  PandaNote
//
//  Created by panway on 2020/12/16.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import FilesProvider
import Alamofire
import ObjectMapper

//兼容FilesProvider的类
open class BaiduyunAPITool: NSObject {

    var access_token : String = ""
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
            guard let jsonDic = response.value as? [String : Any] else {
                return
            }
            let errorNo = (jsonDic["errno"] as? NSNumber)?.intValue
            var dataSource = [PPFileObject]()
            //有错误
            if errorNo != 0 {
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
            completionHandler(dataSource,false, nil)
            
        }
    }
    
    
    //MARK:获取文件
    ///获取文件
    func contents(path: String, fs_id:String, completionHandler: @escaping ((_ contents: Data?, _ isFromCache:Bool, _ error: Error?) -> Void)) -> Void {
        let reqURL = "https://pan.baidu.com/rest/2.0/xpan/multimedia"
        let parameters = ["access_token": access_token,
                          "dlink": "1",
                          "extra": "1",
                          "fsids": "["+fs_id+"]",
                          "method": "filemetas"]

        AF.request(reqURL, parameters: parameters,headers: headers).responseJSON { response in
            guard let jsonDic = response.value as? [String : Any] else {
                return
            }
            let errorNo = (jsonDic["errno"] as? NSNumber)?.intValue
            //如果有错误
            if errorNo != 0 {
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
                }
                break//只处理第一个
            }

        }
        
    }
    
    
    
}




