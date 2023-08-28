//
//  PPDownConfig.swift
//  PandaNote
//
//  Created by Panway on 2023/8/20.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import Down

public struct PPDownColorCollection: ColorCollection {

    // MARK: - Properties

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

    // MARK: - Life cycle

    public init(
        heading1: DownColor = .black,
        heading2: DownColor = .black,
        heading3: DownColor = .black,
        heading4: DownColor = .black,
        heading5: DownColor = .black,
        heading6: DownColor = .black,
        body: DownColor = .black,
        code: DownColor = "#476582".pp_HEXColor(),
        link: DownColor = PPCOLOR_GREEN,
        quote: DownColor = .darkGray,
        quoteStripe: DownColor = PPCOLOR_GREEN,
        thematicBreak: DownColor = .init(white: 0.9, alpha: 1),
        listItemPrefix: DownColor = .lightGray,
        codeBlockBackground: DownColor = UIColor.lightGray.withAlphaComponent(0.3)
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




/// Default implementation of `ListItemPrefixGenerator`.
/// Generating the following symbol based on `List.ListType`:
/// - List.ListType is bullet (黑圆点、项目符号)=> "•"
/// - List.ListType is ordered(有序列表) => "X." (where is the item number)
public class PPListItemPrefixGenerator: ListItemPrefixGenerator {

    // MARK: - Properties

    private var prefixes: IndexingIterator<[String]>

    // MARK: - Life cycle

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

    // MARK: - Methods

    public func next() -> String? {
        prefixes.next()
    }

}

class PPCheckmarkView: UIView {
    var isChecked: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        debugPrint("=========draw")
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
            return CGRect(x: 0, y: 0, width: min(lineFrag.size.width, 20), height: customHeight)
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
