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
        pathID <- map["id"]
        downloadURL <- map["@microsoft.graph.downloadUrl"]

    }
}
