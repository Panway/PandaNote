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
    /// 确定协议子类是否可以处理指定的请求，对处理过请求打上唯一标识符 customKey 的属性，避免循环处理
    override class func canInit(with request: URLRequest) -> Bool {
//        let `extension` = request.url?.pathExtension
        guard let `extension` = request.url?.pathExtension else { return false}
        debugPrint("====\(`extension`) in <\(String(describing: request.url))>")
        if let absoluteString = request.url?.absoluteString {
            if !PPUserInfo.shared.pp_WebViewResource.contains(absoluteString) {
                PPUserInfo.shared.pp_WebViewResource.insert(absoluteString, at: 0)
            }
        }
        let isImage = (["png", "jpeg", "gif", "jpg"] as NSArray).indexOfObject(passingTest: { obj, idx, stop in
            return `extension`.compare(obj as? String ?? "", options: .caseInsensitive, range: nil, locale: .current) == .orderedSame
        }) != NSNotFound
        return URLProtocol.property(forKey: FilteredKey, in: request) == nil && isImage
    }

    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let request:NSMutableURLRequest = self.request as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(true, forKey: FilteredKey, in: request)
//        let path = Bundle.main.path(forResource: "cat", ofType:"jpg")
        let data = try?Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory()+"/Documents/246x0w.png" ))
        guard let requesturl = self.request.url else { return }
        let response = URLResponse(
            url: requesturl,
            mimeType: "image/png",
            expectedContentLength: data?.count ?? 0,
            textEncodingName: nil)
        guard let client = client else { return }
        client.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .allowed)
        if let data = data {
            client.urlProtocol(self, didLoad: data)
        }
        client.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
    }
}


