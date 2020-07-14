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

class PPPasteboardTool: NSObject {
    class func getMoreInfomationOfURL() {
//        UIPasteboard.general.string = "https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other"
        guard let input = UIPasteboard.general.string else { return }
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
        }
        
        //去掉URL问号后面的参数
        if urlString.contains("smzdm.com") {
            urlString = urlString.split(string: "?")[0]
        }
        
        debugPrint(urlString)
        AF.request(urlString).responseJSON { response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
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
                            UIApplication.shared.openURL(weixin)
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
        if let doc = try? HTML(html: html, encoding: .utf8) {
            return doc.title ?? ""
        }
        return ""
    }
    
    
    
    
    
}
