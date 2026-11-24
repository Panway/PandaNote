//
//  PPDropboxService.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import CommonCrypto
import UIKit
// 开发者文档 https://docs.dropboxapi.com/dropbox-api/docs/developer-resources/developer-guide#production-approval
// 控制台 https://www.dropbox.com/developers/console
/// PandaNote 自己在 Dropbox App Console 里注册的应用（2020/12/5 创建，key 就是 client_id）。
//let dropbox_auth_url = "https://www.dropbox.com/oauth2/authorize?client_id=pjmhj9rfhownr7z&redirect_uri=filemgr://oauth-callback/dropbox&response_type=token&state=DROPBOX"
let dropbox_client_id_pandanote = "qa3p6wvu1iqv510"
/// 回调地址，必须和 App Console 里登记的逐字符一致，多一个斜杠都会被拒
let dropbox_redirect_uri_pandanote = "pandanote://oauth-callback/dropbox"
/// 授权页和换 token 的地址
private let dropbox_authorize_url = "https://www.dropbox.com/oauth2/authorize"
private let dropbox_token_url = "https://api.dropboxapi.com/oauth2/token"
/// 回调回来时校验的 state，防的是随便拼一个 pandanote:// 链接把 code 塞进来
private let dropbox_auth_state = "DROPBOX"

/// RPC 接口走这个域名，参数是 JSON body
private let dropbox_api_host = "https://api.dropboxapi.com/2"
/// 传文件内容的接口走这个域名，参数放在 Dropbox-API-Arg 请求头里
private let dropbox_content_host = "https://content.dropboxapi.com/2"

/// 直接用 Dropbox API v2 实现的文件操作，不再依赖 FilesProvider
/// 文档：https://www.dropbox.com/developers/documentation/http/documentation
///
/// 两个域名一定要分清，写反了直接 404：
///   api.dropboxapi.com      列表、建目录、移动、删除这类 RPC，参数是 JSON body
///   content.dropboxapi.com  上传、下载，参数放 Dropbox-API-Arg 头，body 才是文件内容
class PPDropboxService: NSObject, PPCloudServiceProtocol {

    /// baseURL 会参与文件列表缓存的 key，改动它等于让所有已存在的缓存失效
    var url = "https://api.dropboxapi.com/2/"
    var baseURL: String {
        return url
    }
    var access_token = ""
    /// 长期有效的刷新令牌，授权时发一次，之后靠它静默续期。没有它 access_token 四小时一过就得重新登录
    var refresh_token = ""

    /// 更新完 token 后执行的回调，交给 PPFileManager 存进服务器配置（和其他云盘服务保持一致，不在这里直接改 PPUserInfo）
    var configChanged: ((_ key: String, _ value: String) -> ())?

    /// 每页条数，Dropbox 的上限就是 2000
    private let pageLimit = 2000
    /// 最多翻几页，防止服务端一直给 cursor 形成死循环
    private let maxPageCount = 20

    /// 所有请求统一走 PPCloudHTTP。Dropbox 服务器在国外，超时给 60 秒
    private lazy var httpClient = PPCloudHTTP.configure(timeout: 60)

    /// 正在刷新 token 的标记，以及排队等结果的回调。
    /// 几个请求同时撞上 401 时只能由一个去刷，其余排队等同一个结果：
    /// 并发刷新的结果是后到的那个拿着已经作废的 refresh_token 去换，必然失败
    private var isRefreshingToken = false
    private var refreshWaiters: [(Bool) -> Void] = []

    init(access_token: String, refresh_token: String = "") {
        self.access_token = access_token
        self.refresh_token = refresh_token
        super.init()
        // 一屏一二十个格子，300 张足够覆盖来回滚动。超出后 NSCache 自己按最近最少用淘汰，收到内存警告也会自动清
        thumbnailCache.countLimit = 300
    }

    // MARK: - 登录（授权码 + PKCE）

