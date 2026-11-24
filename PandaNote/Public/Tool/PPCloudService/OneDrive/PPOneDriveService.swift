//
//  PPOneDriveService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/2.
//  Copyright © 2021 Panway. All rights reserved.
//
let onedrive_client_id_es = "dedcda2a-3acf-44bb-8baa-17f9ed544d64"
let onedrive_redirect_uri_es = "https://login.microsoftonline.com/common/oauth2/nativeclient"
let onedrive_client_id_pandanote = "064f5b62-97a8-4dae-b5c1-aaf44439939d"
let onedrive_redirect_uri_pandanote = "pandanote://msredirect"
/// 要申请的权限，必须用 Microsoft Graph 的权限名。
/// Files.ReadWrite.All 是委托权限，允许读写用户能访问的所有文件；
/// offline_access 是拿到 refresh_token 的前提，不申请它 access_token 一小时后过期就没法自动续期了。
/// 注意别写成 onedrive.readwrite，那是 Live Connect 时代的老名字，Azure AD 不认，会报 AADSTS70011 且错误里 scope 显示为空
let onedrive_scope_pandanote = "Files.ReadWrite.All offline_access"
let onedrive_login_url_es = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=dedcda2a-3acf-44bb-8baa-17f9ed544d64&scope=User.Read%20offline_access%20files.readwrite.all&redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient&response_type=code"
/// 授权地址必须和换 token 的地址同属 v2.0 体系。
/// 以前这里用的是 login.live.com/oauth20_authorize.srf（Live Connect 老端点），
/// 它签发的 code 到 v2.0 token 端点会被解析成空 scope，报 AADSTS70011
let onedrive_auth_url = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=\(onedrive_client_id_pandanote)&scope=\(onedrive_scope_pandanote.replacingOccurrences(of: " ", with: "%20"))&response_type=code&redirect_uri=\(onedrive_redirect_uri_pandanote)"//pandanote的

import Foundation

/// Graph 接口的版本前缀，所有资源都挂在 /v1.0 下面
private let onedrive_graph_version = "v1.0"
/// 换 token 的地址。它和 Graph 不在同一个域名，所以每次都要传完整地址
private let onedrive_token_url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"

/// 直接用 Microsoft Graph 实现的 OneDrive 文件操作，不再依赖 FilesProvider 和 Alamofire
/// 接口文档：https://learn.microsoft.com/en-us/graph/api/resources/onedrive
///
/// 定位一个文件（夹）有两种写法，这个类里到处都会用到：
///   - 按 id：/me/drive/items/{item-id}       —— 改名、挪目录都不影响，能用就用它
///   - 按路径：/me/drive/root:/Notes/me.md     —— 只有拿到路径、没有 id 的时候才退回这种
class PPOneDriveService: NSObject, PPCloudServiceProtocol {

    var url = "https://graph.microsoft.com"
    var access_token = ""
    var refresh_token = ""
    /// 换 token 时要带上的 client_id。App 里有两套 client_id（ES 文件浏览器那套 + 本 App 自己申请的），refresh_token 是跟着申请它的应用走的，用错会 400
    var clientID: String
    var baseURL: String {
        return url
    }

    /// 更新完 token 等信息后执行的回调，交给 PPFileManager 存到服务器配置里（和其他云盘服务保持一致，不在这里直接改 PPUserInfo）
    var configChanged : ((_ key:String,_ value:String) -> ())?

    /// 所有请求统一走 PPCloudHTTP。超时给 60 秒：OneDrive 在国外，走代理时握手本来就慢
    /// 用 lazy 是因为 baseURL 要拼上版本号，写起来比在 init 里赋值一堆属性清楚
    private lazy var httpClient = PPCloudHTTP.configure(baseURL: url + "/" + onedrive_graph_version, timeout: 60)

    /// 每页条数。Graph 的 children 默认一页 200 条，超过就返回 @odata.nextLink
    private let pageSize = 200
    /// 最多翻几页，防止服务端一直给 nextLink 形成死循环。200 * 10 = 2000 条，一个笔记目录远远够用
    private let maxPageCount = 10

