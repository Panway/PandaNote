//
//  PPDouyinParser.swift
//  PandaNote
//
//  Created by pan on 2023/11/20.
//  Copyright © 2023 Panway. All rights reserved.
//  感谢 https://github.com/iawia002/lux
//  感谢 createCookie https://github.com/iawia002/lux/commit/103df6f319a1c631a5110f2ca1b1ba03612a1514
//  抖音换新的API了 https://github.com/iawia002/lux/issues/1184
//  感谢ChatGPT将上面go语言代码转换成swift代码：

import Foundation
import Alamofire
import JavaScriptCore

class PPDouyinParser {

    class func executeJavaScriptScript(_ param1 : String, _ param2: String) -> String {
        // 创建JavaScriptContext
        let context = JSContext()
        let path = Bundle.main.path(forResource: "sign", ofType:"js")
        let consolejs = try? String(contentsOfFile: path ?? "", encoding: .utf8)

        // 定义JavaScript脚本
        let script = consolejs //"function add(x, y) { return x + y; };"

        // 执行JavaScript脚本
        context?.evaluateScript(script)

        // 调用JavaScript函数
        if let addFunction = context?.objectForKeyedSubscript("sign") {
            if let result = addFunction.call(withArguments: [param1, param2]) {
                print("Result of add function: \(result)")
                return result.toString()
            }
        }
        return ""
    }

    // 调用示例

    
    // 2022年无水印解析来自：https://gist.github.com/d1y/cf8e21a1ad36b582e70da2941e624ea9
    /// 解析抖音无水印视频并下载V1
    class func downLoadDouYinVideoWithoutWaterMark(_ id: String,_ douyinRedirectURL: String) {
//        let parameters = ["item_ids": id]
//        let url2022 = "https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/"
        let userAgent = "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Mobile Safari/537.36 Edg/87.0.664.66"
        let sign = executeJavaScriptScript("aweme_id=\(id)", userAgent)
        let url202311 = "https://www.douyin.com/aweme/v1/web/aweme/detail/?aweme_id=\(id)&X-Bogus=\(sign)"
        let headers: HTTPHeaders =
        ["User-Agent": userAgent,
         "Referer" : douyinRedirectURL,
         "Cookie": createCookie()]
        AF.request(url202311,headers: headers).responseData { response in
            guard let jsonDic = response.data?.pp_JSONObject() else { return }
            jsonDic.printJSON()
//            debugPrint("==========\()")
            //目的：取jsonDic["item_list"][0]["video"]["play_addr"]["url_list"][0]
            //2023 取jsonDic["aweme_detail"]["video"]["play_addr"]
            guard let aweme_detail = jsonDic["aweme_detail"] else {
                return
            }
//            let array:Array = item_list as! Array<Any>
            let user = DouyinItem(JSON:aweme_detail as! [String : Any] )
            if let videoURL = user?.video?.playAddr?.urlList?[0] {
                debugPrint(videoURL)
                let videoURLWithoutWaterMark = videoURL.replacingOccurrences(of: "playwm", with: "play")
                PPWebFileViewController.downloadVideo(url: videoURLWithoutWaterMark)
                //HTTP HEAD 方法 请求资源的头部信息, 并且这些头部与 HTTP GET 方法请求时返回的一致. 该请求方法的一个使用场景是在下载一个大文件前先获取其大小再决定是否要下载, 以此可以节约带宽资源.
                // https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Methods/HEAD
//                AF.request(videoURL, method: .head, headers: headers).responseString { response in
//                    if let realVideoURL = response.response?.allHeaderFields["Location"] {
//                        debugPrint("无水印地址: \(realVideoURL)")
//                    }
//                }
            }
            
        }
        
    }
    
    

