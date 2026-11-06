//
//  PPAlistService.swift
//  PandaNote
//
//  Created by Panway on 2023/3/19.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import Alamofire

/// AList 云盘的接口封装，接口文档见 https://alistgo.com/zh/guide/api/
class PPAlistService: NSObject, PPCloudServiceProtocol {

    var url = ""
    var username = ""
    var password = ""
    var access_token = ""

    /// 更新完token等信息后执行的回调。你可以保存新token等信息到本地或数据库（解耦）
    var configChanged : ((_ key:String,_ value:String) -> ())?

    /// 和群晖那边一样统一用 PPCloudHTTP 发请求；超时给 60 秒，留够上传笔记的时间
    private let httpClient = PPCloudHTTP.configure(timeout: 60)

    /// 自动重新登录的次数，用完就停手，避免「请求失败 → 重新登录 → 还是失败」无限转圈
    private var retryCount = 0
    private let maxRetryCount = 2

    /// 这些后缀的文件先去问 AList 有没有转码播放地址，拿不到再退回原始直链
    private let videoExtensions: Set<String> = ["mp4", "mov", "mkv", "avi", "flv", "wmv", "webm", "m4v", "ts", "rmvb"]

    var baseURL: String {
        return url
    }

    init(url: String, username: String, password: String, access_token: String) {
        // 用户填的地址可能带结尾斜杠，留着的话拼出来就是 http://host//api/fs/list，有的服务端会直接 404，所以先削掉
        var fixedURL = url
        while fixedURL.hasSuffix("/") {
            fixedURL.removeLast()
        }
        self.url = fixedURL
        self.username = username
        self.password = password
        self.access_token = access_token
        super.init()
    }

    // MARK: - 登录

    /// 用账号密码换一个 token。AList 的 token 有效期默认 48 小时，过期后接口统一返回 code 401
    func login(url:String, username:String, password:String, completion:((_ error: Error?) -> Void)? = nil) {
        let parameters: [String: Any] = [
            "username": username,
            "password": password,
            "otp_code": ""
        ]
        httpClient.postJSON(url: url + "/api/auth/login", parameters: parameters, responseType: AlistResponse<AlistToken>.self) { response in
            guard let res = response.data else {
                // 连不上、超时、返回的不是约定的 JSON，都走这里
                debugPrint("alist 登录请求失败：\(String(describing: response.error))")
                completion?(PPCloudServiceError.from(httpError: response.error))
                return
            }
            guard res.code == 200, let token = res.data?.token, token.isEmpty == false else {
                // 账号密码不对时 AList 返回 400 和 "username or password is incorrect"；402 表示这个账号开了两步验证
                debugPrint("alist 登录失败：\(res.code) \(res.message)")
                let loginError: PPCloudServiceError = (res.code == 402) ? .twoFactorAuthCodeError : .permissionDenied
                completion?(loginError)
                return
            }
            self.access_token = token
            self.configChanged?("PPAccessToken", token)
            completion?(nil)
        }
    }

    /// 保证手上有一个 token，没有就用账号密码登录一次
    private func ensureToken(_ completion: @escaping (Error?) -> Void) {
        if access_token.isEmpty == false {
            completion(nil)
            return
        }
        login(url: url, username: username, password: password, completion: completion)
    }

    // MARK: - 请求封装

    /// 带 token 的请求头。没登录的时候不要带空的 Authorization，不然 AList 会把请求当游客直接顶回 401
    private func authHeaders() -> PPHTTPHeaders? {
        if access_token.isEmpty {
            return nil
        }
        return ["Authorization": access_token]
    }

    /// 拼接「目录 + 文件名」，顺带处理结尾斜杠，避免拼出 "//" 这种路径
    private func join(_ directory: String, _ name: String) -> String {
        if directory.isEmpty {
            return "/" + name
        }
        if directory.hasSuffix("/") {
            return directory + name
        }
        return directory + "/" + name
    }

    /// AList 用 code 表示业务错误：401 没登录或 token 过期，403 没权限，404 文件不存在。
    /// 另外它遇到「文件或目录不存在」时会返回 500 + "object not found"，这里也一起翻译成文件不存在
    private func error(from code: Int, message: String = "") -> PPCloudServiceError {
        if message.contains("not found") {
            return .fileNotExist
        }
        switch code {
        case 401: return .accessTokenExpired
        case 402: return .twoFactorAuthCodeError
        case 403: return .permissionDenied
        case 404: return .fileNotExist
        default: return .unknown
        }
    }

