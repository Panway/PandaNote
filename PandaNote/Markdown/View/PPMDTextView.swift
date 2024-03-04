//
//  PPMDTextView.swift
//  PandaNote
//
//  Created by Panway on 2023/8/20.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import UIKit
import Down
import Highlightr
//import libcmark
public protocol PPMDTextViewDelegate: AnyObject {
    func didUpdateHeading(_ headings:[String])
}

class PPMDTextView: UITextView {
    
    // MARK: - Properties
    
    open var styler: Styler
    open var renderMethod = ""
    var didRender = false ///< 第一次如果只设置text而没设置attributedText，就调用render()
    var cacheDir = ""
    var visitor : PPAttributedStringVisitor
    weak var markdownDelegate: PPMDTextViewDelegate?

    open override var text: String! {
        didSet {
            guard oldValue != text else { return }

            if renderMethod == "Down" {
                render()
            }
        }
    }

    
    // MARK: - Life cycle
    
    public convenience init(frame: CGRect) { //, styler: Styler = DownStyler()) {
        
        let dsc = DownStylerConfiguration(fonts: PPAppConfig.shared.downFont,
                                          colors: PPAppConfig.shared.downColor,
                                          paragraphStyles: PPDownParagraphStyleCollection(),
                                          listItemOptions: ListItemOptions(),
                                          quoteStripeOptions: QuoteStripeOptions(thickness: 5, spacingAfter: 8),
                                          thematicBreakOptions: ThematicBreakOptions(),
                                          codeBlockOptions: CodeBlockOptions())
        let styler = DownStyler(configuration: dsc)
        self.init(frame: frame, styler: styler, layoutManager: DownLayoutManager()) //DownDebugLayoutManager
    }
    
