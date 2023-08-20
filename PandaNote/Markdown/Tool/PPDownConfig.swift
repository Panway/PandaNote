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
        code: DownColor = .black,
        link: DownColor = .blue,
        quote: DownColor = .darkGray,
        quoteStripe: DownColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00),
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
