//
//  PPMarkdownBlockScanner.swift
//  PandaNote
//
//  纯 Swift 顶层块扫描器：直接读源码，产出「哪一段源码是什么形状」，
//  不做 AST、不生成任何显示文本。
//

import Foundation

/// 顶层块扫描器。
///
/// 设计立场：
/// 1. **只判形状，不求规范等价。** 边角情况判错的后果是「某段文字少了一层灰色标记」
///    或「某个背景多刷了一行」，永远不会改动字符——因为本类型不写字符串，只写区间。
/// 2. **行是基本扫描单位。** 每个块都从某行行首开始，因此可以先收集「行区间」，
///    最后统一平铺成 UTF-16 区间，由构造方式本身保证平铺不变量。
/// 3. **列表不递归。** 嵌套项作为兄弟块输出，用 `depth` 标注层级，
///    这样每个 `- ` 标记都有自己的块，画圆点时不必再遍历树。
/// 4. **缩进一律相对「容器基准列」判定**（见 `base`）。列表项内容本身带缩进，
///    如果按绝对列判断 `indent <= 3`，二级、三级列表就会被当成普通文字吞掉。
public struct PPMarkdownBlockScanner {

    public init() {}

    // MARK: - 中间结构

    /// 顶层结构先以「行区间」表达，避免在构造过程中反复换算偏移。
    private struct Pending {
        let kind: PPMarkdownBlockKind
        let firstLine: Int
        let lastLine: Int
        let markerRanges: [NSRange]
        let listContentColumn: Int
    }

    /// 一行的快照。`first` 是行内首个非空白字符偏移，整行空白时等于 `end`。
    private struct LineView {
        let number: Int
        let start: Int
        let end: Int
        let indent: Int
        let first: Int

        var isBlank: Bool { first >= end }
    }

    // MARK: - 入口

    public func scan(_ src: PPMarkdownSource) -> [PPMarkdownBlock] {
        var pendings: [Pending] = []
        var columnStack: [Int] = []
        var line = 1
        let total = src.lineCount

        while line <= total {
            let view = self.view(line, src: src)
            let base = columnStack.last ?? 0

            if view.isBlank {
                var last = line
                while last + 1 <= total && self.view(last + 1, src: src).isBlank { last += 1 }
                pendings.append(Pending(kind: .blank, firstLine: line, lastLine: last,
                                        markerRanges: [], listContentColumn: 0))
                line = last + 1
                continue
            }

            if let fenced = scanFencedCode(view, base: base, src: src, total: total) {
                pendings.append(fenced)
                line = fenced.lastLine + 1
                continue
            }

            if let heading = scanATXHeading(view, base: base, src: src) {
                pendings.append(heading)
                line += 1
                continue
            }

            if isThematicBreak(view, base: base, src: src) {
                pendings.append(Pending(kind: .thematicBreak, firstLine: line, lastLine: line,
                                        markerRanges: [NSRange(location: view.first,
                                                               length: view.end - view.first)],
                                        listContentColumn: 0))
                line += 1
                continue
            }

            if let quoted = scanBlockQuote(view, base: base, src: src, total: total) {
                pendings.append(quoted)
                line = quoted.lastLine + 1
                continue
            }

            if let item = scanListItem(view, base: base, src: src, total: total,
                                       columnStack: &columnStack) {
                pendings.append(item)
                line = item.lastLine + 1
                continue
            }

            if isHTMLBlockStart(view, base: base, src: src) {
                var last = line
                while last + 1 <= total, !self.view(last + 1, src: src).isBlank { last += 1 }
                pendings.append(Pending(kind: .html, firstLine: line, lastLine: last,
                                        markerRanges: [], listContentColumn: 0))
                line = last + 1
                continue
            }

            if view.indent - base >= 4 {
                var last = line
                while last + 1 <= total {
                    let next = self.view(last + 1, src: src)
                    if next.isBlank || next.indent - base < 4 { break }
                    last += 1
                }
                pendings.append(Pending(kind: .indentedCode, firstLine: line, lastLine: last,
                                        markerRanges: [], listContentColumn: 0))
                line = last + 1
                continue
            }

            let paragraph = scanParagraph(view, base: base, src: src, total: total)
            pendings.append(paragraph)
            line = paragraph.lastLine + 1
        }

        return tile(pendings, src: src)
    }

    // MARK: - 逐行读取