    /// 正在刷新 token 的标记，以及排队等结果的回调。
    /// 微软的 refresh_token 是用一次换一个新的，几个请求同时 401 各自去刷新的话，后到的那个拿着已经作废的旧 token 必然失败，所以这里排队只刷一次
    private var isRefreshingToken = false
    private var refreshWaiters: [(Bool) -> Void] = []

    /// 目录相对路径 → item id。批量整理文件时每个文件都要问一次父目录 id，缓存住能省一大半请求
    private var folderIDCache: [String: String] = [:]

    /// 这个服务用到的 HTTP 方法。自己定义一个小枚举，就不用为了 HTTPMethod 这个类型去 import Alamofire
    private enum OneDriveHTTPMethod {
        case get, post, patch, delete

        var name: String {
            switch self {
            case .get: return "GET"
            case .post: return "POST"
            case .patch: return "PATCH"
            case .delete: return "DELETE"
            }
        }
    }

    init(access_token: String, refresh_token: String, clientID: String = onedrive_client_id_es) {
        self.access_token = access_token
        self.refresh_token = refresh_token
        // 传空就别留个空的 clientID，否则换 token 的请求会缺参数直接 400
        self.clientID = clientID.isEmpty ? onedrive_client_id_es : clientID
        super.init()
    }

    // MARK: - 登录：用授权码换 token

    /// 拿授权回调里的 code 换 access_token / refresh_token。
    /// 这是登录流程的最后一步，此时还没有实例，所以做成类方法。
    /// 和下面的 postTokenRequest（用 refresh_token 换）是一对，都打在同一个 token 端点
    /// - Parameters:
    ///   - code: 微软回调 URL 里的 code
    ///   - clientID: 用哪套应用申请的，就要和授权时保持一致
    ///   - redirectUri: 必须和授权时发的逐字符一致，否则被拒（AADSTS70000）
    ///   - scope: 必须和授权时申请的一致。传 nil 就不带这个参数（ES 那条老流程一直没带过）
    ///   - completion: 成功给两个 token；失败给一句能直接显示给用户的原因
    class func exchangeAuthorizationCode(_ code: String,
                                         clientID: String,
                                         redirectUri: String,
                                         scope: String?,
                                         completion: @escaping (_ accessToken: String?, _ refreshToken: String?, _ errorMessage: String?) -> Void) {
        var parameters: [String: Any] = [
            "client_id": clientID,
            "redirect_uri": redirectUri,
            "code": code,
            "grant_type": "authorization_code"
        ]
        if let scope = scope, scope.isEmpty == false {
            parameters["scope"] = scope
        }
        // 登录和 Graph 文件操作是两回事，用共享实例就够了（它没有 baseURL，正好要求传完整地址）
        PPCloudHTTP.shared.postForm(url: onedrive_token_url, parameters: parameters) { response in
            let json = response.data?.pp_JSONObject()
            // 注意顺序：400 也会带 body，而且 PPCloudHTTP 在非 2xx 时同样会填 error。
            // 先看能解析出 access_token 就是成功，再看能不能解析出 error_description 就是业务失败，
            // 两个都没有才当成网络层问题，否则微软给的 AADSTS 原因会被一句「客户端错误 (400)」盖掉
            if let accessToken = json?["access_token"] as? String,
               let refreshToken = json?["refresh_token"] as? String {
                debugPrint("OneDrive 授权成功，access_token 长度 \(accessToken.length)")
                completion(accessToken, refreshToken, nil)
                return
            }
            if let description = json?["error_description"] as? String, description.isEmpty == false {
                debugPrint("OneDrive 授权失败：\(description)")
                completion(nil, nil, description)
                return
            }
            let reason = response.error?.localizedDescription ?? "服务端没有返回原因（HTTP \(response.statusCode)）"
            debugPrint("OneDrive 授权失败：\(reason)")
            completion(nil, nil, reason)
        }
    }

    // MARK: - Token 刷新

