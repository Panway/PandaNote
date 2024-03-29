//
//  PPFileModel.swift
//  PandaNote
//
//  Created by Panway on 2021/11/28.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import ObjectMapper
import FilesProvider

typealias PPFileObject = PPFileModel

//public class PPFileModel:Mappable,Codable,Equatable {
public class PPFileModel:NSObject,Mappable,Codable {
    var name = ""
    //relative path. 文件相对路径，比如`/Documents/me.txt`
    var path = ""
    var downloadURL = ""
    var size: Int64 = 0
    var isDirectory = false
    var modifiedDate = ""
    var thumbnail = "" ///< 略缩图URL
    ///百度网盘、OneDrive等的文件（文件夹）唯一ID标识
    var pathID = ""
//    var downloadURL:String?
    //当前属于哪个云服务的标识
    var associatedServerID = "" ///< 所属服务器序号，仅本地用
    var associatedServerName = "" ///< 所属服务器备注，仅本地用
    var clickCount : Int64 = 0 ///< 用户点击次数，仅本地排序用
    var downloadProgress : Double = 0.0 ///< 下载进度，仅本地用
    var cellIndex = 0 ///< 列表显示时临时使用
    
    ///遵循Equatable协议，判断两个对象是否相等
    public static func == (lhs: PPFileModel, rhs: PPFileModel) -> Bool {
        return lhs.name == rhs.name && lhs.path == rhs.path
    }

    public required init?(map: Map) {

    }

    public override init() {
        
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
        case thumbnail
        case pathID
        case associatedServerID
        case associatedServerName
        case clickCount
        case downloadProgress
    }
    // JSONDecoder().decode() 时调用，将转换成Data类型的json文本转换成对象
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        downloadURL = try container.decode(String.self, forKey: .downloadURL)
        size = try container.decode(Int64.self, forKey: .size)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        modifiedDate = try container.decode(String.self, forKey: .modifiedDate)
        clickCount = try container.decodeIfPresent(Int64.self, forKey: .clickCount) ?? 0
        pathID = try container.decode(String.self, forKey: .pathID)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail) ?? ""
        associatedServerID = try container.decodeIfPresent(String.self, forKey: .associatedServerID) ?? ""
        associatedServerName = try container.decodeIfPresent(String.self, forKey: .associatedServerName) ?? ""
        // 在为PPFileModel新增加属性的时候，会导致之前的json文件不存在某个key，此时需要使用decodeIfPresent https://stackoverflow.com/a/66308592/4493393
        // 排查container.decode异常 https://stackoverflow.com/a/55391123/4493393
        downloadProgress = try container.decodeIfPresent(Double.self, forKey: .downloadProgress) ?? 0
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
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(associatedServerID, forKey: .associatedServerID)
        try container.encode(associatedServerName, forKey: .associatedServerName)
        try container.encode(clickCount, forKey: .clickCount)
        try container.encode(downloadProgress, forKey: .downloadProgress)
    }
    
    public override var description: String {
        return "[PPFileObject] name:\(self.name ) path:\(self.path)}"
    }
    
    
}


extension PPFileObject {
    //MARK: 数据处理 FileObject转PPFileObject
    /// FileObject Array to PPFileObject Array
    class func toPPFileObjects(_ contents:[FileObject]) -> [PPFileObject] {
        var fileArray = [PPFileObject]()
        var dirCount = 0
        //文件夹（目录）排在前面
        let directoryFirst = true
        for item in contents {
            let localDate = item.modifiedDate?.addingTimeInterval(TimeInterval(PPUserInfo.shared.pp_timezoneOffset))
            let dateStr = String(describing: localDate).substring(9..<25)
            let ppFile = PPFileObject()
            ppFile.name = item.name
            ppFile.path = item.path
            ppFile.size = item.size
            ppFile.isDirectory = item.isDirectory
            ppFile.modifiedDate = dateStr

            //添加到结果数组
            if item.isDirectory && directoryFirst {
                fileArray.insert(ppFile, at: dirCount)
                dirCount += 1
            }
            else {
                fileArray.append(ppFile)
            }
        }
        return fileArray
    }
}
