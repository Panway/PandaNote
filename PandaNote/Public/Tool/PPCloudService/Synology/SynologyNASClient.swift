//
//  SynologyNASClient.swift
//  PandaNote
//
//  Created by pan on 2025/9/16.
//  Copyright © 2025 Panway. All rights reserved.
//  暂未使用

import Foundation
import Foundation
import Alamofire

// MARK: - 响应数据模型
struct SynologyResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: SynologyError?
}
struct SynologyDeleteFileData: Codable {
    let errors: [SynologySubError]?
    let finished: Bool
}
struct SynologyError: Codable {
    let code: Int
    let errors: [SynologySubError]?
}
// MARK: - SubError 
struct SynologySubError: Codable {
    let code: Int
    let path: String?
}
struct LoginData: Codable {
    let sid: String
}

struct ApiInfo: Codable {
    let maxVersion: Int
    let minVersion: Int
    let path: String
}

// MARK: - 回调类型定义
typealias ApiInfoCompletion = (Result<[String: ApiInfo], Error>) -> Void
typealias LoginCompletion = (Result<String, Error>) -> Void
typealias LogoutCompletion = (Result<Void, Error>) -> Void

// MARK: - 群晖NAS客户端
class SynologyNASClient {
    private let baseURL: String
    private let session = AF
    private var sessionId: String?
    private var cachedApiInfo: [String: ApiInfo]?
    
    init(baseURL: String) {
        // 确保URL格式正确
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }
    
    // MARK: - 1. 获取API信息
    func getApiInfo(completion: @escaping ApiInfoCompletion) {
        // 如果已缓存，直接返回
        if let cachedInfo = cachedApiInfo {
            completion(.success(cachedInfo))
            return
        }
        
        let url = "\(baseURL)/webapi/query.cgi"
        let parameters: [String: Any] = [
            "api": "SYNO.API.Info",
            "version": 1,
            "method": "query",
            "query": "SYNO.API.Auth,SYNO.FileStation.List,SYNO.FileStation.Upload,SYNO.FileStation.Download"
        ]
        
        session.request(url, method: .get, parameters: parameters)
            .validate()
            .responseDecodable(of: SynologyResponse<[String: ApiInfo]>.self) { [weak self] response in
                switch response.result {
                case .success(let synologyResponse):
                    if synologyResponse.success, let data = synologyResponse.data {
                        self?.cachedApiInfo = data
                        completion(.success(data))
                    } else {
                        let error = synologyResponse.error
                        let apiError = SynologyAPIError.apiError(
                            code: error?.code ?? -1,
                            message: "Failed to get API info"
                        )
                        completion(.failure(apiError))
                    }
                case .failure(let error):
                    completion(.failure(SynologyAPIError.networkError(error)))
                }
            }
    }
    
