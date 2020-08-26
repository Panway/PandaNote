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
fileprivate func getStringSeparatedBy(_ s:String, _ separator:String) -> String {
    var array = s.components(separatedBy: separator)
    if array.count > 1 {
        array.removeLast()
        return array.joined(separator: " ")
    }
    else {
        return s
    }
}

class PPPasteboardTool: NSObject {
    class func getMoreInfomationOfURL() {
//        UIPasteboard.general.string = "https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other"
        guard let input = UIPasteboard.general.string else { return }
        debugPrint("剪切板内容=\(input)")
        if let lastPasteContent : String = PPUserInfo.shared.pp_Setting["PPLastPasteBoardContent"] as? String {
            if input == lastPasteContent {
                return
            }
            
        }
//        let input = "https://m.weibo.cn/1098618600/4494272029733190"

//        let input = "This is a test with the URL https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other to be detected."
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        var urlString = ""
        for match in matches {
            guard let range = Range(match.range, in: input) else { continue }
            let url = input[range]
            urlString = String(url)
            break
        }
        if matches.count > 1 {
            PPHUD.showHUDFromTop("URL太多，已为你解析第一个URL")
        }
        //去掉URL问号后面的参数
        if urlString.contains("smzdm.com") || urlString.contains("okjike.com") {
            urlString = urlString.split(string: "?")[0]
        }
        
        debugPrint(urlString)
        AF.request(urlString).responseJSON { response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                //使用模拟器的时候，保存到自己电脑下载文件夹查看（pan是当前电脑用户名）
                #if DEBUG
                try? data.write(to: URL(fileURLWithPath: "/Users/pan/Downloads/PP_TEST.html", isDirectory: false))
                #endif
                
//                debugPrint("Data: \(utf8Text)")
                var title = PPPasteboardTool.getHTMLTitle(html: utf8Text,originURL: urlString)
                title = title + "\n" + urlString
                UIPasteboard.general.string = title
                PPUserInfo.shared.pp_Setting.updateValue(title, forKey: "PPLastPasteBoardContent")
                debugPrint("新的分享内容====" + title)
                PPAlertAction.showSheet(withTitle: "是否去微信粘贴", message: "", cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["🍀去微信分享","🌏打开网页"]) { (index) in
                    debugPrint("==\(index)")
                    if (index == 1) {
                        if let weixin = URL(string: "wechat://") {
                            UIApplication.shared.open(weixin, options: [:], completionHandler: nil)
                        }
                    }
                    else if (index == 2) {
                        let vc = PPWebViewController()
                        vc.urlString = urlString
                        UIViewController.topViewControllerForKeyWindow()?.navigationController?.pushViewController(vc, animated: true)
                    }
                }
                
            }
        }
        
        
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
        debugPrint(result)
        return result
    }
    
    
    
    
}
