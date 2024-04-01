//
//  String+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2021/11/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation

extension String {
    /// 将字符串通过特定的字符串拆分为字符串数组
    ///
    /// - Parameter string: 拆分数组使用的字符串
    /// - Returns: 字符串数组
    func pp_split(_ separator:String) -> [String] {
        return self.components(separatedBy: separator)
//        method 2
//        let str = "abc/def/ghi"
//        let arr = str.split(separator: "/").map(String.init)
        
//        method 3
//        let str = "abc/def/ghi"
//        let arr = str.indices.filter { str[$0] == "/" }.map { str[str.startIndex..< $0] }
//        arr.append(str[str.lastIndex(of: "/")!, str.endIndex])

    }
    ///将十六进制颜色转换为UIColor
    public func pp_HEXColor() -> UIColor {
        var hexStr = self
        if self.starts(with: "#") {
            hexStr = hexStr.split(separator: "#").last.map(String.init) ?? hexStr
        }
        
        var red:UInt32 = 0, green:UInt32 = 0, blue:UInt32 = 0
        var alpha:CGFloat = 1.0
        Scanner(string: hexStr[0..<2]).scanHexInt32(&red)
        Scanner(string: hexStr[2..<4]).scanHexInt32(&green)
        Scanner(string: hexStr[4..<6]).scanHexInt32(&blue)
        if hexStr.length == 8 {
            var alphaValue:UInt32 = 255
            Scanner(string: hexStr[6..<8]).scanHexInt32(&alphaValue)
            alpha = CGFloat(alphaValue) / 255.0
        }
        return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: alpha)
    }

    
    /// 插入字符
    /// - Parameters:
    ///   - text: 字符
    ///   - index: 位置
    /// - Returns: self
    mutating func insertCharacter(text:Character,index:Int) -> String{
        let start = self.index(self.startIndex, offsetBy: index)
        self.insert(text, at: start)
        return self
    }
    /// 插入字符串
    /// - Parameters:
    ///   - text: 字符串
    ///   - index: 位置
    /// - Returns: self
    mutating func insertString(text:String,index:Int) -> String{
        let start = self.index(self.startIndex, offsetBy: index)
        self.insert(contentsOf: text, at: start)
        return self
    }
    func pp_substring(fromIndex: Int) -> String {
        guard fromIndex < self.count else { return "" }
        let startIndex = self.index(self.startIndex, offsetBy: fromIndex)
        return String(self[startIndex...])
    }
    
    /// 根据指定宽度计算文本高度
    /// - Parameters:
    ///   - font: UIFont
    ///   - fixedWidth: 指定宽度
    /// - Returns: height
    func pp_calcTextHeight(font : UIFont = UIFont.systemFont(ofSize: 18), fixedWidth : CGFloat) -> CGFloat {
        guard self.count > 0 && fixedWidth > 0 else {
            return 0
        }
        //let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        //let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = CGSize(width:fixedWidth, height:CGFloat.greatestFiniteMagnitude)
        let text = self as NSString
        let rect = text.boundingRect(with: size, options:.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : font], context:nil)
        return rect.size.height
    }
    
    /// 获取文本宽度
    /// - Parameter font: 字体
    /// - Returns: 宽度
    func pp_calcTextWidth(font : UIFont = UIFont.systemFont(ofSize: 17)) -> CGFloat {
        guard self.count > 0 else {
            return 0
        }
        let size = CGSize(width:CGFloat.greatestFiniteMagnitude, height:0)
        let text = self as NSString
        let rect = text.boundingRect(with: size, options:.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : font], context:nil)
        return rect.size.width
    }
    
    public var pp_encodedURL: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
    /// 去除字符串开头的连续的某个字符
    func pp_removeLeadingCharacter(_ character: Character) -> String {
        var result = self
        while let firstCharacter = result.first, firstCharacter == character {
            result.removeFirst()
        }
        return result
    }
    
    func toCGFloat() -> CGFloat {
        guard let doubleValue = Double(self) else {
            return 0.0 //nil
        }
        return CGFloat(doubleValue)
    }
    
    private func toCGFloat2() -> CGFloat {
        if let n = NumberFormatter().number(from: self) {
            return CGFloat(n.floatValue)
        }
        else {
            return CGFloat(0)
        }
    }
    
}

// MARK: - URL 相关处理
extension String {
    func pp_getDomain() -> String {
        guard let urlComponents = URLComponents(string: self), let host = urlComponents.host else {
            return ""
        }
        return host //host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    func pp_extractFileNameFromURL() -> String {
        // 查找 "http" 开头的字符串
//        if self.hasPrefix("http") {
            // 分割字符串，获取最后一个路径组件
            let components = self.components(separatedBy: "/")
            if let lastComponent = components.last {
                // 去除文件扩展名
//                let fileName = (lastComponent as NSString).deletingPathExtension
                let res = lastComponent.pp_split("?")
                    if res.count > 1 {
                    return res.first ?? ""
                }
                return lastComponent
            }
//        }
        return ""
    }
}