    class func createCookie() -> String {
        do {
            let v1 = try msToken(107)
            let v2 = try ttwid()
            let v3 = "324fb4ea4a89c0c05827e18a1ed9cf9bf8a17f7705fcc793fec935b637867e2a5a9b8168c885554d029919117a18ba69"
            let v4 = "eyJiZC10aWNrZXQtZ3VhcmQtdmVyc2lvbiI6MiwiYmQtdGlja2V0LWd1YXJkLWNsaWVudC1jc3IiOiItLS0tLUJFR0lOIENFUlRJRklDQVRFIFJFUVVFU1QtLS0tLVxyXG5NSUlCRFRDQnRRSUJBREFuTVFzd0NRWURWUVFHRXdKRFRqRVlNQllHQTFVRUF3d1BZbVJmZEdsamEyVjBYMmQxXHJcbllYSmtNRmt3RXdZSEtvWkl6ajBDQVFZSUtvWkl6ajBEQVFjRFFnQUVKUDZzbjNLRlFBNUROSEcyK2F4bXAwNG5cclxud1hBSTZDU1IyZW1sVUE5QTZ4aGQzbVlPUlI4NVRLZ2tXd1FJSmp3Nyszdnc0Z2NNRG5iOTRoS3MvSjFJc3FBc1xyXG5NQ29HQ1NxR1NJYjNEUUVKRGpFZE1Cc3dHUVlEVlIwUkJCSXdFSUlPZDNkM0xtUnZkWGxwYmk1amIyMHdDZ1lJXHJcbktvWkl6ajBFQXdJRFJ3QXdSQUlnVmJkWTI0c0RYS0c0S2h3WlBmOHpxVDRBU0ROamNUb2FFRi9MQnd2QS8xSUNcclxuSURiVmZCUk1PQVB5cWJkcytld1QwSDZqdDg1czZZTVNVZEo5Z2dmOWlmeTBcclxuLS0tLS1FTkQgQ0VSVElGSUNBVEUgUkVRVUVTVC0tLS0tXHJcbiJ9"
            
            let cookie = String(format: "msToken=%@;ttwid=%@;odin_tt=%@;bd_ticket_guard_client_data=%@;", v1, v2, v3, v4)
            return cookie
        } catch {
            return ""
        }
    }

    class func msToken(_ length: Int) throws -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let randomBytes = try generateRandomBytes(length)
        
        var token = ""
        for b in randomBytes {
            let index = Int(b) % characters.count
            token.append(characters[characters.index(characters.startIndex, offsetBy: index)])
        }
        
        return token
    }

    class func generateRandomBytes(_ length: Int) throws -> [UInt8] {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
        
        return randomBytes
    }

    class func ttwid() throws -> String {
        let body: [String: Any] = [
            "aid": 1768,
            "union": true,
            "needFid": false,
            "region": "cn",
            "cbUrlProtocol": "https",
            "service": "www.ixigua.com",
            "migrate_info": ["ticket": "", "source": "node"]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let payload = String(data: jsonData, encoding: .utf8)!
        
        guard let resp = try request("https://ttwid.bytedance.com/ttwid/union/register/", method: "POST", payload: payload) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "douyin ttwid request failed"])
        }
        
        guard let cookie = resp.allHeaderFields["Set-Cookie"] as? String,//resp.value(forHTTPHeaderField: "Set-Cookie"),
                let match = try? extractTTWID(from: cookie) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "douyin ttwid extraction failed"])
        }
        
        return match
    }

    class func extractTTWID(from cookie: String) throws -> String {
        let regex = try NSRegularExpression(pattern: "ttwid=([^;]+)", options: [])
        let matches = regex.matches(in: cookie, options: [], range: NSRange(location: 0, length: cookie.utf16.count))
        
        if let match = matches.first, let range = Range(match.range(at: 1), in: cookie) {
            return String(cookie[range])
        } else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "douyin ttwid extraction failed"])
        }
    }

    class func request(_ url: String, method: String, payload: String) throws -> HTTPURLResponse? {
        guard let url = URL(string: url) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = payload.data(using: .utf8)
        
        let semaphore = DispatchSemaphore(value: 0)
        var response: HTTPURLResponse?
        
        URLSession.shared.dataTask(with: request) { (_, httpResponse, _) in
            response = httpResponse as? HTTPURLResponse
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return response
    }
}