    private func view(_ line: Int, src: PPMarkdownSource) -> LineView {
        let start = src.startOfLine(line)
        let end = src.endOfLine(line)
        return LineView(number: line,
                        start: start,
                        end: end,
                        indent: src.indent(ofLine: line),
                        first: src.firstNonWhitespace(from: start, to: end))
    }

    /// 该行相对当前容器还剩几个空格可用作块标记。超过 3 就不是块标记了。
    /// 允许负值：缩进比基准还浅，说明外层容器重新开口（列表回退到兄弟项）。
    private func withinMarkerZone(_ view: LineView, base: Int) -> Bool {
        return view.indent - base <= 3
    }

    // MARK: - 围栏代码块

    private func scanFencedCode(_ view: LineView, base: Int, src: PPMarkdownSource,
                                total: Int) -> Pending? {
        guard withinMarkerZone(view, base: base),
              let open = fenceRun(at: view.first, end: view.end, src: src) else { return nil }

        var last = view.number
        var closeView: LineView? = nil
        var line = view.number + 1
        while line <= total {
            let v = self.view(line, src: src)
            if withinMarkerZone(v, base: base), let run = fenceRun(at: v.first, end: v.end, src: src),
               run.char == open.char, run.length >= open.length,
               restIsBlank(from: v.first + run.length, end: v.end, src: src) {
                closeView = v
                last = line
                break
            }
            last = line
            line += 1
        }

        var markers = [NSRange(location: view.first, length: view.end - view.first)]
        var infoStringRange: NSRange? = nil
        let infoStart = view.first + open.length
        let infoEnd = trailingWhitespaceStart(in: view, src: src)
        if infoStart < infoEnd {
            infoStringRange = NSRange(location: infoStart, length: infoEnd - infoStart)
        }
        if let closeView = closeView {
            markers.append(NSRange(location: closeView.first, length: closeView.end - closeView.first))
        }

        return Pending(kind: .fencedCode(infoStringRange: infoStringRange),
                       firstLine: view.number, lastLine: last,
                       markerRanges: markers, listContentColumn: 0)
    }

    /// 从 `i` 开始的同种围栏字符个数；不足 3 个返回 nil。
    private func fenceRun(at i: Int, end: Int, src: PPMarkdownSource) -> (char: UniChar, length: Int)? {
        guard i < end else { return nil }
        let c = src.unit(at: i)
        guard c == PPMarkdownSource.grave || c == PPMarkdownSource.tilde else { return nil }
        var k = i
        while k < end && src.unit(at: k) == c { k += 1 }
        let length = k - i
        guard length >= 3 else { return nil }
        return (c, length)
    }

    private func restIsBlank(from i: Int, end: Int, src: PPMarkdownSource) -> Bool {
        var k = i
        while k < end {
            if !isSpace(src.unit(at: k)) { return false }
            k += 1
        }
        return true
    }

    /// 行尾空白开始前的偏移，用于切出 info string。
    private func trailingWhitespaceStart(in view: LineView, src: PPMarkdownSource) -> Int {
        var k = view.end
        while k > view.first && isSpace(src.unit(at: k - 1)) { k -= 1 }
        return k
    }

    // MARK: - ATX 标题

    private func scanATXHeading(_ view: LineView, base: Int, src: PPMarkdownSource) -> Pending? {
        guard withinMarkerZone(view, base: base),
              src.unit(at: view.first) == PPMarkdownSource.hash else { return nil }
        var i = view.first
        var level = 0
        while i < view.end && src.unit(at: i) == PPMarkdownSource.hash { i += 1; level += 1 }
        guard level >= 1, level <= 6 else { return nil }

        var markers = [NSRange(location: view.first, length: i - view.first)]
        if i < view.end {
            guard isSpace(src.unit(at: i)) else { return nil }
            var contentStart = i
            while contentStart < view.end, isSpace(src.unit(at: contentStart)) { contentStart += 1 }
            markers[0] = NSRange(location: view.first, length: contentStart - view.first)
            if let closing = closingHashRun(in: view, contentStart: contentStart, src: src) {
                markers.append(closing)
            }
        }

        return Pending(kind: .heading(level: level), firstLine: view.number, lastLine: view.number,
                       markerRanges: markers, listContentColumn: 0)
    }

    /// `## 标题 ##` 结尾的 `##` 也是标记。仅当它前面是空白且前面还有正文时才成立。
    private func closingHashRun(in view: LineView, contentStart: Int,
                                src: PPMarkdownSource) -> NSRange? {
        var k = view.end
        while k > contentStart && isSpace(src.unit(at: k - 1)) { k -= 1 }
        let hashesEnd = k
        while k > contentStart && src.unit(at: k - 1) == PPMarkdownSource.hash { k -= 1 }
        guard k < hashesEnd, k > contentStart else { return nil }
        guard isSpace(src.unit(at: k - 1)) else { return nil }
        return NSRange(location: k, length: hashesEnd - k)
    }

