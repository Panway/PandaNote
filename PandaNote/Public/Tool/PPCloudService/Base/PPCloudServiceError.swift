//
//  PPCloudServiceError.swift
//  PandaNote
//
//  Created by pan on 2024/2/18.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation

class PPCloudServiceBaseModel{

    var error : PPCloudServiceError!
    var success : Bool!


    /**
     * Instantiate the instance using the passed dictionary values to set the properties values
     */
//    init(fromDictionary dictionary: [String:Any]){
//        if let errorData = dictionary["error"] as? [String:Any]{
//            error = PPCSError(fromDictionary: errorData)
//        }
//        success = dictionary["success"] as? Bool
//    }

}

class PPCSError{

    var code : Int!


    /**
     * Instantiate the instance using the passed dictionary values to set the properties values
     */
    init(fromDictionary dictionary: [String:Any]){
        code = dictionary["code"] as? Int
    }

}

extension PPCloudServiceError {

    /// 把 PPCloudHTTP 的网络层错误翻译成 App 自己的云盘错误
    /// 为什么要翻译：PPCloudHTTP 只知道「超时 / 403 / 证书过期」，界面关心的是「该提示重试、该让用户重新登录，还是干脆没权限」，两边说的不是一种话
    static func from(httpError: PPCloudHTTPError?) -> PPCloudServiceError {
        guard let httpError = httpError else {
            // 没有网络层错误，却还是走到这里，只能当未知错误处理
            return .unknown
        }
        switch httpError {
        case .timeout, .networkError, .badGateway:
            // 连不上、超时、网关挂了，用户能做的只有换网络或者过会儿再试，都归成一类
            return .serverUnreachable
        case .forbidden:
            return .permissionDenied
        case .notFound:
            return .fileNotExist
        case let .clientError(code):
            // 4xx 是请求本身有问题，其中 401 最特殊，说明登录态失效了，调用方可以据此触发重新登录
            switch code {
            case 401: return .accessTokenExpired
            case 403: return .permissionDenied
            case 404: return .fileNotExist
            default: return .unknown
            }
        case let .unknown(error):
            return fromURLError(error)
        default:
            // 5xx 和 invalidResponse 都算服务端自己出问题，重试就行，不单独区分
            return .unknown
        }
    }

    /// URLError 里藏着比「未知错误」更具体的原因，PPCloudHTTP 统一塞进 .unknown，这里再拆一次
    private static func fromURLError(_ error: Error) -> PPCloudServiceError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorDNSLookupFailed:
                return .serverUnreachable
            case NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                return .certificateInvalid
            default:
                break
            }
        }
        // 有的证书错误会被 Alamofire 再包一层，拿不到 URLError，只能从错误描述里的 -9814 / -9807 认出来
        let detail = String(describing: error)
        if detail.contains("-9814") || detail.contains("-9807") {
            return .certificateInvalid
        }
        return .unknown
    }
}
