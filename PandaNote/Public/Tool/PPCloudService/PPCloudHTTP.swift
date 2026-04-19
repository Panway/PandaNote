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

    var isSuccess: Bool {
        return error == nil && (200 ... 299).contains(statusCode)
    }
}

typealias PPHTTPHeaders = [String: String]

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

    // MARK: - 初始化

    // 20260419 新增 interceptor 参数，支持 Basic Auth、Bearer Token 等注入
    private init(baseURL: String = "",
                 proxyHost: String? = nil,
                 proxyPort: Int? = nil,
                 timeout: TimeInterval = 30,
                 interceptor: RequestInterceptor? = nil)
    {
        self.baseURL = baseURL
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
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
            ]
        }
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: "127.0.0.1",
            kCFNetworkProxiesHTTPPort: 9000,
        ]

        // 20260419 interceptor 传入 Session，让所有请求自动附加认证头
        session = Session(configuration: configuration, interceptor: interceptor)
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
    func get(url: String,
             parameters: [String: Any]? = nil,
             headers: PPHTTPHeaders? = nil,
             timeout _: TimeInterval? = nil,
             completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        let request = session.request(fullURL,
                                      method: .get,
                                      parameters: parameters,
                                      encoding: URLEncoding.default,
                                      headers: requestHeaders)

        request.validate()
            .responseData { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    /// GET 请求 - 返回 JSON
    func getJSON<T: Codable>(url: String,
                             parameters: [String: Any]? = nil,
                             headers: PPHTTPHeaders? = nil,
                             responseType _: T.Type,
                             completion: @escaping PPCloudHTTPCompletion<T>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        session.request(fullURL,
                        method: .get,
                        parameters: parameters,
                        encoding: URLEncoding.default,
                        headers: requestHeaders)
            .validate()
            .responseDecodable(of: T.self) { [weak self] response in
                self?.handleDecodableResponse(response, completion: completion)
            }
    }

    // MARK: - POST 请求

    /// POST 请求 - 返回 Data (JSON 格式)
    func post(url: String,
              parameters: [String: Any]? = nil,
              headers: PPHTTPHeaders? = nil,
              completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        session.request(fullURL,
                        method: .post,
                        parameters: parameters,
                        encoding: JSONEncoding.default,
                        headers: requestHeaders)
            .validate()
            .responseData { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    /// POST 请求 - 返回 JSON (JSON 格式)
    /// PPSwift: _ 表示省略外部参数标签
    /// 调用时不需要写参数名：postJSON(..., SomeType.self, completion: ...)
    func postJSON<T: Codable>(url: String,
                              parameters: [String: Any]? = nil,
                              headers: PPHTTPHeaders? = nil,
                              responseType _: T.Type,
                              completion: @escaping PPCloudHTTPCompletion<T>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        session.request(fullURL,
                        method: .post,
                        parameters: parameters,
                        encoding: JSONEncoding.default,
                        headers: requestHeaders).validate()
            .responseDecodable(of: T.self) { [weak self] response in
                self?.handleDecodableResponse(response, completion: completion)
            }
    }

    /// POST 请求 - 表单格式 (application/x-www-form-urlencoded)
    func postForm(url: String,
                  parameters: [String: Any]? = nil,
                  headers: PPHTTPHeaders? = nil,
                  timeout _: TimeInterval? = nil,
                  completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        var requestHeaders = mergeHeaders(headers)

        // 设置表单类型的 Content-Type
        requestHeaders.update(name: "Content-Type", value: "application/x-www-form-urlencoded")

        session.request(fullURL,
                        method: .post,
                        parameters: parameters,
                        encoding: URLEncoding.default,
                        headers: requestHeaders).validate()
            .responseData { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // 支持传入预编码的 raw body 字符串。同一个函数名，不同的参数列表
    func postForm(url: String,
                  rawBody: String,
                  headers: PPHTTPHeaders? = nil,
                  completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        var requestHeaders = mergeHeaders(headers)
        requestHeaders.update(name: "Content-Type", value: "application/x-www-form-urlencoded")

        var urlRequest = URLRequest(url: URL(string: fullURL)!)
        urlRequest.httpMethod = "POST"
        // 把 requestHeaders 转成 URLRequest headers
        requestHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.name) }
        urlRequest.httpBody = rawBody.data(using: .utf8)

        session.request(urlRequest)
            .validate()
            .responseData { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    /// POST 请求 - 表单格式返回 JSON (application/x-www-form-urlencoded)
    func postFormJSON<T: Codable>(url: String,
                                  parameters: [String: Any]? = nil,
                                  headers: PPHTTPHeaders? = nil,
                                  timeout _: TimeInterval? = nil,
                                  responseType _: T.Type,
                                  completion: @escaping PPCloudHTTPCompletion<T>)
    {
        let fullURL = buildFullURL(url)
        var requestHeaders = mergeHeaders(headers)

        // 设置表单类型的 Content-Type
        requestHeaders.update(name: "Content-Type", value: "application/x-www-form-urlencoded")

        let request = session.request(fullURL,
                                      method: .post,
                                      parameters: parameters,
                                      encoding: URLEncoding.default,
                                      headers: requestHeaders)

        request.validate()
            .responseDecodable(of: T.self) { [weak self] response in
                self?.handleDecodableResponse(response, completion: completion)
            }
    }

    /// POST 请求 - 发送 Codable 对象
    func post<T: Codable, R: Codable>(url: String,
                                      body: T,
                                      headers: PPHTTPHeaders? = nil,
                                      responseType _: R.Type,
                                      completion: @escaping PPCloudHTTPCompletion<R>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        do {
            let jsonData = try JSONEncoder().encode(body)
            let parameters = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            session.request(fullURL,
                            method: .post,
                            parameters: parameters,
                            encoding: JSONEncoding.default,
                            headers: requestHeaders)
                .validate()
                .responseDecodable(of: R.self) { [weak self] response in
                    self?.handleDecodableResponse(response, completion: completion)
                }
        } catch {
            completion(PPCloudHTTPResponse(data: nil,
                                           statusCode: 0,
                                           headers: nil,
                                           error: .unknown(error)))
        }
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
    func request(url: String,
                 method: HTTPMethod,
                 bodyData: Data? = nil,
                 headers: PPHTTPHeaders? = nil,
                 acceptableStatusCodes: [Int] = Array(200 ... 299),
                 emptyResponseCodes: Set<Int> = [200, 201, 204, 205, 207],
                 completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        guard let requestURL = URL(string: fullURL) else {
            completion(PPCloudHTTPResponse(data: nil, statusCode: 0, headers: nil,
                                           error: .networkError))
            return
        }

        // 手动构建 URLRequest，绕过 Alamofire 的 ParameterEncoding 限制
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = bodyData
        // 把合并后的 headers 写入请求（interceptor 会在此之后再追加认证头）
        requestHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.name) }

        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.request(urlRequest)
            .validate(statusCode: acceptableStatusCodes)
            .response(responseSerializer: serializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // MARK: - 20260419 新增：文件下载（支持进度、本地缓存路径）

    //
    // 解决的问题：
    //   WebDAV 文件下载需要写入沙盒指定路径并报告进度，
    //   原有 get() 返回的是内存 Data，不适合大文件。
    //
    // 返回：PPCloudHTTPResponse<URL>，data 为本地文件 URL
    func download(url: String,
                  to destinationURL: URL,
                  headers: PPHTTPHeaders? = nil,
                  progress: PPDownloadProgressHandler? = nil,
                  completion: @escaping PPCloudHTTPCompletion<URL>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)

        let destination: DownloadRequest.Destination = { _, _ in
            (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        session.download(fullURL, headers: requestHeaders, to: destination)
            .downloadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .responseURL { [weak self] response in
                guard let self else { return }
                let statusCode = response.response?.statusCode ?? 0
                let headers = response.response?.headers.dictionary
                let error = self.mapError(from: response.error, statusCode: statusCode)
                let data: URL? = try? response.result.get()

                let result = PPCloudHTTPResponse<URL>(
                    data: data,
                    statusCode: statusCode,
                    headers: headers,
                    error: error
                )
                DispatchQueue.main.async { completion(result) }
            }
    }

    // MARK: - 上传方法

    // https://github.com/Alamofire/Alamofire/issues/2811#issuecomment-490370829
    // let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: [200, 204, 205]) // Default is [204, 205]
    func upload(data: Data,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                progress: PPDownloadProgressHandler? = nil,
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.upload(data, 
	to: fullURL, 
	method: method, 
	headers: requestHeaders)
            .uploadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .response(responseSerializer: serializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持文件上传的重载版本
    func upload(fileURL: URL,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                progress: PPDownloadProgressHandler? = nil,
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.upload(fileURL, to: fullURL, method: method, headers: requestHeaders)
            .uploadProgress { prog in
                DispatchQueue.main.async {
                    progress?(prog.completedUnitCount, prog.totalUnitCount)
                }
            }
            .validate()
            .response(responseSerializer: serializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持 InputStream 上传的重载版本
    func upload(stream: InputStream,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 201, 204, 205],
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = mergeHeaders(headers)
        let serializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.upload(stream, 
	to: fullURL, 
	method: method, 
	headers: requestHeaders)
            .validate()
            .response(responseSerializer: serializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // MARK: - 私有方法

    private func buildFullURL(_ url: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return url
        }
        return baseURL + url
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

    private func handleResponse(_ response: AFDataResponse<Data>, 
    completion: @escaping PPCloudHTTPCompletion<Data>) {
        let statusCode = response.response?.statusCode ?? 0
        let headers = response.response?.headers.dictionary
        let error = mapError(from: response.error, statusCode: statusCode)

        let result = PPCloudHTTPResponse<Data>(
            data: response.data,
            statusCode: statusCode,
            headers: headers,
            error: error
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
            error: error
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
