//
//  PPCloudHTTP.swift
//  PandaNote
//
//  Created by pan on 2025/7/13.
//  Copyright © 2025 Panway. All rights reserved.
//

import Alamofire
import Foundation

// MARK: - 错误类型定义

enum PPCloudHTTPError: Error {
    case forbidden // 403
    case notFound // 404
    case badGateway // 502
    case timeout // 请求超时
    case networkError // 网络错误
    case invalidResponse // 无效响应
    case serverError(Int) // 服务器错误（5xx）
    case clientError(Int) // 客户端错误（4xx）
    case unknown(Error) // 未知错误

    var localizedDescription: String {
        switch self {
        case .forbidden:
            return "访问被拒绝 (403)"
        case .notFound:
            return "资源未找到 (404)"
        case .badGateway:
            return "网关错误 (502)"
        case .timeout:
            return "请求超时"
        case .networkError:
            return "网络连接错误"
        case .invalidResponse:
            return "响应格式无效"
        // PPSwift:Swift 3 引入的 简化写法，通过 let 来直接绑定关联值，语法更简洁
        case let .serverError(code):
//        case .serverError(let code):
            return "服务器错误 (\(code))"
        case let .clientError(code):
            return "客户端错误 (\(code))"
        case let .unknown(error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 响应结果

struct PPCloudHTTPResponse<T> {
    let data: T?
    let statusCode: Int
    let headers: PPHTTPHeaders?
    let error: PPCloudHTTPError?
    /// 请求最终落到的地址。中间被 308 / 301 跳过之后，这里和发起时的地址不一样
    let finalURL: URL?

    init(data: T?, statusCode: Int, headers: PPHTTPHeaders?, error: PPCloudHTTPError?, finalURL: URL? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.error = error
        self.finalURL = finalURL
    }

    var isSuccess: Bool {
        return error == nil && (200 ... 299).contains(statusCode)
    }
}

typealias PPHTTPHeaders = [String: String]

// MARK: - 跳转时保住认证头

/// URLSession 遇到跨域跳转（域名、端口、协议任意一个变了）会主动删掉 Authorization 头，这是规范要求，防的是跳到第三方站点时把密码送出去。
/// 麻烦在于 http 换成 https 也算跨域，而坚果云这类服务就是把 http://dav.jianguoyun.com 308 跳到 https://dav.jianguoyun.com（还是同一台服务器）。
/// 认证头一丢，第二个请求必然 401（服务端回 WWW-Authenticate: Basic），用户看到的就是「加载失败，请检查服务器配置」。
/// 这里只在域名不变的前提下把认证头补回去，真跳到别的域名就不管，凭据不能给外人。
struct PPAuthPreservingRedirectHandler: RedirectHandler {
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for _: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void)
    {
        var newRequest = request
        let originalRequest = task.currentRequest ?? task.originalRequest
        let sameHost = originalRequest?.url?.host == newRequest.url?.host
        // 系统有时会保留一部分头、删掉另一些，所以先看新请求里有没有，没有再补
        if sameHost,
           newRequest.value(forHTTPHeaderField: "Authorization") == nil,
           let authorization = originalRequest?.value(forHTTPHeaderField: "Authorization")
        {
            newRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        completion(newRequest)
    }
}

// MARK: - 完成回调类型

typealias PPCloudHTTPCompletion<T> = (PPCloudHTTPResponse<T>) -> Void
/// 下载进度回调：(已传输字节, 总字节)
typealias PPDownloadProgressHandler = (_ completed: Int64, _ total: Int64) -> Void

// MARK: - Alamofire HTTPMethod 扩展（WebDAV 自定义方法）

// Alamofire 的 HTTPMethod 是结构体，可直接扩展静态常量

extension HTTPMethod {
    /// WebDAV：列举目录属性（返回 207 Multi-Status）
    static let propfind = HTTPMethod(rawValue: "PROPFIND")
    /// WebDAV：创建目录（返回 201 Created）
    static let mkcol = HTTPMethod(rawValue: "MKCOL")
    /// WebDAV：移动/重命名（返回 201/204）
    static let move = HTTPMethod(rawValue: "MOVE")
    /// WebDAV：复制（返回 201/204）
    static let copy = HTTPMethod(rawValue: "COPY")
}

// MARK: - PPCloudHTTP 工具类

class PPCloudHTTP {
    // MARK: - 单例

    static let shared = PPCloudHTTP()

    // MARK: - 私有属性

    private let session: Session
    private let baseURL: String
    private var defaultHeaders: HTTPHeaders
    private var defaultTimeout: TimeInterval

    // 两个 Content-Type 常量收在这里，避免同一个字符串在七八个方法里重复手写
    private static let formContentType = "application/x-www-form-urlencoded"
    private static let jsonContentType = "application/json"

    // MARK: - 初始化

    // 20260419 新增 interceptor 参数，支持 Basic Auth、Bearer Token 等注入
    private init(baseURL: String = "",
                 proxyHost: String? = nil,
                 proxyPort: Int? = nil,
                 timeout: TimeInterval = 30,
                 interceptor: RequestInterceptor? = nil)
    {
        // 去掉末尾多余的斜杠：baseURL 带 "/" 时再拼 "/xxx" 会拼出双斜杠，大多数服务器能容忍，但部分 WebDAV 服务端会直接返回 404。只处理结尾，前面的 https:// 一个字符都不动
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        defaultTimeout = timeout
        defaultHeaders = [
            "Content-Type": "application/json",
            "User-Agent": "PPCloudHTTP/1.0",
        ]

        // 配置 URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.httpCookieStorage = nil // 不使用系统 Cookie
        configuration.httpCookieAcceptPolicy = .never

        // 配置代理（如果需要）
        if let host = proxyHost, let port = proxyPort {
            // 键名直接用字符串，因为 kCFNetworkProxiesHTTPSEnable 这几个常量在 Mac Catalyst 上被标成了 unavailable（编译直接报错），而它们的实际值就是 "HTTPSEnable" / "HTTPSProxy" / "HTTPSPort"，用字符串运行时完全等价
            // HTTP 和 HTTPS 两套都得配：实测只配 HTTP 三件套时，https:// 请求会直接绕过代理（连指向没人监听的死端口都照样请求成功），代理等于白设
            configuration.connectionProxyDictionary = [
                "HTTPEnable": true,
                "HTTPProxy": host,
                "HTTPPort": port,
                "HTTPSEnable": true,
                "HTTPSProxy": host,
                "HTTPSPort": port,
            ]
        }

        // 20260419 interceptor 传入 Session，让所有请求自动附加认证头
        // redirectHandler 负责在服务器跳转（尤其是 http → https）时把认证头补回来，不然第二次请求会被当成未登录
        session = Session(configuration: configuration,
                          interceptor: interceptor,
                          redirectHandler: PPAuthPreservingRedirectHandler())
    }

    // MARK: - 配置方法

    /// 设置代理
    static func configureProxy(host: String, port: Int, timeout: TimeInterval = 30) -> PPCloudHTTP {
        return PPCloudHTTP(proxyHost: host, proxyPort: port, timeout: timeout)
    }

    /// 创建自定义配置的实例
    /// - Parameters:
    ///   - baseURL: 基础 URL，留空则每次传完整 URL
    ///   - timeout: 超时时间
    ///   - interceptor: 请求拦截器，可注入 Basic Auth / Bearer Token 等
    static func configure(baseURL: String = "",
                          timeout: TimeInterval = 30,
                          interceptor: RequestInterceptor? = nil) -> PPCloudHTTP
    {
        return PPCloudHTTP(baseURL: baseURL, timeout: timeout, interceptor: interceptor)
    }

    /// 设置默认超时时间
    func setDefaultTimeout(_ timeout: TimeInterval) {
        defaultTimeout = timeout
    }

    /// 设置默认请求头
    func setDefaultHeaders(_ headers: PPHTTPHeaders) {
        defaultHeaders = HTTPHeaders(headers)
    }

    /// 添加默认请求头
    func addDefaultHeader(name: String, value: String) {
        defaultHeaders.add(name: name, value: value)
    }

    // MARK: - GET 请求

    /// GET 请求 - 返回 Data
    /// 返回值可以调 .cancel() 取消请求，不关心的话直接丢掉（已经标了 @discardableResult）
    @discardableResult
    func get(url: String,
             parameters: [String: Any]? = nil,
             headers: PPHTTPHeaders? = nil,
             timeout: TimeInterval? = nil,
             completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        return send(url, method: .get, parameters: parameters, encoding: URLEncoding.default,
                    headers: headers, timeout: timeout, completion: completion)
    }

    /// GET 请求 - 返回 JSON
    @discardableResult
    func getJSON<T: Codable>(url: String,
                             parameters: [String: Any]? = nil,
                             headers: PPHTTPHeaders? = nil,
                             responseType _: T.Type,
                             completion: @escaping PPCloudHTTPCompletion<T>) -> DataRequest?
    {
        return sendDecodable(url, method: .get, parameters: parameters,
                             encoding: URLEncoding.default, headers: headers,
                             completion: completion)
    }

    // MARK: - POST 请求

    /// POST 请求 - 返回 Data (JSON 格式)
    @discardableResult
    func post(url: String,
              parameters: [String: Any]? = nil,
              headers: PPHTTPHeaders? = nil,
              completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        return send(url, method: .post, parameters: parameters, encoding: JSONEncoding.default,
                    headers: headers, completion: completion)
    }

    /// POST 请求 - 返回 JSON (JSON 格式)
    /// PPSwift: _ 表示省略外部参数标签
    /// 调用时不需要写参数名：postJSON(..., SomeType.self, completion: ...)
    @discardableResult
    func postJSON<T: Codable>(url: String,
                              parameters: [String: Any]? = nil,
                              headers: PPHTTPHeaders? = nil,
                              responseType _: T.Type,
                              completion: @escaping PPCloudHTTPCompletion<T>) -> DataRequest?
    {
        return sendDecodable(url, method: .post, parameters: parameters,
                             encoding: JSONEncoding.default, headers: headers,
                             completion: completion)
    }

    /// POST 请求 - 表单格式 (application/x-www-form-urlencoded)
    @discardableResult
    func postForm(url: String,
                  parameters: [String: Any]? = nil,
                  headers: PPHTTPHeaders? = nil,
                  timeout: TimeInterval? = nil,
                  completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        return send(url, method: .post, parameters: parameters, encoding: URLEncoding.default,
                    headers: headers, contentType: Self.formContentType,
                    timeout: timeout, completion: completion)
    }

    // 支持传入预编码的 raw body 字符串。同一个函数名，不同的参数列表
    @discardableResult
    func postForm(url: String,
                  rawBody: String,
                  headers: PPHTTPHeaders? = nil,
                  completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        return send(url, method: .post, bodyData: rawBody.data(using: .utf8),
                    headers: headers, contentType: Self.formContentType,
                    completion: completion)
    }

    /// POST 请求 - 表单格式返回 JSON (application/x-www-form-urlencoded)
    @discardableResult
    func postFormJSON<T: Codable>(url: String,
                                  parameters: [String: Any]? = nil,
                                  headers: PPHTTPHeaders? = nil,
                                  timeout: TimeInterval? = nil,
                                  responseType _: T.Type,
                                  completion: @escaping PPCloudHTTPCompletion<T>) -> DataRequest?
    {
        return sendDecodable(url, method: .post, parameters: parameters,
                             encoding: URLEncoding.default, headers: headers,
                             contentType: Self.formContentType, timeout: timeout,
                             completion: completion)
    }

    /// POST 请求 - 发送 Codable 对象
    ///
    /// 实现上把对象编码成 Data 后直接当 body，不再走 JSONEncoder → JSONSerialization → 字典 那一圈绕路，那一圈不只是多一次转换，body 顶层是数组时 as? [String: Any] 会失败，最终静默发出空 body
    @discardableResult
    func post<T: Codable, R: Codable>(url: String,
                                      body: T,
                                      headers: PPHTTPHeaders? = nil,
                                      responseType _: R.Type,
                                      completion: @escaping PPCloudHTTPCompletion<R>) -> DataRequest?
    {
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(body)
        } catch {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil, error: .unknown(error)))
            return nil
        }
        return sendDecodable(url, method: .post, bodyData: jsonData, headers: headers,
                             contentType: Self.jsonContentType, completion: completion)
    }

    // MARK: - 20260419 新增：通用原始请求（支持任意 HTTP 方法 + 原始 Data body）

    //
    // 解决的问题：
    //   WebDAV 需要 PROPFIND / MKCOL / MOVE / DELETE 等非标准方法，
    //   且请求 body 是 XML 字符串，无法用 parameters 字典描述。
    //
    // 参数：
    //   - method:              任意 HTTPMethod，包括扩展的 .propfind / .mkcol / .move
    //   - bodyData:            原始 body（XML、二进制等），nil 表示无 body
    //   - acceptableStatusCodes: 视为成功的状态码，默认 200-299
    //                           注意：PROPFIND 返回 207，在默认范围内无需额外配置
    //   - emptyResponseCodes:  视为合法空响应的状态码
    //                           MKCOL(201)、DELETE(204)、MOVE(201/204) 需要包含
    //
    // 返回值：请求对象，可以调 .cancel() 中断
    @discardableResult
    func request(url: String,
                 method: HTTPMethod,
                 bodyData: Data? = nil,
                 headers: PPHTTPHeaders? = nil,
                 acceptableStatusCodes: [Int] = Array(200 ... 299),
                 emptyResponseCodes: Set<Int> = [200, 201, 204, 205, 207],
                 completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        return send(url, method: method, bodyData: bodyData, headers: headers,
                    acceptableStatusCodes: acceptableStatusCodes,
                    emptyResponseCodes: emptyResponseCodes, completion: completion)
    }

    // MARK: - 20260419 新增：文件下载（支持进度、本地缓存路径）

    //
    // 解决的问题：
    //   WebDAV 文件下载需要写入沙盒指定路径并报告进度，
    //   原有 get() 返回的是内存 Data，不适合大文件。
    //
    // 返回：PPCloudHTTPResponse<URL>，data 为本地文件 URL
    @discardableResult
    func download(url: String,
                  to destinationURL: URL,
                  headers: PPHTTPHeaders? = nil,
                  progress: PPDownloadProgressHandler? = nil,
                  completion: @escaping PPCloudHTTPCompletion<URL>) -> DownloadRequest?
    {
        guard let requestURL = buildFullURL(url) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }
        let requestHeaders = mergeHeaders(headers)

        let destination: DownloadRequest.Destination = { _, _ in
            (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        return session.download(requestURL, headers: requestHeaders, to: destination)
            .downloadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .responseURL { response in
                let statusCode = response.response?.statusCode ?? 0
                let headers = response.response?.headers.dictionary
                let error = self.mapError(from: response.error, statusCode: statusCode)
                let data: URL? = try? response.result.get()

                let result = PPCloudHTTPResponse<URL>(
                    data: data,
                    statusCode: statusCode,
                    headers: headers,
                    error: error,
                    finalURL: response.response?.url
                )
                DispatchQueue.main.async { completion(result) }
            }
    }

    // MARK: - 上传方法

    // https://github.com/Alamofire/Alamofire/issues/2811#issuecomment-490370829
    // let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: [200, 204, 205]) // Default is [204, 205]
    @discardableResult
    func upload(data: Data,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                progress: PPDownloadProgressHandler? = nil,
                completion: @escaping PPCloudHTTPCompletion<Data>) -> UploadRequest?
    {
        guard let requestURL = buildFullURL(url) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        return session.upload(data, to: requestURL, method: method, headers: requestHeaders)
            .uploadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .response(responseSerializer: serializer) { response in
                self.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持文件上传的重载版本
    @discardableResult
    func upload(fileURL: URL,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                progress: PPDownloadProgressHandler? = nil,
                completion: @escaping PPCloudHTTPCompletion<Data>) -> UploadRequest?
    {
        guard let requestURL = buildFullURL(url) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        return session.upload(fileURL, to: requestURL, method: method, headers: requestHeaders)
            .uploadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .response(responseSerializer: serializer) { response in
                self.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持 InputStream 上传的重载版本
    @discardableResult
    func upload(stream: InputStream,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                completion: @escaping PPCloudHTTPCompletion<Data>) -> UploadRequest?
    {
        guard let requestURL = buildFullURL(url) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        return session.upload(stream, to: requestURL, method: method, headers: requestHeaders)
            .validate()
            .response(responseSerializer: serializer) { response in
                self.handleResponse(response, completion: completion)
            }
    }

    // MARK: - 私有方法

    /// 把相对路径拼成完整 URL，返回 nil 表示地址非法（比如用户手输的服务器地址里带了空格）
    private func buildFullURL(_ url: String) -> URL? {
        // 已经是绝对地址就直接用，不再和 baseURL 拼
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return URL(string: url)
        }
        // 没配 baseURL 说明调用方本来就该传完整地址，原样交给 URL 去校验
        guard !baseURL.isEmpty else {
            return URL(string: url)
        }
        // baseURL 在 init 时已经去掉尾部斜杠，这里统一补一个前导斜杠，让 "/users" 和 "users" 两种写法拼出来都是 baseURL/users
        let path = url.hasPrefix("/") ? url : "/" + url
        return URL(string: baseURL + path)
    }

    /// 构建并校验一个请求。返回 nil 表示 URL 非法，此时请求还没发出去，调用方自己回调错误
    /// 这里不挂响应解析器，因为返回 Data 和泛型解码两条路要挂不同的 serializer
    private func makeRequest(_ url: String,
                             method: HTTPMethod,
                             parameters: [String: Any]? = nil,
                             bodyData: Data? = nil,
                             encoding: ParameterEncoding = URLEncoding.default,
                             headers: PPHTTPHeaders? = nil,
                             contentType: String? = nil,
                             timeout: TimeInterval? = nil,
                             acceptableStatusCodes: [Int] = Array(200 ... 299)) -> DataRequest?
    {
        guard let requestURL = buildFullURL(url) else { return nil }

        var requestHeaders = mergeHeaders(headers)
        // 表单、JSON 这类必须固定 Content-Type 的请求，在这里统一覆盖默认值
        if let contentType = contentType {
            requestHeaders.update(name: "Content-Type", value: contentType)
        }

        // 单个请求的超时只能靠 RequestModifier 改，URLSessionConfiguration 在建 session 时就定死了
        let effectiveTimeout = timeout ?? defaultTimeout
        let modifier: Session.RequestModifier = { urlRequest in
            urlRequest.timeoutInterval = effectiveTimeout
        }

        let dataRequest: DataRequest
        if let bodyData = bodyData {
            // 有现成的 body（XML、预编码表单、已经编码好的 JSON）就绕开 Alamofire 的编码器手动拼 URLRequest。
            // 不走编码器它就不会自动补 Content-Type，所以上面那个 contentType 必须由调用方显式传
            var urlRequest = URLRequest(url: requestURL)
            urlRequest.httpMethod = method.rawValue
            urlRequest.httpBody = bodyData
            // 手动构建的请求直接改 timeoutInterval，不用再借 RequestModifier 绕一道
            urlRequest.timeoutInterval = effectiveTimeout
            // 把合并后的 headers 写入请求（interceptor 会在此之后再追加认证头）
            requestHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.name) }
            dataRequest = session.request(urlRequest)
        } else {
            dataRequest = session.request(requestURL,
                                          method: method,
                                          parameters: parameters,
                                          encoding: encoding,
                                          headers: requestHeaders,
                                          requestModifier: modifier)
        }

        return dataRequest.validate(statusCode: acceptableStatusCodes)
    }

    /// 返回原始 Data 的统一出口，get / post / postForm / request 最后都走这里
    @discardableResult
    private func send(_ url: String,
                      method: HTTPMethod,
                      parameters: [String: Any]? = nil,
                      bodyData: Data? = nil,
                      encoding: ParameterEncoding = URLEncoding.default,
                      headers: PPHTTPHeaders? = nil,
                      contentType: String? = nil,
                      timeout: TimeInterval? = nil,
                      acceptableStatusCodes: [Int] = Array(200 ... 299),
                      // 默认值和 Alamofire 的 responseData 保持一致，避免顺手改了老方法对空 body 的判定
                      emptyResponseCodes: Set<Int> = [204, 205],
                      completion: @escaping PPCloudHTTPCompletion<Data>) -> DataRequest?
    {
        guard let dataRequest = makeRequest(url, method: method, parameters: parameters,
                                            bodyData: bodyData, encoding: encoding,
                                            headers: headers, contentType: contentType,
                                            timeout: timeout,
                                            acceptableStatusCodes: acceptableStatusCodes) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }

        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)
        dataRequest.response(responseSerializer: serializer) { response in
            self.handleResponse(response, completion: completion)
        }

        return dataRequest
    }

    /// 解码成 Codable 的统一出口，和 send 只差最后挂的 serializer
    @discardableResult
    private func sendDecodable<T: Codable>(_ url: String,
                                          method: HTTPMethod,
                                          parameters: [String: Any]? = nil,
                                          bodyData: Data? = nil,
                                          encoding: ParameterEncoding = URLEncoding.default,
                                          headers: PPHTTPHeaders? = nil,
                                          contentType: String? = nil,
                                          timeout: TimeInterval? = nil,
                                          acceptableStatusCodes: [Int] = Array(200 ... 299),
                                          completion: @escaping PPCloudHTTPCompletion<T>) -> DataRequest?
    {
        guard let dataRequest = makeRequest(url, method: method, parameters: parameters,
                                            bodyData: bodyData, encoding: encoding,
                                            headers: headers, contentType: contentType,
                                            timeout: timeout,
                                            acceptableStatusCodes: acceptableStatusCodes) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return nil
        }

        dataRequest.responseDecodable(of: T.self) { response in
            self.handleDecodableResponse(response, completion: completion)
        }

        return dataRequest
    }

