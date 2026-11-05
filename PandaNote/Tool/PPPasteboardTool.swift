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

fileprivate struct PPParseHTMLOptions: OptionSet {
    let rawValue: Int
    static let useDataSrcInImg = PPParseHTMLOptions(rawValue: 1 << 0)
    static let relativeToAbsoluteInImg = PPParseHTMLOptions(rawValue: 1 << 1)
    static let executable = PPParseHTMLOptions(rawValue: 1 << 2)
    static let compressed = PPParseHTMLOptions(rawValue: 1 << 3)
}
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

fileprivate let removeParamList = ["smzdm.com",
                                   "okjike.com",
                                   "weibointl.api.weibo.com",
                                   "weibo.com",
                                   "item.m.jd.com",
                                   "item.jd.com",
                                   "xiaohongshu.com"]
fileprivate let sanitizerRules = ["mobile.yangkeduo.com": "goods_id"]
fileprivate var userActions = ["🍀消毒后微信分享","🌏打开网页"]
fileprivate var douyinVideoID = "" //抖音视频ID
fileprivate var douyinRedirectURL = ""
fileprivate var currentURL = ""
fileprivate var title_intro = "" ///< 标题和链接
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
    @discardableResult
    class func getURLFromPasteboard() -> String {
//        UIPasteboard.general.string = "http://v.douyin.com/mLjjtL/ 抖音的测试链接"
//        UIPasteboard.general.string = "https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other"
        guard let input = UIPasteboard.general.string else { return "" }
//        debugPrint("剪切板内容=\(input)")
        if input == PPAppConfig.shared.getItem("PPLastPasteBoardContent") {
            return ""
        }
        //        let input = "https://m.weibo.cn/1098618600/4494272029733190"
        //        let input = "This is a test with the URL https://www.smzdm.com/p/20405394/?send_by=3716913905&from=other to be detected."
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector = detector else { return ""}
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
//        debugPrint("去除追踪参数的URL:\(urlString)")
        currentURL = urlString
        return urlString
    }
    
    class func getMoreInfomationOfURL() {
        guard let input = UIPasteboard.general.string else { return }
//        debugPrint("剪切板内容=\(input)")
        if input == PPAppConfig.shared.getItem("PPLastPasteBoardContent") {
            return
        }
        if getURLFromPasteboard().length < 1 {
            return
        }
        let url = getURLFromPasteboard()
        var title = ""
        if url.length > 0 {
            title = "检测到链接，请选择以继续"
        }
        if currentURL.contains("v.douyin.com") && userActions.count < 3 {
            userActions.append("⬇️下载抖音无水印视频")
        }
        else if currentURL.hasPrefix("https://mp.weixin.qq.com/s") {
//            userActions.append("保存公众号文章为Markdown")
        }
        if(title.length == 0) { return }
        PPPasteboardTool.showAlert(title,url)
    }
    class func getHTMLSourceCode(urlStr:String, completion: ((String) -> Void)? = nil) {
        var urlString = urlStr
        if urlString == "" {
            urlString = currentURL
        }
        AF.request(urlString).responseData { response in
            //不为空检查
            guard let data = response.data, let utf8Text = String(textData: data) else {
                return
            }
            //使用模拟器的时候，保存到自己电脑下载文件夹查看（pan是当前电脑用户名）
#if DEBUG
            try? data.write(to: URL(fileURLWithPath: "/Users/pan/Downloads/tmp_TEST.html", isDirectory: false))
#endif
                
//                debugPrint("Data: \(utf8Text)")
            if PPPasteboardTool.getWebInfo(urlString) {
                
            }
            
            var title = PPPasteboardTool.getHTMLTitle(html: utf8Text,originURL: urlString)
            title_intro = title + "\n" + urlString
            
            if urlString.contains("v.douyin.com") {
                douyinVideoID = response.response?.url?.pathComponents.last ?? ""
                douyinRedirectURL = response.response?.url?.absoluteString ?? ""
            }
            //重定向后的URL,https://www.iesdouyin.com/share/video/6736813535613013260/ ...
            completion?(utf8Text)
        }
    }
    
    class func getAttributedContentFromPasteboard() -> NSAttributedString? {
        if let pasteboardData = UIPasteboard.general.data(forPasteboardType: .init("public.html")),
           let attributedString = try? NSAttributedString(data: pasteboardData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            return attributedString
        }
        return nil
    }
    class func parseArticleContent(url: String, completion: @escaping((NSAttributedString) -> Void)) {
        getHTMLSourceCode(urlStr: url) { sourceCode in
            var result = ""
            if let doc = try? HTML(html: sourceCode, encoding: .utf8) {
                if url.hasPrefix("https://mp.weixin.qq.com/s") {
                    var titleHTML = ""
                    for link in doc.css("#activity-name") {
                        titleHTML = link.toHTML ?? ""
                    }
                    for var link in doc.css("#js_content") {
                        link["visibility"] = ""
                        result = link.toHTML ?? ""
                        result = "原文链接:" + url + titleHTML + "<br>" + result // 标题+内容
                        let att = parseHTMLCode(result, parseOption: [PPParseHTMLOptions.useDataSrcInImg])
                        completion(att ?? "".pp_attributed)
                    }
                }
            }
            
        }
    }
    
    class func getHTMLFromPasteboard(str: String? = nil) -> NSAttributedString? {
        if let pasteboardData = UIPasteboard.general.data(forPasteboardType: .init("public.rtf"))  {
            // 将 RTF 数据转换为 NSAttributedString
            do {
                let attributedString = try NSAttributedString(data: pasteboardData,
                                                              options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                              documentAttributes: nil)
                // 将 NSAttributedString 转换为 HTML 格式的数据
                let htmlData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                         documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
                
                if let htmlString = String(data: htmlData, encoding: .utf8) {
                    debugPrint("HTML 内容: \(htmlString)")
                    return parseHTMLCode(htmlString, parseOption: [])
                }
                
            } catch {
                debugPrint("转换 RTF 到 HTML 失败: \(error)")
            }
            
            
            return parseHTMLCode(String(data: pasteboardData, encoding: .utf8) ?? "", parseOption: [])
        }
        guard let pasteboardData = UIPasteboard.general.data(forPasteboardType: .init("public.html")) else {
            return UIPasteboard.general.string?.pp_attributed
        }
        return parseHTMLCode(String(data: pasteboardData, encoding: .utf8) ?? "", parseOption: [])
    }

    /// 将剪贴板里的 HTML 片段转换成 Markdown 源码。
    ///
    /// 思路：用 Kanna 解析成 DOM，然后**递归遍历**直接产出 Markdown 文本，
    /// 不再把结果塞回 HTML 交给 NSAttributedString 二次渲染。这样：
    /// - 嵌套结构（列表 / 引用 / 行内强调）靠递归天然保住，不会塌陷；
    /// - 代码块内容原样输出、不进 HTML 解析器，`< > &` 不会被吃掉；
    /// - 表格按行列拼字符串，不再残留 `<table>` 结构；
    /// - 返回值是**纯文本** NSAttributedString，调用方只取 `.string`，无字体/颜色污染。
    ///
    /// 签名与调用点与旧实现保持一致。
    fileprivate class func parseHTMLCode(_ pasteboardData: String, parseOption:[PPParseHTMLOptions]) -> NSAttributedString? {
        guard let doc = try? HTML(html: pasteboardData, encoding: .utf8) else {
            debugPrint("copy content is not html data")
            return nil
        }
        // 调用点传的是 [PPParseHTMLOptions]（数组），这里合并成单个 OptionSet。
        let mergedOptions = parseOption.reduce(into: PPParseHTMLOptions(rawValue: 0)) { $0.formUnion($1) }
        let converter = PPHTML2Markdown(options: mergedOptions)
        // 优先用 <body>；粘贴的 HTML 片段经 libxml 解析后也会自动补出 body。
        let markdown: String
        if let body = doc.body {
            markdown = converter.convert(root: body)
        } else {
            // 兜底：拿不到 body 时退回纯文本，至少不丢字。
            markdown = doc.text ?? ""
        }

#if DEBUG
        let home = NSHomeDirectory() + "/Library/PandaNote/"
        try? pasteboardData.data(using: .utf8)?.write(to: URL(fileURLWithPath: home + "UIPasteboard.html", isDirectory: false))
        try? markdown.data(using: .utf8)?.write(to: URL(fileURLWithPath: home + "UIPasteboard_after.md", isDirectory: false))
#endif
        return NSAttributedString(string: markdown)
    }

    /// 历史实现（保留备查）：改 DOM 文本再塞回 HTML 渲染成富文本。
    /// 已被下方基于递归遍历的 parseHTMLCode 取代，缺陷见 PPDoc/PPMDTextView_CodeReview.md。
    fileprivate class func parseHTMLCodeV1(_ pasteboardData: String, parseOption:[PPParseHTMLOptions]) -> NSAttributedString? {
        guard let doc = try? HTML(html: pasteboardData, encoding: .utf8) else {
            debugPrint("copy content is not html data")
            return nil
        }
        let body = doc

        // h1 - h6 的内容加#转换成markdown文本
        for i in 1...6 {
            let h_tags = body.css("h\(i)")
            for var element in h_tags {
                element.content = "\(String(repeating: "#", count: i)) " + (element.content ?? "")
                element["style"] = ""
            }
        }
        //行内代码
        let code = body.css("code")
        for var element in code {
            element["style"] = ""
            if element.parent?.tagName != "pre" {
                element.content = "`\(element.content ?? "")`"
            }
        }
        // 链接
        let a = body.css("a")
        for var element in a {
            element.content = "[\(element.content ?? "")](\(element["href"] ?? ""))"
            element["style"] = ""
        }
        // 图片
        let img = body.css("img")
        for var element in img {
            var img_src = ""
            if parseOption.contains(.useDataSrcInImg) {
                img_src = element["data-src"] ?? ""
                element["src"] = element["data-src"]
                element["data-src"] = ""
            }
            else {
                img_src = element["src"] ?? ""
            }
            var img_desc = element.content ?? ""
            if let alt = element["alt"], img_desc == "" {
                img_desc = alt
            }
            element.content = "![\(img_desc)](\(img_src))"
            element["style"] = ""
        }
        // 加粗
        let strong = body.css("strong")
        for var element in strong {
            element.content = "**\(element.content ?? "")**"
            element["style"] = ""
        }
        // 斜体
        let em = body.css("em")
        for var element in em {
            element.content = "*\(element.content ?? "")*"
            element["style"] = ""
        }
        // 引用
        let blockquote = body.css("blockquote")
        for var element in blockquote {
            element.content = "> \(element.content ?? "")==pandanote_break====pandanote_break=="
            element["style"] = ""
        }
        // 无序列表
        let uls = body.css("ul")
        
        for var ul in uls {
            ul["style"] = ""

            let lis = ul.css("li")
            for var li in lis {
                li.content = "- " + (li.content ?? "")
                li["style"] = ""
//                if let newxml = try? XML(xml: "<div id=\"pandanote\"><div>li.content</div></div>", encoding: String.Encoding.utf8),
//                let newth = newxml.at_css("#pandanote") {
//                    debugPrint("=========",newth.innerHTML)
//                    debugPrint("=========",li.parent?.innerHTML)
//                    li = newth
//                    debugPrint("=========",li.innerHTML)
//                }
            }
        }
        // 有序列表
        let ols = body.css("ol")
        for ol in ols {
            if ol.parent?.tagName == "pre" {
                continue //pre里面包含ol的话，不加序号
            }
            let lis = ol.css("li")
            for i in 0..<lis.count {
                var li = lis[i]
                li.content = "\(i+1). " + (li.content ?? "")
            }
        }
        // 表格
        let tables = body.css("table")
        for var table in tables {
            table["style"] = ""
            let trs = table.css("tr")
            
            for i in 0..<trs.count {
                var tr = trs[i]
                tr["style"] = ""
                let ths = tr.css("th")
                let tds = tr.css("td")
                
                
                var markdown = ""
                for i in 0..<ths.count {
                    var th = ths[i]
                    th["style"] = ""
                    if i == ths.count - 1 {
                        markdown += "| " + (th.content ?? "") + " | ==pandanote_break== " + "\(String(repeating: "| --- ", count: ths.count)) |"
                        th.content = "\(markdown)"
                        // 我只是想创建一个元素
//                        if let doc = try? XML(xml: "<div id=\"pandanote\"><span>\(markdown)</span></div>", encoding: String.Encoding.utf8),
//                        let newth = doc.at_css("#pandanote") {
//                            th = newth
//                        }
                    }
                    else {
                        markdown += "| " + (th.content ?? "")
                        th.content = ""
                    }
                }
                
                var td_str = ""
                for i in 0..<tds.count {
                    var td = tds[i]
                    td["style"] = ""
                    if i == tds.count - 1 {
                        td_str += "| " + (td.content ?? "") + " |"
                        td.content = "\(td_str)"
                    }
                    else {
                        td_str += "| " + (td.content ?? "")
                        td.content = ""
                    }
                }
            }
        }
        
        var htmlStr = body.innerHTML
        htmlStr = htmlStr?.replacingOccurrences(of: "<pre", with: "<div>```</div><br><pre")
        htmlStr = htmlStr?.replacingOccurrences(of: "/pre>", with: "/pre><br><div>```</div>")
        htmlStr = htmlStr?.replacingOccurrences(of: "<td style=\"\"></td>", with: "")
        htmlStr = htmlStr?.replacingOccurrences(of: "==pandanote_break==", with: "<br>")
        htmlStr = htmlStr?.replacingOccurrences(of: "<ul", with: "<div")
        htmlStr = htmlStr?.replacingOccurrences(of: "</ul>", with: "</div>")
        htmlStr = htmlStr?.replacingOccurrences(of: "<ol", with: "<div")
        htmlStr = htmlStr?.replacingOccurrences(of: "</ol>", with: "</div>")
        htmlStr = htmlStr?.convertImgTagsToMarkdown()
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let new_data = htmlStr?.data(using: .utf8),
           let attributedString = try? NSAttributedString(data: new_data, options: options, documentAttributes: nil) {
#if DEBUG
            try? new_data.write(to: URL(fileURLWithPath: NSHomeDirectory() + "/Library/PandaNote/UIPasteboard_after.html", isDirectory: false))
            try? pasteboardData.data(using: .utf8)?.write(to: URL(fileURLWithPath: NSHomeDirectory() + "/Library/PandaNote/UIPasteboard.html", isDirectory: false))
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
    //复制的内容是富文本或网页内容
    class func copyContentsIsAttributeString() -> Bool {
        let items = UIPasteboard.general.items
        for item in items {
            for (key, _) in item {
                if key == "public.html" || key == "public.rtf" {
                    debugPrint("pasteboard is rtf")
                    return true
                }
            }
        }
        debugPrint("pasteboard is plain text")
        return false
    }
    class func getWebInfo(_ originURL: String) -> Bool {
        if (originURL.contains("https://weibo.com")) {
            let weibo_id = originURL.pp_split("/").last ?? ""
            AF.request("https://weibo.com/ajax/statuses/show?id=\(weibo_id)").responseData { response in
                // debugPrint("weibo.com \(response.value ?? "")")
                guard let jsonDic = response.data?.pp_JSONObject() else { return }
                if let text_raw = jsonDic["text_raw"] as? String {
                    UIPasteboard.general.string = text_raw + "\n" + originURL
                    PPAppConfig.shared.setItem("PPLastPasteBoardContent", text_raw + "\n" + originURL)
                }
            }
            return true
        }
        return false
    }
    
    class func showAlert(_ title:String, _ url: String?) {
        PPAlertAction.showSheet(withTitle: "选择想要的操作", message: "", cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: userActions) { (index) in
            debugPrint("==\(index)")
            if (index == 1) {
                getHTMLSourceCode(urlStr: currentURL) { _ in
                    UIPasteboard.general.string = title_intro
                    PPAppConfig.shared.setItem("PPLastPasteBoardContent", title_intro)
                    debugPrint("新的分享内容:" + title_intro)
                    if let weixin = URL(string: "wechat://") {
                        UIApplication.shared.open(weixin, options: [:], completionHandler: nil)
                    }
                }
            }
            else if (index == 2) {
                let vc = PPWebViewController()
                vc.urlString = getURLFromPasteboard()
                UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
            }
            else if (index == 3) {
                //let results = utf8Text.pp_matches(for: "//s3.{1,80}reflow_video.*.js")
                //guard let res0 = results.first else { return }
                getHTMLSourceCode(urlStr: currentURL) {_ in
                    PPDouyinParser.downLoadDouYinVideoWithoutWaterMark(douyinVideoID, douyinRedirectURL)
                }
            }
            else if (index == 0) {
                // 取消
                PPAppConfig.shared.setItem("PPLastPasteBoardContent", UIPasteboard.general.string ?? "")
            }
        }
    }
    
     
    

    
    
}

// MARK: - HTML → Markdown 递归转换器

/// 基于 Kanna DOM 的递归序列化器：把 HTML 直接转成 Markdown 文本。
/// 与旧实现最大的区别是——不再修改 DOM、也不再回灌 HTML，而是一遍遍历直接产出字符串，
/// 因此嵌套、缩进、代码原文都能完整保留。
fileprivate struct PPHTML2Markdown {
    let options: PPParseHTMLOptions

    // 块级标签：它们之间用空行分隔。
    private static let blockTags: Set<String> = [
        "p", "div", "section", "article", "header", "footer", "main", "aside", "nav",
        "ul", "ol", "li", "blockquote", "pre", "table", "thead", "tbody", "tfoot",
        "tr", "td", "th", "figure", "figcaption", "caption",
        "h1", "h2", "h3", "h4", "h5", "h6", "hr",
        "form", "fieldset", "dl", "dt", "dd", "details", "summary"
    ]

    /// 顶层入口：把 root（一般是 <body>）转成 Markdown。
    func convert(root: Kanna.XMLElement) -> String {
        return cleanup(blocks(of: root).joined(separator: "\n\n"))
    }

    // MARK: 块级

    /// 遍历一个容器的直接子节点，产出若干「块」，调用方用空行拼接。
    /// 容器里散落的行内内容（文本 / <span> / <a> 等）会被累积成一个段落。
    private func blocks(of node: Kanna.XMLElement) -> [String] {
        var result: [String] = []
        var pendingInline = ""   // 累积裸行内内容

        func flushPending() {
            let trimmed = collapseWhitespace(pendingInline).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { result.append(trimmed) }
            pendingInline = ""
        }

        for child in children(of: node) {
            let tag = child.tag
            if tag == "text" {
                pendingInline += normalizeText(child.node.text ?? "")
                continue
            }
            if tag == "comment" { continue }

            if PPHTML2Markdown.blockTags.contains(tag) {
                flushPending()
                if let block = blockMarkdown(child), !block.isEmpty {
                    result.append(block)
                }
            } else {
                // 块级容器里直接出现的行内元素 → 归入当前段落
                pendingInline += inlineMarkdown(child)
            }
        }
        flushPending()
        return result
    }

    /// 单个块级元素 → Markdown。
    private func blockMarkdown(_ child: Node) -> String? {
        let tag = child.tag
        let node = child.node

        // 标题 h1~h6
        if tag.hasPrefix("h"), tag.count == 2, let level = Int(tag.dropFirst()), (1...6).contains(level) {
            let text = inlineMarkdown(child).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return nil }
            return String(repeating: "#", count: level) + " " + text
        }

        switch tag {
        case "hr":
            return "---"
        case "p":
            let text = inlineMarkdown(child).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        case "blockquote":
            let inner = blocks(of: node).joined(separator: "\n\n")
            return inner.isEmpty ? nil : prefixQuote(inner)
        case "pre":
            return preMarkdown(node)
        case "ul":
            return listMarkdown(node, ordered: false)
        case "ol":
            return listMarkdown(node, ordered: true)
        case "table":
            return tableMarkdown(node)
        case "figure", "figcaption", "div", "section", "article", "header", "footer",
             "main", "aside", "nav", "form", "fieldset", "details", "summary",
             "dl", "dd", "dt", "thead", "tbody", "tfoot":
            // 透明容器：直接把子块摊平
            let inner = blocks(of: node).joined(separator: "\n\n")
            return inner.isEmpty ? nil : inner
        default:
            // 其它未知块：当作容器递归
            let inner = blocks(of: node).joined(separator: "\n\n")
            if !inner.isEmpty { return inner }
            let text = inlineMarkdown(child).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    /// 有序 / 无序列表。支持多级嵌套（按 marker 宽度缩进）与任务列表。
    private func listMarkdown(_ node: Kanna.XMLElement, ordered: Bool) -> String? {
        // 起始编号（<ol start="3">）
        var index = 1
        if ordered, let startStr = node["start"], let s = Int(startStr.trimmingCharacters(in: .whitespaces)) {
            index = s
        }

        var lines: [String] = []
        for child in children(of: node) where child.tag == "li" {
            let marker: String
            var indentWidth: Int
            if let task = taskMarker(for: child.node) {
                marker = task              // "- [x]" / "- [ ]"
                // 任务项的项目符号仍是 "-"，内容列在第 2 列，嵌套列表按 2 空格缩进。
                indentWidth = 2
            } else if ordered {
                marker = "\(index)."
                indentWidth = marker.count + 1
                index += 1
            } else {
                marker = "-"
                indentWidth = 2
            }
            lines.append(listItemMarkdown(child.node, marker: marker, indentWidth: indentWidth))
        }
        let joined = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }

    /// 单个 <li>：先导内容（文本 / 段落 / 行内元素），再挂上缩进后的嵌套列表。
    private func listItemMarkdown(_ li: Kanna.XMLElement, marker: String, indentWidth: Int) -> String {
        var leading = ""
        var nested: [String] = []

        for child in children(of: li) {
            switch child.tag {
            case "text":
                leading += normalizeText(child.node.text ?? "")
            case "comment", "input":
                continue
            case "ul", "ol":
                if let sub = (child.tag == "ol")
                    ? listMarkdown(child.node, ordered: true)
                    : listMarkdown(child.node, ordered: false) {
                    nested.append(sub)
                }
            case "p":
                // <li><p>xxx</p></li>：段落内容并入本项（松散列表也压成一行，够用）
                leading += inlineMarkdown(child)
            case "blockquote", "pre", "table", "div", "figure":
                if let b = blockMarkdown(child), !b.isEmpty { nested.append(b) }
            default:
                leading += inlineMarkdown(child)
            }
        }

        let head = marker + " " + collapseWhitespace(leading).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nested.isEmpty else { return head }
        let pad = String(repeating: " ", count: indentWidth)
        let nestedText = nested.joined(separator: "\n")
        return head + "\n" + indentLines(nestedText, pad: pad)
    }

    /// 检测任务列表项，返回 "- [x]" / "- [ ]"；不是任务项返回 nil。
    private func taskMarker(for li: Kanna.XMLElement) -> String? {
        for child in children(of: li) where child.tag == "input" {
            if (child.node["type"] ?? "").lowercased() == "checkbox" {
                // checked="" 时属性存在（值为空串），未选中时属性缺失（nil）
                let checked = child.node["checked"] != nil
                return checked ? "- [x]" : "- [ ]"
            }
        }
        return nil
    }

    /// 代码块：<pre><code>…</code></pre> → ```lang\n原文\n```。
    /// 代码原文用 .text 取（实体已解码），直接输出、不再进 HTML 解析器，避免 < > & 被破坏。
    private func preMarkdown(_ pre: Kanna.XMLElement) -> String? {
        let codeNode = pre.xpath(".//code").first ?? pre
        var body = codeNode.text ?? ""
        if body.hasPrefix("\n") { body.removeFirst() }
        while body.hasSuffix("\n") { body.removeLast() }
        if body.isEmpty { return nil }

        var lang = ""
        if let cls = codeNode["class"] {
            for token in cls.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                if token.hasPrefix("language-") { lang = String(token.dropFirst("language-".count)); break }
                if token.hasPrefix("lang-") { lang = String(token.dropFirst("lang-".count)); break }
            }
        }
        if lang.isEmpty { lang = codeNode["lang"] ?? "" }

        let fence = body.contains("```") ? "~~~" : "```"
        return "\(fence)\(lang)\n\(body)\n\(fence)"
    }

    /// 表格 → GFM 表格（含对齐）。
    private func tableMarkdown(_ table: Kanna.XMLElement) -> String? {
        let trs = table.xpath(".//tr")
        guard trs.count > 0 else { return nil }

        var grid: [[String]] = []
        var aligns: [String] = []
        for (rowIdx, tr) in trs.enumerated() {
            let cells = tr.xpath("./th | ./td")
            var row: [String] = []
            for cell in cells {
                row.append(escapeCell(inlineMarkdown(Node(node: cell, tag: (cell.tagName ?? "").lowercased()))))
                if rowIdx == 0 { aligns.append(cellAlignment(cell)) }
            }
            grid.append(row)
        }
        guard let colCount = grid.map({ $0.count }).max(), colCount > 0 else { return nil }

        // 补齐每行到相同列数
        for i in 0..<grid.count {
            while grid[i].count < colCount { grid[i].append("") }
        }
        while aligns.count < colCount { aligns.append("---") }

        func rowLine(_ cells: [String]) -> String { "| " + cells.joined(separator: " | ") + " |" }

        var out: [String] = []
        out.append(rowLine(grid[0]))
        out.append("| " + aligns.joined(separator: " | ") + " |")
        for r in grid.dropFirst() { out.append(rowLine(r)) }
        return out.joined(separator: "\n")
    }

    private func cellAlignment(_ cell: Kanna.XMLElement) -> String {
        let style = (cell["style"] ?? "").lowercased()
        if let range = style.range(of: "text-align:\\s*(left|right|center)", options: .regularExpression) {
            let value = style[range]
            if value.contains("right") { return "---:" }
            if value.contains("center") { return ":---:" }
            if value.contains("left") { return ":---" }
        }
        return "---"
    }

    private func escapeCell(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "\\|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: 行内

    /// 单个行内节点 → Markdown（按 tag 分派，内容通过 innerText 递归子节点）。
    private func inlineMarkdown(_ child: Node) -> String {
        let tag = child.tag
        let node = child.node

        switch tag {
        case "text":
            return normalizeText(node.text ?? "")
        case "comment":
            return ""
        case "br":
            return "  \n"   // 硬换行
        case "strong", "b":
            return wrap(innerText(child), "**")
        case "em", "i":
            return wrap(innerText(child), "*")
        case "del", "s", "strike":
            return wrap(innerText(child), "~~")
        case "code":
            let raw = node.text ?? ""
            if raw.isEmpty { return "" }
            // 内容含反引号时用双反引号并留空格，符合 GFM
            return raw.contains("`") ? "`` \(raw) ``" : "`\(raw)`"
        case "a":
            let text = innerText(child).trimmingCharacters(in: .whitespacesAndNewlines)
            let href = (node["href"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if href.isEmpty { return text }
            let label = text.isEmpty ? href : text
            return "[\(label)](\(href))"
        case "img":
            var src = node["src"] ?? ""
            if options.contains(.useDataSrcInImg), let ds = node["data-src"], !ds.isEmpty { src = ds }
            let alt = node["alt"] ?? ""
            if src.isEmpty { return "" }
            return "![\(alt)](\(src))"
        case "input":
            return ""   // 复选框在 listItemMarkdown 里处理
        default:
            // span / sup / sub / u / font / p（行内上下文）等：透明处理，递归子节点
            return innerText(child)
        }
    }

    /// 把一个节点的所有混合子节点（文本 + 元素，按文档顺序）的行内内容拼起来。
    private func innerText(_ node: Node) -> String {
        var out = ""
        for c in children(of: node.node) {
            out += inlineMarkdown(c)
        }
        return out
    }

    private func wrap(_ inner: String, _ mark: String) -> String {
        let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        return mark + trimmed + mark
    }

    // MARK: 通用工具

    /// 统一的子节点访问：用 ./node() 拿到「文本 + 元素」的有序混合子节点。
    private func children(of node: Kanna.XMLElement) -> [Node] {
        var result: [Node] = []
        for raw in node.xpath("./node()") {
            let name = (raw.tagName ?? "").lowercased()
            let kind: String
            switch name {
            case "text", "cdata", "#text": kind = "text"
            case "comment", "#comment":   kind = "comment"
            default:                       kind = name
            }
            result.append(Node(node: raw, tag: kind))
        }
        return result
    }

    /// HTML 里换行和缩进只是排版，行内统一折叠成单个空格。
    private func normalizeText(_ text: String) -> String {
        return collapseWhitespace(text)
    }

    private func collapseWhitespace(_ text: String) -> String {
        return text.replacingOccurrences(of: "[\\s]+", with: " ", options: .regularExpression)
    }

    private func prefixQuote(_ text: String) -> String {
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
    }

    private func indentLines(_ text: String, pad: String) -> String {
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "\(pad)\($0)" }
            .joined(separator: "\n")
    }

    /// 收尾：压缩 3 个以上连续换行为 2 个，去掉首尾空白。
    private func cleanup(_ text: String) -> String {
        var out = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out + "\n"
    }

    /// 轻量包装：把 Kanna 节点和它归一化后的 tag 一起带着走。
    private struct Node {
        let node: Kanna.XMLElement
        let tag: String
    }
}

extension String {
    /*
     感谢ChatGPT：
     1. swift如何将<img src="https://e.com/1.jpg"/>123<img src="https://e.com/2.jpg"/>
     转换成![](https://e.com/1.jpg)123![](https://e.com/2.jpg)
     2. 下面的代码在匹配并替换结果后，由于原始文本长度变化，导致后面的替换失败，如何修改？
     */
    // "<img\\s+src=\"(.*?)\".*?>" `\\s`表示空白字符
    func convertImgTagsToMarkdown() -> String {
        let regexPattern = "<img[^>]+src=\"(.*?)\"[^>]*>"
        let regex = try! NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
        var result = self
        
        var offset = 0 // 用于跟踪偏移量
        
        regex.enumerateMatches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) { (match, _, stop) in
            guard let match = match else { return }
            
            let imgTagRange = match.range
            let imgTag = (self as NSString).substring(with: imgTagRange)
//            debugPrint("===========tag:", imgTag)
            
            if let firstSrc = imgTag.extractImgUrl() {
//                debugPrint("===========匹配出", firstSrc)
                let markdownImage = "<p>![](\(firstSrc))</p>"
                
//                let startIndex = self.index(self.startIndex, offsetBy: imgTagRange.location + offset)
//                let endIndex = self.index(startIndex, offsetBy: imgTagRange.length)
                
                // 使用 NSString 的 `replacingCharacters(in:with:)` 替换
                let nsString = NSMutableString(string: result)
                nsString.replaceCharacters(in: NSRange(location: imgTagRange.location + offset, length: imgTagRange.length), with: markdownImage)
                
                result = nsString as String
                
                // 更新偏移量
                let lengthDifference = markdownImage.utf16.count - imgTagRange.length
                offset += lengthDifference
            }
        }
        
        return result
    }
    
    func extractImgUrls() -> [String] {
        var imgUrls = [String]()
        let pattern = #"src="(https?://[^\s]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
            let matches = regex.matches(in: self, options: [], range: nsRange)
            for match in matches {
                if let range = Range(match.range(at: 1), in: self) {
                    imgUrls.append(String(self[range]))
                }
            }
        }
        return imgUrls
    }
    
    func extractImgUrl() -> String? {
        // " src=\"(.*)\""
        let regex = try! NSRegularExpression(pattern: " src=\"([^\\s]+)\"", options: .caseInsensitive)
        if let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            if let range = Range(match.range(at: 1), in: self) {
                return String(self[range])
            }
            return nil
        }
        return nil
    }
}