    /// 所有返回 JSON 的接口都走这里：没登录就先登录，token 过期自动重新登录再来一次，最后把解析好的 JSON 交给调用方
    /// - Parameters:
    ///   - apiPath: 接口路径，比如 "/api/fs/list"
    ///   - parameters: 请求体参数
    ///   - completion: json 是服务端原样返回的字典（含 code、message、data），error 非空时 json 里通常还有服务端的报错文案
    private func requestJSON(_ apiPath: String,
                             parameters: [String: Any],
                             completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void) {
        ensureToken { tokenError in
            if let tokenError = tokenError {
                completion(nil, tokenError)
                return
            }
            self.httpClient.post(url: self.url + apiPath, parameters: parameters, headers: self.authHeaders()) { response in
                // HTTP 层就失败了（连不上、超时、证书有问题），body 里没有 AList 的业务错误码可读
                if let httpError = response.error, response.data == nil {
                    completion(nil, PPCloudServiceError.from(httpError: httpError))
                    return
                }
                guard let json = response.data?.pp_JSONObject() as? [String: Any] else {
                    // 返回的不是 JSON（比如 502 的 HTML 错误页、空 body），退回按 HTTP 层错误翻译
                    completion(nil, PPCloudServiceError.from(httpError: response.error))
                    return
                }
                let code = json["code"] as? Int ?? -1
                if code == 401, self.retryCount < self.maxRetryCount {
                    // token 失效了（改密码、服务端重启、超过 48 小时都会这样）：清掉旧 token 重新登录，然后再请求一次
                    self.retryCount += 1
                    self.access_token = ""
                    self.configChanged?("PPAccessToken", "")
                    self.requestJSON(apiPath, parameters: parameters, completion: completion)
                    return
                }
                if code != 200 {
                    let message = json["message"] as? String ?? ""
                    debugPrint("alist \(apiPath) 返回错误：\(code) \(message)")
                    completion(json, self.error(from: code, message: message))
                    return
                }
                // 请求成功就把失败计数清零，不然累计跑满几次以后就再也不会自动重新登录了
                self.retryCount = 0
                completion(json, nil)
            }
        }
    }

