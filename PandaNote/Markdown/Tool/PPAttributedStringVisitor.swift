//
//  PPAttributedStringVisitor.swift
//  Down
//
//  Created by John Nguyen on 09.04.19.
//

#if !os(Linux)

import Foundation
import Down

/// This class is used to generated an `NSMutableAttributedString` from the abstract syntax
/// tree produced by a markdown string. It traverses the tree to construct substrings
/// represented at each node and uses an instance of `Styler` to apply the visual attributes.
/// These substrings are joined together to produce the final result.

public typealias PPListPrefixGeneratorBuilder = (List) -> ListItemPrefixGenerator

public class PPAttributedStringVisitor {

    // MARK: - Properties
    var cacheDir = ""
    var images = [String]()

    private let styler: Styler
    private let options: DownOptions
    private let listPrefixGeneratorBuilder: PPListPrefixGeneratorBuilder
    private var listPrefixGenerators = [ListItemPrefixGenerator]()

    /// Creates a new instance with the given styler and options.
    ///
    /// - parameters:
    ///     - styler: used to style the markdown elements.
    ///     - options: may be used to modify rendering.
    ///     - listPrefixGeneratorBuilder: may be used to modify list prefixes.

    public init(
        styler: Styler,
        options: DownOptions = .default,
        listPrefixGeneratorBuilder: @escaping PPListPrefixGeneratorBuilder = { StaticListItemPrefixGenerator(list: $0) }
    ) {
        self.styler = styler
        self.options = options
        self.listPrefixGeneratorBuilder = listPrefixGeneratorBuilder
    }

}

extension PPAttributedStringVisitor: Visitor {

    public typealias Result = NSMutableAttributedString

    public func visit(document node: Document) -> NSMutableAttributedString {
        let result = visitChildren(of: node).pp_joined
        styler.style(document: result)
        return result
    }

    public func visit(blockQuote node: BlockQuote) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: "> \(result.string)")
        styler.style(blockQuote: result, nestDepth: node.nestDepth)
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        return result
    }

    public func visit(list node: List) -> NSMutableAttributedString {

        listPrefixGenerators.append(listPrefixGeneratorBuilder(node))
        defer { listPrefixGenerators.removeLast() }

        let items = visitChildren(of: node)

        let result = items.pp_joined
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        styler.style(list: result, nestDepth: node.nestDepth)
        return result
    }

    public func visit(item node: Item) -> NSMutableAttributedString {
        let result = visitChildren(of: node).pp_joined

        let prefix = listPrefixGenerators.last?.next() ?? "-"
        let attributedPrefix = "\(prefix)\t".pp_attributed
        styler.style(listItemPrefix: attributedPrefix)
        result.insert(attributedPrefix, at: 0)

        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        styler.style(item: result, prefixLength: (prefix as NSString).length)
        return result
    }

    public func visit(codeBlock node: CodeBlock) -> NSMutableAttributedString {
        guard let literal = node.literal else { return .pp_empty }
        var result = literal.pp_replacingNewlinesWithLineSeparators().pp_attributed
        result = renewString(result: result, newStr: "```\(node.fenceInfo ?? "")\n\(result.string)\n```\n")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.black,
            .backgroundColor: UIColor.lightGray.withAlphaComponent(0.3), //这里透明度设置成0.1左右，非常重要，不然选中文字看不到选中高亮色，very important!!!
        ]
        result.addAttributes(attributes, range: result.wholeRange)
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
//        styler.style(codeBlock: result, fenceInfo: node.fenceInfo)
        return result
    }

    public func visit(htmlBlock node: HtmlBlock) -> NSMutableAttributedString {
        guard let literal = node.literal else { return .pp_empty }
        let result = literal.pp_replacingNewlinesWithLineSeparators().pp_attributed
        styler.style(htmlBlock: result)
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        return result
    }

    public func visit(customBlock node: CustomBlock) -> NSMutableAttributedString {
        guard let result = node.literal?.pp_attributed else { return .pp_empty }
        styler.style(customBlock: result)
        return result
    }

    public func visit(paragraph node: Paragraph) -> NSMutableAttributedString {
        let result = visitChildren(of: node).pp_joined
        styler.style(paragraph: result)
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        return result
    }

    public func visit(heading node: Heading) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: String(repeating: "#", count: node.headingLevel) + " \(result.string)")
        styler.style(heading: result, level: node.headingLevel)
        if node.hasSuccessor { result.append(.pp_paragraphSeparator) }
        return result
    }

    public func visit(thematicBreak node: ThematicBreak) -> NSMutableAttributedString {
        let result = "\(String.pp_zeroWidthSpace)\n".pp_attributed
        styler.style(thematicBreak: result)
        return result
    }

    public func visit(text node: Text) -> NSMutableAttributedString {
        guard let result = node.literal?.pp_attributed else { return .pp_empty }
        styler.style(text: result)
        return result
    }

    public func visit(softBreak node: SoftBreak) -> NSMutableAttributedString {
        let result = (options.contains(.hardBreaks) ? String.pp_lineSeparator : " ").pp_attributed
        styler.style(softBreak: result)
        return result
    }

    public func visit(lineBreak node: LineBreak) -> NSMutableAttributedString {
        let result = String.pp_lineSeparator.pp_attributed
        styler.style(lineBreak: result)
        return result
    }

    public func visit(code node: Code) -> NSMutableAttributedString {
        guard let result1 = node.literal?.pp_attributed else { return .pp_empty }
        var result = result1
        result = renewString(result: result, newStr: "`\(result.string)`")
//        styler.style(code: result)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: "#000000".pp_HEXColor(),
            .backgroundColor: UIColor.lightGray.withAlphaComponent(0.3), //这里透明度设置成0.1左右，非常重要，不然选中文字看不到选中高亮色，very important!!!
        ]
        result.addAttributes(attributes, range: result.wholeRange)
        return result
    }

    public func visit(htmlInline node: HtmlInline) -> NSMutableAttributedString {
        guard let result = node.literal?.pp_attributed else { return .pp_empty }
        styler.style(htmlInline: result)
        return result
    }

    public func visit(customInline node: CustomInline) -> NSMutableAttributedString {
        guard let result = node.literal?.pp_attributed else { return .pp_empty }
        styler.style(customInline: result)
        return result
    }

    public func visit(emphasis node: Emphasis) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: "*\(result.string)*")
        // 设置字体、下划线和删除线的属性
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 17), // 设置斜体字体
//            .underlineStyle: NSUnderlineStyle.single.rawValue, // 设置下划线样式
//            .strikethroughStyle: NSUnderlineStyle.single.rawValue // 设置删除线样式
        ]
        result.addAttributes(attributes, range: result.wholeRange)
