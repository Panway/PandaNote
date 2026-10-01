import XCTest
@testable import PandaNote

final class InlineScannerTests: XCTestCase {

    private let scanner = PPMarkdownInlineScanner()

    /// 直接扫一段文字（当作一个段落内容）。
    private func spans(_ line: String) -> [PPMarkdownInlineSpan] {
        let src = PPMarkdownSource(line)
        return scanner.scan(src, in: NSRange(location: 0, length: (line as NSString).length))
    }

    private func describe(_ spans: [PPMarkdownInlineSpan], in text: String) -> [String] {
        let ns = text as NSString
        return spans.map { "\(stringify($0.kind)):\(ns.substring(with: $0.range))" }
    }

    private func stringify(_ kind: PPMarkdownInlineKind) -> String {
        switch kind {
        case .codeSpan: return "code"
        case .emphasis: return "em"
        case .strong: return "strong"
        case .strikethrough: return "del"
        case .link: return "link"
        case .image: return "image"
        case .autolink: return "auto"
        case .htmlInline: return "html"
        case .taskBox(let checked): return checked ? "box[x]" : "box[ ]"
        }
    }

    // MARK: - 基本形状

    func testCodeSpan() {
        let text = "用 `code` 包住"
        let found = spans(text)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].kind, .codeSpan)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: found[0].range), "`code`")
        XCTAssertEqual(ns.substring(with: found[0].contentRange), "code")
        XCTAssertEqual(found[0].markerRanges.map { ns.substring(with: $0) }, ["`", "`"])
    }

    func testCodeSpanWithDoubleBackticks() {
        let text = "``a ` b``"
        let found = spans(text)
        XCTAssertEqual(found.count, 1)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: found[0].contentRange), "a ` b")
    }

    func testUnclosedBacktickIsPlainText() {
        XCTAssertEqual(spans("只有 ` 一个反引号").count, 0)
    }

    func testEmphasisAndStrong() {
        let text = "**粗** 和 *斜* 和 __粗2__ 和 _斜2_"
        XCTAssertEqual(describe(spans(text), in: text),
                       ["strong:**粗**", "em:*斜*", "strong:__粗2__", "em:_斜2_"])
    }

    func testSnakeCaseIsNotEmphasis() {
        XCTAssertTrue(spans("snake_case_word 里不成立").isEmpty)
        XCTAssertTrue(spans("a_b 紧邻字母也不成立").isEmpty)
    }

    func testEmphasisRequiresNonSpaceAfterOpening() {
        XCTAssertTrue(spans("* 星号开头是列表或文字 *").isEmpty)
    }

    func testStrikethrough() {
        XCTAssertEqual(describe(spans("~~删掉~~"), in: "~~删掉~~"), ["del:~~删掉~~"])
    }

    // MARK: - 链接与图片

    func testLink() {
        let text = "看 [站点](https://a.b/c) 这里"
        let found = spans(text)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].kind, .link)
        XCTAssertEqual(found[0].urlString, "https://a.b/c")
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: found[0].contentRange), "站点")
    }

    func testImageKeepsSourceRange() {
        let text = "![示例图片](sample.png)"
        let found = spans(text)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].kind, .image)
        XCTAssertEqual(found[0].urlString, "sample.png")
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: found[0].range), "![示例图片](sample.png)")
        XCTAssertEqual(ns.substring(with: found[0].contentRange), "示例图片")
    }

    func testLinkWithAngleURLAndTitle() {
        let found = spans("[站点](<a b.md> \"标题\")")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].urlString, "a b.md")
    }

    func testParenInsideURL() {
        let text = "[维基](https://zh.wikipedia.org/wiki/A_(b))"
        let found = spans(text)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].urlString, "https://zh.wikipedia.org/wiki/A_(b)")
    }

    func testReferenceStyleLinkIsPlainText() {
        XCTAssertTrue(spans("只有 [文本] 没有圆括号").isEmpty)
    }

    func testAutolink() {
        let found = spans("<https://autolink.me>")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].kind, .autolink)
        XCTAssertEqual(found[0].urlString, "https://autolink.me")
    }

    func testHtmlTagIsNotAutolink() {
        let found = spans("<b>粗</b>")
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found[0].kind, .htmlInline)
    }

    func testTaskBox() {
        let text = "[ ] 待办 [x] 已完成 [X] 大写"
        let found = spans(text)
        XCTAssertEqual(found.map { stringify($0.kind) }, ["box[ ]", "box[x]", "box[x]"])
        XCTAssertTrue(found.allSatisfy { $0.markerRanges.isEmpty })
    }

    func testBracketFollowedByTextIsNotTaskBox() {
        XCTAssertTrue(spans("[x][ref] 引用式写法").filter { if case .taskBox = $0.kind { return true }; return false }.isEmpty)
    }

    // MARK: - 不变量

    /// 行内结构只能落在被扫描区间之内——越过块边界就会把装饰画到别的块上。
    func testSpansStayInsideScannedRange() {
        for text in ["**粗** 和 `code` 与 [链接](x) ![图](y.png) <https://z> ~~s~~",
                     "中文 **加粗** emoji 🐼 `代码`",
                     "`未闭合", "**未闭合", "[未闭合](x", "![未闭合](y"] {
            let src = PPMarkdownSource(text)
            let range = NSRange(location: 0, length: src.utf16Length)
            for span in scanner.scan(src, in: range) {
                XCTAssertGreaterThanOrEqual(span.range.location, range.location)
                XCTAssertLessThanOrEqual(NSMaxRange(span.range), NSMaxRange(range), text)
                XCTAssertLessThanOrEqual(NSMaxRange(span.contentRange), NSMaxRange(span.range), text)
                for marker in span.markerRanges {
                    XCTAssertLessThanOrEqual(NSMaxRange(marker), NSMaxRange(span.range), text)
                    XCTAssertFalse(src.string(in: marker).isEmpty, "标记不该为空: \(text)")
                }
            }
        }
    }

    /// 行内区间彼此不重叠，保证着色层按序应用属性时是确定的。
    func testSpansDoNotOverlap() {
        let text = "a **b `c` d** e [x](y) ![z](w.png) <https://q> ~~r~~ <b> s"
        let src = PPMarkdownSource(text)
        let found = scanner.scan(src, in: NSRange(location: 0, length: src.utf16Length))
        var previousEnd = 0
        for span in found {
            XCTAssertGreaterThanOrEqual(span.range.location, previousEnd,
                                        "区间重叠: \(describe(found, in: text))")
            previousEnd = NSMaxRange(span.range)
        }
    }

    /// 扫描器绝不产生字符：把每个 span 的源码原样取回，必须能在原文里定位到。
    func testSpanTextExistsVerbatimInSource() {
        let text = "# 标题 **粗** `code` [链接](a.md) ![图](b.png)\n正文 *斜* ~~删~~ <https://x>\n"
        let src = PPMarkdownSource(text)
        let blocks = PPMarkdownBlockScanner().scan(src)
        let found = scanner.scan(src, blocks: blocks)
        XCTAssertFalse(found.isEmpty)
        for span in found {
            let slice = src.string(in: span.range)
            XCTAssertTrue(text.contains(slice), "取出了不存在于源码的片段: \(slice)")
        }
    }

    /// 代码块内部不做行内解析，否则 `**` 会被误判成加粗。
    func testCodeBlocksAreSkipped() {
        let doc = "```\n**不是加粗** `也不是代码`\n```\n"
        let src = PPMarkdownSource(doc)
        XCTAssertTrue(scanner.scan(src, blocks: PPMarkdownBlockScanner().scan(src)).isEmpty)

        let indented = "    **不是加粗**\n"
        let isrc = PPMarkdownSource(indented)
        XCTAssertTrue(scanner.scan(isrc, blocks: PPMarkdownBlockScanner().scan(isrc)).isEmpty)
    }

    /// 同一份源码扫两次结果一致。
    func testScanIsDeterministic() {
        let doc = "# 标题 **粗** *斜* `c` [l](u) ![i](u2) <https://a> ~~d~~\n\n- [x] 项\n"
        let src = PPMarkdownSource(doc)
        let blocks = PPMarkdownBlockScanner().scan(src)
        let a = scanner.scan(src, blocks: blocks)
        let b = scanner.scan(src, blocks: blocks)
        XCTAssertEqual(a.map { [$0.range.location, $0.range.length] },
                       b.map { [$0.range.location, $0.range.length] })
    }
}
