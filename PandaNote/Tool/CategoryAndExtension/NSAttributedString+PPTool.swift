//
//  NSAttributedString+PPTool.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {
    ///左字右图
    class func pp_AttributedText(withTitle title: String?, titleAttributes: [NSAttributedString.Key : Any]?, image: UIImage?, space: CGFloat) -> NSMutableAttributedString? {
        var font = UIFont.systemFont(ofSize: 15)
        if let ffff = titleAttributes?[NSAttributedString.Key.font] {
            font = ffff as! UIFont
        }
        // 字体高度=基线以上高度+基线以下高度 http://ksnowlv.blog.163.com/blog/static/21846705620142325349309/
        let fontHeight = font.ascender + font.descender
        // yOffset 是`图片底部那条线`相对于`字体底部的基线(baseline，接近字体下边界)`的偏移量，正值往上偏移，负值往下偏移
        let yOffset = fontHeight / 2 - (image?.size.height ?? 0.0) / 2 - 1


        let text = NSMutableAttributedString()

        if let title = title {
            let one = NSMutableAttributedString(string: title)
            one.setAttributes(titleAttributes, range: NSRange(location: 0, length: title.count))
            text.append(one)
        }
        //图片附件
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = image
        imageAttachment.bounds = CGRect(x: 0, y: yOffset, width: imageAttachment.image?.size.width ?? 0.0, height: imageAttachment.image?.size.height ?? 0.0)
        let attrStringWithImage = NSAttributedString(attachment: imageAttachment)

        //间隔
        let spaceAttachment = NSTextAttachment()
        spaceAttachment.bounds = CGRect(x: imageAttachment.image?.size.width ?? 0.0, y: yOffset, width: space, height: imageAttachment.image?.size.height ?? 0.0)
        let attrStringWithSpace = NSAttributedString(attachment: spaceAttachment)

        text.append(attrStringWithSpace)

        text.append(attrStringWithImage)


        return text
    }

}
