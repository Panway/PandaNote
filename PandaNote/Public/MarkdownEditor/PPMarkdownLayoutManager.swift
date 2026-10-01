//
//  PPMarkdownLayoutManager.swift
//  PandaNote
//
//  所有「看起来像往文本里插了东西」的效果都在这里画：引用竖条、列表圆点、
//  代码背景、分割线、图片预览。全部靠 `.ppMarkdownSyntax` 属性定位，
//  一个字符都不加进文本流。
//
//  坐标约定：`rects(for:)` 一律只用 `lineFragmentRect` / `lineFragmentUsedRect`
//  推导（这两个 API 的输出与 Down 的 DownLayoutManager 在同一套 TextKit 1 栈上验证过），
//  不碰 `boundingRect(forGlyphRange:in:)`，避免 container origin 是否计入的歧义。
//  绘制时再整体平移 `origin`。
//

import UIKit

class PPMarkdownLayoutManager: NSLayoutManager {

    var style: PPMarkdownStyle = .current
    weak var imageCache: PPMarkdownImageCache?

    /// 一条待绘制的装饰及其在片段坐标系里的位置。
    struct Decoration {
        let syntax: PPMarkdownSyntax
        let characterRange: NSRange
        let rect: CGRect
    }

    // MARK: - 绘制

