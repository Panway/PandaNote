import XCTest
@testable import PandaNote

final class BlockScannerTests: XCTestCase {

    // MARK: - 不变量：平铺必须严丝合缝覆盖全文

    private let corpus: [String] = [
        "",
        "\n",
        "正文",
        "# 标题\n\n正文段落\n",
        "- 项目一\n- 项目二\n  - 嵌套\n    - 更深\n",
        "* item\n* item2\n",
        "1. 第一\n2. 第二\n",
        "> 引用第一行\n> 引用第二行\n惰性续行\n>  again\n",
        ">> 嵌套引用\n\n文字\n",
        "```swift\nlet x = 1\n```\n后面\n",
        "~~~\ncode\n~~~~~\n",
        "```python\n未闭合的围栏\n",
        "    缩进代码\n    第二行\n文字\n",
        "---\n\n***\n\n___\n\n- - -\n",
        "Setext 一级\n=========\n\nSetext 二级\n---------\n",
        "<div class=\"x\">\n  <p>hi</p>\n</div>\n\n段落\n",
        "文本里的 `code` 和 **bold** 与 *ital* 及 ~~s~~。\n",
        "![示例图片](sample.png)\n",
        "[链接](https://a.b/c)\n\n<https://autolink.me>\n",
        "- [ ] 待办\n- [x] 已完成\n",
        "emoji 🐼 增补平面 **加粗**\n\n中文下划线 snake_case_word 测试\n",
        "行尾空格  \n第二行\n",
        "\r\nCRLF 文档\r\n第二行\r\n",
        "Tab\t缩进\t列\t对齐\n\t制表符开头\n",
        "混合：\n\n# H1\n- a\n- b\n\n> q\n\n```\nc\n```\n\n    i\n\n最后\n",
        "#\n##\n####### 七个井号不是标题\n#无空格不是标题\n",
        "段落\n- 列表打断段落\n段落2\n3. 有序不打断\n段落3\n",
        "\n\n\n多个空行\n\n\n",
        "最后一行没有换行符",
        "![图](a.png) 与 [链接](b.md) 同行\n",
        "转义 \\* 不是强调 \\_ 不是下划线\n",
        "a_b_c 单词内下划线\n"
    ]

    func testBlocksTileTheWholeDocumentWithoutGaps() {
        for doc in corpus {
            let src = PPMarkdownSource(doc)
            let blocks = PPMarkdownBlockScanner().scan(src)
            let ns = doc as NSString

            if doc.isEmpty {
                XCTAssertEqual(blocks.count, 1, "空文档也要有一块，否则增量层无起点: \(doc)")
                XCTAssertEqual(blocks[0].range, NSRange(location: 0, length: 0))
                continue
            }
            XCTAssertFalse(blocks.isEmpty, "非空文档不该扫出 0 块: \(doc)")

            var cursor = 0
            for (idx, block) in blocks.enumerated() {
                XCTAssertEqual(block.range.location, cursor,
                               "第 \(idx) 块起点接不上: \(debugDoc(doc))")
                XCTAssertGreaterThanOrEqual(block.range.length, 0, "长度不能为负")
                XCTAssertLessThanOrEqual(NSMaxRange(block.range), ns.length, "越界: \(debugDoc(doc))")
                cursor = NSMaxRange(block.range)
            }
            XCTAssertEqual(cursor, ns.length, "末块没覆盖到文档末尾: \(debugDoc(doc))")
        }
    }

    func testContentRangesStayInsideTheirBlockAndEndBeforeNewline() {
        for doc in corpus {
            let src = PPMarkdownSource(doc)
            let ns = doc as NSString
            for block in PPMarkdownBlockScanner().scan(src) {
                XCTAssertGreaterThanOrEqual(block.contentRange.location, block.range.location)
                XCTAssertGreaterThanOrEqual(NSMaxRange(block.contentRange), block.contentRange.location)
                XCTAssertLessThanOrEqual(NSMaxRange(block.contentRange), NSMaxRange(block.range),
                                         "contentRange 越出本块: \(debugDoc(doc))")
                let tail = block.contentRange.length
                if tail > 0 {
                    let lastUnit = Array(ns.substring(with: block.contentRange).utf16).last!
                    XCTAssertNotEqual(lastUnit, 0x0A, "contentRange 不该含换行: \(debugDoc(doc))")
                    XCTAssertNotEqual(lastUnit, 0x0D, "contentRange 不该含回车: \(debugDoc(doc))")
                }
            }
        }
    }

