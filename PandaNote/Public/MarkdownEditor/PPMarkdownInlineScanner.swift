//
//  PPMarkdownInlineScanner.swift
//  PandaNote
//
//  纯 Swift 行内语法扫描器：只输出「哪几个区间是什么角色」，
//  由着色层照着上颜色，全程不产生也不删除任何字符。
//

import Foundation

/// 行内结构的角色。
public enum PPMarkdownInlineKind: Equatable {
    case codeSpan
    case emphasis
    case strong
    case strikethrough
    case link
    case image
    case autolink
    case htmlInline
    /// `- [ ]` / `- [x]`：区间覆盖 `[ ]` 三个字符，由布局管理器在其上画出方框。
    case taskBox(checked: Bool)
}

public struct PPMarkdownInlineSpan {
    public let kind: PPMarkdownInlineKind

    /// 整个语法结构，含所有标记字符。
    public let range: NSRange

    /// 正文区间（不含标记）。`taskBox` / `htmlInline` 没有正文，长度可能为 0。
    public let contentRange: NSRange

    /// 需要弱化显示的标记区间：`**` `` ` `` `[` `]` `(url)` 等。
    public let markerRanges: [NSRange]

    /// link / image / autolink 的目标 URL 原文，未解码、未做相对路径解析。
    public let urlString: String?

    init(kind: PPMarkdownInlineKind, range: NSRange, contentRange: NSRange,
         markerRanges: [NSRange], urlString: String? = nil) {
        self.kind = kind
        self.range = range
        self.contentRange = contentRange
        self.markerRanges = markerRanges
        self.urlString = urlString
    }
}

/// 行内扫描器。
///
/// 与 CommonMark 的偏差都朝「少上色」一侧收敛：判不出来就当普通文字，
/// 判错了也只是某对星号灰了或不灰，字符序列始终等于源码。
public struct PPMarkdownInlineScanner {

    public init() {}

    // MARK: - 入口

    /// 跳过代码块、HTML 块与空行，只在需要行内装饰的块里扫描。
    public func scan(_ src: PPMarkdownSource, blocks: [PPMarkdownBlock]) -> [PPMarkdownInlineSpan] {
        var spans = [PPMarkdownInlineSpan]()
        for block in blocks {
            switch block.kind {
            case .blank, .fencedCode, .indentedCode, .html, .thematicBreak:
                continue
            default:
                break
            }
            spans.append(contentsOf: scan(src, in: block.contentRange))
        }
        return spans
    }

    /// 扫描一个区间。调用方应保证区间不跨行首块结构（段落/标题/列表项的 contentRange）。
    public func scan(_ src: PPMarkdownSource, in range: NSRange) -> [PPMarkdownInlineSpan] {
        var spans = [PPMarkdownInlineSpan]()
        let end = NSMaxRange(range)
        var i = range.location

        while i < end {
            switch src.unit(at: i) {
            case PPMarkdownSource.backslash:
                // 转义：`\*` 里的星号没有语法意义，两个字符一起跳过。
                i += 2
            case PPMarkdownSource.grave:
                if let span = codeSpan(at: i, end: end, src: src) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.star:
                if let span = emphasisLike(at: i, end: end, src: src, char: PPMarkdownSource.star) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.under:
                // snake_case 里的下划线不是强调：起始 `_` 前是字母数字时跳过。
                if i > range.location, isWord(src.unit(at: i - 1)),
                   i + 1 < end, isWord(src.unit(at: i + 1)) {
                    i += 1
                } else if let span = emphasisLike(at: i, end: end, src: src, char: PPMarkdownSource.under) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.tilde:
                if let span = strikethrough(at: i, end: end, src: src) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.bang:
                if let span = linkOrImage(at: i + 1, end: end, src: src, isImage: true) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.lbracket:
                if let span = taskBox(at: i, end: end, src: src) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else if let span = linkOrImage(at: i, end: end, src: src, isImage: false) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            case PPMarkdownSource.lt:
                if let span = autolink(at: i, end: end, src: src) {
                    spans.append(span)
                    i = NSMaxRange(span.range)
                } else {
                    i += 1
                }
            default:
                i += 1
            }
        }
        return spans
    }

    // MARK: - 行内代码

