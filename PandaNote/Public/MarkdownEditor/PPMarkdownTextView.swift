//
//  PPMarkdownTextView.swift
//  PandaNote
//
//  Created by pan on 2026/10/1.
//  Copyright © 2026 Panway. All rights reserved.
//
//  Markdown 编辑器内核。
//
//  本文件的第一性原则：**`textStorage.string` 恒等于 Markdown 源码。**
//  渲染只做一件事——在这段字符串上贴属性；装饰一律由 PPMarkdownLayoutManager 画出来。
//  只要不往文本里插字符（图片附件的 U+FFFC、圆点、按钮都算插入），
//  「全选复制 == 源文件」「搜索命中原文」「撤销不丢格式」就自动成立。
//

import UIKit

public protocol PPMarkdownTextViewDelegate: AnyObject {
    func didUpdateHeading(_ headings: [String])
    func didUpdateContent()
}

class PPMarkdownTextView: UITextView {

    // MARK: - Properties

    /// 图片等相对路径的解析根目录。
    var cacheDir = ""
    /// 关掉后本视图只是一个「带源码真值的纯文本框」，属性交给外部（Highlightr）负责。
    var stylesMarkdown = true

    /// 编辑器内边距。本视图是 `textContainerInset` 的唯一写入者：首行是图片预览时，
    /// 顶边距要额外让出那段空白，所以别绕开这里直接改 `textContainerInset`。
    var contentInsetPadding = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8) {
        didSet { updateContainerInset() }
    }

    /// 「文档首行就是图片预览」时需要让出的空白，由 `restyleNow` 每轮量一次。
    private var leadingImageBand: CGFloat = 0

    weak var markdownDelegate: PPMarkdownTextViewDelegate?

    private let blockScanner = PPMarkdownBlockScanner()
    private let inlineScanner = PPMarkdownInlineScanner()
    private let imageStore = PPMarkdownImageCache()
    private let markdownLayoutManager: PPMarkdownLayoutManager
    /// 着色自身可能连带派发文本变化通知，用这个旗标挡住，避免一次输入着色两遍。
    private var isDecoratingPass = false
    private var blocks = [PPMarkdownBlock]()
    private var spans = [PPMarkdownInlineSpan]()

    private var style: PPMarkdownStyle { return PPMarkdownStyle.current }

    // MARK: - 源码真值

    /// 视图当前承载的 Markdown 源码。
    ///
    /// 它和 `text` 恒等不是巧合，而是本内核的**不变量**：`text` 是源码，
    /// `attributedText.string` 也是源码，样式只活在属性里。保存时读这个。
    var sourceText: String {
        get { return textStorage.string }
        set {
            guard newValue != sourceText else { return }
            let length = (newValue as NSString).length
            let selection = NSRange(location: min(selectedRange.location, length),
                                    length: 0)
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length),
                                          with: newValue)
            selectedRange = selection
            // 程序化赋值不走 textDidChange 通知，这里自己补一次。
            restyleNow()
        }
    }

    // MARK: - Life cycle

    public convenience init(frame: CGRect) {
        self.init(frame: frame, layoutManager: PPMarkdownLayoutManager())
    }

    public init(frame: CGRect, layoutManager: PPMarkdownLayoutManager) {
        markdownLayoutManager = layoutManager
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer(size: CGSize(width: frame.size.width,
                                                         height: .greatestFiniteMagnitude))
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: frame, textContainer: textContainer)

        markdownLayoutManager.imageCache = imageStore
        autocorrectionType = .no
        spellCheckingType = .no
        // 链接色由着色层逐段决定，不能被全局 linkTextAttributes 覆盖。
        linkTextAttributes = [:]
        applyTypingAttributes()
        updateContainerInset()
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextChange),
                                               name: UITextView.textDidChangeNotification, object: self)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 1.0
        addGestureRecognizer(longPress)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 着色

    /// 旧调用点保留：新内核里「渲染」不产生文本，只是重新贴属性。
    open func render() {
        restyleNow()
    }

    /// 全量重新着色。块级增量留到下一轮，这一轮先把正确性立住。
    func restyleNow() {
        guard stylesMarkdown else { return }
        let source = PPMarkdownSource(textStorage.string)
        blocks = blockScanner.scan(source)
        spans = inlineScanner.scan(source, blocks: blocks)

        applyTypingAttributes()
        // 着色只贴属性、不动字符，扫描结果始终是有效的。
        isDecoratingPass = true
        let styler = PPMarkdownStyler(style: style, images: imageStore, cacheDir: cacheDir)
        textStorage.beginEditing()
        styler.apply(to: textStorage, source: source, blocks: blocks, spans: spans)
        textStorage.endEditing()
        isDecoratingPass = false
        leadingImageBand = measureLeadingImageBand()
        updateContainerInset()

        markdownDelegate?.didUpdateHeading(headings)
        markdownDelegate?.didUpdateContent()
    }

    /// 新输入的字符回到正文样式，否则敲下的字会继承上一个标题的 32 号粗体。
    private func applyTypingAttributes() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.paragraphSpacing = style.paragraphSpacing
        typingAttributes = [.font: style.fonts.body,
                            .foregroundColor: style.colors.body,
                            .paragraphStyle: paragraph]
    }

    private func updateContainerInset() {
        textContainerInset = UIEdgeInsets(top: contentInsetPadding.top + leadingImageBand,
                                          left: contentInsetPadding.left,
                                          bottom: contentInsetPadding.bottom,
                                          right: contentInsetPadding.right)
    }

    /// 预览图靠「源码行上方的空白」容身，而 TextKit 1 会直接忽略容器首段的
    /// `paragraphSpacingBefore`，所以文档第一行就是图片时，那段空白只能从顶内边距
    /// 补——它是全局的，正好等价于「整篇往下挪一个图位」。
    /// 见 `PPMarkdownKernelTests.testLeadingImagePreviewReservesSpaceViaInset`。
    private func measureLeadingImageBand() -> CGFloat {
        guard textStorage.length > 0,
              let syntax = textStorage.attribute(.ppMarkdownSyntax, at: 0,
                                                 effectiveRange: nil) as? PPMarkdownSyntax,
              case .imagePreview(_, let size) = syntax.role else { return 0 }
        return size.height + style.imagePreviewGap
    }

    // MARK: - 派生数据

    /// 大纲：标题正文去掉两侧的 `#`。源码里仍在，`pp_scrollSubstringToTop` 照样命中。
    var headings: [String] {
        let source = sourceText as NSString
        return blocks.compactMap { block in
            guard case .heading = block.kind else { return nil }
            let raw = source.substring(with: block.contentRange)
            // Setext 标题的 `===` 在第二行，正文只取首行。
            let firstLine = raw.components(separatedBy: "\n").first ?? raw
            return firstLine.removingMarkdownHeadingMarkers()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// 文档里出现的图片引用（未解析的原始 URL）。
    var imageURLs: [String] {
        return spans.compactMap { span in
            guard case .image = span.kind else { return nil }
            return span.urlString
        }
    }

    // MARK: - 文本改写

    /// 所有程序化改写都走这里：`replaceRange:withText:` 是唯一同时保住
    /// 撤销栈、输入法和委托回调的入口。
    private func replaceSource(_ range: NSRange, with text: String) {
        guard let target = textRange(for: range) else { return }
        replace(target, withText: text)
    }

    private func textRange(for range: NSRange) -> UITextRange? {
        let length = sourceText.utf16.count
        let location = min(max(range.location, 0), length)
        let end = min(location + range.length, length)
        guard let start = position(from: beginningOfDocument, offset: location),
              let stop = position(from: beginningOfDocument, offset: end) else { return nil }
        return textRange(from: start, to: stop)
    }

    /// 插入文本。**接收富文本但只取其中的字符**——连样式一起插进去，
    /// 显示文本就和源码分叉了。
    func insertAttributedString(_ attributedString: NSAttributedString) {
        let location = min(selectedRange.location, sourceText.utf16.count)
        replaceSource(NSRange(location: location, length: selectedRange.length),
                      with: attributedString.string)
        selectedRange = NSRange(location: location + (attributedString.string as NSString).length,
                                length: 0)
    }

    /// 更改光标所在行的标题级别。
    func updateCurrentLineWithHeadingLevel(_ headingLevel: Int) {
        let source = sourceText as NSString
        let caret = min(max(selectedRange.location, 0), source.length)
        let rawLine = source.lineRange(for: NSRange(location: caret, length: 0))
        // 不含行尾换行符，避免把下一行的开头也算进来。
        let contentLength = source.substring(with: rawLine).hasSuffix("\n") ? rawLine.length - 1 : rawLine.length
        let line = NSRange(location: rawLine.location, length: contentLength)
        let body = source.substring(with: line).removingMarkdownHeadingMarkers()
        let rebuilt = String(repeating: "#", count: max(headingLevel, 1)) + " " + body
        let column = caret - line.location
        replaceSource(line, with: rebuilt)
        let newLength = (rebuilt as NSString).length
        selectedRange = NSRange(location: line.location + min(column, newLength), length: 0)
    }

    /// 给选区加/去 `**`。只操作源码字符，不读任何属性。
    func setBold() {
        let source = sourceText as NSString
        let selection = selectedRange.length > 0
            ? selectedRange
            : source.lineRange(for: NSRange(location: min(selectedRange.location, source.length), length: 0))
        let contentLength = source.substring(with: selection).hasSuffix("\n") ? selection.length - 1 : selection.length
        let target = NSRange(location: selection.location, length: contentLength)
        guard target.length > 0 else { return }

        let left = NSRange(location: max(target.location - 2, 0), length: 2)
        let right = NSRange(location: NSMaxRange(target),
                            length: min(2, source.length - NSMaxRange(target)))
        if source.substring(with: left) == "**", source.substring(with: right) == "**" {
            replaceSource(NSRange(location: left.location, length: 4 + target.length),
                          with: source.substring(with: target))
            selectedRange = NSRange(location: left.location, length: target.length)
        } else {
            replaceSource(target, with: "**" + source.substring(with: target) + "**")
            selectedRange = NSRange(location: target.location + 2, length: target.length)
        }
    }

    // MARK: - 光标

    /// https://stackoverflow.com/a/34922332
    func moveCursor(offset: Int) {
        guard let current = selectedTextRange,
              let newPosition = position(from: current.start, offset: offset) else { return }
        selectedTextRange = textRange(from: newPosition, to: newPosition)
    }

    func moveCursorToLastRect() {
        guard let current = selectedTextRange else { return }
        scrollRectToVisible(caretRect(for: current.start), animated: false)
    }
}

// MARK: - 粘贴与菜单

extension PPMarkdownTextView {

    /// Mac Catalyst 上 Cmd+V 走的是这个方法，不是 `UIPasteboard` 那套。
    @objc override func paste(_ sender: Any?) {
        if PPPasteboardTool.copyContentsIsAttributeString() {
            PPAlertAction.showAlert(withTitle: "是否将富文本解析为Markdown", msg: nil,
                                    buttonsStatement: ["确定", "取消"]) { index in
                if index == 0 { self.pasteRichText() }
            }
            return
        }
        super.paste(sender)
    }

    @objc func pasteRichText() {
        guard let attributed = PPPasteboardTool.getHTMLFromPasteboard() else { return }
        insertAttributedString(attributed)
    }

    @objc func handleLongPress(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended, gestureRecognizer.view is UITextView else { return }
        let menuController = UIMenuController.shared
        menuController.menuItems = [UIMenuItem(title: "粘贴为富文本", action: #selector(pasteRichText))]
        if #available(iOS 13.0, *) {
            menuController.showMenu(from: self, rect: bounds)
        } else {
            menuController.setTargetRect(bounds, in: self)
            menuController.setMenuVisible(true, animated: true)
        }
    }
}

// MARK: - 文本变化自动重着色

extension PPMarkdownTextView {

    /// 打字、粘贴、撤销、重做完成后重新着色。
    ///
    /// 为什么不用 `NSTextStorageDelegate`：着色要在 textStorage 上再开一轮编辑，
    /// 而 TextKit 在 `textStorage(_:didProcessEditing:)` 回调里嵌套编辑时，文档
    /// 大幅缩短会拿旧下标去读新字符串（`NSRangeException`，首行图片预览那条
    /// 用例可复现）。`textDidChange` 通知在编辑周期结束之后才派发，天然安全。
    /// 程序化赋值不走这条通知，由 `sourceText` setter 自己补一次着色。
    @objc private func handleTextChange(_ notification: Notification) {
        guard !isDecoratingPass else { return }
        restyleNow()
    }
}