    /// 装饰全部画在字形之前，文字不会被盖住。
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        for decoration in rects(for: characterRange) {
            switch decoration.syntax.role {
            case .codeBlock:
                paint(roundedRect: decoration.rect.offsetBy(dx: origin.x, dy: origin.y),
                      color: style.colors.codeBlockBackground,
                      radius: style.codeCornerRadius)
            case .inlineCode:
                paint(roundedRect: decoration.rect.offsetBy(dx: origin.x, dy: origin.y),
                      color: style.colors.codeBlockBackground, radius: 3)
            case .quoteStripe:
                paint(verticalLine: decoration.rect.offsetBy(dx: origin.x, dy: origin.y))
            case .bullet:
                paint(filledEllipseIn: decoration.rect.offsetBy(dx: origin.x, dy: origin.y))
            case .thematicBreak:
                paint(horizontalLine: decoration.rect.offsetBy(dx: origin.x, dy: origin.y))
            case .imagePreview(let path, let size):
                paintImage(atPath: path, size: size, in: decoration.rect.offsetBy(dx: origin.x, dy: origin.y),
                           characterRange: decoration.characterRange)
            }
        }
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
    }

    // MARK: - 位置计算（可单测）

    /// 给定字符区间，算出其中每个装饰该画在哪。抽成纯查询是为了能在单测里断言
    /// 「图片预留的空白确实存在、且不压到任何一行文字」，而不是靠人眼盯模拟器。
    func rects(for characterRange: NSRange) -> [Decoration] {
        guard let storage = textStorage, characterRange.length > 0 else { return [] }
        var result = [Decoration]()
        storage.enumerateAttribute(.ppMarkdownSyntax, in: characterRange, options: []) {
            value, range, _ in
            guard let syntax = value as? PPMarkdownSyntax else { return }
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            switch syntax.role {
            case .codeBlock:
                if let rect = codeRect(forGlyphRange: glyphRange) {
                    result.append(Decoration(syntax: syntax, characterRange: range, rect: rect))
                }
            case .inlineCode:
                if let rect = inlineCodeRect(forGlyphRange: glyphRange) {
                    result.append(Decoration(syntax: syntax, characterRange: range, rect: rect))
                }
            case .quoteStripe:
                result.append(contentsOf: quoteStripes(forGlyphRange: glyphRange, syntax: syntax,
                                                       characterRange: range))
            case .bullet:
                if let rect = bulletRect(forGlyphRange: glyphRange) {
                    result.append(Decoration(syntax: syntax, characterRange: range, rect: rect))
                }
            case .thematicBreak:
                if let rect = thematicBreakRect(forGlyphRange: glyphRange) {
                    result.append(Decoration(syntax: syntax, characterRange: range, rect: rect))
                }
            case .imagePreview(_, let size):
                if let rect = imageRect(forGlyphRange: glyphRange, size: size) {
                    result.append(Decoration(syntax: syntax, characterRange: range, rect: rect))
                }
            }
        }
        return result
    }

    private func codeRect(forGlyphRange glyphRange: NSRange) -> CGRect? {
        var union: CGRect? = nil
        var firstMinY = CGFloat.greatestFiniteMagnitude
        var lastMaxY = -CGFloat.greatestFiniteMagnitude
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX: CGFloat = 0
        enumerateLineFragments(forGlyphRange: glyphRange) { rect, used, _, _, _ in
            union = union.map { $0.union(rect) } ?? rect
            firstMinY = min(firstMinY, used.minY)
            lastMaxY = max(lastMaxY, used.maxY)
            minX = min(minX, used.minX)
            maxX = max(maxX, rect.maxX)
        }
        guard union != nil else { return nil }
        return CGRect(x: minX - style.codeBlockHorizontalBleed,
                      y: firstMinY - style.codeBlockVerticalBleed,
                      width: maxX - minX + style.codeBlockHorizontalBleed * 2,
                      height: lastMaxY - firstMinY + style.codeBlockVerticalBleed * 2)
    }

    private func inlineCodeRect(forGlyphRange glyphRange: NSRange) -> CGRect? {
        guard glyphRange.length > 0 else { return nil }
        var used = lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let padding = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)?
            .lineFragmentPadding ?? 0
        used.origin.x += padding
        return used.insetBy(dx: -style.inlineCodeHorizontalPadding, dy: 1)
    }

    private func quoteStripes(forGlyphRange glyphRange: NSRange, syntax: PPMarkdownSyntax,
                              characterRange: NSRange) -> [Decoration] {
        var stripes = [Decoration]()
        let stripeWidth = style.quoteStripeWidth
        let stripeOffset = style.quoteStripeGap + style.quoteStripeWidth
        enumerateLineFragments(forGlyphRange: glyphRange) { _, used, container, _, _ in
            let startX = used.minX + container.lineFragmentPadding
            stripes.append(Decoration(syntax: syntax, characterRange: characterRange,
                                      rect: CGRect(x: startX - stripeOffset, y: used.minY,
                                                   width: stripeWidth,
                                                   height: used.height)))
        }
        return stripes
    }

    private func bulletRect(forGlyphRange glyphRange: NSRange) -> CGRect? {
        guard glyphRange.length > 0 else { return nil }
        var used = lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let padding = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)?
            .lineFragmentPadding ?? 0
        used.origin.x += padding
        let diameter = style.bulletDiameter
        return CGRect(x: used.minX - style.bulletGap - diameter,
                      y: used.midY - diameter / 2,
                      width: diameter, height: diameter)
    }

    private func thematicBreakRect(forGlyphRange glyphRange: NSRange) -> CGRect? {
        guard glyphRange.length > 0 else { return nil }
        let line = lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        var used = lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let padding = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)?
            .lineFragmentPadding ?? 0
        used.origin.x += padding
        let startX = used.minX + style.thematicBreakHorizontalInset
        let endX = line.maxX - style.thematicBreakHorizontalInset
        guard endX > startX else { return nil }
        return CGRect(x: startX, y: used.midY, width: endX - startX, height: 1)
    }

    /// 图片画在源码行上方那段由 `paragraphSpacingBefore` 让出来的空白里。
    /// 基准取 `used.minY`（真正画字的那条线的顶部）而不是 `line.minY`：
    /// TextKit 1 会把 spacingBefore 并进片段矩形，两者不一定相等。
    private func imageRect(forGlyphRange glyphRange: NSRange, size: CGSize) -> CGRect? {
        guard glyphRange.length > 0 else { return nil }
        var used = lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let padding = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)?
            .lineFragmentPadding ?? 0
        used.origin.x += padding
        return CGRect(x: used.minX, y: used.minY - style.imagePreviewGap - size.height,
                      width: size.width, height: size.height)
    }

    // MARK: - 画笔

    private func paint(roundedRect rect: CGRect, color: UIColor, radius: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
        context.fillPath()
        context.restoreGState()
    }

    private func paint(verticalLine rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(style.colors.quoteStripe.cgColor)
        context.setLineWidth(style.quoteStripeWidth)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: rect.minX + style.quoteStripeWidth / 2, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX + style.quoteStripeWidth / 2, y: rect.maxY))
        context.strokePath()
        context.restoreGState()
    }

    private func paint(horizontalLine rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(style.colors.thematicBreak.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: rect.minX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.strokePath()
        context.restoreGState()
    }

    private func paint(filledEllipseIn rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setFillColor(style.colors.quoteStripe.cgColor)
        context.fillEllipse(in: rect)
        context.restoreGState()
    }

    private func paintImage(atPath path: String, size: CGSize, in rect: CGRect,
                            characterRange: NSRange) {
        guard let cache = imageCache else { return }
        guard let image = cache.image(for: path) else {
            loadImage(path: path, pointSize: size, characterRange: characterRange)
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 4).cgPath)
        context.clip()
        image.draw(in: rect)
        context.restoreGState()
    }

    // MARK: - 图片异步补全

    private var requestedPaths = Set<String>()

    private func loadImage(path: String, pointSize: CGSize, characterRange: NSRange) {
        guard let cache = imageCache, !requestedPaths.contains(path) else { return }
        requestedPaths.insert(path)
        let glyphRange = self.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        cache.request(path: path, pointSize: pointSize) { [weak self] image in
            guard let self = self else { return }
            self.requestedPaths.remove(path)
            guard image != nil else { return }
            // 位图到位只需要重画，行高早在「只读元数据」那一轮就留好了。
            self.invalidateDisplay(forGlyphRange: glyphRange)
        }
    }
}
