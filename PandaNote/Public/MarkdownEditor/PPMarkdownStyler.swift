//
//  PPMarkdownStyler.swift
//
//  把扫描结果翻译成属性，直接打在「源码本身」这一段文本上。
//
//  本文件有一条铁律：**只调用 addAttribute / removeAttribute，绝不 insert 或
//  replaceCharacters**。一旦往文本里插字符（哪怕是图片附件的 U+FFFC），
//  显示文本就和源码永久分叉，全选复制、搜索、撤销全部会跟着坏。
//

import UIKit

struct PPMarkdownStyler {

    let style: PPMarkdownStyle
    let images: PPMarkdownImageCache
    var cacheDir: String

    /// 在原地给 `text` 上色。调用方必须保证 `text.string` 就是源码本身。
    func apply(to text: NSMutableAttributedString,
               source: PPMarkdownSource,
               blocks: [PPMarkdownBlock],
               spans: [PPMarkdownInlineSpan]) {
        let whole = NSRange(location: 0, length: text.length)
        reset(whole, in: text)

        for block in blocks {
            style(block, in: text, source: source)
        }
        for span in spans {
            style(span, in: text, source: source,
                  block: ownerBlock(containing: span.range.location, in: blocks))
        }
        // 标记色最后打：段落里也可能有 `#`，但块标记优先于行内解释。
        for block in blocks {
            for marker in block.markerRanges {
                text.addAttribute(.foregroundColor, value: style.markerColor, range: marker)
            }
        }
    }

    // MARK: - 复位

    /// 每一轮都从干净状态开始，否则上一次渲染留下的装饰会粘在已经改过的文字上。
    private func reset(_ whole: NSRange, in text: NSMutableAttributedString) {
        text.addAttributes([
            .font: style.fonts.body,
            .foregroundColor: style.colors.body,
            .paragraphStyle: bodyParagraphStyle()
        ], range: whole)
        text.removeAttribute(.ppMarkdownSyntax, range: whole)
        text.removeAttribute(.link, range: whole)
        text.removeAttribute(.backgroundColor, range: whole)
    }