    // MARK: - 2. 执行登录
    func login(username: String, password: String, otpCode: String? = nil, completion: @escaping LoginCompletion) {
        // 首先获取API信息
        getApiInfo { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let apiInfo):
                guard let authInfo = apiInfo["SYNO.API.Auth"] else {
                    completion(.failure(SynologyAPIError.apiError(code: -1, message: "Auth API not found")))
                    return
                }
                
                self.performLogin(
                    username: username,
                    password: password,
                    otpCode: otpCode,
                    authInfo: authInfo,
                    completion: completion
                )
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performLogin(username: String, password: String, otpCode: String?, authInfo: ApiInfo, completion: @escaping LoginCompletion) {
        let loginURL = "\(baseURL)/webapi/\(authInfo.path)"
        
        var parameters: [String: Any] = [
            "api": "SYNO.API.Auth",
            "version": authInfo.maxVersion,
            "method": "login",
            "account": username,
            "passwd": password,
            "session": "FileStation",
            "format": "sid"
        ]
        
        // 如果提供了OTP代码（两步验证）
        if let otpCode = otpCode {
            parameters["otp_code"] = otpCode
        }
        
        session.request(loginURL, method: .get, parameters: parameters)
            .validate()
            .responseDecodable(of: SynologyResponse<LoginData>.self) { [weak self] response in
                switch response.result {
                case .success(let synologyResponse):
                    if synologyResponse.success, let data = synologyResponse.data {
                        self?.sessionId = data.sid
                        completion(.success(data.sid))
                    } else {
                        let error = synologyResponse.error
                        let errorMessage = self?.getErrorMessage(code: error?.code ?? -1) ?? "Login failed"
                        let loginError = SynologyAPIError.loginFailed(
                            code: error?.code ?? -1,
                            message: errorMessage
                        )
                        completion(.failure(loginError))
                    }
                case .failure(let error):
                    completion(.failure(SynologyAPIError.networkError(error)))
                }
            }
    }
    
    // MARK: - 3. 登出
    func logout(completion: @escaping LogoutCompletion) {
        guard let sessionId = self.sessionId else {
            completion(.failure(SynologyAPIError.noSession))
            return
        }
        
        getApiInfo { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let apiInfo):
                guard let authInfo = apiInfo["SYNO.API.Auth"] else {
                    completion(.failure(SynologyAPIError.apiError(code: -1, message: "Auth API not found")))
                    return
                }
                
                self.performLogout(sessionId: sessionId, authInfo: authInfo, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performLogout(sessionId: String, authInfo: ApiInfo, completion: @escaping LogoutCompletion) {
        let logoutURL = "\(baseURL)/webapi/\(authInfo.path)"
        let parameters: [String: Any] = [
            "api": "SYNO.API.Auth",
            "version": authInfo.maxVersion,
            "method": "logout",
            "session": "FileStation",
            "_sid": sessionId
        ]
        
        session.request(logoutURL, method: .get, parameters: parameters)
            .validate()
            .responseDecodable(of: SynologyResponse<String>.self) { [weak self] response in
                switch response.result {
                case .success(let synologyResponse):
                    if synologyResponse.success {
                        self?.sessionId = nil
                        completion(.success(()))
                    } else {
                        let error = synologyResponse.error
                        let logoutError = SynologyAPIError.apiError(
                            code: error?.code ?? -1,
                            message: "Logout failed"
                        )
                        completion(.failure(logoutError))
                    }
                case .failure(let error):
                    completion(.failure(SynologyAPIError.networkError(error)))
                }
            }
    }
    
    // MARK: - 4. 获取当前会话ID
    func getSessionId() -> String? {
        return sessionId
    }
    
    // MARK: - 5. 检查登录状态
    func isLoggedIn() -> Bool {
        return sessionId != nil
    }
    
    // MARK: - 6. 清除缓存的API信息
    func clearApiInfoCache() {
        cachedApiInfo = nil
    }
    
    // MARK: - 错误代码解析
    private func getErrorMessage(code: Int) -> String {
        switch code {
        case 400:
            return "No such account or incorrect password"
        case 401:
            return "Account disabled"
        case 402:
            return "Permission denied"
        case 403:
            return "2-step verification code required"
        case 404:
            return "Failed to authenticate 2-step verification code"
        case 406:
            return "Enforce to authenticate with 2-factor authentication code"
        case 407:
            return "Blocked IP source"
        case 408:
            return "Expired password cannot change"
        case 409:
            return "Expired password"
        case 410:
            return "Password must change (when first time use or after reset password by admin)"
        default:
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - 自定义错误类型
enum SynologyAPIError: Error {
    case apiError(code: Int, message: String)
    case loginFailed(code: Int, message: String)
    case noSession
    case networkError(Error)
}

extension SynologyAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            return "API Error \(code): \(message)"
        case .loginFailed(let code, let message):
            return "Login Failed \(code): \(message)"
        case .noSession:
            return "No active session"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - 使用示例
class NASManager {
    private let client: SynologyNASClient
    
    init(nasURL: String) {
        self.client = SynologyNASClient(baseURL: nasURL)
    }
    
    func performLogin() {
        print("正在登录...")
        
        client.login(username: "your_username", password: "your_password") { [weak self] result in
            switch result {
            case .success(let sessionId):
                print("登录成功！Session ID: \(sessionId)")
                
                // 检查登录状态
                if self?.client.isLoggedIn() == true {
                    print("当前已登录")
                }
                
            case .failure(let error):
                if let synologyError = error as? SynologyAPIError {
                    print("登录失败: \(synologyError.errorDescription ?? "Unknown error")")
                } else {
                    print("网络错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func performLoginWithOTP(otpCode: String) {
        client.login(username: "your_username", password: "your_password", otpCode: otpCode) { result in
            switch result {
            case .success(let sessionId):
                print("两步验证登录成功！Session ID: \(sessionId)")
            case .failure(let error):
                print("登录失败: \(error.localizedDescription)")
            }
        }
    }
    
    func performLogout() {
        client.logout { result in
            switch result {
            case .success:
                print("已成功登出")
            case .failure(let error):
                print("登出失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 链式登录示例
    func performChainedLogin() {
        client.getApiInfo { result in
            switch result {
            case .success(let apiInfo):
                print("获取API信息成功: \(apiInfo.keys)")
                
                self.client.login(username: "admin", password: "password") { loginResult in
                    switch loginResult {
                    case .success(_):
                        print("登录成功，开始执行其他操作...")
                        // 在这里执行需要登录的操作
                        
                    case .failure(let error):
                        print("登录失败: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                print("获取API信息失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 便捷扩展
extension SynologyNASClient {
    // 快捷登录方法
    static func quickLogin(baseURL: String, username: String, password: String, otpCode: String? = nil, completion: @escaping (Result<SynologyNASClient, Error>) -> Void) {
        let client = SynologyNASClient(baseURL: baseURL)
        
        client.login(username: username, password: password, otpCode: otpCode) { result in
            switch result {
            case .success:
                completion(.success(client))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 带重试的登录方法
    func loginWithRetry(username: String, password: String, otpCode: String? = nil, maxRetries: Int = 3, completion: @escaping LoginCompletion) {
        performLoginWithRetry(username: username, password: password, otpCode: otpCode, currentRetry: 0, maxRetries: maxRetries, completion: completion)
    }
    
    private func performLoginWithRetry(username: String, password: String, otpCode: String?, currentRetry: Int, maxRetries: Int, completion: @escaping LoginCompletion) {
        login(username: username, password: password, otpCode: otpCode) { result in
            switch result {
            case .success(let sessionId):
                completion(.success(sessionId))
                
            case .failure(let error):
                if currentRetry < maxRetries {
                    print("登录失败，正在重试... (\(currentRetry + 1)/\(maxRetries))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.performLoginWithRetry(username: username, password: password, otpCode: otpCode, currentRetry: currentRetry + 1, maxRetries: maxRetries, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
}




/*
 let client = SynologyNASClient(baseURL: "http://192.168.1.100:5000")

 client.login(username: "admin", password: "password") { result in
     switch result {
     case .success(let sessionId):
         print("登录成功，Session ID: \(sessionId)")
     case .failure(let error):
         print("登录失败: \(error)")
     }
 }
 
 client.login(username: "admin", password: "password", otpCode: "123456") { result in
     switch result {
     case .success(let sessionId):
         print("两步验证登录成功")
     case .failure(let error):
         print("登录失败: \(error)")
     }
 }
 
 SynologyNASClient.quickLogin(baseURL: "http://192.168.1.100:5000", username: "admin", password: "password") { result in
     switch result {
     case .success(let client):
         print("快捷登录成功")
         // 使用 client 进行后续操作
     case .failure(let error):
         print("登录失败: \(error)")
     }
 }
 
 
 
 
 
 
 
 
 
 
 
 
 let client = SynologyNASClient(baseURL: "http://192.168.1.100:5000")

 Task {
     do {
         let sessionId = try await client.login(username: "admin", password: "password")
         print("登录成功，Session ID: \(sessionId)")
     } catch {
         print("登录失败: \(error)")
     }
 }
 
 
 let sessionId = try await client.login(username: "admin", password: "password", otpCode: "123456")
 
 
 let client = try await SynologyNASClient.quickLogin(
     baseURL: "http://192.168.1.100:5000",
     username: "admin",
     password: "password"
 )
 
 
 */
