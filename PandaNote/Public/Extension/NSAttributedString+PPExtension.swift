//
//  NSAttributedString+PPExtension.swift
//  PandaNote
//
//  Created by Panway on 2023/8/22.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

extension NSAttributedString {
    
    func pp_attributes(at index: Int) -> [NSAttributedString.Key: Any]? {
        if index > self.length || self.length == 0 {
            return nil
        }
        if self.length > 0 && index == self.length {
            return self.attributes(at: index - 1, effectiveRange: nil)
        }
        return self.attributes(at: index, effectiveRange: nil)
    }
    
    var wholeRange: NSRange {
        return NSRange(location: 0, length: length)
    }
    
    // MARK: - Enumerate attributes

    func pp_enumerateAttributes<A>(for key: Key, block: (_ attr: A, _ range: NSRange) -> Void) {
        pp_enumerateAttributes(for: key, in: wholeRange, block: block)
    }

    func pp_enumerateAttributes<A>(for key: Key, in range: NSRange, block: (_ attr: A, _ range: NSRange) -> Void) {
        enumerateAttribute(key, in: range, options: []) { value, range, _ in
            if let value = value as? A {
                block(value, range)
            }
        }
    }
}


extension NSMutableAttributedString {
    func pp_setAttributes(_ attrs: [NSAttributedString.Key: Any]) {
        setAttributes(attrs, range: wholeRange)
    }

    func pp_addAttributes(_ attrs: [NSAttributedString.Key: Any]) {
        addAttributes(attrs, range: wholeRange)
    }

    func pp_addAttribute(for key: Key, value: Any) {
        addAttribute(key, value: value, range: wholeRange)
    }

    func pp_removeAttribute(for key: Key) {
        removeAttribute(key, range: wholeRange)
    }

    func pp_replaceAttribute(for key: Key, value: Any) {
        pp_replaceAttribute(for: key, value: value, inRange: wholeRange)
    }

    func pp_replaceAttribute(for key: Key, value: Any, inRange range: NSRange) {
        removeAttribute(key, range: range)
        addAttribute(key, value: value, range: range)
    }

    func pp_updateExistingAttributes<A>(for key: Key, using transform: (A) -> A) {
        pp_updateExistingAttributes(for: key, in: wholeRange, using: transform)
    }

    func pp_updateExistingAttributes<A>(for key: Key, in range: NSRange, using transform: (A) -> A) {
        var existingValues = [(value: A, range: NSRange)]()
        pp_enumerateAttributes(for: key, in: range) { existingValues.append(($0, $1)) }
        existingValues.forEach { addAttribute(key, value: transform($0.0), range: $0.1) }
    }

   
}
//iOS 中给文字设置斜体时, 中文下是没有效果的. 这是因为斜体需要字体的支持, iOS 默认中文字体没有对应的斜体. https://www.jianshu.com/p/d28692854f10
extension UIFont {
    
    var pp_bold: UIFont {
        return with(.traitBold)
    }
    
    var pp_italic: UIFont {
        return with(.traitItalic)
    }
    
    var pp_boldItalic: UIFont {
        return with([.traitBold, .traitItalic])
    }
    
    
    
    func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(self.fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    func without(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(self.fontDescriptor.symbolicTraits.subtracting(UIFontDescriptor.SymbolicTraits(traits))) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    
    /// 设置倾斜`angle`度
    /// - Parameter angle: 度 degree
    func pp_lantedMatrix(_ angle: CGFloat) -> CGAffineTransform{
        // 1. 设置倾斜15度
//        let angle: CGFloat = 15.0
        let radians = angle * CGFloat.pi / 180.0
        return CGAffineTransform(a: 1, b: 0, c: tan(radians), d: 1, tx: 0, ty: 0)

    }
    func pp_setItalic() -> UIFont {
        // 通过字体描述符的 UIFontDescriptorSymbolicTraits 设置斜体样式
        let symTraits = fontDescriptor.symbolicTraits
        var fontDescriptorVar = fontDescriptor.withSymbolicTraits(symTraits)
        
        fontDescriptorVar = fontDescriptorVar?.addingAttributes([.matrix: pp_lantedMatrix(15.0)])//CGAffineTransform.skew(c: -15*CGFloat.pi/180, b: 0)])
        return UIFont(descriptor: fontDescriptorVar ?? fontDescriptor, size: 0)
    }
}

extension CGAffineTransform {
    static func skew(c: CGFloat, b: CGFloat) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform.c = -c
        transform.b = b
        return transform
    }
}
