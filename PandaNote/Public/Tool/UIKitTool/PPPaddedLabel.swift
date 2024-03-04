//
//  PPPaddedLabel.swift
//  PandaNote
//
//  Created by pan on 2024/2/29.
//  Copyright © 2024 Panway. All rights reserved.
//

import UIKit

class PPPaddedLabel: UILabel {
    // 定义内间距
    var textInsets = UIEdgeInsets.zero {
        didSet {
            // 每当内间距发生变化时，调用 setNeedsDisplay 方法重绘 Label
            setNeedsDisplay()
        }
    }
    
    // 重写 drawText 方法，在绘制文本之前应用内间距
    override func drawText(in rect: CGRect) {
        // 应用内间距
        let insetsRect = rect.inset(by: textInsets)
        super.drawText(in: insetsRect)
    }
    
    // 重写 intrinsicContentSize 属性，包括内间距
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}

