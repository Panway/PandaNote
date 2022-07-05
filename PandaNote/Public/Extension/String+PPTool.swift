//
//  String+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2021/11/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation

extension String {
    ///将十六进制颜色转换为UIColor
    func pp_HEXColor() -> UIColor {
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
}
