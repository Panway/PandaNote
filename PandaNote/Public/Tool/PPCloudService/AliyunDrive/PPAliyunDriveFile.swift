//
//  PPAliyunDriveFile.swift
//  PandaNote
//
//  Created by Panway on 2023/4/1.
//  Copyright © 2023 Panway. All rights reserved.
//

import UIKit
import ObjectMapper

class PPAliyunDriveFile: PPFileModel {
//    private var type = ""
    
    public override func mapping(map: Map) {
        super.mapping(map: map)
//        type <- map["type"]
//        isDirectory = type == "folder"
        
        // 使用Swift库ObjectMapper的时候，json对象的type等于字符串folder时isDirectory才是true，如何实现？
        isDirectory <- (map["type"],
                        TransformOf<Bool, String>(
                            fromJSON: { $0 == "folder" },
                            toJSON: { $0 == true ? "folder" : "file" }))
         

        
        name <- map["name"]
        size <- map["size"]
        pathID <- map["file_id"]
        modifiedDate <- map["updated_at"]
        // 2023-03-19T06:34:26.513Z
        // ISO 8601格式的时间戳，也称为UTC时间，字母T是日期和时间的分隔符，“Z”表示协调世界时（UTC）的标准时间
        modifiedDate = modifiedDate
            .replacingOccurrences(of: "T", with: " ")
        if modifiedDate.length > 19 {
            modifiedDate = String(modifiedDate.prefix(19))
        }
        
        thumbnail <- map["thumbnail"]
        downloadURL <- map["download_url"]

    }
    
    public class func toModelArray(_ fileList:[[String:Any]]) -> [PPAliyunDriveFile] {
        if let modelsArray = Mapper<PPAliyunDriveFile>().mapArray(JSONObject: fileList) {
            return modelsArray
        }
        return []
    }

}