    func testMarkerRangesLandInsideBlock() {
        for doc in corpus {
            let src = PPMarkdownSource(doc)
            let ns = doc as NSString
            for block in PPMarkdownBlockScanner().scan(src) {
                for marker in block.markerRanges {
                    XCTAssertGreaterThanOrEqual(marker.location, block.range.location)
                    XCTAssertLessThanOrEqual(NSMaxRange(marker), NSMaxRange(block.range),
                                             "标记越界: \(debugDoc(doc))")
                    XCTAssertGreaterThan(marker.length, 0, "不该产出零长标记: \(debugDoc(doc))")
                    _ = ns.substring(with: marker)
                }
            }
        }
    }

    func testFingerprintIsStableAndDistinguishesKind() {
        let src = PPMarkdownSource("段落\n")
        let blocks = PPMarkdownBlockScanner().scan(src)
        let other = PPMarkdownBlockScanner().scan(src)
        XCTAssertEqual(blocks[0].fingerprint, other[0].fingerprint)

        let same = PPMarkdownSource("段落\n")
        let asHeading = PPMarkdownBlock(
            kind: .heading(level: 1),
            range: blocks[0].range,
            contentRange: blocks[0].contentRange,
            markerRanges: [],
            fingerprint: PPMarkdownBlockScanner.fingerprint(of: .heading(level: 1),
                                                            src: same,
                                                            range: blocks[0].range))
        XCTAssertNotEqual(asHeading.fingerprint, blocks[0].fingerprint,
                          "同文本不同形状必须判为脏")
        _ = src
    }

    // MARK: - 形状判定

    func testHeadingDetection() {
        XCTAssertEqual(kinds(of: "# 一\n## 二\n###### 六\n"),
                       [.heading(level: 1), .heading(level: 2), .heading(level: 6)])
        // 7 个井号、井号后无空格，都只是段落
        XCTAssertEqual(kinds(of: "####### 七\n#无空格\n"), [.paragraph])
    }

    func testHeadingMarkerCoversHashesAndFollowingSpace() {
        let src = PPMarkdownSource("## 标题文字\n")
        let block = PPMarkdownBlockScanner().scan(src)[0]
        XCTAssertEqual(block.markerRanges.count, 1)
        XCTAssertEqual(src.string(in: block.markerRanges[0]), "## ")

        let closing = PPMarkdownSource("## 标题 ##\n")
        let b = PPMarkdownBlockScanner().scan(closing)[0]
        XCTAssertEqual(b.markerRanges.map { closing.string(in: $0) }, ["## ", "##"])
    }

    func testSetextHeadingWinsOverThematicBreak() {
        let blocks = PPMarkdownBlockScanner().scan(PPMarkdownSource("标题\n---\n\n---\n"))
        XCTAssertEqual(blocks.map { $0.kind }, [.heading(level: 2), .blank, .thematicBreak])
    }

    func testThematicBreakVersusListItem() {
        XCTAssertEqual(kinds(of: "- - -\n"), [.thematicBreak])
        XCTAssertEqual(kinds(of: "---\n"), [.thematicBreak])
        XCTAssertEqual(kinds(of: "- 事项\n"), [.listItem(depth: 0, ordered: false)])
    }

    func testFencedCodeMarkersAndInfoString() {
        let src = PPMarkdownSource("```swift\nlet x = 1\n```\n")
        let block = PPMarkdownBlockScanner().scan(src)[0]
        guard case .fencedCode(let info) = block.kind else {
            return XCTFail("应为围栏代码块，实际 \(block.kind)")
        }
        XCTAssertEqual(src.string(in: block.markerRanges[0]), "```swift")
        XCTAssertEqual(src.string(in: block.markerRanges[1]), "```")
        XCTAssertEqual(info.map { src.string(in: $0) }, "swift")
        // 背景不该刷到闭合围栏之后的那一行
        XCTAssertEqual(block.contentRange.length, ("```swift\nlet x = 1\n```" as NSString).length)
    }

    func testUnclosedFenceRunsToEndOfDocument() {
        let src = PPMarkdownSource("前\n```\nc\n继续\n")
        let blocks = PPMarkdownBlockScanner().scan(src)
        XCTAssertEqual(blocks.map { $0.kind }, [.paragraph, .fencedCode(infoStringRange: nil)])
        let fence = blocks[1]
        XCTAssertFalse(src.string(in: fence.range).contains("前"))
        XCTAssertTrue(src.string(in: fence.range).hasSuffix("继续\n"))
        // 未闭合时块尾就是文档尾，但背景只刷到最后一行非空内容
        XCTAssertEqual(src.string(in: fence.contentRange), "```\nc\n继续")
    }

