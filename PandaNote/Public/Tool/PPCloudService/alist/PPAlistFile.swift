//
//  PPAlistFile.swift
//  PandaNote
//
//  Created by Panway on 2023/3/19.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import ObjectMapper
struct AlistResponse: Decodable {
    let message: String
    let code: Int
    let data: AlistToken
}

struct AlistToken: Decodable {
    let token: String
}


class PPAlistFile: PPFileModel {


    public override func mapping(map: Map) {
        super.mapping(map: map)
        name <- map["name"]
        size <- map["size"]
        isDirectory <- map["is_dir"]
        
        modifiedDate <- map["modified"]
        // 2023-03-19T06:34:26.513Z
        // ISO 8601格式的时间戳，也称为UTC时间，字母T是日期和时间的分隔符，“Z”表示协调世界时（UTC）的标准时间
        modifiedDate = modifiedDate
            .replacingOccurrences(of: "T", with: " ")
        if modifiedDate.length > 19 {
            modifiedDate = String(modifiedDate.prefix(19))
        }
        
        thumbnail <- map["thumb"]


    }
    public class func toModelArray(_ fileList:[[String:Any]], _ baseURL:String) -> [PPAlistFile] {
        var dataSource = [PPAlistFile]()
        for f in fileList {
            if let item = PPAlistFile(JSON: f) {
                // 如果是第三方网盘直接就是http开头的略缩图URL
                if(item.thumbnail.length > 0 && !item.thumbnail.hasPrefix("http")) {
                    item.thumbnail = "\(baseURL)\(item.thumbnail)"
                }
                dataSource.append(item)
            }
        }
        return dataSource
    }
    public class func toModelArray(_ fileList:[[String:Any]]) -> [PPAlistFile] {
        if let modelsArray = Mapper<PPAlistFile>().mapArray(JSONObject: fileList) {
            return modelsArray
        }
        return []
    }
}