    /// 刷新 access_token，成功后通过 configChanged 通知外面落盘
    func refreshAccessToken(_ completion: @escaping (Bool) -> Void) {
        // 没有 refresh_token 就不用往服务端打了：微软一定回 400 invalid_request，两套 client_id 各打一次纯属白等。
        // 这种配置基本是老版本保存时把 refresh_token 丢了（配置页没显示那一行），只能重新授权，日志里说清楚原因
        guard refresh_token.isEmpty == false else {
            debugPrint("OneDrive 没有 refresh_token，无法自动续期，需要重新授权")
            completion(false)
            return
        }
        // 已经有请求在刷了，排它后面等同一个结果，别并发去刷
        if isRefreshingToken {
            refreshWaiters.append(completion)
            return
        }
        isRefreshingToken = true
        refreshWaiters.append(completion)
        debugPrint("OneDrive token 已过期，开始刷新")
        postTokenRequest(clientID: clientID) { success in
            if success {
                self.finishRefresh(true)
                return
            }
            // 登录入口有两套 client_id，老版本存下来的 refresh_token 可能属于另一套。
            // 用错 client_id 微软会回 invalid_client / 400，换一套再试一次，别让用户莫名要去重新登录
            let fallbackID = (self.clientID == onedrive_client_id_pandanote) ? onedrive_client_id_es : onedrive_client_id_pandanote
            debugPrint("OneDrive 用 \(self.clientID) 刷新失败，换 \(fallbackID) 再试一次")
            self.postTokenRequest(clientID: fallbackID) { retrySuccess in
                self.finishRefresh(retrySuccess)
            }
        }
    }

    private func postTokenRequest(clientID: String, completion: @escaping (Bool) -> Void) {
        // redirect_uri 故意不传：两套登录入口的回调地址不一样，refresh 请求里它本来也不是必填项，带上反而容易对不上
        let parameters: [String: Any] = [
            "client_id": clientID,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token"
        ]
        httpClient.postForm(url: onedrive_token_url, parameters: parameters) { response in
            guard let json = response.data?.pp_JSONObject(),
                  let accessToken = json["access_token"] as? String, accessToken.isEmpty == false else {
                // 只打 error 看不出是哪种 400，微软会把原因写在 body 里：
                // invalid_grant   → refresh_token 失效（微软的 refresh_token 用一次就下发新的，旧的立刻作废）
                // invalid_client  → client_id 和 refresh_token 不匹配
                // invalid_request → 参数缺失，refresh_token 是空串时就是这种
                let body = response.data?.pp_JSONObject()
                let code = body?["error"] as? String ?? ""
                let detail = body?["error_description"] as? String ?? ""
                debugPrint("OneDrive 刷新 token 失败：\(String(describing: response.error)) clientID=\(clientID) refreshTokenLength=\(self.refresh_token.length) code=\(code) detail=\(detail)")
                completion(false)
                return
            }
            self.access_token = accessToken
            // 记住这次成功的 client_id。之前是 fallback 到另一套才成功的话，下次刷新还是先用错的那套再试一遍，
            // 白打一次请求还可能刷出 invalid_client 的噪音日志
            self.clientID = clientID
            // 微软不是每次都回新的 refresh_token，没回就继续用旧的
            if let newRefreshToken = json["refresh_token"] as? String, newRefreshToken.isEmpty == false {
                self.refresh_token = newRefreshToken
            }
            debugPrint("OneDrive 刷新 token 成功")
            self.configChanged?("PPWebDAVPassword", self.access_token)
            self.configChanged?("PPCloudServiceExtra", self.refresh_token)
            completion(true)
        }
    }

    /// 把排队等着的结果一次性发出去。注意要先把队列清空再回调，否则回调里又触发刷新会陷进同一个队列
    private func finishRefresh(_ success: Bool) {
        isRefreshingToken = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        for waiter in waiters {
            waiter(success)
        }
    }

    // MARK: - 请求封装

    private func authHeaders() -> PPHTTPHeaders {
        return ["Authorization": "Bearer " + access_token]
    }