//        styler.style(emphasis: result)
        return result
    }

    public func visit(strong node: Strong) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: "**\(result.string)**")
        styler.style(strong: result)
        return result
    }

    public func visit(link node: Link) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: "[\(result.string)](\(node.url ?? ""))")
        styler.style(link: result, title: node.title, url: node.url)
        return result
    }

    public func visit(image node: Image) -> NSMutableAttributedString {
        var result = visitChildren(of: node).pp_joined
        result = renewString(result: result, newStr: "![\(result.string)](\(node.url ?? ""))")
        styler.style(image: result, title: node.title, url: node.url)
        
        //显示图片附件
        let fileManager = FileManager.default
        let path = "\(cacheDir)/\(node.url ?? "")".replacingOccurrences(of: "//", with: "/")
        if let url_ = node.url {
            images.append(url_)
        }
        if fileManager.fileExists(atPath: path) {
            result.append("\n".pp_attributed) //换行
            // 创建一个NSTextAttachment实例并设置图片
            let imageAttachment = NSTextAttachment()
            if let localImage = UIImage(contentsOfFile: path) {
                imageAttachment.image = localImage
                // 设置图片尺寸：宽度最大为320，如果小于320按原始大小显示，且始终保持纵横比
                let maxWidth: CGFloat = 320.0
                var imageSize = localImage.size
                // 调整图片尺寸，保持纵横比
                if imageSize.width > maxWidth {
                    let scaleFactor = maxWidth / imageSize.width
                    imageSize.width *= scaleFactor
                    imageSize.height *= scaleFactor
                }
                imageAttachment.bounds = CGRect(origin: .zero, size: imageSize)
            }
            // 创建包含图片附件的NSAttributedString
            let attributedString = NSAttributedString(attachment: imageAttachment)
            result.append(attributedString)
        }
        return result
    }
    
    public func renewString(result:NSMutableAttributedString, newStr:String) -> NSMutableAttributedString{
        // 创建一个属性字典，用于存储原始样式
        if let originalAttributes = result.pp_attributes(at: 0) {
            // 创建一个新的属性字符串 "# "，设置其样式为原始样式
            let newAtt = newStr.pp_attributed
            newAtt.addAttributes(originalAttributes, range: NSRange(location: 0, length: newAtt.length))
            return newAtt
        }
        else {
            return newStr.pp_attributed
        }
    }
}

// MARK: - Helper extensions

private extension Sequence where Iterator.Element == NSMutableAttributedString {

    var pp_joined: NSMutableAttributedString {
        return reduce(into: NSMutableAttributedString()) { $0.append($1) }
    }

}

private extension NSMutableAttributedString {

    static var pp_empty: NSMutableAttributedString {
        return "".pp_attributed
    }

}

private extension NSAttributedString {

    static var pp_paragraphSeparator: NSAttributedString {
        return "\n\n".pp_attributed
    }
    
}

private extension String {
    
    var pp_attributed: NSMutableAttributedString {
        return NSMutableAttributedString(string: self, attributes: [.font:UIFont.systemFont(ofSize: 17)])
    }

    // This codepoint marks the end of a paragraph and the start of the next.
//    这几个符号是 Unicode 转义字符，用于表示不同的特殊空白字符或换行符：
//    1. `\u{2029}`：这是 Unicode 转义字符，代表 "Paragraph Separator"（段落分隔符）。在文本中，它通常用于分隔段落。
//    2. `\u{2028}`：这是 Unicode 转义字符，代表 "Line Separator"（行分隔符）。在文本中，它通常用于分隔行。
//    3. `\u{200B}`：这是 Unicode 转义字符，代表 "Zero Width Space"（零宽度空格）。这个字符在显示文本时不会产生实际的可见空格，但它可以影响到某些文本处理情景。
    static var pp_paragraphSeparator: String {
        return "\n"
//        return "\u{2029}"
    }

    // This code point allows line breaking, without starting a new paragraph.

    static var pp_lineSeparator: String {
        return "\n"
//        return "\u{2028}"
    }

    static var pp_zeroWidthSpace: String {
        return "---"
//        return "\u{200B}"
    }

    func pp_replacingNewlinesWithLineSeparators() -> String {
        let trimmed = trimmingCharacters(in: .newlines)
        let lines = trimmed.components(separatedBy: .newlines)
        return lines.joined(separator: .pp_lineSeparator)
    }

}

#endif // !os(Linux)
