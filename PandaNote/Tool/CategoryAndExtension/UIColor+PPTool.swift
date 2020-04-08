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
