//
//  PPAlistFile.swift
//  PandaNote
//
//  Created by Panway on 2023/3/19.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import ObjectMapper

/// AList 所有接口的统一返回格式：{"code":200,"message":"success","data":{...}}
struct AlistResponse<T: Codable>: Codable {
    let message: String
    let code: Int
    /// 失败时服务端返回的 data 是 null，所以这里必须是可选，否则连报错文案都读不出来
    let data: T?
}

struct AlistToken: Codable {
    let token: String
}


class PPAlistFile: PPFileModel {


    public override func mapping(map: Map) {
        super.mapping(map: map)
        name <- map["name"]
        size <- map["size"]
        isDirectory <- map["is_dir"]
        
        modifiedDate <- map["modified"]
        // AList 的时间是 ISO8601 字符串，比如 "2023-03-19T06:34:26.513Z"（UTC）或 "2024-05-17T13:47:55+08:00"（自带时区），
        // 直接截断字符串的话，UTC 的时间会比北京时间慢 8 小时，所以这里统一转成本机时间再显示
        modifiedDate = PPAlistFile.localDateString(modifiedDate)
        
        thumbnail <- map["thumb"]


    }

    /// 把 ISO8601 时间转成本机时区的 "yyyy-MM-dd HH:mm:ss"，实在转不了就退回原来的截断方式
    private class func localDateString(_ raw: String) -> String {
        // ISO8601DateFormatter 的默认格式不认小数秒（.513 这种），先去掉再解析
        let noFraction = raw.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: noFraction) {
            return date.toString()
        }
        var fallback = raw.replacingOccurrences(of: "T", with: " ")
        if fallback.length > 19 {
            fallback = String(fallback.prefix(19))
        }
        return fallback
    }

    public class func toModelArray(_ fileList:[[String:Any]], _ baseURL:String) -> [PPAlistFile] {
        var dataSource = [PPAlistFile]()
        for f in fileList {
            if let item = PPAlistFile(JSON: f) {
                // 如果是第三方网盘直接就是http开头的略缩图URL
                if(item.thumbnail.length > 0 && !item.thumbnail.hasPrefix("http")) {
                    // 缩略图地址是 "/p/xxx" 这种相对路径，拼上服务器地址才能显示；两边都有斜杠时不要拼出 "//"
                    let separator = item.thumbnail.hasPrefix("/") ? "" : "/"
                    item.thumbnail = "\(baseURL)\(separator)\(item.thumbnail)"
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