    /// 闭合围栏的反引号个数必须与开头一致，所以这里按「串」而不是按「字符」匹配。
    private func codeSpan(at i: Int, end: Int, src: PPMarkdownSource) -> PPMarkdownInlineSpan? {
        let open = runLength(of: PPMarkdownSource.grave, at: i, end: end, src: src)
        let contentStart = i + open
        var k = contentStart
        while k + open <= end {
            if src.unit(at: k) == PPMarkdownSource.grave {
                let found = runLength(of: PPMarkdownSource.grave, at: k, end: end, src: src)
                if found == open {
                    let contentEnd = k
                    guard contentEnd > contentStart else { return nil }
                    let markers = [NSRange(location: i, length: open),
                                   NSRange(location: k, length: open)]
                    return PPMarkdownInlineSpan(kind: .codeSpan,
                                                range: NSRange(location: i, length: k + open - i),
                                                contentRange: NSRange(location: contentStart,
                                                                       length: contentEnd - contentStart),
                                                markerRanges: markers)
                }
                k += found
            } else {
                k += 1
            }
        }
        return nil
    }

    // MARK: - 强调 / 加粗

    /// 同一字符连写成 2 个以上时优先按加粗处理，`***x***` 只判出最外层的加粗。
    private func emphasisLike(at i: Int, end: Int, src: PPMarkdownSource, char: UniChar)
        -> PPMarkdownInlineSpan? {
        let open = min(runLength(of: char, at: i, end: end, src: src), 2)
        guard open >= 1 else { return nil }
        let contentStart = i + open
        guard contentStart < end, !isSpace(src.unit(at: contentStart)) else { return nil }
        guard let close = closingRun(of: char, length: open, after: contentStart, end: end, src: src) else {
            return nil
        }
        guard close > contentStart else { return nil }
        let kind: PPMarkdownInlineKind = open == 1 ? .emphasis : .strong
        return PPMarkdownInlineSpan(kind: kind,
                                    range: NSRange(location: i, length: close + open - i),
                                    contentRange: NSRange(location: contentStart,
                                                          length: close - contentStart),
                                    markerRanges: [NSRange(location: i, length: open),
                                                   NSRange(location: close, length: open)])
    }

    /// 从 `after` 起找第一个「独立成串」的同种闭合标记。
    private func closingRun(of char: UniChar, length: Int, after: Int, end: Int,
                            src: PPMarkdownSource) -> Int? {
        var i = after
        while i + length <= end {
            if src.unit(at: i) == char, runLength(of: char, at: i, end: end, src: src) == length,
               !isSpace(src.unit(at: i - 1)) {
                return i
            }
            i += 1
        }
        return nil
    }

    // MARK: - 删除线

    private func strikethrough(at i: Int, end: Int, src: PPMarkdownSource) -> PPMarkdownInlineSpan? {
        guard runLength(of: PPMarkdownSource.tilde, at: i, end: end, src: src) == 2 else { return nil }
        let contentStart = i + 2
        guard contentStart < end, !isSpace(src.unit(at: contentStart)) else { return nil }
        guard let close = closingRun(of: PPMarkdownSource.tilde, length: 2,
                                     after: contentStart, end: end, src: src) else { return nil }
        return PPMarkdownInlineSpan(kind: .strikethrough,
                                    range: NSRange(location: i, length: close + 2 - i),
                                    contentRange: NSRange(location: contentStart,
                                                          length: close - contentStart),
                                    markerRanges: [NSRange(location: i, length: 2),
                                                   NSRange(location: close, length: 2)])
    }

    // MARK: - 链接与图片

    /// 约定：`i` 始终是链接文本起始 `[` 的位置；`isImage` 为真时它的前一位是 `!`。
    private func linkOrImage(at i: Int, end: Int, src: PPMarkdownSource, isImage: Bool)
        -> PPMarkdownInlineSpan? {
        guard src.unit(at: i) == PPMarkdownSource.lbracket else { return nil }
        let start = isImage ? i - 1 : i
        guard start >= 0 else { return nil }

        var k = i + 1
        while k < end && src.unit(at: k) != PPMarkdownSource.rbracket {
            if src.unit(at: k) == PPMarkdownSource.backslash { k += 1 }
            k += 1
        }
        guard k < end else { return nil }
        let textStart = i + 1
        let textEnd = k
        k += 1
        guard k < end, src.unit(at: k) == PPMarkdownSource.lparen else { return nil }

        let urlStart = k + 1
        guard let urlEnd = closingParen(from: urlStart, end: end, src: src) else { return nil }
        let wholeEnd = urlEnd + 1
        guard wholeEnd <= end else { return nil }

        let raw = src.string(in: NSRange(location: urlStart, length: urlEnd - urlStart))
        let url = normalizeURL(raw)
        let contentLength = max(0, textEnd - textStart)
        return PPMarkdownInlineSpan(kind: isImage ? .image : .link,
                                    range: NSRange(location: start, length: wholeEnd - start),
                                    contentRange: NSRange(location: textStart, length: contentLength),
                                    markerRanges: [NSRange(location: start, length: textStart - start),
                                                   NSRange(location: textEnd, length: wholeEnd - textEnd)],
                                    urlString: url)
    }

