//
//  PPMarkdownDecoration.swift
//  PandaNote
//
//  装饰信息的载体：告诉布局管理器「这段源码上要画什么」，
//  而不是往文本流里塞字符。这是「显示文本 ≡ 源码」能成立的唯一可行路径，
//  因为 NSTextAttachment / 圆点图片 / 复制按钮都会往文本里插入 U+FFFC。
//

import UIKit

/// 装饰类型标记。一个属性键承载全部装饰，布局管理器只需一次枚举。
final class PPMarkdownSyntax: NSObject {

    enum Role {
        /// 引用块左侧竖条
        case quoteStripe(depth: Int)
        /// 无序列表圆点（画在 `-` 左侧）
        case bullet(depth: Int)
        /// 整段代码背景（围栏或缩进）
        case codeBlock
        /// 行内代码背景
        case inlineCode
        /// 分割线
        case thematicBreak
        /// 图片预览，画在该行上方预留出的空白里
        case imagePreview(path: String, size: CGSize)
    }

    let role: Role

    private init(_ role: Role) {
        self.role = role
    }

    static func quoteStripe(depth: Int) -> PPMarkdownSyntax { PPMarkdownSyntax(.quoteStripe(depth: depth)) }
    static func bullet(depth: Int) -> PPMarkdownSyntax { PPMarkdownSyntax(.bullet(depth: depth)) }
    static let codeBlock = PPMarkdownSyntax(.codeBlock)
    static let inlineCode = PPMarkdownSyntax(.inlineCode)
    static let thematicBreak = PPMarkdownSyntax(.thematicBreak)
    static func imagePreview(path: String, size: CGSize) -> PPMarkdownSyntax {
        PPMarkdownSyntax(.imagePreview(path: path, size: size))
    }

    /// TextKit 用 `isEqual` 合并相邻的相同属性区间。不实现它就会退化成逐字符枚举，
    /// 长文渲染会明显变慢。
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PPMarkdownSyntax else { return false }
        return PPMarkdownSyntax.sameRole(role, other.role)
    }

    override var hash: Int {
        var seed = 0
        switch role {
        case .quoteStripe(let depth): seed = 1 &+ depth
        case .bullet(let depth): seed = 2 &+ depth
        case .codeBlock: seed = 3
        case .inlineCode: seed = 4
        case .thematicBreak: seed = 5
        case .imagePreview(let path, let size):
            seed = 6 &+ path.hashValue &+ Int(size.width) &* 31 &+ Int(size.height)
        }
        return seed
    }

    private static func sameRole(_ a: Role, _ b: Role) -> Bool {
        switch (a, b) {
        case (.quoteStripe(let x), .quoteStripe(let y)): return x == y
        case (.bullet(let x), .bullet(let y)): return x == y
        case (.codeBlock, .codeBlock): return true
        case (.inlineCode, .inlineCode): return true
        case (.thematicBreak, .thematicBreak): return true
        case (.imagePreview(let p1, let s1), .imagePreview(let p2, let s2)):
            return p1 == p2 && s1 == s2
        default: return false
        }
    }
}

extension NSAttributedString.Key {
    /// 值类型是 `PPMarkdownSyntax`，由 `PPMarkdownLayoutManager` 读取后自绘。
    static let ppMarkdownSyntax = NSAttributedString.Key("PPMarkdownSyntax")
}