    private func bodyParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.paragraphSpacing = style.paragraphSpacing
        return paragraph
    }

    // MARK: - 块级

    private func style(_ block: PPMarkdownBlock, in text: NSMutableAttributedString,
                       source: PPMarkdownSource) {
        switch block.kind {
        case .blank, .paragraph:
            break

        case .heading(let level):
            text.addAttribute(.font, value: font(forHeading: level), range: block.contentRange)

        case .thematicBreak:
            guard let marker = block.markerRanges.first else { break }
            text.addAttribute(.ppMarkdownSyntax, value: PPMarkdownSyntax.thematicBreak, range: marker)

        case .blockQuote(let depth):
            let paragraph = style.paragraphStyle(quoteDepth: depth, base: bodyParagraphStyle())
            text.addAttribute(.paragraphStyle, value: paragraph, range: block.range)
            text.addAttribute(.foregroundColor, value: style.quoteColor, range: block.contentRange)
            guard block.contentRange.length > 0 else { break }
            text.addAttribute(.ppMarkdownSyntax,
                              value: PPMarkdownSyntax.quoteStripe(depth: depth),
                              range: block.contentRange)

        case .listItem(let depth, let ordered):
            let paragraph = style.paragraphStyle(listDepth: depth,
                                                contentColumn: block.listContentColumn,
                                                base: bodyParagraphStyle())
            text.addAttribute(.paragraphStyle, value: paragraph, range: block.range)
            // 有序列表的序号本身就是正文，不画圆点。
            guard !ordered, let marker = block.markerRanges.first else { break }
            text.addAttribute(.ppMarkdownSyntax,
                              value: PPMarkdownSyntax.bullet(depth: depth),
                              range: NSRange(location: marker.location, length: 1))

        case .fencedCode:
            styleCodeBlock(block, in: text)

        case .indentedCode:
            styleCodeBlock(block, in: text)

        case .html:
            text.addAttribute(.foregroundColor, value: style.markerColor, range: block.contentRange)
        }
    }

    private func styleCodeBlock(_ block: PPMarkdownBlock, in text: NSMutableAttributedString) {
        let font = style.fonts.code
        text.addAttribute(.font, value: font, range: block.contentRange)
        text.addAttribute(.foregroundColor, value: style.colors.code, range: block.contentRange)
        text.addAttribute(.ppMarkdownSyntax, value: PPMarkdownSyntax.codeBlock,
                          range: block.contentRange)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = style.paragraphSpacing
        text.addAttribute(.paragraphStyle, value: paragraph, range: block.range)
    }

    private func font(forHeading level: Int) -> UIFont {
        switch level {
        case 1: return style.fonts.heading1
        case 2: return style.fonts.heading2
        case 3: return style.fonts.heading3
        case 4: return style.fonts.heading4
        case 5: return style.fonts.heading5
        default: return style.fonts.heading6
        }
    }

    // MARK: - 行内

    private func style(_ span: PPMarkdownInlineSpan, in text: NSMutableAttributedString,
                       source: PPMarkdownSource, block: PPMarkdownBlock?) {
        for marker in span.markerRanges {
            text.addAttribute(.foregroundColor, value: style.markerColor, range: marker)
        }
        switch span.kind {
        case .codeSpan:
            text.addAttribute(.font, value: style.fonts.code, range: span.range)
            text.addAttribute(.foregroundColor, value: style.colors.code,
                              range: span.contentRange)
            text.addAttribute(.ppMarkdownSyntax, value: PPMarkdownSyntax.inlineCode,
                              range: span.contentRange)

        case .emphasis:
            text.addAttribute(.font, value: traitFont(.traitItalic), range: span.contentRange)

        case .strong:
            text.addAttribute(.font, value: traitFont(.traitBold), range: span.contentRange)

        case .strikethrough:
            text.addAttribute(.strikethroughStyle,
                              value: NSUnderlineStyle.single.rawValue,
                              range: span.contentRange)

        case .link, .autolink:
            styleLink(span, in: text, source: source)

        case .image:
            styleImage(span, in: text, source: source, block: block)

        case .htmlInline, .taskBox:
            break
        }
    }

    private func styleLink(_ span: PPMarkdownInlineSpan, in text: NSMutableAttributedString,
                           source: PPMarkdownSource) {
        guard let url = span.urlString, let link = URL(string: url) else { return }
        text.addAttribute(.link, value: link, range: span.contentRange)
        text.addAttribute(.foregroundColor, value: style.colors.link, range: span.contentRange)
    }

    /// 图片：源码整段弱化 + 可点击预览，预览图由布局画在该行上方预留的空白里。
    private func styleImage(_ span: PPMarkdownInlineSpan, in text: NSMutableAttributedString,
                            source: PPMarkdownSource, block: PPMarkdownBlock?) {
        guard let url = span.urlString else { return }
        let path = PPMarkdownImageCache.localPath(for: url, cacheDir: cacheDir)
        let tapURL = "pandanote://openimage?path=\(path)"
        text.addAttribute(.link, value: tapURL, range: span.range)
        text.addAttribute(.foregroundColor, value: style.markerColor, range: span.range)
        guard FileManager.default.fileExists(atPath: path),
              let size = images.displaySize(for: path,
                                            maxWidth: style.imageMaxWidth,
                                            maxHeight: style.imageMaxHeight),
              let line = standaloneImageLine(of: span, source: source, block: block) else { return }
        text.addAttribute(.ppMarkdownSyntax,
                          value: PPMarkdownSyntax.imagePreview(path: path, size: size),
                          range: span.range)
        // `paragraphSpacingBefore` 只有打在段首才生效，所以预留区间就是这一行本身。
        let paragraph = style.paragraphStyle(imageGap: size.height + style.imagePreviewGap,
                                            base: bodyParagraphStyle())
        text.addAttribute(.paragraphStyle, value: paragraph, range: line)
    }

    /// 图片独占一段开头时返回它所在行的区间，否则返回 nil。
    /// 混在段落中间的图片不能预留——那段空白属于整段的首行，图片会画到上一行上去。
    private func standaloneImageLine(of span: PPMarkdownInlineSpan, source: PPMarkdownSource,
                                     block: PPMarkdownBlock?) -> NSRange? {
        guard let block = block else { return nil }
        let line = source.line(of: span.range.location)
        let start = source.startOfLine(line)
        let end = source.endOfLine(line)
        guard block.contentRange.location == start,
              source.firstNonWhitespace(from: start, to: end) == span.range.location else { return nil }
        return NSRange(location: start, length: end - start)
    }

    /// 平铺不变量保证全体块按 `range` 有序且互不重叠，二分即可定位。
    private func ownerBlock(containing offset: Int, in blocks: [PPMarkdownBlock]) -> PPMarkdownBlock? {
        var lo = 0
        var hi = blocks.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let range = blocks[mid].range
            if offset < range.location { hi = mid - 1 }
            else if offset >= NSMaxRange(range) { lo = mid + 1 }
            else { return blocks[mid] }
        }
        return nil
    }

    // MARK: - 字体

    private func traitFont(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let body = style.fonts.body
        let descriptor = body.fontDescriptor.withSymbolicTraits(traits) ?? body.fontDescriptor
        return UIFont(descriptor: descriptor, size: body.pointSize)
    }
}