    // MARK: - 文件列表

    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping (_ data: [PPFileObject], _ error: Error?) -> Void) {
        let parameters: [String: Any] = [
            "path": path,
            "password": "",
            "page": 1,
            // per_page 超过 500 会被服务端截成 500，传 0 则用默认值 200；这里一次要满，暂时不做翻页
            "per_page": 500,
            "refresh": false
        ]
        requestJSON("/api/fs/list", parameters: parameters) { json, error in
            if let error = error {
                completion([], error)
                return
            }
            // 空文件夹时 AList 返回的 content 是 null 而不是空数组，所以要兜一个默认值，否则这里直接返回会让界面一直转圈
            let data = json?["data"] as? [String: Any]
            let fileList = data?["content"] as? [[String: Any]] ?? []
            completion(PPAlistFile.toModelArray(fileList, self.baseURL), nil)
        }
    }

    // MARK: - 文件内容

    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (_ data: Data?, _ url: String, _ error: Error?) -> Void) {
        let ext = (path as NSString).pathExtension.lowercased()
        if videoExtensions.contains(ext) {
            // 视频先问 AList 要转码播放地址（网盘类存储才有），本地存储会直接回 500 not implement，那就走下面的原始直链
            let parameters: [String: Any] = ["path": path, "password": "", "method": "video_preview"]
            requestJSON("/api/fs/other", parameters: parameters) { json, error in
                if error == nil,
                   let data = json?["data"] as? [String: Any],
                   let preview = data["video_preview_play_info"] as? [String: Any],
                   let tasks = preview["live_transcoding_task_list"] as? [[String: Any]],
                   let bestURL = self.bestQualityURL(tasks) {
                    completion(nil, bestURL, nil)
                    return
                }
                self.fetchRawURL(path, completion: completion)
            }
            return
        }
        fetchRawURL(path, completion: completion)
    }

    /// 从转码列表里挑分辨率最高的一路
    private func bestQualityURL(_ tasks: [[String: Any]]) -> String? {
        var bestWidth = -1
        var bestURL: String?
        for task in tasks {
            guard let taskURL = task["url"] as? String, taskURL.isEmpty == false else { continue }
            let width = (task["template_width"] as? NSNumber)?.intValue ?? 0
            if width > bestWidth {
                bestWidth = width
                bestURL = taskURL
            }
        }
        return bestURL
    }

    /// 拿文件的原始直链，App 拿到地址后自己去下载
    private func fetchRawURL(_ path: String, completion: @escaping (_ data: Data?, _ url: String, _ error: Error?) -> Void) {
        let parameters: [String: Any] = ["path": path, "password": ""]
        requestJSON("/api/fs/get", parameters: parameters) { json, error in
            if let error = error {
                completion(nil, "", error)
                return
            }
            guard let data = json?["data"] as? [String: Any],
                  let rawURL = data["raw_url"] as? String,
                  rawURL.isEmpty == false else {
                // 目录不会返回 raw_url，这里也必须回调一次，否则调用方会一直等下去
                completion(nil, "", PPCloudServiceError.fileNotExist)
                return
            }
            completion(nil, rawURL, nil)
        }
    }

    // MARK: - 新建

    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        // atPath 一般是 "/alist/notes" 这种结尾没有斜杠的目录，直接拼会变成 "/alist/notes202501"，所以要先补斜杠
        let parameters: [String: Any] = ["path": join(atPath, folderName)]
        requestJSON("/api/fs/mkdir", parameters: parameters) { _, error in
            completion(error)
        }
    }

    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping (_ result: [String:String]?, _ error: Error?) -> Void) {
        // 上传不是 JSON 接口，是把文件内容直接 PUT 上去，所以走 PPCloudHTTP 的上传方法
        ensureToken { tokenError in
            if let tokenError = tokenError {
                completion(nil, tokenError)
                return
            }
            let headers: PPHTTPHeaders = [
                "Authorization": self.access_token,
                // AList 要求把完整路径做 URL 编码后放进 file-path 头，它自己会解码
                "File-Path": self.encodeFilePath(path),
                "Content-Type": "application/octet-stream"
            ]
            self.httpClient.upload(data: contents, to: self.url + "/api/fs/put", method: .put, headers: headers) { response in
                completion(nil, self.getResponseError(response))
            }
        }
    }

    /// 路径编码：只保留字母、数字和 - . _ ~，其余（空格、中文、+、/ 等）全部转成 %XX。
    /// 不能用 .urlQueryAllowed，它不转义 "+"，而 AList 是用 QueryUnescape 解码的，文件名叫 "a+b.md" 会被还原成 "a b.md"
    private func encodeFilePath(_ path: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    // MARK: - 移动 / 重命名 / 删除

    /// 移动或重命名文件（夹）
    /// 注意：AList 的 rename 只能改名字，不能换目录（实测把 path 写成别的目录，文件还是留在原地），换目录必须用 move 接口
    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (_ error:Error?) -> Void) {
        let srcName = (srcPath as NSString).lastPathComponent
        let destName = (destPath as NSString).lastPathComponent
        let srcDir = (srcPath as NSString).deletingLastPathComponent
        let destDir = (destPath as NSString).deletingLastPathComponent

        if isRename {
            let parameters: [String: Any] = ["path": srcPath, "name": destName]
            requestJSON("/api/fs/rename", parameters: parameters) { _, error in
                completion(error)
            }
            return
        }

        // 先移动到目标目录，如果名字也一起改了，移动完再补一次重命名
        let parameters: [String: Any] = ["src_dir": srcDir, "dst_dir": destDir, "names": [srcName]]
        requestJSON("/api/fs/move", parameters: parameters) { _, error in
            if let error = error {
                completion(error)
                return
            }
            if srcName == destName {
                completion(nil)
                return
            }
            let movedPath = self.join(destDir, srcName)
            self.requestJSON("/api/fs/rename", parameters: ["path": movedPath, "name": destName]) { _, renameError in
                completion(renameError)
            }
        }
    }

    func removeItem(_ path: String, _ fileID: String, completion: @escaping (_ error: Error?) -> Void) {
        // 删除接口要的是「所在目录 + 文件名列表」，不是完整路径
        let name = (path as NSString).lastPathComponent
        let dir = (path as NSString).deletingLastPathComponent
        let parameters: [String: Any] = ["dir": dir, "names": [name]]
        requestJSON("/api/fs/remove", parameters: parameters) { _, error in
            completion(error)
        }
    }

    /// 上传、改名、删除这些接口只关心成功还是失败，这里把服务端的 code 翻译成 App 的错误类型
    private func getResponseError(_ response: PPCloudHTTPResponse<Data>) -> Error? {
        guard let json = response.data?.pp_JSONObject() as? [String: Any] else {
            // 没有 JSON 可读，说明是 HTTP 层失败（网络断了、服务端返回 502 页面之类）
            debugPrint("alist 请求失败：\(String(describing: response.error))")
            return PPCloudServiceError.from(httpError: response.error)
        }
        let code = json["code"] as? Int ?? -1
        if code == 200 {
            return nil
        }
        let message = json["message"] as? String ?? ""
        debugPrint("alist 操作失败：\(code) \(message)")
        if code == 401 {
            // 顺手把过期 token 清掉，下次请求会自动重新登录
            access_token = ""
            configChanged?("PPAccessToken", "")
        }
        return error(from: code, message: message)
    }
}
