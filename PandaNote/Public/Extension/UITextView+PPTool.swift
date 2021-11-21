//
//  UITextView+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2021/11/20.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation


extension UITextView {
    
    /// Get the NSRange of the first line of words on the screen 获取屏幕上的第一行文字的range
    /// Thanks to https://stackoverflow.com/a/37428252/4493393
    func pp_visibleRange() -> NSRange {
        let bounds = self.bounds
        let origin = CGPoint(x: 0,y: self.contentOffset.y)
        let startCharacterRange = self.characterRange(at: origin)
        if startCharacterRange == nil {
            return NSMakeRange(0,0)
        }
        let startPosition = self.characterRange(at: origin)!.start
        let endCharacterRange = self.characterRange(at: CGPoint(x: bounds.maxX, y: bounds.maxY))
        if endCharacterRange == nil {
            return NSMakeRange(0,0)
        }
        let endPosition = self.characterRange(at:CGPoint(x: bounds.maxX, y: bounds.maxY))!.end
        let startIndex = self.offset(from: self.beginningOfDocument, to: startPosition)
        let endIndex = self.offset(from: startPosition, to: endPosition)
        return NSMakeRange(startIndex, endIndex)
    }

}
