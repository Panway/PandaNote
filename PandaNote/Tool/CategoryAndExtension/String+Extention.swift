//
//  StringExtention.swift
//  XiZhuStore
//
//  Created by wangyongxin on 2018/11/13.
//  Copyright © 2018 xiuLu. All rights reserved.
//

import Foundation
import UIKit
import CommonCrypto

//MARK: 字符串扩展工具
extension String {
    var pp_md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    func substring(_ r: Range<Int>) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
        let toIndex = self.index(self.startIndex, offsetBy: r.upperBound)
        let indexRange = Range<String.Index>(uncheckedBounds: (lower: fromIndex, upper: toIndex))
        return String(self[indexRange])
    }
    func pp_isImageFile() -> Bool { if(self.lowercased().hasSuffix("jpg")||self.lowercased().hasSuffix("jpeg")||self.lowercased().hasSuffix("png")||self.lowercased().hasSuffix("gif")||self.lowercased().hasSuffix("webp")) {
        return true
        }
        return false
    }
    //MARK: 布尔值
    var bool: Bool {
        switch self.lowercased() {
        case "true", "t", "yes", "y", "1":
            return true
        case "false", "f", "no", "n", "0":
            return false
        default:
            return false
        }
    }

    
    
    
    
    
    
    
    //MARK: 密码
    func isVaildPassword() -> Bool {
        return self.count > 5
    }
    //MARK: 验证码
    func isVaildVerify() -> Bool {
        return self.count < 7  &&  self.count > 3
    }
    
    // MARK: 获取app的名字
    static func getAPPName() -> String{
        let nameKey = "CFBundleName"
        let appName = Bundle.main.object(forInfoDictionaryKey: nameKey) as? String   //这里也是坑，请不要翻译oc的代码，而是去NSBundle类里面看它的api
        return appName!
    }
    // MARK: 获取app的版本
    static func getAPPVersion() -> String{
        let versionKey = "CFBundleShortVersionString"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: versionKey) as? String
        return appVersion!
    }
    
    //MARK:获取工程名
    static func getAppProjectName()  -> String{
        let projectName = Bundle.main.object(forInfoDictionaryKey: "kCFBundleExecutableKey") as? String
        return projectName!
    }
    
    //MARK: 设备识别
    //    func getDeviceID() -> String? {
    //        let uuidStr =  SSKeychain.password(forService: appBundleID, account: appBundleID)
    //        if (uuidStr != "") && (uuidStr != nil)  {
    //            return uuidStr!
    //        }else{
    //            let str = UUID.init().uuidString
    //            let isSuccess = SSKeychain.setPassword(str, forService: appBundleID, account: appBundleID)
    //            if isSuccess{
    //                return str
    //            }else{
    //                print("储存失败")
    //            }
    //        }
    //        return nil
    //    }
    
    
    ///是否是邮箱
    public var isEmail: Bool {
        return range(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", options: .regularExpression, range: nil, locale: nil) != nil
    }
    /// 是否是URL
    public var isValidUrl: Bool {
        return URL(string: self) != nil
    }
    
    //MARK: 正则效验手机号
    func isTelNumber()->Bool {
        let mobile = "^1(3[0-9]|5[0-35-9]|8[025-9])\\d{8}$"
        let  CM = "^1(34[0-8]|(3[5-9]|5[017-9]|8[278])\\d)\\d{7}$"
        let  CU = "^1(3[0-2]|5[256]|8[56])\\d{8}$"
        let  CT = "^1((33|53|8[09])[0-9]|349)\\d{7}$"
        let regextestmobile = NSPredicate(format: "SELF MATCHES %@",mobile)
        let regextestcm = NSPredicate(format: "SELF MATCHES %@",CM )
        let regextestcu = NSPredicate(format: "SELF MATCHES %@" ,CU)
        let regextestct = NSPredicate(format: "SELF MATCHES %@" ,CT)
        if ((regextestmobile.evaluate(with: self) == true)
            || (regextestcm.evaluate(with: self)  == true)
            || (regextestct.evaluate(with: self) == true)
            || (regextestcu.evaluate(with: self) == true))
        {
            return true
        }else{
            return false
        }
    }
    
    //MARK: 正则效验手机号 首位 和 11位
    func isVaildTelNumber() -> Bool {
        let mobile = "^1\\d{10}$"
        let regextestmobile = NSPredicate(format: "SELF MATCHES %@",mobile)
        if regextestmobile.evaluate(with: self) == true{
            return true
        }else{
            return false
        }
    }
    
    //MARK: 获取ip地址
    func getLocalIPAddressForCurrentWiFi() -> String? {
        var address: String?
        // get list of all interfaces on the local machine
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else {
            return nil
        }
        guard let firstAddr = ifaddr else {
            return nil
        }
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            
            let interface = ifptr.pointee
            
            // Check for IPV4 or IPV6 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                // Check interface name
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    
                    // Convert interface address to a human readable string
                    var addr = interface.ifa_addr.pointee
                    var hostName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostName, socklen_t(hostName.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostName)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    //MARK:  将十六进制颜色转换为UIColor
    func HEXColor() -> UIColor {
        // 存储转换后的数值
        var red:UInt32 = 0, green:UInt32 = 0, blue:UInt32 = 0
        // 分别转换进行转换
        Scanner(string: self[0..<2]).scanHexInt32(&red)
        
        Scanner(string: self[2..<4]).scanHexInt32(&green)
        
        Scanner(string: self[4..<6]).scanHexInt32(&blue)
        
        return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
    }
    
    
    //银行卡格式化
    public func formateForBankCard(joined: String = " ") -> String {
        guard self.count > 0 else {
            return self
        }
        let length: Int = self.count
        let count: Int = length / 4
        var data: [String] = []
        for i in 0..<count {
            let start: Int = 4 * i
            let end: Int = 4 * (i + 1)
            data.append(self[start..<end])
        }
        if length % 4 > 0 {
            data.append(self[4 * count..<length])
        }
        let result = data.joined(separator: " ")
        return result
    }
    
    /// base64编码
    var base64: String {
        let plainData = (self as NSString).data(using: String.Encoding.utf8.rawValue)
        let base64String = plainData!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        return base64String
    }
    /// Base64解码
    public var base64Decode: String? {
        
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
}



//MARK:字符串操作
extension String {
    
    /**
     截取字符串
     - Parameter startIndex: 起始索引点
     - Parameter endIndex:   结束索引点（最终字符串中不会包含该字符）
     - Returns: 返回指定截取的字符串
     */
    func slice2333(startIndex: Int = 0, endIndex: Int = Int.max) -> String {
        var str = ""
        var start = startIndex, end = endIndex
        let count = self.length
        if start < 0 {
            if start < -count {
                start = -count
            }
            start += count
        }
        if end < 0 {
            end += count
        }
        else if end > count {
            end = count
        }
        if end >= start {
            let index = self.index(self.startIndex, offsetBy: (start - 0))..<self.index(self.startIndex, offsetBy: end - 0)
            str = String(self[index])
        }
        return str
    }
    
    /**
     截取字符串
     - Parameter startIndex: 起始索引点
     - Parameter len:   截取的字符串长度
     - Returns: 返回指定截取的字符串
     */
    func substr2333(startIndex: Int = 0, len: Int = Int.max) -> String {
        var str = ""
        var start = startIndex, end = len
        let count = self.length
        if end > count {
            end = count
        }
        if start < 0 {
            if start < -count {
                start = -count
            }
            start += count
        }
        end += start
        if end > count {
            end = count
        }
        if start < count {
            let index = self.index(self.startIndex, offsetBy: (start - 0))..<self.index(self.startIndex, offsetBy: end - 0)
            str = String(self[index])
        }
        return str
    }
    
    /**
     截取字符串
     - Parameter startIndex: 起始索引点
     - Parameter endIndex:   结束索引点（最终字符串中不会包含该字符）
     - Returns: 返回指定截取的字符串
     */
    func substring2333(startIndex: Int = 0, endIndex: Int = Int.max) -> String {
        var str = ""
        var start = startIndex, end = endIndex
        let count = self.length
        if start < 0 {
            start = 0
        }
        if end < 0 {
            end = 0
        }
        if start > end {
            let tmp = end
            end = start
            start = tmp
        }
        if end > count {
            end = count
        }
        if start < count {
            let index = self.index(self.startIndex, offsetBy: (start - 0))..<self.index(self.startIndex, offsetBy: end - 0)
            str = String(self[index])
        }
        return str
    }
    
    /**
     检查指定索引处的字符
     - Parameter index: 字符串中指定的索引值
     - Returns:  返回指定位置字符，默认为空字符
     */
    func charAt(index: Int) -> String {
        let count = self.length
        var str = "" //if str is a character, it is Illegal
        if index >= 0 && index <= count - 1{
            let index = self.index(self.startIndex, offsetBy: index)..<self.index(self.startIndex, offsetBy: index+1)
            str = String(self[index])
        }
        return str
    }
    
    /**
     是否匹配指定字符串
     - Parameter pattern: 正则表达式
     */
    func isMatch(pattern: String) -> Bool {
        var isMatch:Bool = false
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let result = regex.firstMatch(in: self, options: NSRegularExpression.MatchingOptions(rawValue: 0),
                                                  range: NSMakeRange(0, self.count))
            if (result != nil){
                isMatch = true
            }
        }
        catch {
            isMatch = false
        }
        return isMatch
    }
    
    /**
     检索指定字符串
     - Parameter val:        待搜索字符串
     - Parameter startIndex: 起始搜索索引
     - Returns: 返回搜索到的字符串最初索引位置，如没有搜索到返回－1
     */
    func indexOf(val: String, startIndex: Int = 0) -> Int {
        var findIndex: Int = -1
        let count = self.length
        var index = startIndex
        if index < 0 {
            index = 0
        }
        else if index > count {
            index = count
        }
        do {
            let regex = try NSRegularExpression(pattern: val, options: [.caseInsensitive])
            let result = regex.rangeOfFirstMatch(in: self, options: NSRegularExpression.MatchingOptions.reportProgress,
                                                         range: NSMakeRange(index, count - index))
            
            if result.location != NSNotFound {
                findIndex = result.location
            }
        }
        catch {
            
        }
        return findIndex
    }
    
    /**
     前后翻转指定字符串
     */
    func reverse() -> String {
        return String(self.reversed())
    }
    
    /**
     获取字符串长度
     */
    var length: Int {
        return self.count
    }
    
    /// 字符的插入
    mutating func insertString(text:Character,index:Int) -> String{
        let start = self.index(self.startIndex, offsetBy: index)
        self.insert(text, at: start)
        return self
    }
    ///字符串的插入
    mutating func insertString(text:String,index:Int) -> String{
        let start = self.index(self.startIndex, offsetBy: index)
        self.insert(contentsOf: text, at: start)
        return self
    }
    
    /// 将字符串通过特定的字符串拆分为字符串数组
    ///
    /// - Parameter string: 拆分数组使用的字符串
    /// - Returns: 字符串数组
    func split(string:String) -> [String] {
        return NSString(string: self).components(separatedBy: string)
    }
    
    
    //MARK: String使用下标截取字符串
    /// 例: "示例字符串"[0..<2] 结果是 "示例"
    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
            let endIndex = self.index(self.startIndex, offsetBy: r.upperBound)
            
            return String(self[startIndex..<endIndex])
        }
    }
    
    ///（如果backwards参数设置为true，则返回最后出现的位置）
    func positionOf(sub:String, backwards:Bool = false)->Int {
        // 如果没有找到就返回-1
        var pos = -1
        if let range = range(of:sub, options: backwards ? .backwards : .literal ) {
            if !range.isEmpty {
                pos = self.distance(from:startIndex, to:range.lowerBound)
            }
        }
        return pos
    }
    
    func nsranges(of string: String) -> [NSRange] {
        return ranges(of: string).map { (range) -> NSRange in
            self.nsrange(fromRange: range)
        }
    }
    
    //MARK:Range -> NSRange
    func nsrange(fromRange range : Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
    }
    
    func ranges(of string: String) -> [Range<String.Index>] {
        var rangeArray = [Range<String.Index>]()
        var searchedRange: Range<String.Index>
        guard let sr = self.range(of: self) else {
            return rangeArray
        }
        searchedRange = sr
        var resultRange = self.range(of: string, options: .regularExpression, range: searchedRange, locale: nil)
        while let range = resultRange {
            rangeArray.append(range)
            searchedRange = Range(uncheckedBounds: (range.upperBound, searchedRange.upperBound))
            resultRange = self.range(of: string, options: .regularExpression, range: searchedRange, locale: nil)
        }
        return rangeArray
    }
    
    //MARK:NSRange -> Range
    func toRange(_ range: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex) else { return nil }
        guard let to16 = utf16.index(from16, offsetBy: range.length, limitedBy: utf16.endIndex) else { return nil }
        guard let from = String.Index(from16, within: self) else { return nil }
        guard let to = String.Index(to16, within: self) else { return nil }
        return from ..< to
    }
    
}