    /// 返回 JSON 的统一出口。401 自动刷新 token 再试一次，其余错误翻译成 App 自己的云盘错误
    /// - Parameters:
    ///   - apiPath: 相对路径（如 /me/drive/root/children），也可以是完整地址（分页时 nextLink 就是完整地址）
    ///   - allowRetry: 只允许重试一次，避免「刷新→401→再刷新」转圈
    private func requestJSON(_ apiPath: String,
                             method: OneDriveHTTPMethod = .get,
                             jsonBody: [String: Any]? = nil,
                             allowRetry: Bool = true,
                             completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void) {
        let handler: PPCloudHTTPCompletion<Data> = { response in
            if response.isSuccess {
                // DELETE 成功返回 204 没有 body，这时 json 是 nil，调用方只判断 error 即可
                completion(response.data?.pp_JSONObject(), nil)
                return
            }
            if response.statusCode == 401, allowRetry {
                self.refreshAccessToken { success in
                    if success {
                        self.requestJSON(apiPath, method: method, jsonBody: jsonBody, allowRetry: false, completion: completion)
                    } else {
                        completion(nil, PPCloudServiceError.forcedLoginRequired)
                    }
                }
                return
            }
            debugPrint("OneDrive 请求失败：\(method.name) \(apiPath) 状态码 \(response.statusCode)")
            completion(response.data?.pp_JSONObject(), PPCloudServiceError.from(httpError: response.error))
        }
        switch method {
        case .get:
            httpClient.get(url: apiPath, headers: authHeaders(), completion: handler)
        case .post:
            httpClient.post(url: apiPath, parameters: jsonBody, headers: authHeaders(), completion: handler)
        case .patch:
            httpClient.patch(url: apiPath, json: jsonBody, headers: authHeaders(), completion: handler)
        case .delete:
            httpClient.delete(url: apiPath, headers: authHeaders(), completion: handler)
        }
    }

    /// 把分页拉完，把每页 value 里的条目累加起来
    /// - Parameters:
    ///   - pageIndex: 已经拉了几页，递归时 +1
    private func fetchPages(_ urlString: String,
                            pageIndex: Int,
                            collected: [[String: Any]],
                            completion: @escaping (_ items: [[String: Any]], _ error: Error?) -> Void) {
        requestJSON(urlString) { json, error in
            if let error = error {
                // 已经拉到一些条目时，宁可少几页也别让整个文件列表打不开
                completion(collected.isEmpty ? [] : collected, collected.isEmpty ? error : nil)
                return
            }
            var items = collected
            if let value = json?["value"] as? [[String: Any]] {
                items.append(contentsOf: value)
            }
            guard let nextLink = json?["@odata.nextLink"] as? String,
                  nextLink.isEmpty == false,
                  pageIndex + 1 < self.maxPageCount else {
                completion(items, nil)
                return
            }
            self.fetchPages(nextLink, pageIndex: pageIndex + 1, collected: items, completion: completion)
        }
    }

    // MARK: - URL 拼接

