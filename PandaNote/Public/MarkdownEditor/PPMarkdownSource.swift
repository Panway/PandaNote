//
//  PPMarkdownSource.swift
//  PandaNote
//
//  Markdown 源码的不可变快照与索引设施。
//  本文件与 PPMarkdownBlockScanner / PPMarkdownInlineScanner 组成零 UIKit 依赖的纯逻辑层。
//

import Foundation

/// 源码真值容器。
///
/// 坐标系约定：全部以 **UTF-16 code unit 偏移**表示，与 `NSRange` / TextKit / `UITextView`
/// 完全同一套坐标，因此扫描结果可以直接 `addAttribute`，无需任何单位换算。
/// 这也是放弃 cmark AST 换来自写扫描器的主要收益之一——cmark 的 `start_column` 是
/// UTF-8 字节列，用在中文笔记上必须额外做 UTF-8 → UTF-16 转换。
public struct PPMarkdownSource {

    public let text: String

    let units: [UniChar]

    /// 每行首字符的 UTF-16 偏移。行号 1-based，即第 n 行的起点是 `lineStarts[n - 1]`。
    public let lineStarts: [Int]

    /// 每行行尾（换行符之前）的 UTF-16 偏移，与 `lineStarts` 一一对应。
    let lineEnds: [Int]

    public var utf16Length: Int { units.count }

    public init(_ text: String) {
        self.text = text
        self.units = Array(text.utf16)
        let table = PPMarkdownSource.makeLineTable(self.units)
        self.lineStarts = table.starts
        self.lineEnds = table.ends
    }

    /// 换行符按 CommonMark 认定为 `\n` / `\r\n` / `\r` 三种，
    /// 但**只是不作为行内容**，字符本身仍留在 `text` 里——本类型从不修改字符串。
    private static func makeLineTable(_ units: [UniChar]) -> (starts: [Int], ends: [Int]) {
        let n = units.count
        var starts = [0]
        var ends = [Int]()
        var i = 0
        while i < n {
            switch units[i] {
            case Self.lf:
                ends.append(i)
                i += 1
                if i < n { starts.append(i) }
            case Self.cr:
                ends.append(i)
                i += (i + 1 < n && units[i + 1] == Self.lf) ? 2 : 1
                if i < n { starts.append(i) }
            default:
                i += 1
            }
        }
        if ends.count < starts.count { ends.append(n) }
        return (starts, ends)
    }

    // MARK: - 读写单元

    @inline(__always) func unit(at i: Int) -> UniChar {
        return units[i]
    }

    @inline(__always) var count: Int { units.count }

    /// 最后一行之后返回 `count`，便于扫描器写 `while i < endOfLine`。
    @inline(__always) func endOfLine(_ line: Int) -> Int {
        return lineEnds[line - 1]
    }

    @inline(__always) func startOfLine(_ line: Int) -> Int {
        return lineStarts[line - 1]
    }

    var lineCount: Int { lineStarts.count }

    /// 第 line 行去掉行尾换行符后的内容区间。
    @inline(__always) func lineRange(_ line: Int) -> NSRange {
        return NSRange(location: lineStarts[line - 1], length: lineEnds[line - 1] - lineStarts[line - 1])
    }

    /// 把 (1-based 行号, 0-based 列号) 折算成绝对 UTF-16 偏移。
    func offset(line: Int, column: Int) -> Int {
        return lineStarts[line - 1] + column
    }

    /// 返回该行内列号的上限，避免越界构造出跨行区间。
    func clampedColumn(_ column: Int, onLine line: Int) -> Int {
        return min(max(column, 0), lineEnds[line - 1] - lineStarts[line - 1])
    }

    func string(in range: NSRange) -> String {
        guard range.location >= 0, range.length >= 0,
              NSMaxRange(range) <= units.count else { return "" }
        return (text as NSString).substring(with: range)
    }

