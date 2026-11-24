//
//  PPCloudService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//
public typealias PPCSCompletionhandler = (_ error:Error?) -> Void

import Foundation
import Alamofire
import UIKit // loadThumbnail 的签名用到 UIImage

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
    case serverUnreachable //服务器无法访问
    case certificateInvalid // 新的HTTPS证书过期（无效）情况
    case twoFactorAuthCodeError // 双重（两步）验证码错误
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

    /// 只取"可直接流式播放的直连地址 + 认证请求头"，不发起下载。
    /// 用于边播边缓存：播放器拿这个地址自己流式拉取。
    /// 返回 nil 表示该服务不支持直连流式（调用方回退到"先下载再播放"）。
    func streamRequest(path: String, fileID: String?) -> (url: String, headers: [String: String])?

    /// 取一张列表用的小缩略图。默认不支持（直接回 nil），需要的服务自己重写。
    /// 给没有缩略图直连地址的服务用（如 Dropbox）；有直连地址的服务填 PPFileModel.thumbnail 即可，不用实现这个。
    /// completion 在主线程回调。
    /// 注意：必须在 protocol 主体里声明成 requirement，只写在 extension 里的话，
    /// 通过协议类型调用会永远走默认实现，具体服务的实现被静默忽略（参考上面的 streamRequest）
    func loadThumbnail(path: String, fileID: String?, completion: @escaping (UIImage?) -> Void)

}

extension PPCloudServiceProtocol {

    /// 默认不支持直连流式播放，需要的服务自己重写
    func streamRequest(path: String, fileID: String?) -> (url: String, headers: [String: String])? {
        return nil
    }

    /// 默认不提供缩略图：不发任何请求，直接回 nil，调用方保持占位图标
    func loadThumbnail(path: String, fileID: String?, completion: @escaping (UIImage?) -> Void) {
        completion(nil)
    }

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

