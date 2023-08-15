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
        


    }
    
    public class func toModelArray(_ fileList:[[String:Any]]) -> [PPSynologyFile] {
        if let modelsArray = Mapper<PPSynologyFile>().mapArray(JSONObject: fileList) {
            return modelsArray
        }
        return []
    }
}
