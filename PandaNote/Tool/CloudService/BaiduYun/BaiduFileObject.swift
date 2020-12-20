//
//  BaiduFileObject.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/16.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import ObjectMapper
import FilesProvider

public final class BDFileObject: Mappable {
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
    var modifiedDate: Date?
//    var fileID = ""
    var fs_id = 0
    var downloadLink = ""
    
    public func mapping(map: Map) {
        name <- map["server_filename"]
        path <- map["path"]
        size <- map["size"]
        isDirectory <- map["isdir"]
        modifiedDate <- (map["server_ctime"], DateTransform())
        fs_id <- map["fs_id"]
        downloadLink <- map["dlink"]

    }

}











