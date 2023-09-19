//
//  UIColor+PPTool.swift
//  PandaNote
//
//  Created by panwei on 2020/4/8.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

//import Foundation


//https://stackoverflow.com/a/24263296
extension UIColor {
    static func pp_random() -> UIColor {
        let red = CGFloat.random(in: 0.0 ... 1.0)
        let green = CGFloat.random(in: 0.0 ... 1.0)
        let blue = CGFloat.random(in: 0.0 ... 1.0)
        let alpha = CGFloat.random(in: 0.5 ... 1.0) // 透明度范围可以根据需要调整
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(hexRGBValue: Int) {
        self.init(
            red: (hexRGBValue >> 16) & 0xFF,
            green: (hexRGBValue >> 8) & 0xFF,
            blue: hexRGBValue & 0xFF
        )
    }
}
