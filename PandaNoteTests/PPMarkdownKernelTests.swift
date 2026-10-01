//
//  PPMarkdownKernelTests.swift
//  PandaNoteTests
//
//  在真实运行时（Mac Catalyst）里验证内核的两条命根子：
//  1. 显示文本恒等于源码——着色只贴属性，一个字符都不产生；
//  2. 图片预览让出来的那段空白确实存在，既没被挤出可视区，也没压到文字上。
//

import XCTest
import UIKit
@testable import PandaNote

final class PPMarkdownKernelTests: XCTestCase {

    private func makeView(_ source: String, cacheDir: String = "") -> PPMDTextView {
        let view = PPMDTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        view.cacheDir = cacheDir
        view.sourceText = source
        view.layoutManager.ensureLayout(for: view.textContainer)
        return view
    }

    // MARK: - 源码恒等

    func testRenderingNeverChangesCharacters() {
        let doc = "# 标题\n\n- 项目 **粗** 与 `码`\n  - 嵌套\n\n> 引用\n> 第二行\n\n"
            + "```swift\nlet x = 1\n```\n\n![图](missing.png)\n\n---\n\n[链接](https://a.b/c) 结束\n"
        let view = makeView(doc)
        XCTAssertEqual(view.sourceText, doc)
        XCTAssertEqual(view.text, doc)
        XCTAssertEqual(view.attributedText.string, doc)
        XCTAssertFalse(view.text.contains("\u{FFFC}"),
                       "文本里出现附件占位符，说明有装饰被插进了文本流")
    }

