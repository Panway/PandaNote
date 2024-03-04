//
//  PPSynologyFile.swift
//  PandaNote
//
//  Created by Panway on 2023/8/16.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import ObjectMapper

class PPSynologyFile: PPFileModel {
    public override func mapping(map: Map) {
        super.mapping(map: map)
        name <- map["name"]
        isDirectory <- map["isdir"]
        path <- map["path"]


    }
    /* 文件响应数据示例：
     {
       "path" : "\/Baidu\/App",
       "additional" : {
         "type" : "",
         "size" : 40,
         "time" : {
           "ctime" : 1629907945,
           "atime" : 1692110003,
           "mtime" : 1604847363,
           "crtime" : 1604847212
         }
       },
       "isdir" : true,
       "name" : "App"
     }
     */
    public class func toModelArray(_ fileList:[[String:Any]],_ dateFormatter:DateFormatter,_ thumbBaseURL:String) -> [PPSynologyFile] {
        var dataSource = [PPSynologyFile]()
        for f in fileList {
            if let item = PPSynologyFile(JSON: f) {
                if let additional = f["additional"] as? [String: Any],
                   let size = additional["size"] as? Int64,
                   let time = additional["time"] as? [String: Any],
                   let mtime = time["mtime"] as? Int64{
                    item.size = size
                                        
                    let date = Date(timeIntervalSince1970: TimeInterval(mtime))
                    let dateString = dateFormatter.string(from: date)
                    item.modifiedDate = dateString
                }
                if item.path.length > 0 && item.path.pp_isImageFile() {
                    item.thumbnail = thumbBaseURL + "&path=%22\(item.path.pp_encodedURL)%22&size=small" //%22是`"`
                }

                
                dataSource.append(item)
            }
        }
        
        return dataSource
        
        
//        if let modelsArray = Mapper<PPSynologyFile>().mapArray(JSONObject: fileList) {
//            return modelsArray
//        }
//        return []
    }
}
