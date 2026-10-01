//
//  PPMarkdownBlock.swift
//  PandaNote
//

import Foundation

/// 顶层块的语法类别。
///
/// 注意：这里只描述「上色和画装饰需要知道的形状」，不是 CommonMark 规范的完整 AST。
/// 判定偏保守，边角情况判错只会导致某个标记少上一层灰色，**永远不会改动字符**。
public enum PPMarkdownBlockKind: Equatable {
    case blank
    case heading(level: Int)
    case thematicBreak
    case blockQuote(depth: Int)
    case listItem(depth: Int, ordered: Bool)
    case paragraph
    case fencedCode(infoStringRange: NSRange?)
    case indentedCode
    case html
}

public struct PPMarkdownBlock {

    public let kind: PPMarkdownBlockKind

    /// **平铺区间**：从本块首字符一直到下一块首字符之前，因此全体 block 的 range
    /// 无重叠、无缝隙地覆盖整个文档（含各自行尾的换行符）。
    /// 这条不变量由 `PPMarkdownBlockScanner` 构造保证，并有单测把守。
    public let range: NSRange

    /// 块内容的实际结束位置（不含尾随空行与行尾换行）。绘制代码块背景、
    /// 引用竖条时用这个，否则背景会多刷一整行。
    public let contentRange: NSRange

    /// 语法标记自身的区间，用于弱化显示：`## ` / `> ` / `- ` / ```` ``` ```` 围栏行。
    /// 一个块可能有多处标记（引用与列表逐行各一个）。
    public let markerRanges: [NSRange]

    /// 列表项内容起始列，用于给续行和子项算 `headIndent`。非列表项为 0。
    public let listContentColumn: Int

    /// 供后续增量渲染做脏判定：同一 kind + 同一段源码文本的指纹一致即可跳过重扫。
    public let fingerprint: Int

    init(kind: PPMarkdownBlockKind,
         range: NSRange,
         contentRange: NSRange,
         markerRanges: [NSRange],
         listContentColumn: Int = 0,
         fingerprint: Int) {
        self.kind = kind
        self.range = range
        self.contentRange = contentRange
        self.markerRanges = markerRanges
        self.listContentColumn = listContentColumn
        self.fingerprint = fingerprint
    }
}
