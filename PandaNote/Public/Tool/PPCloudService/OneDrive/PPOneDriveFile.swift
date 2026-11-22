//
//  PPOneDriveFile.swift
//  PandaNote
//
//  Created by Panway on 2021/11/28.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import ObjectMapper

class PPOneDriveFile:PPFileModel {
    var folder : [String:Any]?

    public override func mapping(map: Map) {
        super.mapping(map: map)
        name <- map["name"]
        pathID <- map["id"]
        size <- map["size"]
        folder <- map["folder"]
        modifiedDate <- map["lastModifiedDateTime"]
        // Graph 给的是 UTC 时间（2021-11-28T09:12:35Z），直接显示会比北京时间慢 8 小时，先转成本机时区
        modifiedDate = PPOneDriveFile.localDateString(modifiedDate)
        // 必须显式写 nested: false。ObjectMapper 的下标默认把 "." 当层级分隔符，
        // 不写的话 "@microsoft.graph.downloadUrl" 会被拆成 ["@microsoft"]["graph"]["downloadUrl"] 去查，
        // 而 Graph 返回的是扁平 key，永远查不到，downloadURL 一直是空字符串
        downloadURL <- map["@microsoft.graph.downloadUrl", nested: false]
    }

    /// 把 ISO8601 时间转成本机时区的 "yyyy-MM-dd HH:mm:ss"，实在转不了就退回「换空格、截 19 位」的老办法
    private class func localDateString(_ raw: String) -> String {
        // ISO8601DateFormatter 的默认格式不认小数秒（.123 这种），先去掉再解析
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
}