    public init(frame: CGRect, styler: Styler, layoutManager: NSLayoutManager) {
        self.styler = styler
        
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer(size: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude))
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        self.visitor = PPAttributedStringVisitor(styler: styler, options: DownOptions.hardBreaks)
        super.init(frame: frame, textContainer: textContainer)
        self.autocorrectionType = .no  // 取消拼写自动纠错 Disable the default autocorrection
        self.spellCheckingType = .no // 禁用拼写检查
        // We don't want the text view to overwrite link attributes set
        // by the styler.
        linkTextAttributes = [:]
        // 注册剪贴板在App内部变化的通知
//        NotificationCenter.default.addObserver(self, selector: #selector(handlePasteboardChange), name: UIPasteboard.changedNotification, object: nil)
        // 长按事件
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        longPress.minimumPressDuration = 1.0
        self.addGestureRecognizer(longPress)

    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // 移除通知观察者
//        NotificationCenter.default.removeObserver(self)
    }
    // 我操你大爷的，重写Command+V原来这么简单？？？
    @objc override func paste(_ sender: Any?) {
        let isRtf = PPPasteboardTool.copyContentsIsAttributeString()
        if isRtf {
            PPAlertAction.showAlert(withTitle: "是否将富文本解析为Markdown", msg: nil, buttonsStatement: ["确定","取消"]) { index in
                if index == 0 {
                    self.pasteRichText()
                }
            }
        }
        else {
            super.paste(sender)
            // self.insertAttributedString(UIPasteboard.general.string?.pp_attributed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.render()
            }
        }
    }
    // MARK: - Methods
    // 按 Cmd+Z 撤销时调用 （还原）
    @objc func undoAttributedTextChange(_ backupText: NSAttributedString) {
        self.attributedText = backupText
    }
    @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            if gestureRecognizer.view is UITextView {
                debugPrint("Double tap detected in UITextView")
                // 在这里执行双击事件的处理
                let menuController = UIMenuController.shared
                // 添加"粘贴为富文本"菜单项
                let pasteRichTextMenuItem = UIMenuItem(title: "粘贴为富文本", action: #selector(pasteRichText))
                // 设置菜单项
                menuController.menuItems = [pasteRichTextMenuItem]
                // 设置弹出（右键）菜单显示位置
                if #available(iOS 13.0, *) {
                    menuController.showMenu(from: self, rect: self.frame)
                }
                else {
                    menuController.setTargetRect(self.frame, in: self)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }
    @objc func pasteRichText() {
        if let attributedString = PPPasteboardTool.getHTMLFromPasteboard() {
            // 在这里处理富文本的插入
            self.insertAttributedString(attributedString)
            self.render()
        }
    }
    
    
    // 处理粘贴板变化通知
    @objc func handlePasteboardChange(_ notification: Notification) {
//        if let pasteboard = notification.object as? UIPasteboard {
//            if let copiedString = pasteboard.string {
//                debugPrint("Pasted String:")
//                debugPrint(copiedString)
//            }
//        }
    }
    // utf8编码的纯文本，用16进制查看发现有好多EFBFBCEFBFBC，请问这是什么字符？(退出保存的时候)
    // UTF-8 编码的文本中，EFBFBCEFBFBC 表示的是 UTF-8 编码的 REPLACEMENT CHARACTER（替代字符），在 Unicode 中表示为 U+FFFD。
    // UTF-8 编码的 REPLACEMENT CHARACTER 是一个特殊字符，通常用来替代文本中包含了无法正确解码的或损坏的字节序列的部分。它是一个Unicode的保留字符，通常用于指示编码或解码问题。当文本中包含无法识别或无法解码的字符时，文本处理程序通常会将其替换为 U+FFFD。
    // 这个字符在文本处理中用来表明出现了编码问题，通常意味着原始文本中包含了某种无法识别或正确解码的字符或字节序列。在处理文本时，你可能需要查找并解决编码问题，以确保文本能够正确显示和处理。
    open func render() {
        if renderMethod != "Down" {
            return
        }
        // 获取原来的光标位置
        let selectedRange = self.selectedRange
        let offsetY = self.contentOffset.y
//        self.text = self.text.replacingOccurrences(of: "￼", with: "") //去掉替代字符
        let ttttt = self.text.replacingOccurrences(of: "￼", with: "")
        print("render==========\n\(ttttt)\n=========="  )
        let down = Down(markdownString: ttttt)
        
        guard let document = try? down.toDocument(DownOptions.hardBreaks) else { return }
        visitor.cacheDir = cacheDir
        visitor.images.removeAll()
        visitor.headings.removeAll()
        let attText = document.accept(visitor)
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(undoAttributedTextChange), object: attText)
        attributedText = attText
        self.markdownDelegate?.didUpdateHeading(visitor.headings)
        didRender = true
        debugPrint("===========")
        // 恢复光标位置
        if selectedRange.location != NSNotFound {
            self.selectedRange = selectedRange
        }
        for item in visitor.images {
            let path = "\(cacheDir)/\(item)".replacingOccurrences(of: "//", with: "/").pp_split(PPUserInfo.shared.webDAVRemark).last ?? ""
            // 是完整的http路径，缓存到 `/Library/Caches/PandaCache/XXX/7217078bf5868444aa1dd421eafbd956`
            if item.hasPrefix("http://") || item.hasPrefix("https://") {
                let absPath = "\(cacheDir)/\(item.pp_md5)".replacingOccurrences(of: "//", with: "/")
                if FileManager.default.fileExists(atPath: absPath) {
                    continue
                }
                PPFileManager.shared.downloadThenCache(url: item, path: absPath.pp_split(PPUserInfo.shared.webDAVRemark).last ?? "") { contents, isFromCache, error in
                }
                continue
            }
            //不是完整的http路径
            PPFileManager.shared.getFileData(path: path,
                                             fileID: nil,
                                             alwaysDownload:false) { (contents: Data?,isFromCache, error) in
            }
        }
        self.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
    }
    // 如何在UITextView已经显示的attributedText当前光标处插入一个NSAttributedString对象
    func insertAttributedString(_ attributedString: NSAttributedString) {
        let selectedRange = self.selectedRange
        guard let at = self.attributedText else { return }
        let mutableAttributedString = NSMutableAttributedString(attributedString: at)
        mutableAttributedString.replaceCharacters(in: selectedRange, with: attributedString)
        self.undoManager?.registerUndo(withTarget: self, selector: #selector(undoAttributedTextChange), object: mutableAttributedString)
        self.attributedText = mutableAttributedString
        // 更新光标位置
        self.selectedRange = NSRange(location: selectedRange.location + attributedString.length, length: 0)
    }
    /// 更改标题级别
    func updateCurrentLineWithHeadingLevel(_ headingLevel:Int) {
        // 获取光标所在行的文本范围
        if let selectedTextRange = self.selectedTextRange,
           let currentLineRange = self.tokenizer.rangeEnclosingPosition(selectedTextRange.start, with: .line, inDirection: .init(rawValue: 1)) {
            // 获取光标所在行的 NSRange
            let cursorPosition = self.offset(from: self.beginningOfDocument, to: currentLineRange.start)
            let lineNSRange = NSRange(location: cursorPosition, length: self.offset(from: currentLineRange.start, to: currentLineRange.end))
            let currentLineText = self.attributedText.attributedSubstring(from: lineNSRange)
            // 更新光标所在行的NSAttributedString
            let stringWithoutHash = currentLineText.string.pp_removeLeadingCharacter("#").pp_removeLeadingCharacter(" ")
            let newAttributedString = NSAttributedString(string: String(repeating: "#", count: headingLevel) + " \(stringWithoutHash)", attributes: currentLineText.pp_attributes(at: 0))
            
            // 更新当前行的文本
            let mutableAttributedString = NSMutableAttributedString(attributedString: self.attributedText)
            mutableAttributedString.replaceCharacters(in: lineNSRange, with: newAttributedString)
            let selectedRange = self.selectedRange
            // 备份，以供Command + Z撤销
            self.undoManager?.registerUndo(withTarget: self, selector: #selector(undoAttributedTextChange), object: mutableAttributedString)
            self.attributedText = mutableAttributedString
            self.render()
            // 恢复光标位置
            if selectedRange.location != NSNotFound {
                self.becomeFirstResponder()
                self.selectedRange = selectedRange
            }
        }
    }
    
    // https://stackoverflow.com/a/34922332
    func moveCursor(offset:Int) {
        if let selectedRange = self.selectedTextRange {
            // and only if the new position is valid
            if let newPosition = self.position(from: selectedRange.start, offset: offset) {
                // set the new position
                self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            }
        }
    }
    
    func moveCursorToLastRect() {
        if let selectedTextRange = self.selectedTextRange {
            let caretRect = self.caretRect(for: selectedTextRange.start)
            self.scrollRectToVisible(caretRect, animated: false)
        }
    }
}
//https://levelup.gitconnected.com/background-with-rounded-corners-in-uitextview-1c095c708d14
/// Shadow style for background attribute
public class ShadowStyle {
    /// Color of the shadow
    public let color: UIColor

    /// Shadow offset
    public let offset: CGSize

    /// Shadow blur
    public let blur: CGFloat

    public init(color: UIColor, offset: CGSize, blur: CGFloat) {
        self.color = color
        self.offset = offset
        self.blur = blur
    }
}

/// Additional style for background color attribute. Adding `BackgroundStyle` attribute in addition to
/// `backgroundColor` attribute will apply shadow and rounded corners as specified.
/// - Note:
/// This attribute had no effect in absence of `backgroundColor` attribute.
public class BackgroundStyle {

    /// Corner radius of the background
    public let cornerRadius: CGFloat

    /// Optional shadow style for the background
    public let shadow: ShadowStyle?

    public init(cornerRadius: CGFloat = 0, shadow: ShadowStyle? = nil) {
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }
}

class PPLayoutManager: NSLayoutManager {

    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<CGRect>, count rectCount: Int, forCharacterRange charRange: NSRange, color: UIColor) {
        guard let textStorage = textStorage,
            let currentCGContext = UIGraphicsGetCurrentContext(),
            let backgroundStyle = textStorage.attribute(.backgroundStyle, at: charRange.location, effectiveRange: nil) as? BackgroundStyle else {
                super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
                return
        }

        currentCGContext.saveGState()
        let cornerRadius = backgroundStyle.cornerRadius

        let corners = UIRectCorner.allCorners

        for i in 0..<rectCount  {
            let rect = rectArray[i]
            let rectanglePath = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            color.set()

            if let shadowStyle = backgroundStyle.shadow {
                currentCGContext.setShadow(offset: shadowStyle.offset, blur: shadowStyle.blur, color: shadowStyle.color.cgColor)
            }

            currentCGContext.setAllowsAntialiasing(true)
            currentCGContext.setShouldAntialias(true)

            currentCGContext.setFillColor(color.cgColor)
            currentCGContext.addPath(rectanglePath.cgPath)
            currentCGContext.drawPath(using: .fill)
        }
        currentCGContext.restoreGState()
    }
}
public extension NSAttributedString.Key {
    /// Additional style attribute for background color. Using this attribute in addition to `backgroundColor` attribute allows applying
    /// shadow and corner radius to the background.
    /// - Note:
    /// This attribute only takes effect with `.backgroundColor`. In absence of `.backgroundColor`, this attribute has no effect.
    static let backgroundStyle = NSAttributedString.Key("_backgroundStyle")
}
