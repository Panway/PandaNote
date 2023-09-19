//
//  PPDownConfig.swift
//  PandaNote
//
//  Created by Panway on 2023/8/20.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import Down

//MARK: - Color 颜色
public struct PPDownColorCollection: ColorCollection {

    public var heading1: DownColor
    public var heading2: DownColor
    public var heading3: DownColor
    public var heading4: DownColor
    public var heading5: DownColor
    public var heading6: DownColor
    public var body: DownColor
    public var bodyLight = UIColor.lightGray
    public var code: DownColor
    public var link: DownColor
    public var quote: DownColor
    public var quoteStripe: DownColor
    public var thematicBreak: DownColor
    public var listItemPrefix: DownColor
    public var codeBlockBackground: DownColor


    public init(
        heading1: DownColor = "#2c3e50".pp_HEXColor(),
        heading2: DownColor = "#2c3e50".pp_HEXColor(),
        heading3: DownColor = "#2c3e50".pp_HEXColor(),
        heading4: DownColor = "#2c3e50".pp_HEXColor(),
        heading5: DownColor = "#2c3e50".pp_HEXColor(),
        heading6: DownColor = "#2c3e50".pp_HEXColor(),
        body: DownColor = "#2c3e50".pp_HEXColor(),
        code: DownColor = "#476582".pp_HEXColor(),
        link: DownColor = PPCOLOR_GREEN,
        quote: DownColor = .darkGray,
        quoteStripe: DownColor = PPCOLOR_GREEN,
        thematicBreak: DownColor = .init(white: 0.9, alpha: 1),
        listItemPrefix: DownColor = .lightGray,
        codeBlockBackground: DownColor = UIColor.green.withAlphaComponent(0.3)
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.body = body
        self.code = code
        self.link = link
        self.quote = quote
        self.quoteStripe = quoteStripe
        self.thematicBreak = thematicBreak
        self.listItemPrefix = listItemPrefix
        self.codeBlockBackground = codeBlockBackground
    }

}
//MARK: - Font 字体

public struct PPDownFontCollection: FontCollection {


    public var heading1: DownFont
    public var heading2: DownFont
    public var heading3: DownFont
    public var heading4: DownFont
    public var heading5: DownFont
    public var heading6: DownFont
    public var body: DownFont
    public var code: DownFont
    public var listItemPrefix: DownFont


    public init(
        heading1: DownFont = .boldSystemFont(ofSize: 32),
        heading2: DownFont = .boldSystemFont(ofSize: 28),
        heading3: DownFont = .boldSystemFont(ofSize: 24),
        heading4: DownFont = .boldSystemFont(ofSize: 22),
        heading5: DownFont = .boldSystemFont(ofSize: 20),
        heading6: DownFont = .boldSystemFont(ofSize: 18),
        body: DownFont = .systemFont(ofSize: 18),
        code: DownFont = .systemFont(ofSize: 18),
        listItemPrefix: DownFont = DownFont.monospacedDigitSystemFont(ofSize: 18, weight: .regular)
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.body = body
        self.code = code
        self.listItemPrefix = listItemPrefix
    }

}


/// Default implementation of `ListItemPrefixGenerator`.
/// Generating the following symbol based on `List.ListType`:
/// - List.ListType is bullet (黑圆点、项目符号)=> "•"
/// - List.ListType is ordered(有序列表) => "X." (where is the item number)
public class PPListItemPrefixGenerator: ListItemPrefixGenerator {


    private var prefixes: IndexingIterator<[String]>


    required public init(listType: List.ListType, numberOfItems: Int, nestDepth: Int) {
            switch listType {
            case .bullet:
                prefixes = [String](repeating: "-", count: numberOfItems)
                    .makeIterator()

            case .ordered(let start):
                prefixes = (start..<(start + numberOfItems))
                    .map { "\($0)." }
                    .makeIterator()
            }
        }


    public func next() -> String? {
        prefixes.next()
    }

}
//MARK: - ParagraphStyle 段落样式
public struct PPDownParagraphStyleCollection: ParagraphStyleCollection {


    public var heading1: NSParagraphStyle
    public var heading2: NSParagraphStyle
    public var heading3: NSParagraphStyle
    public var heading4: NSParagraphStyle
    public var heading5: NSParagraphStyle
    public var heading6: NSParagraphStyle
    public var body: NSParagraphStyle
    public var code: NSParagraphStyle


    public init() {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacing = 8

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.paragraphSpacingBefore = 8
        bodyStyle.paragraphSpacing = 8
//        bodyStyle.lineSpacing = 8

        let codeStyle = NSMutableParagraphStyle()
        codeStyle.paragraphSpacingBefore = 8
        codeStyle.paragraphSpacing = 8

        heading1 = headingStyle
        heading2 = headingStyle
        heading3 = headingStyle
        heading4 = headingStyle
        heading5 = headingStyle
        heading6 = headingStyle
        body = bodyStyle
        code = codeStyle
    }

}


class PPCheckmarkView: UIView {
    var isChecked: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
//        debugPrint("=========draw")
        let center = CGPoint(x: rect.size.width / 2, y: rect.size.height / 2)
        let radius = min(rect.size.width, rect.size.height) / 2
        
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(2)
        context?.setStrokeColor(UIColor.black.cgColor)
        context?.addArc(center: center, radius: radius - 1, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: false)
        
        if isChecked {
            context?.setFillColor(UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00).cgColor)
            context?.fillPath()
        } else {
            context?.strokePath()
        }
    }
}


class PPCheckmarkTextAttachment: NSTextAttachment {
    var switchView: PPCheckmarkView?
    var customHeight: CGFloat = 15

    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
            //return CGRect(x: 0, y: 0, width: min(lineFrag.size.width, 20), height: customHeight)
        var bounds = super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
                
                // 计算垂直居中的偏移量
                let yOffset = (lineFrag.size.height - bounds.size.height) / 2.0
                
                // 调整原始的 bounds 属性
                bounds.origin.y = yOffset
                
                return bounds
        }
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        if let switchView = switchView {
            UIGraphicsBeginImageContextWithOptions(imageBounds.size, false, 0.0)
            switchView.draw(switchView.bounds)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        }
        return nil
    }
}
