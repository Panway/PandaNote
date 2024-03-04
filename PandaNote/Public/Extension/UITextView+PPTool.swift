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
    
    /// a replacement of `insetText` method
    func pp_insertText(_ text: String) {
        if let selectedRange = self.selectedTextRange {
            let cursorPosition = self.offset(from: self.beginningOfDocument, to: selectedRange.start)
            // insert
            let start = self.text.index(self.text.startIndex, offsetBy: cursorPosition)
            self.text.insert(contentsOf: text, at: start)
            // move cursor
            if let from = self.position(from: self.beginningOfDocument, offset: cursorPosition + text.length) {
                self.selectedTextRange = self.textRange(from: from, to: from)
            }
        }
        
    }
    /// I DONT KNOW WHY 暂时不知道原因???
    /// A UITextView extension to scroll a substring to the "top line" of the view
    ///  https://stackoverflow.com/a/44553609 https://gist.github.com/DonMag/19daac863553c51725a56f0bc3296076
    /// - Parameters:
    ///   - searchString: the string in the textview you want brought to the top
    ///   - animated: animate the scrolling (or not)
    /// - Returns: False if the searchString was not found, else True
    @discardableResult func pp_scrollSubstringToTop(_ searchString: String, animated: Bool) -> Bool {
        
        let nsText = self.text as NSString
        
        // get the range of the string to scroll to the top
        self.selectedRange = nsText.range(of: searchString)
        
        // if text not found, return false
        guard let sr = self.selectedTextRange else {
            return false
        }
        
        // get the bounding box of the string
        var rect = self.firstRect(for: sr)
        
        // if the bounding box is *below* the top of the text view, add the
        //  height of the text view to the y offset
        // this will result in the "target rect" being at the bottom of the text view,
        //    pushing the "desired rect" up to the top
//        debugPrint("rect = (\(rect.origin.x),\(rect.origin.y)  [\(rect.size.width),\(rect.size.height)]")
        if rect.origin.y > self.contentOffset.y {
            rect.origin.y += self.bounds.height - rect.size.height
        }
        
        // make sure the bounding box y is not beyond the scrollable height
        //    so, if we have 20 rows of text and 10 rows are visible, we cannot
        //    scroll row 16 to the top (for example)
        rect.origin.y = min(rect.origin.y, self.contentSize.height - 1)
//        debugPrint("rect2= (\(rect.origin.x),\(rect.origin.y)  [\(rect.size.width),\(rect.size.height)]")
        // scroll the bounding box rect into view
        self.scrollRectToVisible(rect, animated: animated)
        
        return true
        
    }
    // 我自己写的，滚动到某个字符串所在的位置
    func pp_scrollToSubstring(string: String) {
        let searchRange = NSRange(location: 0, length: self.text.length)
        let nsstr = self.text as NSString
        let lastSearchRange = nsstr.range(of: string, options: .caseInsensitive,range: searchRange)
        if lastSearchRange.location != NSNotFound {
            self.scrollRangeToVisible(lastSearchRange)
        }
    }
    // current row and column 当前行和列
    func currentRowColumnNumber() -> (line: Int, column: Int) {
        guard let selectedRange = selectedTextRange else {
            return (line: 0, column: 0)
        }
        
        let cursorOffset = offset(from: beginningOfDocument, to: selectedRange.start)
        let text = self.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        var lineCount = 0
        var currentOffset = 0
        
        for line in lines {
            let lineLength = line.count
            if currentOffset + lineLength >= cursorOffset {
                let column = cursorOffset - currentOffset
                return (line: lineCount + 1, column: column + 1)
            }
            lineCount += 1
            currentOffset += lineLength + 1 // Add 1 for the newline character
        }
        
        return (line: 0, column: 0)
    }
    

}