//MARK: -- 将字符串替换成值类型 --
extension String{
    
    ///变成Int 类型
    public func toInt() -> Int? {
        if let num = NumberFormatter().number(from: self) {
            return num.intValue
        } else {
            return nil
        }
    }
    /// 变成Double 类型
    public func toDouble() -> Double? {
        if let num = NumberFormatter().number(from: self) {
            return num.doubleValue
        } else {
            return nil
        }
    }
    /// 变成Float 类型
    public func toFloat() -> Float? {
        if let num = NumberFormatter().number(from: self) {
            return num.floatValue
        } else {
            return nil
        }
    }
}

//MARK:-- 获取文本的宽高 --
extension String{
    /// 获取文本高度
    ///
    /// - Parameters:
    ///   - font: font
    ///   - fixedWidth: fixedWidth
    func obtainTextHeight(font : UIFont = UIFont.systemFont(ofSize: 18), fixedWidth : CGFloat) -> CGFloat {
        
        guard self.count > 0 && fixedWidth > 0 else {
            return 0
        }
        
        let size = CGSize(width:fixedWidth, height:CGFloat.greatestFiniteMagnitude)
        let text = self as NSString
        let rect = text.boundingRect(with: size, options:.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : font], context:nil)
        
        return rect.size.height
    }
    
    
    /// 获取文本宽度
    ///
    /// - Parameter font: font
    func obtainTextWidth(font : UIFont = UIFont.systemFont(ofSize: 17)) -> CGFloat {
        
        guard self.count > 0 else {
            return 0
        }
        
        let size = CGSize(width:CGFloat.greatestFiniteMagnitude, height:0)
        let text = self as NSString
        let rect = text.boundingRect(with: size, options:.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : font], context:nil)
        
        return rect.size.width
    }
    
}




extension Int {
    func pp_SizeString() -> String {
        if(self>0) {
            if self < 1024 {
                return String(format: "%dByte",self )
            }
            else if self < 1024*1024 {
                return String(format: "%dKB",self/1024 )
            }
            else if self < 1024*1024*1024 {
                return String(format: "%.2fMB",Float(self)/1024.0/1024.0 )
            }
        }
        return ""
    }
    
}
