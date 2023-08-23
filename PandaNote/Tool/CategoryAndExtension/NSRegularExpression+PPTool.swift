//
//  NSRegularExpression+PPTool.swift
//  PandaNote
//
//  Created by topcheer on 2020/7/19.
//  Copyright © 2020 WeirdPan. All rights reserved.
//
//https://www.hackingwithswift.com/articles/108/how-to-use-regular-expressions-in-swift
//正则表达式 正则匹配
import Foundation

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
    
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
    
    
}

extension String {
    //这段代码让我们可以在左边使用任何字符串，在右边使用正则表达式，所有这些操作都集成在一起:
    //比如 "hat" ~= "[a-z]at" 表示在hat里正则匹配以at结尾的单词
    // 会覆盖Swift中String类型的 ~= 操作符。这是因为你在String类型的扩展中定义了一个与Swift标准库中已有的模式匹配操作符~=相同的操作符
//    static func ~= (lhs: String, rhs: String) -> Bool {
//        //注意: 创建一个 nsregularexexpression 实例是有成本的，因此如果您打算重复使用正则表达式，那么最好缓存 nsregularexexpression 实例
//        guard let regex = try? NSRegularExpression(pattern: rhs) else { return false }
//        let range = NSRange(location: 0, length: lhs.utf16.count)
//        return regex.firstMatch(in: lhs, options: [], range: range) != nil
//    }
    
    func pp_matches(for regex: String) -> [String] {

        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                                        range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            debugPrint("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
