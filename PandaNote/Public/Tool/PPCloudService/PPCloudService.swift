//
//  PPCloudService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//
public typealias PPCSCompletionhandler = (_ error:Error?) -> Void
//public typealias SimpleCompletionHandler = ((_ error: Error?) -> Void)?

import Foundation
//import FilesProvider

protocol PPCloudServiceProtocol {
    var baseURL: String { get }

    /// 获取文件列表
    func contentsOfDirectory(_ path: String, completionHandler:@escaping(_ data:[PPFileObject],_ error:Error?) -> Void)
    
    /// 获取文件列表（可选）
    func contentsOfPathID(_ pathID: String, completionHandler:@escaping(_ data:[PPFileObject],_ error:Error?) -> Void)
    
    /// 获取文件二进制数据
    func contentsOfFile(_ path: String, completionHandler:@escaping(_ data:Data?,_ error:Error?) -> Void)

    /// 创建目录
    func createDirectory(_ folderName: String, at atPath: String, completionHandler:@escaping(_ error:Error?) -> Void)
    
    /// 创建文件
    func createFile(atPath path: String, contents: Data, completionHandler:@escaping(_ error:Error?) -> Void)
    
    /// 移动文件
    func moveItem(atPath srcPath: String, toPath dstPath: String, completionHandler:@escaping(_ error:Error?) -> Void)
    
    /// 删除文件
    func removeItem(atPath path: String, completionHandler:@escaping(_ error:Error?) -> Void)

}



open class PPCloudService : NSObject {
    
    func createDirectory(_ folderName: String, at atPath: String, completionHandler:@escaping(_ error:Error?) -> Void) {
        try? FileManager.default.createDirectory(at: URL(string: "")!, withIntermediateDirectories: true, attributes: [:])
    }
}

extension Dictionary {
    func printJSON(_ shouldPrint:Bool = true) {
        if shouldPrint == false {
            return
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) {
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}