    /// 偏移所属的行号（1-based）。越界时钳到首/末行。
    func line(of utf16Offset: Int) -> Int {
        var lo = 0
        var hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= utf16Offset { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }

    /// 该行剩余的空白数（含 Tab，Tab 按制表位展开到 4 的倍数）。
    /// CommonMark 的块缩进以 4 空格为界，Tab 必须展开而不是按 1 计。
    func indent(ofLine line: Int) -> Int {
        var column = 0
        let end = lineEnds[line - 1]
        var i = lineStarts[line - 1]
        while i < end {
            switch units[i] {
            case Self.space:
                column += 1
            case Self.tab:
                column += 4 - (column % 4)
            default:
                return column
            }
            i += 1
        }
        return column
    }

    /// 行内某个偏移之前有多少个连续空白，用于判断 `#` / `>` / 列表标记是否在行首。
    func isFirstNonWhitespace(at i: Int, inLine line: Int) -> Bool {
        var k = i - 1
        let start = lineStarts[line - 1]
        while k >= start {
            switch units[k] {
            case Self.space, Self.tab:
                k -= 1
            default:
                return false
            }
        }
        return true
    }

    /// 从某偏移开始的第一个非空白字符下标；整行空白返回 `endOfLine`。
    func firstNonWhitespace(from i: Int, to end: Int) -> Int {
        var k = i
        while k < end {
            if units[k] != Self.space && units[k] != Self.tab { return k }
            k += 1
        }
        return end
    }
}

// MARK: - ASCII 常量

/// 扫描器只比较 ASCII 语法字符；中文等 BMP 字符占 1 个 UTF-16 单元、
/// 增补平面字符（emoji）占 2 个代理单元，其值落在 D800–DFFF，
/// 永远不会与下面的 ASCII 常量相等，因此按单元逐个比较是安全的。
extension PPMarkdownSource {
    static let space:  UniChar = 0x20
    static let tab:    UniChar = 0x09
    static let lf:     UniChar = 0x0A
    static let cr:     UniChar = 0x0D
    static let hash:   UniChar = 0x23   // #
    static let star:   UniChar = 0x2A   // *
    static let under:  UniChar = 0x5F   // _
    static let grave:  UniChar = 0x60   // `
    static let tilde:  UniChar = 0x7E   // ~
    static let gt:     UniChar = 0x3E   // >
    static let lt:     UniChar = 0x3C   // <
    static let slash:  UniChar = 0x2F   // /
    static let bang:   UniChar = 0x21   // !
    static let lparen: UniChar = 0x28   // (
    static let rparen: UniChar = 0x29   // )
    static let lbracket:  UniChar = 0x5B // [
    static let rbracket:  UniChar = 0x5D // ]
    static let lbrace:   UniChar = 0x7B  // {
    static let rbrace:   UniChar = 0x7D  // }
    static let colon:    UniChar = 0x3A  // :
    static let equal:    UniChar = 0x3D  // =
    static let dash:     UniChar = 0x2D  // -
    static let plus:     UniChar = 0x2B  // +
    static let dot:      UniChar = 0x2E  // .
    static let questionMark: UniChar = 0x3F // ?
    static let backslash: UniChar = 0x5C // \
    static let quote:    UniChar = 0x22  // "
    static let apost:    UniChar = 0x27  // '
    static let at:       UniChar = 0x40  // @
    static let xChar:    UniChar = 0x78  // x
    static let XChar:    UniChar = 0x58  // X

    static func isASCIIDigit(_ u: UniChar) -> Bool { u >= 0x30 && u <= 0x39 }
    static func isASCIILetter(_ u: UniChar) -> Bool {
        return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A)
    }
    static func isWhitespace(_ u: UniChar) -> Bool {
        return u == space || u == tab || u == lf || u == cr
    }
}

// MARK: - 标题文本

extension String {

    /// 去掉 ATX 标题两端的 `#` 标记，返回标题正文。
    ///
    /// 判定与 `PPMarkdownBlockScanner.scanATXHeading` 保持一致：行首 1~6 个 `#` 之后
    /// 必须紧跟空白才算标题，所以 `#tag`、`C#` 不会被误伤；行尾的 `#` 关闭序列只剥
    /// 哈希段本身，它前面的空白属于正文，由调用方按需 trim。
    func removingMarkdownHeadingMarkers() -> String {
        let ns = self as NSString
        let end = ns.length
        let isBlank: (UniChar) -> Bool = { $0 == PPMarkdownSource.space || $0 == PPMarkdownSource.tab }
        var i = 0
        while i < end, ns.character(at: i) == PPMarkdownSource.hash { i += 1 }

        var start = 0
        var isATXHeading = false
        if i > 0, i <= 6 {
            if i == end {
                return ""                       // 整行都是 `#`
            }
            if isBlank(ns.character(at: i)) {
                isATXHeading = true
                start = i
                while start < end, isBlank(ns.character(at: start)) { start += 1 }
            }
        }
        guard isATXHeading else { return self }

        var stop = end
        var k = end
        while k > start, isBlank(ns.character(at: k - 1)) { k -= 1 }
        let closingEnd = k
        while k > start, ns.character(at: k - 1) == PPMarkdownSource.hash { k -= 1 }
        if k < closingEnd, k > start, isBlank(ns.character(at: k - 1)) { stop = k }
        return ns.substring(with: NSRange(location: start, length: max(stop - start, 0)))
    }
}