    /// 用 item id 定位：/me/drive/items/{id}。空值、"/"、"root" 都当根目录
    private func itemPrefix(_ itemID: String?) -> String {
        let id = (itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty || id == "/" || id == "root" {
            return "/me/drive/root"
        }
        return "/me/drive/items/" + encodePathSegment(id)
    }

    /// 用相对路径定位：/me/drive/root:/Notes/me.md。只有拿不到 id 的时候才用
    private func pathPrefix(_ path: String) -> String {
        let cleanPath = normalizePath(path)
        if cleanPath.isEmpty {
            return "/me/drive/root"
        }
        return "/me/drive/root:/" + encodePath(cleanPath)
    }

    /// 移动文件时 parentReference 要的格式是 "/drive/root:/Notes"，根目录是 "/drive/root:"
    private func parentReferencePath(_ folderPath: String) -> String {
        let cleanPath = normalizePath(folderPath)
        if cleanPath.isEmpty {
            return "/drive/root:"
        }
        return "/drive/root:/" + cleanPath
    }

    /// 去掉首尾多余的斜杠，Graph 的路径寻址多一个斜杠就是 404
    private func normalizePath(_ path: String) -> String {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleanPath.hasPrefix("/") {
            cleanPath.removeFirst()
        }
        while cleanPath.hasSuffix("/") {
            cleanPath.removeLast()
        }
        return cleanPath
    }

    /// 单个路径段编码。文件名里可能有空格、中文、#、? 这些字符，不编码会把 URL 拆坏
    private func encodePathSegment(_ text: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        // 斜杠在文件名里必须转义，否则会被服务端当成目录分隔符
        allowed.remove(charactersIn: "/")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// 整段路径编码，保留斜杠作为目录分隔符
    private func encodePath(_ path: String) -> String {
        return path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    }

    // MARK: - id 解析

    /// 拿某个目录的 item id。传了 id 就直接用，没传就按路径查一次，查到的结果缓存起来
    /// id 返回 nil 表示「根目录」，调用方用 itemPrefix(nil) 就得到 /me/drive/root，不是错误
    private func folderID(forPath path: String, givenID: String, completion: @escaping (_ id: String?, _ error: Error?) -> Void) {
        if givenID.isEmpty == false, givenID != "/", givenID != "root" {
            completion(givenID, nil)
            return
        }
        let cleanPath = normalizePath(path)
        if cleanPath.isEmpty {
            completion(nil, nil)
            return
        }
        if let cachedID = folderIDCache[cleanPath] {
            completion(cachedID, nil)
            return
        }
        requestJSON(pathPrefix(cleanPath) + "?$select=id") { json, error in
            guard let itemID = json?["id"] as? String else {
                completion(nil, error ?? PPCloudServiceError.fileNotExist)
                return
            }
            self.folderIDCache[cleanPath] = itemID
            completion(itemID, nil)
        }
    }

    /// 拿单个文件（夹）的 id，逻辑和 folderID 一样
    private func resolveItemID(path: String, givenID: String, completion: @escaping (_ id: String?, _ error: Error?) -> Void) {
        if givenID.isEmpty == false, givenID != "/", givenID != "root" {
            completion(givenID, nil)
            return
        }
        let cleanPath = normalizePath(path)
        if cleanPath.isEmpty {
            completion(nil, PPCloudServiceError.unknown)
            return
        }
        requestJSON(pathPrefix(cleanPath) + "?$select=id") { json, error in
            guard let itemID = json?["id"] as? String else {
                completion(nil, error ?? PPCloudServiceError.fileNotExist)
                return
            }
            completion(itemID, nil)
        }
    }

    // MARK: - 文件列表

    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping (_ data: [PPFileObject], _ error: Error?) -> Void) {
        // pathID 是 OneDrive 的 item id，改名、挪目录都不会变，能拿到就优先用它定位；
        // 只有批量整理文件那种「只给了路径」的场景才退回按路径请求
        let prefix = (pathID.isEmpty && path.length > 1) ? pathPrefix(path) : itemPrefix(pathID)
        // 这里故意不写 $select：Graph 的历史版本在 $select 里写 @microsoft.graph.downloadUrl 会直接报
        // 「character '@' is not valid」，一个参数把整个文件列表打死；不同租户的 Graph 版本还不一样，不值得赌。
        // 不带 $select 时服务端会返回完整 driveItem，里面本来就有这个地址，响应大一点但稳
        let query = "$expand=thumbnails&$top=\(pageSize)"

        fetchPages(prefix + "/children?" + query, pageIndex: 0, collected: []) { items, error in
            if let error = error {
                completion([], error)
                return
            }
            var dataSource = [PPFileObject]()
            // 文件夹排在前面，和项目里其它云盘的列表顺序保持一致
            var folderCount = 0
            for json in items {
                guard let item = PPOneDriveFile(JSON: json) else { continue }
                // folder 字段只有目录才有，文件身上没有
                item.isDirectory = (json["folder"] != nil)
                item.thumbnail = self.thumbnailURL(from: json)
                if item.isDirectory {
                    dataSource.insert(item, at: folderCount)
                    folderCount += 1
                } else {
                    dataSource.append(item)
                }
            }
            completion(dataSource, nil)
        }
    }

    /// 从 children 的响应里挖出缩略图地址。thumbnails 是数组，取第一个（其实就是唯一一个 set）的中图
    private func thumbnailURL(from json: [String: Any]) -> String {
        guard let thumbnails = json["thumbnails"] as? [[String: Any]], let first = thumbnails.first else {
            return ""
        }
        // medium 大约 176px，列表格子够用；没有 medium 就退回 small
        if let medium = first["medium"] as? [String: Any], let url = medium["url"] as? String {
            return url
        }
        if let small = first["small"] as? [String: Any], let url = small["url"] as? String {
            return url
        }
        return ""
    }

    // MARK: - 文件内容

    /// 把文件整个下下来交给调用方，url 回空串。
    /// 为什么不在外面拿直连地址自己下：@microsoft.graph.downloadUrl 是一次性地址，
    /// 交给 PPFileManager 的 handleResult 会被当成「本地临时文件路径」去 move，那条路走不通
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (_ data: Data?, _ url: String, _ error: Error?) -> Void) {
        resolveItemID(path: path, givenID: extraParams) { itemID, error in
            guard let itemID = itemID else {
                completion(nil, "", error ?? PPCloudServiceError.fileNotExist)
                return
            }
            // 同样是「不带 $select」，理由见文件列表那里的注释
            self.requestJSON(self.itemPrefix(itemID)) { json, error in
                guard let downloadURL = json?["@microsoft.graph.downloadUrl"] as? String, downloadURL.isEmpty == false else {
                    completion(nil, "", error ?? PPCloudServiceError.fileNotExist)
                    return
                }
                // 直连地址自带签名，不需要带认证头
                self.httpClient.get(url: downloadURL) { response in
                    if response.isSuccess, let data = response.data {
                        completion(data, "", nil)
                        return
                    }
                    // 失败时把状态码和已收到的字节数打出来，定位问题时能直接区分是签名过期（403）、
                    // 地址被截断（404）还是超时（-1001）。文件大小也一起打，方便判断是不是大文件超时
                    debugPrint("OneDrive 直连下载失败 file=\(path) status=\(response.statusCode) bytes=\(response.data?.count ?? 0) error=\(String(describing: response.error))")
                    completion(nil, "", PPCloudServiceError.from(httpError: response.error))
                }
            }
        }
    }

