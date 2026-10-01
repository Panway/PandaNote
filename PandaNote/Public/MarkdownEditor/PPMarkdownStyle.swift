//
//  PPMarkdownStyle.swift
//  PandaNote
//
//  新版渲染层读取样式的唯一入口。
//  本轮不做完整的 MarkdownTheme 收口，字体/颜色仍然实取 PPAppConfig 现值，
//  好让现有的主题切换继续生效；但装饰几何（引用条宽度、圆点直径等）已经集中到这里，
//  后续 MarkdownTheme 落地时只需把 `current` 的数据源换掉。
//

import UIKit

struct PPMarkdownStyle {

    // MARK: 字体与颜色（沿用现有配置，主题切换后仍是新值）

    let fonts: PPDownFontCollection
    let colors: PPDownColorCollection

    // MARK: 语法标记的弱化色

    /// `#`、`>`、`-`、反引号、`**` 这些标记本身的颜色。
    let markerColor: UIColor
    /// 引用块正文颜色。
    let quoteColor: UIColor

    // MARK: 装饰几何

    /// 引用块左侧竖条宽度。用户明确要求 3px。
    let quoteStripeWidth: CGFloat
    /// 竖条与正文之间的间距。
    let quoteStripeGap: CGFloat
    /// 无序列表绿色圆点直径。
    let bulletDiameter: CGFloat
    /// 圆点到 `-` 的距离。
    let bulletGap: CGFloat
    /// 列表每一层嵌套向右推进的距离，用于算 headIndent。
    let listIndentPerLevel: CGFloat
    /// 代码块圆角。
    let codeCornerRadius: CGFloat
    /// 代码块背景在左右各多画出的距离。
    let codeBlockHorizontalBleed: CGFloat
    /// 代码块背景在上下各多画出的距离。
    let codeBlockVerticalBleed: CGFloat
    /// 行内代码背景左右留白。
    let inlineCodeHorizontalPadding: CGFloat
    /// 分割线左右缩进。
    let thematicBreakHorizontalInset: CGFloat
    /// 图片预览与其下方源码之间的间隙。
    let imagePreviewGap: CGFloat
    /// 图片预览最大宽度。
    let imageMaxWidth: CGFloat
    /// 图片预览最大高度，超过则等比缩小。
    let imageMaxHeight: CGFloat
    /// 段落行间距。
    let lineSpacing: CGFloat
    /// 段落之后的间距。
    let paragraphSpacing: CGFloat

    /// 每次渲染现取，避免旧实现里「init 时快照一次、切主题不生效」的问题。
    static var current: PPMarkdownStyle {
        let config = PPAppConfig.shared
        return PPMarkdownStyle(
            fonts: config.downFont,
            colors: config.downColor,
            markerColor: config.downColor.bodyLight,
            quoteColor: config.downColor.quote,
            quoteStripeWidth: 3,
            quoteStripeGap: 8,
            bulletDiameter: 7,
            bulletGap: 6,
            listIndentPerLevel: 18,
            codeCornerRadius: 6,
            codeBlockHorizontalBleed: 6,
            codeBlockVerticalBleed: 4,
            inlineCodeHorizontalPadding: 2,
            thematicBreakHorizontalInset: 24,
            imagePreviewGap: 6,
            imageMaxWidth: 320,
            imageMaxHeight: 420,
            lineSpacing: 6,
            paragraphSpacing: 8
        )
    }

    // MARK: 段落样式

    /// 引用块正文段落样式：整段左移，给竖条让出位置。
    func paragraphStyle(quoteDepth: Int, base: NSParagraphStyle) -> NSParagraphStyle {
        let mutable = (base.copy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        let indent = CGFloat(quoteDepth) * (quoteStripeWidth + quoteStripeGap)
        mutable.firstLineHeadIndent = max(mutable.firstLineHeadIndent, indent)
        mutable.headIndent = max(mutable.headIndent, indent)
        return mutable
    }

    /// 列表项段落样式：做成悬挂缩进，圆点占据标记左侧让出来的那段空白。
    func paragraphStyle(listDepth: Int, contentColumn: Int, base: NSParagraphStyle) -> NSParagraphStyle {
        let mutable = (base.copy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        let level = CGFloat(listDepth) * listIndentPerLevel
        // 圆点画在 `-` 左侧，所以首行必须先让出「圆点 + 间距」的宽度，否则会被裁掉。
        let hanging = bulletDiameter + bulletGap
        // 标记本身（`- ` / `1. `）在源码里占的列宽折算成像素，续行才能和正文对齐。
        let markerWidth = CGFloat(contentColumn) * (fonts.body.pointSize * 0.5)
        mutable.firstLineHeadIndent = level + hanging
        mutable.headIndent = level + hanging + markerWidth
        return mutable
    }

    /// 图片预览预留出的行前空白。
    func paragraphStyle(imageGap: CGFloat, base: NSParagraphStyle) -> NSParagraphStyle {
        let mutable = (base.copy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        mutable.paragraphSpacingBefore = max(mutable.paragraphSpacingBefore, imageGap)
        return mutable
    }
}
