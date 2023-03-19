//
//  BaiduFileObject.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/16.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import ObjectMapper

public final class BDFileObject: PPFileModel {
    required init?(map: Map) {
        super.init(map: map)
    }
    
    //2021.11
    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    var server_ctime: Date?
//    var fileID = ""
    var fs_id = 0
    var downloadLink = ""
    
    public override func mapping(map: Map) {
        name <- map["server_filename"]
        path <- map["path"]
        size <- map["size"]
        isDirectory <- map["isdir"]
        server_ctime <- (map["server_ctime"], DateTransform())
        fs_id <- map["fs_id"]
        downloadLink <- map["dlink"]
    }

}