    func testBlockQuoteMarkersPerLineAndLazyContinuation() {
        let src = PPMarkdownSource("> 一\n> 二\n惰性\n\n新段\n")
        let blocks = PPMarkdownBlockScanner().scan(src)
        XCTAssertEqual(blocks.map { $0.kind }, [.blockQuote(depth: 1), .blank, .paragraph])
        // 只有真正写了 `>` 的行才有标记；惰性续行的首字符绝不能被标成 `>`。
        XCTAssertEqual(blocks[0].markerRanges.map { src.string(in: $0) }, ["> ", "> "])
    }

    func testNestedQuoteDepth() {
        let blocks = PPMarkdownBlockScanner().scan(PPMarkdownSource(">>> 深\n"))
        XCTAssertEqual(blocks.map { $0.kind }, [.blockQuote(depth: 3)])
    }

    func testListDepthsAndColumns() {
        let src = PPMarkdownSource("- a\n  - b\n    - c\n- d\n")
        let blocks = PPMarkdownBlockScanner().scan(src)
        XCTAssertEqual(blocks.map { $0.kind }, [
            .listItem(depth: 0, ordered: false),
            .listItem(depth: 1, ordered: false),
            .listItem(depth: 2, ordered: false),
            .listItem(depth: 0, ordered: false)
        ])
        XCTAssertEqual(blocks.map { $0.markerRanges.first.map { src.string(in: $0) } },
                       ["- ", "- ", "- ", "- "])
        XCTAssertEqual(blocks[0].listContentColumn, 2)
        XCTAssertEqual(blocks[1].listContentColumn, 4)
    }

    func testOrderedListMarkerIncludesDotAndSpace() {
        let src = PPMarkdownSource("10. 十\n")
        let block = PPMarkdownBlockScanner().scan(src)[0]
        XCTAssertEqual(block.kind, .listItem(depth: 0, ordered: true))
        XCTAssertEqual(src.string(in: block.markerRanges[0]), "10. ")
    }

    func testIndentedCodeNeedsFourColumns() {
        XCTAssertEqual(kinds(of: "   三格不是代码\n"), [.paragraph])
        XCTAssertEqual(kinds(of: "    四格是代码\n"), [.indentedCode])
    }

    func testHTMLBlockRunsUntilBlankLine() {
        let blocks = PPMarkdownBlockScanner().scan(PPMarkdownSource("<div>\n<p>x</p>\n</div>\n\n段\n"))
        XCTAssertEqual(blocks.map { $0.kind }, [.html, .blank, .paragraph])
    }

    // MARK: - 硬性需求：源码保真

    /// 把每个块的源码原样拼回去，必须和输入逐字符相等。
    /// 这一条是「显示文本 ≠ 数据源」这类根因缺陷的守门测试——扫描器永远不许改写文本。
    func testReassemblyIsCharacterIdentical() {
        for doc in corpus {
            let src = PPMarkdownSource(doc)
            let blocks = PPMarkdownBlockScanner().scan(src)
            let rebuilt = blocks.map { src.string(in: $0.range) }.joined()
            XCTAssertEqual(rebuilt, doc, "块拼接不等于原文: \(debugDoc(doc))")
        }
    }

    /// 同一份源码扫描两次必须完全一致（无隐藏状态、无随机性）。
    func testScanIsDeterministic() {
        for doc in corpus {
            let src = PPMarkdownSource(doc)
            let a = PPMarkdownBlockScanner().scan(src)
            let b = PPMarkdownBlockScanner().scan(src)
            XCTAssertEqual(a.map { $0.kind }, b.map { $0.kind })
            XCTAssertEqual(a.map { $0.range }, b.map { $0.range })
            XCTAssertEqual(a.map { $0.fingerprint }, b.map { $0.fingerprint })
        }
    }