    private func isSpace(_ u: UniChar) -> Bool {
        return u == PPMarkdownSource.space || u == PPMarkdownSource.tab
    }

    // MARK: - 分割线

    private func isThematicBreak(_ view: LineView, base: Int, src: PPMarkdownSource) -> Bool {
        guard withinMarkerZone(view, base: base), !view.isBlank else { return false }
        let c = src.unit(at: view.first)
        guard c == PPMarkdownSource.star || c == PPMarkdownSource.dash || c == PPMarkdownSource.under else {
            return false
        }
        var count = 0
        var i = view.first
        while i < view.end {
            let u = src.unit(at: i)
            if u == c { count += 1 }
            else if !isSpace(u) { return false }
            i += 1
        }
        return count >= 3
    }

    // MARK: - 引用块

    private func scanBlockQuote(_ view: LineView, base: Int, src: PPMarkdownSource,
                                total: Int) -> Pending? {
        guard withinMarkerZone(view, base: base),
              src.unit(at: view.first) == PPMarkdownSource.gt else { return nil }
        var markers = [quoteMarker(in: view, src: src)]
        var depth = quoteDepth(in: view, src: src)
        var last = view.number
        var line = view.number + 1

        while line <= total {
            let v = self.view(line, src: src)
            if v.isBlank { break }
            if withinMarkerZone(v, base: base), src.unit(at: v.first) == PPMarkdownSource.gt {
                markers.append(quoteMarker(in: v, src: src))
                depth = max(depth, quoteDepth(in: v, src: src))
                last = line
                line += 1
                continue
            }
            // 惰性续行：引用段落的下一行允许不写 `>`，但自己没有标记可弱化。
            if startsInterruptingBlock(v, base: base, src: src) { break }
            last = line
            line += 1
        }

        return Pending(kind: .blockQuote(depth: depth), firstLine: view.number, lastLine: last,
                       markerRanges: markers, listContentColumn: 0)
    }

    /// `> ` 本身；不含行首缩进，缩进部分保持正常颜色。
    private func quoteMarker(in view: LineView, src: PPMarkdownSource) -> NSRange {
        var i = view.first + 1
        while i < view.end && isSpace(src.unit(at: i)) { i += 1 }
        return NSRange(location: view.first, length: i - view.first)
    }

    private func quoteDepth(in view: LineView, src: PPMarkdownSource) -> Int {
        var i = view.first
        var depth = 0
        while i < view.end, src.unit(at: i) == PPMarkdownSource.gt {
            depth += 1
            i += 1
            while i < view.end && isSpace(src.unit(at: i)) { i += 1 }
        }
        return max(depth, 1)
    }

    // MARK: - 列表项

    private func scanListItem(_ view: LineView, base: Int, src: PPMarkdownSource,
                              total: Int, columnStack: inout [Int]) -> Pending? {
        // `---` 这类分割线已在更早的分派里拦掉。
        guard let marker = listMarker(in: view, base: base, src: src) else { return nil }

        // 缩进列栈换算层级：比栈顶深就进栈，回到同一列则弹出同级及更深层。
        while let last = columnStack.last, last >= marker.contentColumn { columnStack.removeLast() }
        columnStack.append(marker.contentColumn)
        let depth = max(columnStack.count - 1, 0)

        var last = view.number
        var line = view.number + 1
        while line <= total {
            let v = self.view(line, src: src)
            if v.isBlank || v.indent < marker.contentColumn { break }
            // 更深或同层的列表标记、以及其他块结构都另起一块，各自画自己的圆点。
            if listMarker(in: v, base: marker.contentColumn, src: src) != nil { break }
            if startsInterruptingBlock(v, base: marker.contentColumn, src: src) { break }
            last = line
            line += 1
        }

        return Pending(kind: .listItem(depth: depth, ordered: marker.ordered),
                       firstLine: view.number, lastLine: last,
                       markerRanges: [marker.range], listContentColumn: marker.contentColumn)
    }