    func testTypingAttributesMatchBodyStyle() {
        let view = makeView("# 标题\n")
        let font = view.typingAttributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, PPMarkdownStyle.current.fonts.body.pointSize)
    }

    /// 赋值即着色，不需要谁再显式调一次 render。
    func testProgrammaticAssignmentRestyles() {
        let view = makeView("# 标题\n")
        let font = view.attributedText.attribute(.font, at: 2, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, PPMarkdownStyle.current.fonts.heading1.pointSize)
    }

    /// 真实打字通道也要自动着色。这条守的是「钩子写错就静默失效」那次事故：
    /// 曾经把回调写成 `textStorageDidProcessEditing(_:)`，selector 不匹配协议，
    /// 编译通过但永远不回调，只有显式 render 的地方看起来正常。
    func testTypingRestylesWithoutExplicitRender() {
        let view = PPMDTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        view.insertText("# 标题\n")
        XCTAssertEqual(view.sourceText, "# 标题\n")
        let font = view.attributedText.attribute(.font, at: 2, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, PPMarkdownStyle.current.fonts.heading1.pointSize)
    }

    /// 大纲标题去掉 `#` 后必须仍是源码里的原文子串，否则点击目录无法滚动定位。
    func testHeadingsAreSourceSubstrings() {
        let doc = "# 一级 ##\n\n正文\n\n二级\n====\n"
        let view = makeView(doc)
        let titles = view.headings
        XCTAssertEqual(titles, ["一级", "二级"])
        for title in titles {
            XCTAssertTrue(doc.contains(title), title)
        }
    }

    // MARK: - 编辑动作只动源码字符

    func testInsertRichTextKeepsSourceIdentical() {
        let view = makeView("前\n")
        view.selectedRange = NSRange(location: 1, length: 0)
        view.insertAttributedString(NSAttributedString(
            string: "后**粗**",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 30), .backgroundColor: UIColor.red]))
        XCTAssertEqual(view.sourceText, "前后**粗**\n")
    }

    /// 加粗两次必须原样回到未加粗的文本——编辑动作可逆，且不吞字符。
    func testSetBoldRoundTrips() {
        let view = makeView("重点\n")
        view.selectedRange = NSRange(location: 2, length: 0)
        view.setBold()
        XCTAssertEqual(view.sourceText, "**重点**\n")
        view.setBold()
        XCTAssertEqual(view.sourceText, "重点\n")
        XCTAssertEqual(view.selectedRange.length, 2)
    }

    func testUpdateHeadingLevelRebuildsLine() {
        let view = makeView("## 旧标题 ##\n")
        view.selectedRange = NSRange(location: 5, length: 0)
        view.updateCurrentLineWithHeadingLevel(1)
        XCTAssertTrue(view.sourceText.hasPrefix("# 旧标题"), view.sourceText)
        XCTAssertTrue(view.sourceText.hasSuffix("\n"), view.sourceText)
    }

    // MARK: - 图片预览的几何

    /// 图片在正文中间：空白由 `paragraphSpacingBefore` 让出来，预览画在源码行正上方。
    func testImagePreviewReservesSpaceAboveItsLine() throws {
        let size = CGSize(width: 40, height: 20)
        let dir = try makeImageDir(size: size)
        defer { try? FileManager.default.removeItem(at: dir) }
        let style = PPMarkdownStyle.current

        let doc = "前言\n\n![示例图片](sample.png)\n\n正文\n"
        let view = makeView(doc, cacheDir: dir.path)
        let manager = try XCTUnwrap(view.layoutManager as? PPMarkdownLayoutManager)
        let range = (doc as NSString).range(of: "![示例图片](sample.png)")
        let glyph = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil).location
        let rect = try XCTUnwrap(manager.rects(for: range).first { $0.syntax.role.isImagePreview },
                                 "图片没登记预览装饰").rect
        let fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let used = manager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        let band = size.height + style.imagePreviewGap

        XCTAssertEqual(rect.width, size.width, accuracy: 0.5)
        XCTAssertEqual(rect.height, size.height, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(rect.minY, 0, "预览图被裁到了可视区外")
        XCTAssertLessThanOrEqual(rect.maxY, used.minY + 0.5, "图片压到了源码行上")
        XCTAssertLessThanOrEqual(used.minY - rect.maxY, style.imagePreviewGap + 0.5, "图片和源码行之间空得过远")
        // 空白确实是布局让出来的：片段顶到墨迹顶之间有整整一个图位。
        XCTAssertGreaterThanOrEqual(used.minY - fragment.minY, band - 0.5,
                                   "paragraphSpacingBefore 没生效")
        // 让出来的那段带子里不能压着上一行的字。
        let prevUsed = manager.lineFragmentUsedRect(forGlyphAt: 0, effectiveRange: nil)
        XCTAssertLessThanOrEqual(prevUsed.maxY, rect.minY + 0.5, "预留带被上一行的文字占了")
    }

    /// 图片就是文档第一行时，TextKit 1 会吞掉首段的 `paragraphSpacingBefore`，
    /// 预留只能落在顶内边距上。删掉图片后必须回落，否则首行永远被白推下去一截。
    func testLeadingImagePreviewReservesSpaceViaInset() throws {
        let size = CGSize(width: 40, height: 20)
        let dir = try makeImageDir(size: size)
        defer { try? FileManager.default.removeItem(at: dir) }
        let style = PPMarkdownStyle.current

        let doc = "![示例图片](sample.png)\n\n正文\n"
        let view = makeView(doc, cacheDir: dir.path)
        let manager = try XCTUnwrap(view.layoutManager as? PPMarkdownLayoutManager)
        let range = (doc as NSString).range(of: "![示例图片](sample.png)")
        let rect = try XCTUnwrap(manager.rects(for: range).first { $0.syntax.role.isImagePreview },
                                 "图片没登记预览装饰").rect

        let band = size.height + style.imagePreviewGap
        XCTAssertGreaterThanOrEqual(view.textContainerInset.top, band - 0.5, "首行图片没让出顶部空白")

        // `rect` 是容器坐标，落屏要加顶边距；这两条断言的是用户真正看得见的东西。
        let top = rect.minY + view.textContainerInset.top
        let usedMinY = manager.lineFragmentUsedRect(
            forGlyphAt: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil).location,
            effectiveRange: nil).minY + view.textContainerInset.top
        XCTAssertGreaterThanOrEqual(top, -0.5, "预览图被裁掉了")
        XCTAssertLessThanOrEqual(rect.maxY + view.textContainerInset.top, usedMinY + 0.5, "图片压到了源码行上")

        // 这一句同时守住那条老 bug：着色如果嵌在 textStorage 的编辑回调里跑，
        // 文档从「带图片装饰」大幅缩短时 TextKit 会拿旧下标读新字符串并抛
        // NSRangeException。
        view.sourceText = "正文\n"
        XCTAssertEqual(view.textContainerInset.top, view.contentInsetPadding.top)
    }

    private func makeImageDir(size: CGSize) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ppmd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try writeImage(of: size, to: dir.appendingPathComponent("sample.png"))
        return dir
    }

    private func writeImage(of size: CGSize, to url: URL) throws {
        // scale=1 让位图像素 == 点尺寸，否则 @2x 屏上 40×20 会被读成 80×40。
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.pngData() else { throw XCTSkip("无法生成测试图片") }
        try data.write(to: url)
    }
}

private extension PPMarkdownSyntax.Role {
    var isImagePreview: Bool {
        if case .imagePreview = self { return true }
        return false
    }
}
