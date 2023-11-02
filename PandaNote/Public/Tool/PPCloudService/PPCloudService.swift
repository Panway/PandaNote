//
//  PPCloudService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//
public typealias PPCSCompletionhandler = (_ error:Error?) -> Void

import Foundation
///PPSwiftTips:  自定义错误
public enum PPCloudServiceError: Error {
    /// 未知错误
    case unknown
    /// 文件不存在错误
    case fileNotExist
    case permissionDenied
    case preCreateError
    case forcedLoginRequired
    case accessTokenExpired
    case certificateInvalid // 新的HTTPS证书过期（无效）情况
}
public enum PPCreateFileResult {
    case success([String:String])
    case failure(Error)
}

class PPCloudServiceParam {
    var fileID = ""
}


protocol PPCloudServiceProtocol {
    var baseURL: String { get }

    /// 获取文件列表
    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping(_ data: [PPFileObject], _ error: Error?) -> Void)
    
    /// 获取文件二进制数据
//    func contentsOfFile(_ path: String, completionHandler:@escaping(_ data:Data?,_ error:Error?) -> Void)
    func getFileData(_ path: String, _ extraParams:String, completion:@escaping(_ data:Data?, _ url:String, _ error:Error?) -> Void)

    /// 创建目录
    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion:@escaping(_ error: Error?) -> Void)
    
    /// 创建文件
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping(_ result: [String:String]?, _ error: Error?) -> Void)
    
    /// 移动文件
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping(_ error:Error?) -> Void)

    /// 删除文件
    func removeItem(_ path: String, _ fileID: String, completion: @escaping(_ error: Error?) -> Void)

}

extension PPCloudServiceProtocol {


}


//open class PPCloudService : NSObject {
//
//    func createDirectory(_ folderName: String, at atPath: String, completionHandler:@escaping(_ error:Error?) -> Void) {
//        try? FileManager.default.createDirectory(at: URL(string: "")!, withIntermediateDirectories: true, attributes: [:])
//    }
//}

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