    private func closingParen(from i: Int, end: Int, src: PPMarkdownSource) -> Int? {
        var depth = 1
        var k = i
        while k < end {
            let u = src.unit(at: k)
            if u == PPMarkdownSource.backslash { k += 2; continue }
            if u == PPMarkdownSource.lparen { depth += 1 }
            if u == PPMarkdownSource.rparen {
                depth -= 1
                if depth == 0 { return k }
            }
            k += 1
        }
        return nil
    }

    /// `(url)`、`(url "title")`、`(<url>)` 三种写法统一取出 URL。
    private func normalizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("<"), let close = trimmed.firstIndex(of: ">") {
            return String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
        }
        if let space = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) {
            return String(trimmed[..<space])
        }
        return trimmed
    }

    // MARK: - 任务框

    private func taskBox(at i: Int, end: Int, src: PPMarkdownSource) -> PPMarkdownInlineSpan? {
        guard i + 2 < end else { return nil }
        guard src.unit(at: i) == PPMarkdownSource.lbracket else { return nil }
        let state = src.unit(at: i + 1)
        guard state == PPMarkdownSource.space || state == PPMarkdownSource.xChar || state == PPMarkdownSource.XChar else {
            return nil
        }
        guard src.unit(at: i + 2) == PPMarkdownSource.rbracket else { return nil }
        // 后面必须跟空白，否则 `[x]` 可能是链接文字的一部分。
        guard i + 3 >= end || isSpace(src.unit(at: i + 3)) else { return nil }
        return PPMarkdownInlineSpan(kind: .taskBox(checked: state != PPMarkdownSource.space),
                                    range: NSRange(location: i, length: 3),
                                    contentRange: NSRange(location: i, length: 3),
                                    markerRanges: [])
    }

    // MARK: - 自动链接与行内 HTML

    private func autolink(at i: Int, end: Int, src: PPMarkdownSource) -> PPMarkdownInlineSpan? {
        var k = i + 1
        while k < end, PPMarkdownSource.isASCIILetter(src.unit(at: k)) || src.unit(at: k) == PPMarkdownSource.plus
            || src.unit(at: k) == PPMarkdownSource.dot || src.unit(at: k) == PPMarkdownSource.dash { k += 1 }
        guard k > i + 1, k < end, src.unit(at: k) == PPMarkdownSource.colon else {
            return htmlInline(at: i, end: end, src: src)
        }
        let urlStart = i + 1
        var m = k + 1
        while m < end {
            let u = src.unit(at: m)
            if u == PPMarkdownSource.gt { break }
            if isSpace(u) { return nil }
            m += 1
        }
        guard m < end, src.unit(at: m) == PPMarkdownSource.gt, m > urlStart else { return nil }
        return PPMarkdownInlineSpan(kind: .autolink,
                                    range: NSRange(location: i, length: m + 1 - i),
                                    contentRange: NSRange(location: urlStart, length: m - urlStart),
                                    markerRanges: [NSRange(location: i, length: 1),
                                                   NSRange(location: m, length: 1)],
                                    urlString: src.string(in: NSRange(location: urlStart,
                                                                      length: m - urlStart)))
    }

    private func htmlInline(at i: Int, end: Int, src: PPMarkdownSource) -> PPMarkdownInlineSpan? {
        var k = i + 1
        guard k < end, src.unit(at: k) == PPMarkdownSource.slash
            || PPMarkdownSource.isASCIILetter(src.unit(at: k)) else { return nil }
        while k < end, src.unit(at: k) != PPMarkdownSource.gt { k += 1 }
        guard k < end, k > i + 1 else { return nil }
        return PPMarkdownInlineSpan(kind: .htmlInline,
                                    range: NSRange(location: i, length: k + 1 - i),
                                    contentRange: NSRange(location: i, length: k + 1 - i),
                                    markerRanges: [])
    }

    // MARK: - 小工具

    private func runLength(of char: UniChar, at i: Int, end: Int, src: PPMarkdownSource) -> Int {
        var k = i
        while k < end && src.unit(at: k) == char { k += 1 }
        return k - i
    }

    private func isSpace(_ u: UniChar) -> Bool {
        return u == PPMarkdownSource.space || u == PPMarkdownSource.tab
    }

    private func isWord(_ u: UniChar) -> Bool {
        return PPMarkdownSource.isASCIIDigit(u) || PPMarkdownSource.isASCIILetter(u)
    }
}
