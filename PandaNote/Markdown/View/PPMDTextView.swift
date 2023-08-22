//
//  PPMDTextView.swift
//  PandaNote
//
//  Created by Panway on 2023/8/20.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import UIKit
import Down
import Highlightr
//import libcmark


class PPMDTextView: UITextView {
    
    // MARK: - Properties
    
    open var styler: Styler
    open var renderMethod = ""
    var cacheDir = ""
    var visitor : PPAttributedStringVisitor
    
    open override var text: String! {
        didSet {
            guard oldValue != text else { return }

            if renderMethod == "Down" {
                try? render()
            }
        }
    }

    
    // MARK: - Life cycle
    
    public convenience init(frame: CGRect) { //, styler: Styler = DownStyler()) {
        let dsc = DownStylerConfiguration(fonts: StaticFontCollection(),
                                          colors: PPDownColorCollection(),
                                          paragraphStyles: StaticParagraphStyleCollection(),
                                          listItemOptions: ListItemOptions(),
                                          quoteStripeOptions: QuoteStripeOptions(thickness: 5, spacingAfter: 8),
                                          thematicBreakOptions: ThematicBreakOptions(),
                                          codeBlockOptions: CodeBlockOptions())
        let styler = DownStyler(configuration: dsc)
        self.init(frame: frame, styler: styler, layoutManager: DownLayoutManager()) //DownDebugLayoutManager
    }
    
    public init(frame: CGRect, styler: Styler, layoutManager: NSLayoutManager) {
        self.styler = styler
        
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer(size: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude))
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        self.visitor = PPAttributedStringVisitor(styler: styler, options: DownOptions.hardBreaks)
        super.init(frame: frame, textContainer: textContainer)
        
        // We don't want the text view to overwrite link attributes set
        // by the styler.
        linkTextAttributes = [:]
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Methods
    
    open func render() {
        if renderMethod != "Down" {
            return
        }
        // 获取原来的光标位置
        let selectedRange = self.selectedRange
        let offsetY = self.contentOffset.y
        let ttttt = self.text ?? "@@@"
        print("render==========\n\(ttttt)"  )
        let down = Down(markdownString: ttttt)
        
        guard let document = try? down.toDocument(DownOptions.hardBreaks) else { return }
        visitor.cacheDir = cacheDir
        visitor.images.removeAll()
        attributedText = document.accept(visitor)
        debugPrint("===========")
        // 恢复光标位置
        if selectedRange.location != NSNotFound {
            self.selectedRange = selectedRange
        }
        for item in visitor.images {
            let path = "\(cacheDir)/\(item)".replacingOccurrences(of: "//", with: "/").pp_split(PPUserInfo.shared.webDAVRemark).last ?? ""

            PPFileManager.shared.getFileData(path: path,
                                             fileID: nil,
                                             alwaysDownload:false) { (contents: Data?,isFromCache, error) in
            }
        }
        self.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
    }
    /// 更改标题级别
    func updateCurrentLineWithHeadingLevel(_ headingLevel:Int) {
        // 获取光标所在行的文本范围
        if let selectedTextRange = self.selectedTextRange,
           let currentLineRange = self.tokenizer.rangeEnclosingPosition(selectedTextRange.start, with: .line, inDirection: .init(rawValue: 1)) {
            // 获取光标所在行的 NSRange
            let cursorPosition = self.offset(from: self.beginningOfDocument, to: currentLineRange.start)
            let lineNSRange = NSRange(location: cursorPosition, length: self.offset(from: currentLineRange.start, to: currentLineRange.end))
            let currentLineText = self.attributedText.attributedSubstring(from: lineNSRange)
            // 更新光标所在行的NSAttributedString
            let stringWithoutHash = currentLineText.string.pp_removeLeadingCharacter("#").pp_removeLeadingCharacter(" ")
            let newAttributedString = NSAttributedString(string: String(repeating: "#", count: headingLevel) + " \(stringWithoutHash)", attributes: currentLineText.pp_attributes(at: 0))
            
            // 更新当前行的文本
            let mutableAttributedString = NSMutableAttributedString(attributedString: self.attributedText)
            mutableAttributedString.replaceCharacters(in: lineNSRange, with: newAttributedString)
            let selectedRange = self.selectedRange
            self.attributedText = mutableAttributedString
            self.render()
            // 恢复光标位置
            if selectedRange.location != NSNotFound {
                self.becomeFirstResponder()
                self.selectedRange = selectedRange
            }
        }
    }
    
    // https://stackoverflow.com/a/34922332
    func moveCursor(offset:Int) {
        if let selectedRange = self.selectedTextRange {
            // and only if the new position is valid
            if let newPosition = self.position(from: selectedRange.start, offset: offset) {
                // set the new position
                self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            }
        }
    }
}
//https://levelup.gitconnected.com/background-with-rounded-corners-in-uitextview-1c095c708d14
/// Shadow style for background attribute
public class ShadowStyle {
    /// Color of the shadow
    public let color: UIColor

    /// Shadow offset
    public let offset: CGSize

    /// Shadow blur
    public let blur: CGFloat

    public init(color: UIColor, offset: CGSize, blur: CGFloat) {
        self.color = color
        self.offset = offset
        self.blur = blur
    }
}

/// Additional style for background color attribute. Adding `BackgroundStyle` attribute in addition to
/// `backgroundColor` attribute will apply shadow and rounded corners as specified.
/// - Note:
/// This attribute had no effect in absence of `backgroundColor` attribute.
public class BackgroundStyle {

    /// Corner radius of the background
    public let cornerRadius: CGFloat

    /// Optional shadow style for the background
    public let shadow: ShadowStyle?

    public init(cornerRadius: CGFloat = 0, shadow: ShadowStyle? = nil) {
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }
}

class PPLayoutManager: NSLayoutManager {

    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<CGRect>, count rectCount: Int, forCharacterRange charRange: NSRange, color: UIColor) {
        guard let textStorage = textStorage,
            let currentCGContext = UIGraphicsGetCurrentContext(),
            let backgroundStyle = textStorage.attribute(.backgroundStyle, at: charRange.location, effectiveRange: nil) as? BackgroundStyle else {
                super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
                return
        }

        currentCGContext.saveGState()
        let cornerRadius = backgroundStyle.cornerRadius

        let corners = UIRectCorner.allCorners

        for i in 0..<rectCount  {
            let rect = rectArray[i]
            let rectanglePath = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            color.set()

            if let shadowStyle = backgroundStyle.shadow {
                currentCGContext.setShadow(offset: shadowStyle.offset, blur: shadowStyle.blur, color: shadowStyle.color.cgColor)
            }

            currentCGContext.setAllowsAntialiasing(true)
            currentCGContext.setShouldAntialias(true)

            currentCGContext.setFillColor(color.cgColor)
            currentCGContext.addPath(rectanglePath.cgPath)
            currentCGContext.drawPath(using: .fill)
        }
        currentCGContext.restoreGState()
    }
}
public extension NSAttributedString.Key {
    /// Additional style attribute for background color. Using this attribute in addition to `backgroundColor` attribute allows applying
    /// shadow and corner radius to the background.
    /// - Note:
    /// This attribute only takes effect with `.backgroundColor`. In absence of `.backgroundColor`, this attribute has no effect.
    static let backgroundStyle = NSAttributedString.Key("_backgroundStyle")
}
