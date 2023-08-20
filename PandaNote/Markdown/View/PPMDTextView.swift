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
    
    
    open override var text: String! {
        didSet {
            guard oldValue != text else { return }
            try? render()
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
        
        super.init(frame: frame, textContainer: textContainer)
        
        // We don't want the text view to overwrite link attributes set
        // by the styler.
        linkTextAttributes = [:]
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Methods
    
    open func render() throws {
        let ttttt = self.text ?? "@@@"
        print("render==========\n\(ttttt)"  )
        let down = Down(markdownString: ttttt)
        
        let document = try down.toDocument(DownOptions.hardBreaks)
        let visitor = PPAttributedStringVisitor(styler: styler, options: DownOptions.hardBreaks)
        attributedText = document.accept(visitor)
        debugPrint("===========")
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
