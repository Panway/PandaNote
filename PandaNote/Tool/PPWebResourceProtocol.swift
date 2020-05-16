//
//  PPWebResourceProtocol.swift
//  PandaNote
//
//  Created by panwei on 2020/4/29.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import UIKit
import WebKit

private let FilteredKey = "FilteredKey"

// 替换web图片
class PPReplacingImageURLProtocol : URLProtocol {
    //    private var _task: URLSessionTask
    //    override var task: URLSessionTask? { return _task }
    
    //    init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
    //        _task = task
    //        super.init(request: task.originalRequest!, cachedResponse: cachedResponse, client: client)
    //    }
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    // 返回true表明我们要拦截这个请求（可以处理指定的请求）
    override class func canInit(with request: URLRequest) -> Bool {
//        let `extension` = request.url?.pathExtension
        // 对处理过请求打上唯一标识符 customKey 的属性，避免循环处理
        if URLProtocol.property(forKey: FilteredKey, in: request) != nil {
            debugPrint("=====重复的不处理")
            return false
        }
        
        guard let `extension` = request.url?.pathExtension else { return false}
        debugPrint("=\(`extension`) in <\(String(describing: request.url))>")
        if let absoluteString = request.url?.absoluteString {
            if !PPUserInfo.shared.pp_WebViewResource.contains(absoluteString) {
                PPUserInfo.shared.pp_WebViewResource.insert(absoluteString, at: 0)
            }
        }
        return false//返回false就不会执行下面的替换操作！！！
        /*
        let isImage = (["png", "jpeg", "gif", "jpg"] as NSArray).indexOfObject(passingTest: { obj, idx, stop in
            return `extension`.compare(obj as? String ?? "", options: .caseInsensitive, range: nil, locale: .current) == .orderedSame
        }) != NSNotFound
        return isImage
 */
    }

    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    // 把自己制造的数据传递给请求者（客户端）
    override func startLoading() {
        guard let request = self.request as? NSMutableURLRequest else { return }
        //该方法允许您向给定的 URL 请求添加自定义属性。 通过这种方式，你可以通过附加一个属性来标记它，浏览器就会知道它以前是否看到过这个属性
        URLProtocol.setProperty(true, forKey: FilteredKey, in: request)
//        let path = Bundle.main.path(forResource: "cat", ofType:"jpg")
        let data = try?Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory()+"/Documents/246x0w.png" ))
        guard let requesturl = self.request.url else { return }
        let response = URLResponse(url: requesturl, mimeType: "image/png", expectedContentLength: data?.count ?? 0,textEncodingName: nil)
//        guard let client = client else { return }
        self.client?.urlProtocol(self,didReceive: response,cacheStoragePolicy: .allowed)
        if let data = data {
            self.client?.urlProtocol(self, didLoad: data)
        }
        
        self.client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
    }
    
}















// 返回测试的假数据。mock意为 “虚假、虚设”，我们也可以将其理解成 “虚假数据”，或者 “真实数据的替身”
//https://enlab.github.io/ios/xcode/swift/2017/08/06/build-a-proxy-on-ios/

//其他可参考的 https://wigl.github.io/2018/02/21/WKWebView/
//https://www.raywenderlich.com/2292-using-nsurlprotocol-with-swift#toc-anchor-007
//https://www.hackingwithswift.com/articles/153/how-to-test-ios-networking-code-the-easy-way
class PPMockProtocol: URLProtocol {
    var dataTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: "is_handled", in: request) as? Bool == true {
            return false
        }
        return true
    }
    override func startLoading() {
        debugPrint(#function)
        
        // #1
        guard let stream = request.httpBodyStream else { return }
        stream.open()
        guard let payload = try? JSONSerialization.jsonObject(with: stream, options: []) as? [String: Any] else { return }
        
        // #2
        let wrapper = [
            "data": payload,
        ]
        
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "is_handled", in: mutableRequest)
        var newRequest = mutableRequest as URLRequest
        
        // #3
        newRequest.httpBody = try? JSONSerialization.data(withJSONObject: wrapper, options: [])
        
        dataTask = URLSession.shared.dataTask(with: newRequest, completionHandler: { data, response, error in
            
            if let data = data, let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
            } else if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        })
        dataTask?.resume()
    }
    //override
    override func stopLoading() {
        self.dataTask?.cancel()
    }
    
}