    private func mergeHeaders(_ headers: PPHTTPHeaders?) -> HTTPHeaders {
        var requestHeaders = defaultHeaders
        if let headers = headers {
            for (key, value) in headers {
                requestHeaders[key] = value
            }
        }

        return requestHeaders
    }

    // 这里不能加 [weak self]：Alamofire 的 Session 一旦 deinit 就会 invalidateAndCancel，
    // 实例要是先走一步，请求直接被取消、回调一次都不会触发，调用方永远等在那里（实测过：临时实例发请求，置 nil 之后一点动静都没有）
    // 强引用让实例活到请求结束，最坏情况是请求挂死时多活一个超时周期
    private func handleResponse(_ response: AFDataResponse<Data>,
                                completion: @escaping PPCloudHTTPCompletion<Data>) {
        let statusCode = response.response?.statusCode ?? 0
        let headers = response.response?.headers.dictionary
        let error = mapError(from: response.error, statusCode: statusCode)

        let result = PPCloudHTTPResponse<Data>(
            data: response.data,
            statusCode: statusCode,
            headers: headers,
            error: error,
            finalURL: response.response?.url
        )

        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func handleDecodableResponse<T: Codable>(_ response: AFDataResponse<T>, completion: @escaping PPCloudHTTPCompletion<T>) {
        let statusCode = response.response?.statusCode ?? 0
        let headers = response.response?.headers.dictionary
        let error = mapError(from: response.error, statusCode: statusCode)

        let result = PPCloudHTTPResponse<T>(
            data: response.value,
            statusCode: statusCode,
            headers: headers,
            error: error,
            finalURL: response.response?.url
        )

        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func mapError(from afError: AFError?, statusCode: Int) -> PPCloudHTTPError? {
        // 如果没有错误且状态码正常，返回nil
        if afError == nil, (200 ... 299).contains(statusCode) {
            return nil
        }

        // 根据状态码判断错误类型
        switch statusCode {
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 502:
            return .badGateway
        case 400 ... 499:
            return .clientError(statusCode)
        case 500 ... 599:
            return .serverError(statusCode)
        default:
            break
        }

        // 根据 AFError 判断错误类型
        if let afError = afError {
            switch afError {
            case let .sessionTaskFailed(error):
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        return .timeout
                    case .notConnectedToInternet, .networkConnectionLost:
                        return .networkError
                    default:
                        return .unknown(urlError)
                    }
                }
                return .unknown(error)
            case .responseValidationFailed:
                return .invalidResponse
            default:
                return .unknown(afError)
            }
        }

        return .unknown(NSError(domain: "PPCloudHTTP", code: statusCode, userInfo: nil))
    }
}
// MARK: - AFDataResponse 便利扩展