    private func listMarker(in view: LineView, base: Int, src: PPMarkdownSource)
        -> (ordered: Bool, range: NSRange, contentColumn: Int)? {
        guard withinMarkerZone(view, base: base), !view.isBlank else { return nil }
        let head = src.unit(at: view.first)

        if head == PPMarkdownSource.dash || head == PPMarkdownSource.star || head == PPMarkdownSource.plus {
            return makeMarker(view: view, markerEnd: view.first + 1,
                              contentColumn: view.indent + 1, ordered: false, src: src)
        }

        var i = view.first
        var digits = 0
        while i < view.end && PPMarkdownSource.isASCIIDigit(src.unit(at: i)) { i += 1; digits += 1 }
        guard digits >= 1, digits <= 9, i < view.end else { return nil }
        let delimiter = src.unit(at: i)
        guard delimiter == PPMarkdownSource.dot || delimiter == PPMarkdownSource.rparen else { return nil }
        return makeMarker(view: view, markerEnd: i + 1,
                          contentColumn: view.indent + digits + 1, ordered: true, src: src)
    }

    /// 标记之后必须紧跟空白或行尾，同时把内容起始列按展开宽度推进。
    private func makeMarker(view: LineView, markerEnd: Int, contentColumn: Int,
                            ordered: Bool, src: PPMarkdownSource)
        -> (ordered: Bool, range: NSRange, contentColumn: Int)? {
        guard markerEnd <= view.end else { return nil }
        var column = contentColumn
        if markerEnd < view.end && !isSpace(src.unit(at: markerEnd)) { return nil }
        let end = skipSpaces(from: markerEnd, end: view.end, src: src, column: &column)
        return (ordered, NSRange(location: view.first, length: end - view.first), column)
    }

    /// 跳过空白并同步推进「展开列」，Tab 按 4 的制表位展开。
    private func skipSpaces(from i: Int, end: Int, src: PPMarkdownSource, column: inout Int) -> Int {
        var k = i
        while k < end && isSpace(src.unit(at: k)) {
            column += (src.unit(at: k) == PPMarkdownSource.tab) ? (4 - (column % 4)) : 1
            k += 1
        }
        return k
    }

    // MARK: - HTML 块

    private func isHTMLBlockStart(_ view: LineView, base: Int, src: PPMarkdownSource) -> Bool {
        guard withinMarkerZone(view, base: base),
              src.unit(at: view.first) == PPMarkdownSource.lt else { return false }
        guard view.first + 1 < view.end else { return false }
        let c = src.unit(at: view.first + 1)
        return c == PPMarkdownSource.bang
            || c == PPMarkdownSource.questionMark
            || c == PPMarkdownSource.slash
            || PPMarkdownSource.isASCIILetter(c)
    }

    // MARK: - 段落

    private func scanParagraph(_ view: LineView, base: Int, src: PPMarkdownSource,
                               total: Int) -> Pending {
        var last = view.number
        var markers = view.indent > 0
            ? [NSRange(location: view.start, length: view.first - view.start)]
            : [NSRange]()
        var line = view.number + 1

        while line <= total {
            let v = self.view(line, src: src)
            if v.isBlank { break }

            if v.indent - base < 4, let level = setextLevel(in: v, src: src) {
                markers.append(NSRange(location: v.first, length: v.end - v.first))
                return Pending(kind: .heading(level: level), firstLine: view.number, lastLine: line,
                               markerRanges: markers, listContentColumn: 0)
            }
            // 无序列表可以打断段落，有序列表不行（`2019.09 发布` 这类正文很常见）。
            if interruptsParagraph(v, base: base, src: src) { break }
            last = line
            line += 1
        }

        return Pending(kind: .paragraph, firstLine: view.number, lastLine: last,
                       markerRanges: markers, listContentColumn: 0)
    }

    /// Setext 下划线：整行只有 `=` 或只有 `-`。`=` 是一级，`-` 是二级。
    private func setextLevel(in view: LineView, src: PPMarkdownSource) -> Int? {
        guard !view.isBlank else { return nil }
        let c = src.unit(at: view.first)
        guard c == PPMarkdownSource.equal || c == PPMarkdownSource.dash else { return nil }
        var i = view.first
        while i < view.end {
            if src.unit(at: i) != c { return nil }
            i += 1
        }
        return c == PPMarkdownSource.equal ? 1 : 2
    }

    /// 能打断段落的新块起点。有序列表按 CommonMark 不算。
    private func interruptsParagraph(_ view: LineView, base: Int, src: PPMarkdownSource) -> Bool {
        guard view.indent - base <= 3 else { return false }
        if isThematicBreak(view, base: base, src: src) { return true }
        if fenceRun(at: view.first, end: view.end, src: src) != nil { return true }
        if atxHeadingMarker(in: view, src: src) { return true }
        if src.unit(at: view.first) == PPMarkdownSource.gt { return true }
        if isHTMLBlockStart(view, base: base, src: src) { return true }
        return isBulletHead(in: view, src: src)
    }

