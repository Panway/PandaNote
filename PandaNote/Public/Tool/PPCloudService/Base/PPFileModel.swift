//
//  PPFileModel.swift
//  PandaNote
//
//  Created by Panway on 2021/11/28.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import ObjectMapper

typealias PPFileObject = PPFileModel

public class PPFileModel:Mappable,Codable,Equatable {
    
    var name: String!
    //relative path. 文件相对路径，比如`/Documents/me.txt`
    var path: String = ""
    var downloadURL: String = ""
    var size: Int64 = 0
    var isDirectory = false
    var modifiedDate: String = ""
    ///百度网盘、OneDrive等的文件（文件夹）唯一ID标识
    var pathID = ""
//    var downloadURL:String?
    //当前属于哪个云服务的标识
    var serverID = ""
    
    
    ///遵循Equatable协议，判断两个对象是否相等
    public static func == (lhs: PPFileModel, rhs: PPFileModel) -> Bool {
        return lhs.name == rhs.name && lhs.path == rhs.path
    }

    public required init?(map: Map) {

    }

    public init() {
        
    }
    
    
    
    // Mappable
    public func mapping(map: Map) {
//        name <- map["name"]

    }
    
    // MARK: Encode & Decode
    enum CodingKeys: String, CodingKey {
        case name
        case path
        case downloadURL
        case size
        case modifiedDate
        case isDirectory
        case pathID
        case serverID
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        downloadURL = try container.decode(String.self, forKey: .downloadURL)
        size = try container.decode(Int64.self, forKey: .size)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        modifiedDate = try container.decode(String.self, forKey: .modifiedDate)
        pathID = try container.decode(String.self, forKey: .pathID)
        serverID = try container.decode(String.self, forKey: .serverID)
    }
        
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(downloadURL, forKey: .downloadURL)
        try container.encode(size, forKey: .size)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encode(pathID, forKey: .pathID)
        try container.encode(serverID, forKey: .serverID)
    }
}


