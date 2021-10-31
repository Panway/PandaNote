//
//  PPOneDriveFileObject.swift
//  PandaNote
//
//  Created by WeirdPan on 2021/10/31.
//  Copyright © 2021 WeirdPan. All rights reserved.
//

import UIKit

import ObjectMapper

public final class PPOneDriveFileObject: Mappable {
    public init?(map: Map) {
        
    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    var name = ""
    //文件相对路径，比如`/我的坚果云/me.jpg`
    var path = ""
    var size : Int64 = 0
    var isDirectory = false
    var modifiedDate: String?
//    var fileID = ""
    var fs_id = ""
    var downloadLink = ""
    var folder : [String:Any]?
    
    public func mapping(map: Map) {
        name <- map["name"]
        path <- map["id"]
        size <- map["size"]
        folder <- map["folder"]
        modifiedDate <- map["lastModifiedDateTime"]
        fs_id <- map["id"]
        downloadLink <- map["@microsoft.graph.downloadUrl"]

    }

}











