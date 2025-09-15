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

    private init(baseURL: String = "",
                 proxyHost: String? = nil,
                 proxyPort: Int? = nil,
                 timeout: TimeInterval = 30)
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

        // 配置代理（如果需要）
        if let host = proxyHost, let port = proxyPort {
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
            ]
        }

        session = Session(configuration: configuration)
    }

    // MARK: - 配置方法

    /// 设置代理
    static func configureProxy(host: String, port: Int, timeout: TimeInterval = 30) -> PPCloudHTTP {
        return PPCloudHTTP(proxyHost: host, proxyPort: port, timeout: timeout)
    }

    /// 创建自定义配置的实例
    static func configure(baseURL: String = "", timeout: TimeInterval = 30) -> PPCloudHTTP {
        return PPCloudHTTP(baseURL: baseURL, timeout: timeout)
    }

    /// 设置基础URL
    func setBaseURL(_: String) {
        // 由于baseURL是let，这里需要重新创建实例或者修改为var
        // 为了简化，这里提供一个静态方法
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
            let errorResponse = PPCloudHTTPResponse<R>(
                data: nil,
                statusCode: 0,
                headers: nil,
                error: .unknown(error)
            )
            completion(errorResponse)
        }
    }

    // MARK: - 上传方法

    // https://github.com/Alamofire/Alamofire/issues/2811#issuecomment-490370829
    // let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: [200, 204, 205]) // Default is [204, 205]
    func upload(data: Data,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 204, 205],
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = HTTPHeaders(headers ?? [:])
        let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)
        session.upload(data,
                       to: fullURL,
                       method: method,
                       headers: requestHeaders)
            .validate()
            .response(responseSerializer: dataResponseSerializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持文件上传的重载版本
    func upload(fileURL: URL,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 204, 205],
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = HTTPHeaders(headers ?? [:])
        let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.upload(fileURL,
                       to: fullURL,
                       method: method,
                       headers: requestHeaders)
            .validate()
            .response(responseSerializer: dataResponseSerializer) { [weak self] response in
                self?.handleResponse(response, completion: completion)
            }
    }

    // 如果需要支持 InputStream 上传的重载版本
    func upload(stream: InputStream,
                to url: String,
                method: HTTPMethod = .put,
                headers: PPHTTPHeaders? = nil,
                emptyResponseCodes: Set<Int> = [200, 204, 205],
                completion: @escaping PPCloudHTTPCompletion<Data>)
    {
        let fullURL = buildFullURL(url)
        let requestHeaders = HTTPHeaders(headers ?? [:])
        let dataResponseSerializer = DataResponseSerializer(emptyResponseCodes: emptyResponseCodes)

        session.upload(stream,
                       to: fullURL,
                       method: method,
                       headers: requestHeaders)
            .validate()
            .response(responseSerializer: dataResponseSerializer) { [weak self] response in
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

    private func handleResponse(_ response: AFDataResponse<Data>, completion: @escaping PPCloudHTTPCompletion<Data>) {
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
            case .sessionTaskFailed(let error):
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