    /// 用于引用惰性续行和列表续行的边界判定。
    private func startsInterruptingBlock(_ view: LineView, base: Int, src: PPMarkdownSource) -> Bool {
        return interruptsParagraph(view, base: base, src: src)
    }

    private func atxHeadingMarker(in view: LineView, src: PPMarkdownSource) -> Bool {
        guard src.unit(at: view.first) == PPMarkdownSource.hash else { return false }
        var i = view.first
        var level = 0
        while i < view.end && src.unit(at: i) == PPMarkdownSource.hash { i += 1; level += 1 }
        guard level >= 1, level <= 6 else { return false }
        return i >= view.end || isSpace(src.unit(at: i))
    }

    private func isBulletHead(in view: LineView, src: PPMarkdownSource) -> Bool {
        let head = src.unit(at: view.first)
        guard head == PPMarkdownSource.dash || head == PPMarkdownSource.star || head == PPMarkdownSource.plus else {
            return false
        }
        let after = view.first + 1
        return after >= view.end || isSpace(src.unit(at: after))
    }

    // MARK: - 平铺

    /// 把行区间换算成 UTF-16 区间：第 k 块结束于第 k+1 块的起点，最后一块结束于全文末尾。
    /// 由此**构造性保证**全体 range 无重叠、无缝隙地覆盖 `[0, utf16Length)`。
    private func tile(_ pendings: [Pending], src: PPMarkdownSource) -> [PPMarkdownBlock] {
        guard !pendings.isEmpty else { return [] }
        let total = src.utf16Length
        var blocks = [PPMarkdownBlock]()
        blocks.reserveCapacity(pendings.count)

        for (index, pending) in pendings.enumerated() {
            let start = src.startOfLine(pending.firstLine)
            let end = index + 1 < pendings.count
                ? src.startOfLine(pendings[index + 1].firstLine)
                : total
            let contentEnd = Self.contentEndLine(pending, src: src)
            let range = NSRange(location: start, length: end - start)
            blocks.append(PPMarkdownBlock(kind: pending.kind,
                                          range: range,
                                          contentRange: NSRange(location: start,
                                                                length: max(0, contentEnd - start)),
                                          markerRanges: pending.markerRanges,
                                          listContentColumn: pending.listContentColumn,
                                          fingerprint: Self.fingerprint(of: pending.kind,
                                                                       src: src,
                                                                       range: range)))
        }
        return blocks
    }

    /// 内容结束位置取「块内最后一行非空行的行尾」，
    /// 否则未闭合围栏或尾随空行会把背景多刷一整行。
    private static func contentEndLine(_ pending: Pending, src: PPMarkdownSource) -> Int {
        var line = pending.lastLine
        while line >= pending.firstLine {
            let start = src.startOfLine(line)
            let end = src.endOfLine(line)
            if src.firstNonWhitespace(from: start, to: end) < end { return end }
            line -= 1
        }
        return src.startOfLine(pending.firstLine)
    }

    // MARK: - 指纹

    /// FNV-1a：把「形状 + 该块源码文本」压成一个整数。
    /// 增量渲染时，形状和文本都没变的块可以直接跳过重扫。
    /// 刻意不用 Swift 的 `hashValue`——它每进程随机加种，测试里不可复现。
    static func fingerprint(of kind: PPMarkdownBlockKind, src: PPMarkdownSource, range: NSRange) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ value: UInt64) {
            hash = (hash ^ value) &* 0x0000_0100_0000_01b3
        }
        mix(discriminator(of: kind))
        var i = range.location
        let end = NSMaxRange(range)
        while i < end {
            mix(UInt64(src.unit(at: i)))
            i += 1
        }
        return Int(hash & 0x7fff_ffff_ffff_ffff)
    }

    private static func discriminator(of kind: PPMarkdownBlockKind) -> UInt64 {
        switch kind {
        case .blank:
            return 1
        case .heading(let level):
            return 10 + UInt64(level)
        case .thematicBreak:
            return 20
        case .blockQuote(let depth):
            return 30 + UInt64(depth)
        case .listItem(let depth, let ordered):
            return 50 + UInt64(depth) * 2 + (ordered ? 1 : 0)
        case .paragraph:
            return 200
        case .fencedCode:
            return 210
        case .indentedCode:
            return 220
        case .html:
            return 230
        }
    }
}