    /// 真实笔记文件：能读进来就必须能原样拼回去。
    /// 仓库根目录从测试文件位置向上找，找不到（例如在临时包子里跑）就跳过。
    func testRealNoteFilesRoundTrip() throws {
        var root: URL? = ProcessInfo.processInfo.environment["PANDA_REPO_ROOT"]
            .map { URL(fileURLWithPath: $0) }
        if root == nil {
            var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            for _ in 0..<8 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("PandaNote.xcodeproj").path) {
                    root = dir
                    break
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        guard let repo = root else { throw XCTSkip("未找到仓库根目录，跳过真实文件校验") }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: repo, includingPropertiesForKeys: nil) else {
            throw XCTSkip("无法枚举仓库目录")
        }
        var checked = 0
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md" else { continue }
            guard !url.path.contains("/Pods/") else { continue }
            guard let data = try? Data(contentsOf: url),
                  var text = String(data: data, encoding: .utf8) else { continue }
            text = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            let src = PPMarkdownSource(text)
            let blocks = PPMarkdownBlockScanner().scan(src)
            XCTAssertEqual(blocks.map { src.string(in: $0.range) }.joined(), text, url.path)
            checked += 1
            if checked >= 200 { break }
        }
        XCTAssertGreaterThan(checked, 0, "一个真实文件都没校验到，说明目录定位有问题")
        print("真实文件校验数：\(checked)")
    }

    /// 平铺不变量是整个改造的地基，手工语料覆盖不够，这里做确定性模糊。
    /// 固定种子保证失败可复现。
    func testFuzzKeepsTilingAndCharacterIdentity() {
        let fragments = [
            "", " ", "\t", "#", "## 标题", "###", "#### 四级 ####", "正文段落文字",
            "-", "- 项目", "  - 嵌套项", "    - 更深", "*", "+ ", "1. 有序", "10) 括号",
            ">", "> 引用", ">> 双层", ">>> 三层", "惰性续行文字",
            "```", "```swift", "~~~", "    缩进代码", "\t制表符代码",
            "---", "***", "___", "- - -", "=", "====", "=========",
            "<div>", "</div>", "<!-- 注释 -->", "<p>html 段落</p>",
            "`行内代码`", "``带 ` 反引号``", "**粗**", "*斜*", "__粗__", "_斜_",
            "~~删~~", "[链接](a.md)", "![图](b.png)", "<https://x.y>", "- [ ] 待办",
            "snake_case_word", "中文，标点。！？「」", "emoji 🐼👍 增补平面",
            "尾随空格  ", "a\\*b", "\\# 转义井号", "  前导空格行",
            "![图](带 空格.png)", "[x](<a b> \"题\")", "```未闭合"
        ]
        let newlineStyles = ["\n", "\r\n", "\r"]

        var generator = DeterministicGenerator(seed: 0x5EED_1234)
        for iteration in 0..<2000 {
            let lineBreak = newlineStyles[generator.next() % newlineStyles.count]
            let lineCount = 1 + generator.next() % 12
            var pieces = [String]()
            for _ in 0..<lineCount {
                pieces.append(fragments[generator.next() % fragments.count])
            }
            let doc = pieces.joined(separator: lineBreak)

            let src = PPMarkdownSource(doc)
            let ns = doc as NSString
            let blocks = PPMarkdownBlockScanner().scan(src)

            var cursor = 0
            for block in blocks {
                XCTAssertEqual(block.range.location, cursor, "空隙或重叠 @\(iteration) \(doc.debugDescription)")
                XCTAssertLessThanOrEqual(NSMaxRange(block.range), ns.length, "越界 @\(iteration) \(doc.debugDescription)")
                XCTAssertLessThanOrEqual(NSMaxRange(block.contentRange), NSMaxRange(block.range),
                                         "contentRange 越界 @\(iteration) \(doc.debugDescription)")
                for marker in block.markerRanges {
                    XCTAssertGreaterThanOrEqual(marker.location, block.range.location)
                    XCTAssertLessThanOrEqual(NSMaxRange(marker), NSMaxRange(block.range),
                                             "标记越界 @\(iteration) \(doc.debugDescription)")
                }
                cursor = NSMaxRange(block.range)
            }
            XCTAssertEqual(cursor, ns.length, "未覆盖到文末 @\(iteration) \(doc.debugDescription)")
            XCTAssertEqual(blocks.map { src.string(in: $0.range) }.joined(), doc,
                           "回拼不等 @\(iteration) \(doc.debugDescription)")

            let spans = PPMarkdownInlineScanner().scan(src, blocks: blocks)
            for span in spans {
                XCTAssertGreaterThanOrEqual(span.range.location, 0, "@\(iteration) \(doc.debugDescription)")
                XCTAssertLessThanOrEqual(NSMaxRange(span.range), ns.length,
                                         "行内区间越界 @\(iteration) \(doc.debugDescription)")
                XCTAssertLessThanOrEqual(NSMaxRange(span.contentRange), NSMaxRange(span.range))
            }
        }
    }

    /// 不用系统随机数：自己写一个可复现的线性同余发生器。
    private struct DeterministicGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) & 0x7FFF_FFFF)
        }
    }

    // MARK: - helper

    private func kinds(of doc: String) -> [PPMarkdownBlockKind] {
        return PPMarkdownBlockScanner().scan(PPMarkdownSource(doc)).map { $0.kind }
    }

    private func debugDoc(_ doc: String) -> String {
        return doc.debuggingDescription
    }
}

extension String {
    var debuggingDescription: String {
        return self.debugDescription.replacingOccurrences(of: "\n", with: "\\n")
    }
}