private extension AFDataResponse {
    /// 取成功值，失败时返回 nil（避免 switch）
//    var success: Value? {
//        if case let .success(v) = result { return v }
//        return nil
//    }
}


// MARK: - 使用示例

/*
 // 基本使用
 PPCloudHTTP.shared.get(url: "https://api.example.com/users") { response in
     if response.isSuccess {
         print("请求成功: \(response.data)")
     } else {
         print("请求失败: \(response.error?.localizedDescription ?? "未知错误")")
     }
 }

 // 带参数的 GET 请求，自定义超时时间
 PPCloudHTTP.shared.get(url: "https://api.example.com/users",
                       parameters: ["page": 1, "limit": 10],
                       timeout: 60) { response in
     // 处理响应
 }

 // 带自定义请求头的 POST 请求 (JSON 格式)
 let headers: PPHTTPHeaders = ["Authorization": "Bearer token123"]
 PPCloudHTTP.shared.post(url: "https://api.example.com/users",
                        parameters: ["name": "John", "email": "john@example.com"],
                        headers: headers,
                        timeout: 45) { response in
     // 处理响应
 }

 // POST 表单请求 (application/x-www-form-urlencoded)
 PPCloudHTTP.shared.postForm(url: "https://api.example.com/login",
                            parameters: ["username": "admin", "password": "123456"],
                            timeout: 30) { response in
     // 处理登录响应
 }

 // POST 表单请求返回 JSON
 struct LoginResponse: Codable {
     let token: String
     let userId: Int
 }

 PPCloudHTTP.shared.postFormJSON(url: "https://api.example.com/login",
                                parameters: ["username": "admin", "password": "123456"],
                                responseType: LoginResponse.self) { response in
     if let loginData = response.data {
         print("登录成功，Token: \(loginData.token)")
     }
 }

 // 使用 Codable 的 JSON 请求
 struct User: Codable {
     let id: Int
     let name: String
     let email: String
 }

 PPCloudHTTP.shared.getJSON(url: "https://api.example.com/users/1",
                           timeout: 20,
                           responseType: User.self) { response in
     if let user = response.data {
         print("用户名: \(user.name)")
     }
 }

 // 配置代理和超时时间
 let httpClient = PPCloudHTTP.configureProxy(host: "192.168.1.14", port: 9000, timeout: 60)
 httpClient.get(url: "https://api.example.com/test") { response in
     // 处理响应
 }

 // 创建自定义配置的实例
 let customClient = PPCloudHTTP.configure(baseURL: "https://api.example.com", timeout: 45)
 customClient.get(url: "/users") { response in
     // 处理响应
 }

 // 设置默认超时时间
 PPCloudHTTP.shared.setDefaultTimeout(60)
 */
