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
        Scanner(string: hexStr[0..<2]).scanHexInt32(&red)
        Scanner(string: hexStr[2..<4]).scanHexInt32(&green)
        Scanner(string: hexStr[4..<6]).scanHexInt32(&blue)
        return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
    }
}
