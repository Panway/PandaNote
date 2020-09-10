//
//  PPFileObject.swift
//  PandaNote
//
//  Created by panwei on 2020/4/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
import FilesProvider

//class Person: Codable {
//}

struct PPFileObject:Equatable {
    var name: String
    var path: String//文件相对路径，比如`/我的坚果云/me.jpg`
    var size: Int64
    var isDirectory: Bool
    var modifiedDate: String
    ///遵循Equatable协议，判断两个对象是否相等
    static func ==(lhs: PPFileObject, rhs: PPFileObject) -> Bool {
        return lhs.name == rhs.name && lhs.path == rhs.path
    }
//    var favoriteColor: UIColor
}


extension PPFileObject: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case path
        case size
        case modifiedDate
        case isDirectory
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(Int64.self, forKey: .size)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        modifiedDate = try container.decode(String.self, forKey: .modifiedDate)
        path = try container.decode(String.self, forKey: .path)
        // 获取到原始数据
//        let colorData = try container.decode(Data.self, forKey: .favoriteColor)
        // 进行解码
//        favoriteColor = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? UIColor ?? UIColor.black
    }
        
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encode(size, forKey: .size)
        // 转化为 原始数据
//        let colorData = try NSKeyedArchiver.archivedData(withRootObject: favoriteColor, requiringSecureCoding: false)
        // 进行编码
//        try container.encode(colorData, forKey: .favoriteColor)
    }
    
    
}
//MARK: 测试代码
class PPPFileObject: NSObject {
    var name: String
    init(name: String) {
        self.name = name
    }
    //    func encode(with coder: NSCoder) {
    //        coder.encode(name, forKey: "name")
    //    }
    //    required convenience init(coder aDecoder: NSCoder) {
    //        let name = aDecoder.decodeObject(forKey: "name") as! String
    //        self.init(name: name)
    //    }
}
//MARK: extension 对象

//extension FileObject: Codable {
//    enum CodingKeys: String, CodingKey {
//        case name
//    }
//
//    public convenience init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        name = try container.decode(String.self, forKey: .name)
//        self.init(url: nil, name: "String", path: "String")
//
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(name, forKey: .name)
//    }
//}





//MARK:NSCoding
class PFileObject: FileObject, NSCoding {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(modifiedDate, forKey: "modifiedDate")
        coder.encode(size, forKey: "size")
        coder.encode(isDirectory, forKey: "isDirectory")
    }
//    public required convenience init?(coder : NSCoder) {
//        let name : String = coder.decodeObject(forKey: "name") as? String ?? ""
//        //        let modifiedDate = coder.decodeObject(forKey: "modifiedDate") as? Date ?? ""
//        //        self.size = coder.decodeInt64(forKey: "size") as? String ?? ""
//        //        self.isDirectory = coder.decodeBool(forKey: "isDirectory")
//        //        coder.encode(name, forKey: "name")
//        //        coder.encode(image, forKey: "image")
//        self.init(url: nil, name: name, path: "")
//    }
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
    //        super.init(url: nil, name: name, path: "")
    
    
}
