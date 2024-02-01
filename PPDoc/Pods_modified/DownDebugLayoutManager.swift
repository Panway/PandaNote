//
//  DownDebugLayoutManager.swift
//  Down
//
//  Created by John Nguyen on 06.08.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

#if canImport(UIKit)

import UIKit

#elseif canImport(AppKit)

import AppKit

#endif

/// A layout manager that draws the line fragments.
///
/// Line fragments are the areas with a document that contain lines of text. There
/// are two types.
///
/// 1. A *line rect* (drawn in red) indicates the maximum rect enclosing the line.
/// This inlcudes not only the textual content, but also the padding (if any) around that text.
/// 2. A *line used rect* (drawn in blue) is the smallest rect enclosing the textual content.
///
/// The visualization of these rects is useful when determining the paragraph styles
/// of a `DownStyler`.
///
/// Insert this into a TextKit stack manually, or use the provided `DownDebugTextView`.

public class DownDebugLayoutManager: DownLayoutManager {

    // MARK: - Drawing

    override public func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
//        drawLineFragments(forGlyphRange: glyphsToShow, at: origin)
    }

    private func drawLineFragments(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, usedRect, _, _, _ in
            [(usedRect, DownColor.blue), (rect, DownColor.red)].forEach { rectToDraw, color in
                let adjustedRect = rectToDraw.translated(by: origin)
                self.drawRect(adjustedRect, color: color.cgColor)
            }
        }
    }

    private func drawRect(_ rect: CGRect, color: CGColor) {
        guard let context = context else { return }
        push(context: context)
        defer { popContext() }

        context.setStrokeColor(color)
        context.stroke(rect)
    }
//    绘制字形辅助线
    public override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        let textContainer = self.textContainers[0] // Assuming only one text container
        
        for glyphIndex in glyphsToShow.location..<NSMaxRange(glyphsToShow) {
            let glyphRect = self.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
            
            if let font = self.textStorage?.attribute(.font, at: glyphIndex, effectiveRange: nil) as? UIFont {
                let ascentLineY = glyphRect.origin.y + font.ascender//glyphRect.origin.y - font.ascender
                let descentLineY = glyphRect.origin.y + glyphRect.height //  + font.descender
                let lineHeight = glyphRect.height// + font.ascender + font.descender
                let string = self.textStorage?.attributedSubstring(from: NSRange(location: glyphIndex, length: 1)).string
                if string == "\n" {
                    continue
                }
//                debugPrint("\n\n[char]:\(string ?? "") \(ascentLineY) \(descentLineY) \(glyphRect.height) \n\(font.ascender)\n\(font.descender)")
                let context = UIGraphicsGetCurrentContext()
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.setLineWidth(1.0)
                context?.move   (to: CGPoint(x: glyphRect.origin.x, y: ascentLineY)) //baseLine
                context?.addLine(to: CGPoint(x: glyphRect.origin.x + glyphRect.width, y: ascentLineY)) //baseLine
                context?.strokePath()
                
                context?.setStrokeColor(UIColor.green.cgColor)
                
                context?.move   (to: CGPoint(x: glyphRect.origin.x, y: glyphRect.origin.y))
                context?.addLine(to: CGPoint(x: glyphRect.origin.x + glyphRect.width, y: glyphRect.origin.y))
                context?.strokePath()
                
                context?.setStrokeColor(UIColor.blue.cgColor)
                context?.move   (to: CGPoint(x: glyphRect.origin.x, y: descentLineY))
                context?.addLine(to: CGPoint(x: glyphRect.origin.x + glyphRect.width, y: descentLineY))
                context?.strokePath()
                
            }
        }
    }

    


}

#endif
