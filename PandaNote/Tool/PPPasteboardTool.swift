//
//  PPClipboardTool.swift
//  PandaNote
//
//  Created by panwei on 2020/4/15.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
import Kanna
import Alamofire

/// 字符串分割取前面的，eg："小爱同学调戏天猫精灵集锦_哔哩哔哩" -> "小爱同学调戏天猫精灵集锦"
/// - Parameters:
///   - s: 原始字符串
///   - separator: 分隔符，如`-`
fileprivate func getStringSeparatedBy(_ s:String, _ separator:String,_ removeLast:Bool?=true) -> String {
    var array = s.components(separatedBy: separator)
    if array.count > 1 {
        if removeLast == true {
            array.removeLast()//移除分隔符后面的，取前
        }
        else {
            array.remove(at: 0)//移除分隔符前面的，取后
        }
        return array.joined(separator: " ")
    }
    else {
        return s
    }
}

fileprivate let removeParamList = ["smzdm.com", "okjike.com", "weibointl.api.weibo.com", "weibo.com"]
fileprivate let sanitizerRules = ["mobile.yangkeduo.com": "goods_id"]
fileprivate var userActions = ["🍀去微信分享","🌏打开网页"]
fileprivate var douyinVideoID = "" //抖音视频ID
fileprivate var currentURL = ""
class PPPasteboardTool: NSObject {
    // URL链接防跟踪、消毒、只保留必要参数
    class func urlNoTracking(_ url:String) -> String {
        var urlString = url
        //去掉URL问号后面的参数
        let results = removeParamList.filter { urlString.contains($0)}
        if results.count > 0 {
            urlString = urlString.split(string: "?")[0]
        }
        //只提取必要参数
        let paramKey = sanitizerRules[urlString.pp_getDomain()] ?? ""
        let paramValue = urlString.pp_valueOf(paramKey) ?? ""
        if paramValue.length > 0 {
            urlString = urlString.split(string: "?")[0] + "?\(paramKey)=\(paramValue)"
        }
        return urlString
    }
    
    class func getMoreInfomationOfURL() {
//        UIPasteboard.general.string = "http://v.douyin.com/mLjjtL/ 抖音的测试链接"
//        UIPasteboard.general.string = "https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other"
        guard let input = UIPasteboard.general.string else { return }
        debugPrint("剪切板内容=\(input)")
        if input == PPAppConfig.shared.getItem("PPLastPasteBoardContent") {
            return
        }
//        let input = "https://m.weibo.cn/1098618600/4494272029733190"
//        let input = "This is a test with the URL https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other to be detected."
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector = detector else { return }
        let matches = detector.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        var urlString = ""
        for match in matches {
            guard let range = Range(match.range, in: input) else { continue }
            let url = input[range]
            urlString = String(url)
            break // only match FIRST URL 仅匹配第一个URL
        }
        if matches.count > 1 {
            PPHUD.showHUDFromTop("URL太多，已为你解析第一个URL")
        }
        urlString = urlNoTracking(urlString)
        debugPrint("消毒后的URL:\(urlString)")
        currentURL = urlString
        AF.request(urlString).responseJSON { response in
            //不为空检查
            guard let data = response.data, let utf8Text = String(textData: data) else {
                return
            }
            //使用模拟器的时候，保存到自己电脑下载文件夹查看（pan是当前电脑用户名）
#if DEBUG
            try? data.write(to: URL(fileURLWithPath: "/Users/pan/Downloads/PP_TEST.html", isDirectory: false))
#endif
                
//                debugPrint("Data: \(utf8Text)")
            if PPPasteboardTool.getWebInfo(urlString) {
                
            }
            
            var title = PPPasteboardTool.getHTMLTitle(html: utf8Text,originURL: urlString)
            title = title + "\n" + urlString
            UIPasteboard.general.string = title
            PPAppConfig.shared.setItem("PPLastPasteBoardContent", title)
            debugPrint("新的分享内容:" + title)
            if urlString.contains("v.douyin.com") {
                userActions.append("⬇️下载抖音无水印视频")
                douyinVideoID = response.response?.url?.pathComponents.last ?? ""
                //重定向后的URL,https://www.iesdouyin.com/share/video/6736813535613013260/ ...
            }
            PPPasteboardTool.showAlert()
        }
        
        
    }
    
    class func getAttributedContentFromPasteboard() -> NSAttributedString? {
        if let pasteboardData = UIPasteboard.general.data(forPasteboardType: .init("public.html")),
           let attributedString = try? NSAttributedString(data: pasteboardData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            return attributedString
        }
        return nil
    }
    
    class func getHTMLFromPasteboard() -> NSAttributedString? {
        guard let pasteboardData = UIPasteboard.general.data(forPasteboardType: .init("public.html")) else {
            return nil
        }
        
        guard let doc = try? HTML(html: pasteboardData, encoding: .utf8),
              var body = doc.body else {
            debugPrint("copy content is not html data")
            return nil
        }
        let h1s = body.css("h1", namespaces: nil)
        for var element in h1s {
            element.content = "# " + (element.content ?? "")
            element["style"] = ""
        }
        
        let h2 = body.css("h2", namespaces: nil)
        for var element in h2 {
            element.content = "## " + (element.content ?? "")
            element["style"] = ""
        }
        