    /// 登录过程中暂存的 code_verifier。
    /// 授权是异步的（用户可能在浏览器里停留很久），换 token 时必须拿同一个值，
    /// 用一个静态变量传递最省事；同一时刻只会有一个登录流程在跑
    private static var pendingCodeVerifier = ""

    /// 生成授权地址，同时把这次用的 code_verifier 存起来，换 token 时要配对
    ///
    /// 两个参数是必须的，少一个都会出问题：
    ///   - code_challenge：自定义 scheme（pandanote://）只有在带 PKCE 时才允许配 response_type=code，
    ///     不带会被直接打回 invalid_redirect_uri
    ///   - token_access_type=offline：只有它才会发 refresh_token，少了它 access_token 四小时就废
    class func makeAuthorizationURL() -> String {
        let verifier = randomURLSafeString(byteCount: 32)
        pendingCodeVerifier = verifier
        var components = URLComponents(string: dropbox_authorize_url)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: dropbox_client_id_pandanote),
            URLQueryItem(name: "redirect_uri", value: dropbox_redirect_uri_pandanote),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "token_access_type", value: "offline"),
            URLQueryItem(name: "code_challenge", value: codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: dropbox_auth_state),
        ]
        return components?.url?.absoluteString ?? ""
    }

    /// 从回调地址里取授权码，顺便校验 state。
    /// WebView 回调（pandanote://oauth-callback/dropbox?code=xxx）和系统浏览器回调走的是同一个方法
    class func authorizationCode(fromCallback url: URL) -> String? {
        let state = url.absoluteString.pp_valueOf("state") ?? ""
        guard state == dropbox_auth_state else {
            debugPrint("Dropbox 回调 state 不对，丢弃：\(url.absoluteString)")
            return nil
        }
        let code = url.absoluteString.pp_valueOf("code") ?? ""
        return code.isEmpty ? nil : code
    }

    /// 拿授权码换 access_token / refresh_token。这是登录流程的最后一步，此时还没有实例，所以做成类方法
    class func exchangeAuthorizationCode(_ code: String,
                                        completion: @escaping (_ accessToken: String?, _ refreshToken: String?, _ errorMessage: String?) -> Void) {
        let verifier = pendingCodeVerifier
        // 没有 verifier 说明不是从 makeAuthorizationURL 进来的（比如热启动时直接吃到了回调），PKCE 校验必挂，早点说清楚
        guard verifier.isEmpty == false else {
            completion(nil, nil, "缺少 PKCE 校验串，请重新发起授权")
            return
        }
        let parameters: [String: Any] = [
            "code": code,
            "grant_type": "authorization_code",
            "client_id": dropbox_client_id_pandanote,
            "redirect_uri": dropbox_redirect_uri_pandanote,
            "code_verifier": verifier,
        ]
        // 登录和文件操作是两回事，用共享实例就够了（它没有 baseURL，正好要求传完整地址）
        PPCloudHTTP.shared.postForm(url: dropbox_token_url, parameters: parameters) { response in
            let json = response.data?.pp_JSONObject()
            // 400 也会带 body，先看能不能解析出 token 再谈错误，
            // 否则 Dropbox 给的 invalid_grant 原因会被一句「客户端错误 (400)」盖掉
            if let accessToken = json?["access_token"] as? String, accessToken.isEmpty == false {
                pendingCodeVerifier = ""
                let refreshToken = json?["refresh_token"] as? String ?? ""
                debugPrint("Dropbox 授权成功，access_token 长度 \(accessToken.length)，refresh_token 长度 \(refreshToken.length)")
                completion(accessToken, refreshToken, nil)
                return
            }
            if let description = json?["error_description"] as? String, description.isEmpty == false {
                debugPrint("Dropbox 授权失败：\(description)")
                completion(nil, nil, description)
                return
            }
            if let errorName = json?["error"] as? String, errorName.isEmpty == false {
                debugPrint("Dropbox 授权失败：\(errorName)")
                completion(nil, nil, errorName)
                return
            }
            let reason = response.error?.localizedDescription ?? "服务端没有返回原因（HTTP \(response.statusCode)）"
            debugPrint("Dropbox 授权失败：\(reason)")
            completion(nil, nil, reason)
        }
    }

    // MARK: - Token 刷新

    /// 用 refresh_token 换新的 access_token，成功后通过 configChanged 通知外面落盘
    func refreshAccessToken(_ completion: @escaping (Bool) -> Void) {
        guard refresh_token.isEmpty == false else {
            debugPrint("Dropbox 没有 refresh_token，无法自动续期，需要重新授权")
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
        debugPrint("Dropbox token 已过期，开始刷新")
        let parameters: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": dropbox_client_id_pandanote,
        ]
        PPCloudHTTP.shared.postForm(url: dropbox_token_url, parameters: parameters) { response in
            let json = response.data?.pp_JSONObject()
            guard let accessToken = json?["access_token"] as? String, accessToken.isEmpty == false else {
                // 失败原因都在 body 里：invalid_grant 是 refresh_token 失效（用户取消了授权或改了密码），
                // invalid_client 是 client_id 对不上，只看状态码 400 分不出来是哪一种
                let code = json?["error"] as? String ?? ""
                let detail = json?["error_description"] as? String ?? ""
                debugPrint("Dropbox 刷新 token 失败：\(String(describing: response.error)) code=\(code) detail=\(detail)")
                self.finishRefresh(false)
                return
            }
            self.access_token = accessToken
            // Dropbox 每次都会回新的 refresh_token，回了就换掉，没回继续用旧的
            if let newRefreshToken = json?["refresh_token"] as? String, newRefreshToken.isEmpty == false {
                self.refresh_token = newRefreshToken
            }
            debugPrint("Dropbox 刷新 token 成功")
            self.configChanged?("PPWebDAVPassword", self.access_token)
            self.configChanged?("PPCloudServiceExtra", self.refresh_token)
            self.finishRefresh(true)
        }
    }

    /// 把排队等着的结果一次性发出去。要先把队列清空再回调，否则回调里又触发刷新会陷进同一个队列
    private func finishRefresh(_ success: Bool) {
        isRefreshingToken = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        for waiter in waiters {
            waiter(success)
        }
    }

    // MARK: - PKCE 工具

    /// 随机串：32 字节随机数转 base64url 之后是 43 个字符，正好落在 PKCE 要求的 43~128 区间。
    /// SystemRandomNumberGenerator 底层就是系统的密码学随机源，不是伪随机，用来做校验串没问题
    private class func randomURLSafeString(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8]()
        bytes.reserveCapacity(byteCount)
        for _ in 0 ..< byteCount {
            bytes.append(UInt8.random(in: 0 ... 255, using: &generator))
        }
        return base64URLEncode(Data(bytes))
    }

    /// code_challenge = base64url(SHA256(code_verifier))，这是 S256 的算法定义
    private class func codeChallenge(for verifier: String) -> String {
        return base64URLEncode(sha256(Data(verifier.utf8)))
    }

    private class func sha256(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    /// base64url：把标准 base64 里的 + 换成 -、/ 换成 _，并去掉末尾的 = 填充。
    /// PKCE 要求这种形式，直接发标准 base64 服务端算出来的摘要对不上
    private class func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func authHeaders() -> PPHTTPHeaders {
        return ["Authorization": "Bearer " + access_token]
    }

    // MARK: - 请求封装

    /// RPC 请求：POST JSON 到 api.dropboxapi.com，返回解析好的 JSON
    /// Dropbox 的错误一律用 HTTP 409 表示，具体原因写在 body 的 error_summary 里，所以失败时把 json 也一起传出去
    /// - Parameter allowRetry: 只允许重试一次，避免「刷新 token → 又 401 → 再刷新」转圈
    private func requestJSON(_ endpoint: String,
                             body: [String: Any]?,
                             allowRetry: Bool = true,
                             completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void) {
        httpClient.post(url: dropbox_api_host + endpoint, parameters: body, headers: authHeaders()) { response in
            let json = response.data?.pp_JSONObject()
            if response.isSuccess {
                completion(json, nil)
                return
            }
            if response.statusCode == 401, allowRetry {
                self.refreshAccessToken { success in
                    if success {
                        self.requestJSON(endpoint, body: body, allowRetry: false, completion: completion)
                    } else {
                        // 刷新都失败了（refresh_token 被撤销之类），只能让用户重新授权
                        completion(nil, PPCloudServiceError.forcedLoginRequired)
                    }
                }
                return
            }
            debugPrint("Dropbox 请求失败：\(endpoint) 状态码 \(response.statusCode) body=\(String(describing: json))")
            completion(json, self.mapError(statusCode: response.statusCode, json: json, fallback: response.error))
        }
    }

    /// 内容请求：POST 到 content.dropboxapi.com。
    /// 参数必须放进 Dropbox-API-Arg 头，下载时 body 要为空，上传时 body 才是文件内容
    private func requestContent(_ endpoint: String,
                                arg: [String: Any],
                                bodyData: Data?,
                                contentType: String?,
                                allowRetry: Bool = true,
                                completion: @escaping PPCloudHTTPCompletion<Data>) {
        var headers = authHeaders()
        headers["Dropbox-API-Arg"] = asciiEscapedJSON(arg)
        httpClient.postRaw(url: dropbox_content_host + endpoint,
                           bodyData: bodyData,
                           headers: headers,
                           contentType: contentType) { response in
            // 上传、下载请求不会走 requestJSON，401 得在这里单独处理一遍，否则 token 一过期上传就整段失败
            if response.statusCode == 401, allowRetry {
                self.refreshAccessToken { success in
                    if success {
                        self.requestContent(endpoint, arg: arg, bodyData: bodyData,
                                            contentType: contentType, allowRetry: false,
                                            completion: completion)
                    } else {
                        // 造一个 401 响回去，让调用方的 mapError 统一翻译成 forcedLoginRequired
                        completion(PPCloudHTTPResponse<Data>(data: nil, statusCode: 401,
                                                             headers: response.headers,
                                                             error: .clientError(401)))
                    }
                }
                return
            }
            completion(response)
        }
    }

    /// 把参数 JSON 转成「HTTP 头安全」的形式：0x7F 和所有非 ASCII 字符都写成 \uXXXX。
    /// Dropbox 对 Dropbox-API-Arg 这个头有硬性要求，中文文件名按 UTF-8 直接塞进去会报
    /// 「could not decode input as JSON」或者 bad header，而不是干脆地提示参数错误
    private func asciiEscapedJSON(_ dictionary: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        var escaped = ""
        for scalar in json.unicodeScalars {
            if scalar.value < 0x80 && scalar.value != 0x7F {
                escaped.unicodeScalars.append(scalar)
            } else if scalar.value <= 0xFFFF {
                escaped += String(format: "\\u%04x", scalar.value)
            } else {
                // 超出 BMP 的字符（emoji 之类）在 JSON 里本来就是代理对，这里按高低位拆开输出
                let value = scalar.value - 0x10000
                let high = 0xD800 + (value >> 10)
                let low = 0xDC00 + (value & 0x3FF)
                escaped += String(format: "\\u%04x\\u%04x", high, low)
            }
        }
        return escaped
    }

    /// 把 HTTP 状态码和 body 翻译成 App 自己的云盘错误
    private func mapError(statusCode: Int, json: [String: Any]?, fallback: PPCloudHTTPError?) -> Error {
        // 走到这里说明 401 重试也失败了：refresh_token 被用户撤销或者已经失效，只能重新授权。
        // 只有 forcedLoginRequired 才会弹出「是否重新登录」那个框
        if statusCode == 401 {
            return PPCloudServiceError.forcedLoginRequired
        }
        let summary = json?["error_summary"] as? String ?? ""
        if summary.hasPrefix("path/not_found") {
            return PPCloudServiceError.fileNotExist
        }
        // 429 是限流，服务端会在 Retry-After 里给要等几秒。这里不自动重试，让用户过会儿再来
        return PPCloudServiceError.from(httpError: fallback)
    }

    // MARK: - 路径处理

    /// App 里的路径约定：根目录是 "/"，其它是 "/a/b"。
    /// Dropbox 的根目录必须传空字符串，传 "/" 会被当成「名字为空的目录」，直接回 path/malformed_path
    private func apiPath(_ path: String) -> String {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        if clean.isEmpty {
            return ""
        }
        return clean.hasPrefix("/") ? clean : "/" + clean
    }

    /// 拼子路径。父目录是根目录时不能拼出 "//名字"
    private func joinPath(_ parent: String, _ name: String) -> String {
        let cleanParent = apiPath(parent)
        return cleanParent.isEmpty ? "/" + name : cleanParent + "/" + name
    }

    // MARK: - 文件列表

    func contentsOfDirectory(_ path: String, _ pathID: String, completion: @escaping (_ data: [PPFileObject], _ error: Error?) -> Void) {
        // pathID 在 Dropbox 里用不上，它的列表接口只认路径，这里直接用 path
        let body: [String: Any] = [
            "path": apiPath(path),
            "recursive": false,
            "include_deleted": false,
            "include_non_downloadable_files": false,
            "limit": pageLimit
        ]
        fetchFolderPages("/files/list_folder", body: body, pageIndex: 0, collected: []) { entries, error in
            if let error = error {
                completion([], error)
                return
            }
            var dataSource = [PPFileObject]()
            // 进目录、下拉刷新都算一次「重新来」：之前判定失败的缩略图要再给一次机会，
            // 否则网络抖一下导致的那次失败会跟着这个路径到 App 重启
            self.failedThumbnailPaths.removeAll()
            // 文件夹排在前面，和项目里其它云盘的列表顺序保持一致
            var folderCount = 0
            for json in entries {
                let item = self.fileObject(from: json)
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

    /// 顺着 cursor 把分页拉完。首页用 list_folder，后面的页都用 list_folder/continue
    private func fetchFolderPages(_ endpoint: String,
                                  body: [String: Any],
                                  pageIndex: Int,
                                  collected: [[String: Any]],
                                  completion: @escaping (_ entries: [[String: Any]], _ error: Error?) -> Void) {
        requestJSON(endpoint, body: body) { json, error in
            if let error = error {
                // 已经拉到一些条目时，宁可少几页也别让整个文件列表打不开
                completion(collected.isEmpty ? [] : collected, collected.isEmpty ? error : nil)
                return
            }
            var entries = collected
            if let list = json?["entries"] as? [[String: Any]] {
                entries.append(contentsOf: list)
            }
            guard let cursor = json?["cursor"] as? String,
                  cursor.isEmpty == false,
                  (json?["has_more"] as? Bool) == true,
                  pageIndex + 1 < self.maxPageCount else {
                completion(entries, nil)
                return
            }
            self.fetchFolderPages("/files/list_folder/continue",
                                  body: ["cursor": cursor],
                                  pageIndex: pageIndex + 1,
                                  collected: entries,
                                  completion: completion)
        }
    }

    /// 把 Dropbox 的一条 entry 转成 App 的文件模型
    private func fileObject(from json: [String: Any]) -> PPFileObject {
        let item = PPFileObject()
        item.name = json["name"] as? String ?? ""
        // path_display 保留原始大小写，展示和后续请求都用它；万一没有就用小写的 path_lower
        item.path = json["path_display"] as? String ?? json["path_lower"] as? String ?? ""
        // Dropbox 用 .tag 区分类型，文件是 file、目录是 folder
        item.isDirectory = (json[".tag"] as? String) == "folder"
        // size 只有文件才有，目录没有这个字段
        item.size = (json["size"] as? NSNumber)?.int64Value ?? 0
        item.pathID = json["id"] as? String ?? ""
        item.modifiedDate = PPDropboxService.localDateString(json["server_modified"] as? String ?? "")
        return item
    }

    /// Dropbox 给的是 UTC 时间（2015-05-12T15:50:38Z），直接显示会比北京时间慢 8 小时，先转成本机时区
    private static func localDateString(_ raw: String) -> String {
        if raw.isEmpty {
            return ""
        }
        // ISO8601DateFormatter 的默认格式不认小数秒（.123 这种），先去掉再解析
        let noFraction = raw.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: noFraction) {
            return date.toString()
        }
        var fallback = raw.replacingOccurrences(of: "T", with: " ")
        if fallback.length > 19 {
            fallback = String(fallback.prefix(19))
        }
        return fallback
    }

    // MARK: - 缩略图

    /// 缩略图的内存缓存。列表滚动、下拉刷新都会让同一张图被反复问一遍，
    /// 不缓存的话一次滑动就能打出几十个请求，而 Dropbox 对缩略图这种「数据传输」接口限流比普通 RPC 严
    private let thumbnailCache = NSCache<NSString, UIImage>()
    /// 正在请求的路径，同一个文件同一时刻只发一次
    private var loadingThumbnailPaths = Set<String>()
    /// 已经确认拿不到缩略图的路径（不是真图片、格式不支持、文件已被删），记下来不再重试
    private var failedThumbnailPaths = Set<String>()

    /// 取一张列表用的小缩略图（实现协议 PPCloudServiceProtocol.loadThumbnail）。
    /// Dropbox 的 list_folder 只回元数据，不像 OneDrive 那样自带 thumbnails 字段，
    /// 所以只能等 cell 真正显示出来，再按 path 单独要一次图。
    /// fileID 用不上：Dropbox 的缩略图接口按 path 取图
    func loadThumbnail(path: String, fileID _: String?, completion: @escaping (UIImage?) -> Void) {
        // NSCache 的 key 必须是对象，NSString 在 Swift 里能直接桥接
        if let cached = thumbnailCache.object(forKey: path as NSString) {
            completion(cached)
            return
        }
        if failedThumbnailPaths.contains(path) {
            completion(nil)
            return
        }
        // 已经在请求了就先不排队，让这个 cell 用默认图标顶着；等它滚回来时缓存里已经有了。
        // 排队反而会把「滚一下屏幕」变成几十个请求同时悬着
        if loadingThumbnailPaths.contains(path) {
            completion(nil)
            return
        }
        loadingThumbnailPaths.insert(path)
        // resource 是个 union，必须写成 {".tag": "path"} 的形式，直接给一个 path 字段会被判成参数错误。
        // 尺寸只要 128：列表格子最大也就一百多点，再大纯粹是白传流量
        let arg: [String: Any] = [
            "resource": [".tag": "path", "path": apiPath(path)],
            "format": "jpeg",
            "size": "w128h128",
            "mode": "bestfit",
        ]
        requestContent("/files/get_thumbnail_v2",
                       arg: arg,
                       bodyData: Data(),
                       contentType: "application/octet-stream",
                       // 这里不刷新 token：一屏可能同时有十几个缩略图请求，
                       // 每个撞上 401 都去刷一遍会把 refresh_token 并发消费掉
                       allowRetry: false) { response in
            self.loadingThumbnailPaths.remove(path)
            guard response.isSuccess, let data = response.data, let image = UIImage(data: data) else {
                debugPrint("Dropbox 缩略图获取失败 path=\(path) status=\(response.statusCode)")
                // 429 是限流，不是这张图真的没有缩略图，下次滚动还得再试。
                // 其它错误（非图片、格式不支持、超过 20MB）记下来，免得同一个路径反复打无用的请求
                if response.statusCode != 429 {
                    self.failedThumbnailPaths.insert(path)
                }
                completion(nil)
                return
            }
            self.thumbnailCache.setObject(image, forKey: path as NSString)
            completion(image)
        }
    }

    // MARK: - 文件内容

    /// 把文件整个下下来交给调用方，url 回空串。
    /// 为什么不用直连地址：Dropbox 的临时直链要走一次 get_temporary_link，而且 4 小时就失效，
    /// 存进列表缓存等于埋一个过期时间炸弹
    func getFileData(_ path: String, _ extraParams: String, completion: @escaping (_ data: Data?, _ url: String, _ error: Error?) -> Void) {
        // 下载接口要求 body 为空，参数全部在 Dropbox-API-Arg 头里
        requestContent("/files/download",
                       arg: ["path": apiPath(path)],
                       bodyData: Data(),
                       contentType: "application/octet-stream") { response in
            if response.isSuccess, let data = response.data {
                completion(data, "", nil)
                return
            }
            let json = response.data?.pp_JSONObject()
            // 失败时把状态码和 body 打出来，定位问题时能区分是路径不对（409 path/not_found）、
            // token 失效（401）还是网络问题
            debugPrint("Dropbox 下载失败 file=\(path) status=\(response.statusCode) body=\(String(describing: json))")
            completion(nil, "", self.mapError(statusCode: response.statusCode, json: json, fallback: response.error))
        }
    }

    // MARK: - 新建文件夹

    func createDirectory(_ folderName: String, _ atPath: String, _ parentID: String, completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = [
            "path": joinPath(atPath, folderName),
            // 重名时自动加后缀，不然同名文件夹直接回 409，用户只能换个名字重来
            "autorename": true
        ]
        requestJSON("/files/create_folder_v2", body: parameters) { _, error in
            completion(error)
        }
    }

    // MARK: - 新建（上传）文件

    /// 单次上传上限 150MB（大文件要开 upload_session 分片），笔记用不到这个量级
    func createFile(_ path: String, _ pathID: String, contents: Data, completion: @escaping (_ result: [String:String]?, _ error: Error?) -> Void) {
        let parameters: [String: Any] = [
            "path": apiPath(path),
            // overwrite：同名文件直接覆盖，笔记保存走的就是这条路
            "mode": "overwrite",
            "autorename": false,
            "mute": false
        ]
        requestContent("/files/upload",
                       arg: parameters,
                       bodyData: contents,
                       contentType: "application/octet-stream") { response in
            let json = response.data?.pp_JSONObject()
            if response.isSuccess == false {
                debugPrint("Dropbox 上传失败 path=\(path) status=\(response.statusCode) body=\(String(describing: json))")
                completion(nil, self.mapError(statusCode: response.statusCode, json: json, fallback: response.error))
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

    // MARK: - 移动 / 重命名

    func moveItem(srcPath: String, destPath: String, srcItemID: String, destItemID: String, isRename: Bool, completion: @escaping (_ error:Error?) -> Void) {
        // Dropbox 没有单独的改名接口，改名就是把文件 move 到同目录下的新名字，所以 isRename 不用分支
        let parameters: [String: Any] = [
            "from_path": apiPath(srcPath),
            "to_path": apiPath(destPath),
            // 目标重名时报错而不是偷偷改名，批量整理文件时才能发现路径算错了
            "autorename": false,
            "allow_ownership_transfer": false
        ]
        requestJSON("/files/move_v2", body: parameters) { _, error in
            completion(error)
        }
    }

    // MARK: - 删除

    func removeItem(_ path: String, _ fileID: String, completion: @escaping (_ error: Error?) -> Void) {
        // delete_v2 删目录会连子项一起删，和 App 里「删除文件夹」的预期一致
        requestJSON("/files/delete_v2", body: ["path": apiPath(path)]) { _, error in
            completion(error)
        }
    }
}