    // MARK: - 新建文件夹

    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        folderID(forPath: atPath, givenID: parentID) { parentItemID, error in
            if let error = error {
                completion(error)
                return
            }
            let requestURL = self.itemPrefix(parentItemID) + "/children"
            let parameters: [String: Any] = [
                "name": folderName,
                "folder": [String: Any](),
                // 重名时自动加后缀，不然同名文件夹会直接回 409，用户只能换个名字重来
                "@microsoft.graph.conflictBehavior": "rename"
            ]
            self.requestJSON(requestURL, method: .post, jsonBody: parameters) { json, error in
                if error == nil, let newID = json?["id"] as? String {
                    // 刚建出来的目录顺手记进缓存，后面往里传文件就不用再查一次
                    let newPath = self.normalizePath(atPath) + "/" + folderName
                    self.folderIDCache[self.normalizePath(newPath)] = newID
                }
                completion(error)
            }
        }
    }

    // MARK: - 新建（上传）文件

    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping (_ result: [String:String]?, _ error: Error?) -> Void) {
        let fileName = (path as NSString).lastPathComponent
        guard fileName.isEmpty == false else {
            completion(nil, PPCloudServiceError.unknown)
            return
        }
        let parentPath = (path as NSString).deletingLastPathComponent
        folderID(forPath: parentPath, givenID: pathID) { parentItemID, error in
            if let error = error {
                completion(nil, error)
                return
            }
            // 有父目录 id 时写成 /items/{id}:/文件名:/content，文件名里的中文、空格交给编码处理；
            // 只有根目录（没有 id）才退回按完整路径上传
            let requestURL: String
            if let parentItemID = parentItemID, parentItemID.isEmpty == false {
                requestURL = self.itemPrefix(parentItemID) + ":/" + self.encodePathSegment(fileName) + ":/content"
            } else {
                requestURL = "/me/drive/root:/" + self.encodePath(self.normalizePath(path)) + ":/content"
            }
            // Graph 单次 PUT 上限 250MB，笔记 App 碰不到这个量级；真要做大文件得走 createUploadSession 分片上传
            self.uploadData(contents, to: requestURL) { json, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let fileID = json?["id"] as? String else {
                    // 传上去了但服务端没回 id，基本不会出现，真出现也别让调用方以为写入失败
                    completion(nil, nil)
                    return
                }
                completion(["fileID": fileID], nil)
            }
        }
    }

    /// 上传二进制内容，回传解析好的 JSON。
    /// 单独抽出来是为了能重试：token 过期时 Graph 回 401，刷新之后得把同样的内容再 PUT 一次
    private func uploadData(_ data: Data,
                            to requestURL: String,
                            allowRetry: Bool = true,
                            completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void) {
        // Authorization 必须手动带上。上传是独立的一条请求，不会继承 requestJSON 里那套认证头，
        // 少了它 Graph 直接回 401，紧接着代码就跑去刷新 token，日志看起来像「token 过期」，
        // 其实跟 token 没关系，是这条请求根本没带凭证
        var headers = authHeaders()
        headers["Content-Type"] = "application/octet-stream"
        httpClient.upload(data: data, to: requestURL, headers: headers) { response in
            if response.statusCode == 401, allowRetry {
                self.refreshAccessToken { success in
                    if success {
                        self.uploadData(data, to: requestURL, allowRetry: false, completion: completion)
                    } else {
                        // 刷新都失败了，只能让用户重新登录
                        completion(nil, PPCloudServiceError.forcedLoginRequired)
                    }
                }
                return
            }
            if let error = response.error {
                debugPrint("OneDrive 上传失败：\(requestURL) 状态码 \(response.statusCode)")
                completion(response.data?.pp_JSONObject(), PPCloudServiceError.from(httpError: error))
                return
            }
            completion(response.data?.pp_JSONObject(), nil)
        }
    }

    // MARK: - 移动 / 重命名

    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (_ error:Error?) -> Void) {
        let destName = (destPath as NSString).lastPathComponent
        guard destName.isEmpty == false else {
            completion(PPCloudServiceError.unknown)
            return
        }
        // 「按年月整理文件」那个功能只传路径不传 id，所以这里先补一次查询
        resolveItemID(path: srcPath, givenID: srcItemID) { itemID, error in
            guard let itemID = itemID else {
                completion(error ?? PPCloudServiceError.fileNotExist)
                return
            }
            // 只是改名：PATCH 里只带 name，父子关系不动
            if isRename {
                self.patchItem(itemID, body: ["name": destName], completion: completion)
                return
            }
            let destFolderPath = (destPath as NSString).deletingLastPathComponent
            self.folderID(forPath: destFolderPath, givenID: destItemID) { destFolderID, folderError in
                if let folderError = folderError {
                    completion(folderError)
                    return
                }
                var body: [String: Any] = ["name": destName]
                if let destFolderID = destFolderID, destFolderID.isEmpty == false {
                    body["parentReference"] = ["id": destFolderID]
                } else {
                    // 根目录拿不到 id，用路径形式表达「挪到根目录」
                    body["parentReference"] = ["path": self.parentReferencePath(destFolderPath)]
                }
                self.patchItem(itemID, body: body, completion: completion)
            }
        }
    }

    private func patchItem(_ itemID: String, body: [String: Any], completion: @escaping (_ error: Error?) -> Void) {
        requestJSON(itemPrefix(itemID), method: .patch, jsonBody: body) { _, error in
            // 移动/改名后目录结构变了，缓存里的「路径→id」可能对不上，直接清掉，下次用到再查
            self.folderIDCache.removeAll()
            completion(error)
        }
    }

    // MARK: - 删除

    func removeItem(_ path: String, _ fileID: String, completion: @escaping (_ error: Error?) -> Void) {
        resolveItemID(path: path, givenID: fileID) { itemID, error in
            guard let itemID = itemID else {
                completion(error ?? PPCloudServiceError.fileNotExist)
                return
            }
            // 删目录时子项会一起进回收站，缓存里那些子目录的 id 也就全失效了，一起清掉
            self.folderIDCache.removeAll()
            self.requestJSON(self.itemPrefix(itemID), method: .delete) { _, error in
                completion(error)
            }
        }
    }
}