        let htmlStr = body.innerHTML
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let new_data = htmlStr?.data(using: .utf8),
           let attributedString = try? NSAttributedString(data: new_data, options: options, documentAttributes: nil) {
#if DEBUG
            try? new_data.write(to: URL(fileURLWithPath: NSHomeDirectory() + "/Library/PandaNote/UIPasteboard_after.html", isDirectory: false))
            try? pasteboardData.write(to: URL(fileURLWithPath: NSHomeDirectory() + "/Library/PandaNote/UIPasteboard.html", isDirectory: false))
#endif
            return attributedString
        }
        return nil
    }
    
    class func getHTMLTitle(html:String,originURL:String) -> String {
        var result = ""
        if let doc = try? HTML(html: html, encoding: .utf8) {
            if originURL.contains("mp.weixin.qq.com/s") {
                for link in doc.css("#activity-name") {
                    result = link.text ?? ""
                }
            }
            else if originURL.contains("www.smzdm.com/p") {
                //如果是什么值得买网站
                result = ""
                for node in doc.xpath("/html/head/meta") {
                    guard let metaC = node.toXML else {
                        continue
                    }
                    if metaC.contains("og:title") {
                        debugPrint(metaC)
                        if let metaArray = metaC.split(string: "content=").last {
                            result = metaArray.replacingOccurrences(of: "\"", with: "")
                        }
                        else {
                            result = doc.title ?? ""
                        }
                        result = getStringSeparatedBy(result,"_")
                        break
                    }
                }
            }
            else if (originURL.contains("weibointl.api.weibo.com") || originURL.contains("share.api.weibo.cn")) {//微博国际版解析正文内容
                for link in doc.css(".weibo-text") {
                    result = link.text ?? ""
                }
            }
            else if originURL.contains("//github.com") {
                result = doc.title ?? ""
                result = getStringSeparatedBy(result,"-",false)
            }
            else {
                result = doc.title ?? ""
                result = getStringSeparatedBy(result,"-")
                result = getStringSeparatedBy(result,"_")
            }
        }
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "\n", with: "")
//        if originURL.contains("b23.tv") || originURL.contains("bilibili.com") {
//            result = result.split(string: "_哔哩哔哩").first ?? ""
//        }
        if originURL.contains("m.weibo.cn") {
            let results = html.pp_matches(for: "text(.*),\n")
            guard let res0 = results.first else { return "" }
            var weiboString = res0.replacingOccurrences(of: "text\": \"", with: "")
            weiboString = weiboString.replacingOccurrences(of: "\",\n", with: "")
            if let doc = try? HTML(html: weiboString, encoding: .utf8) {
                result = doc.text ?? ""
            }
        }
        debugPrint("链接主要内容 URL content:",result)
        return result
    }
    
    class func getWebInfo(_ originURL: String) -> Bool {
        if (originURL.contains("https://weibo.com")) {
            let weibo_id = originURL.pp_split("/").last ?? ""
            AF.request("https://weibo.com/ajax/statuses/show?id=\(weibo_id)").responseJSON { response in
                // debugPrint("weibo.com \(response.value ?? "")")
                guard let jsonDic = response.value as? [String : Any] else { return }
                if let text_raw = jsonDic["text_raw"] as? String {
                    UIPasteboard.general.string = text_raw + "\n" + originURL
                    PPAppConfig.shared.setItem("PPLastPasteBoardContent", text_raw + "\n" + originURL)
                }
            }
            return true
        }
        return false
    }
    
    class func showAlert() {
        PPAlertAction.showSheet(withTitle: "是否去微信粘贴", message: "", cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: userActions) { (index) in
            debugPrint("==\(index)")
            if (index == 1) {
                if let weixin = URL(string: "wechat://") {
                    UIApplication.shared.open(weixin, options: [:], completionHandler: nil)
                }
            }
            else if (index == 2) {
                let vc = PPWebViewController()
                vc.urlString = currentURL
                UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
            }
            else if (index == 3) {
                //let results = utf8Text.pp_matches(for: "//s3.{1,80}reflow_video.*.js")
                //guard let res0 = results.first else { return }
                PPPasteboardTool.downLoadDouYinVideoWithoutWaterMark(id: douyinVideoID)
            }
        }
    }
    
     
    // 无水印解析来自：https://gist.github.com/d1y/cf8e21a1ad36b582e70da2941e624ea9
    /// 解析抖音无水印视频并下载V1
    class func downLoadDouYinVideoWithoutWaterMark(id:String) {
        let parameters = ["item_ids": id]
//        let headers: HTTPHeaders = ["User-Agent":"Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.25 Mobile Safari/537.36"]
        AF.request("https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/", parameters: parameters).responseJSON { response in
            guard let value = response.value else {
                return
            }
            let jsonDic:Dictionary = value as! Dictionary<String, Any>
            //目的：取jsonDic["item_list"][0]["video"]["play_addr"]["url_list"][0]
            guard let item_list = jsonDic["item_list"] else {
                return
            }
            let array:Array = item_list as! Array<Any>
            let user = DouyinItem(JSON:array.first as! [String : Any] )
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
    
    
    
}
