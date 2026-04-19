//
//  WebDAVXMLParser.swift
//  CloudDrive
//
//  解析 WebDAV PROPFIND 响应（multistatus XML）
//
//  WebDAV 服务器返回的 XML 示例结构：
//  <D:multistatus xmlns:D="DAV:">
//    <D:response>
//      <D:href>/path/to/file.txt</D:href>
//      <D:propstat>
//        <D:prop>
//          <D:displayname>file.txt</D:displayname>
//          <D:getcontentlength>1024</D:getcontentlength>
//          <D:getcontenttype>text/plain</D:getcontenttype>
//          <D:getetag>"abc123"</D:getetag>
//          <D:getlastmodified>Mon, 01 Jan 2024 00:00:00 GMT</D:getlastmodified>
//          <D:creationdate>2024-01-01T00:00:00Z</D:creationdate>
//          <D:resourcetype/>  <!-- 文件时为空 -->
//        </D:prop>
//        <D:status>HTTP/1.1 200 OK</D:status>
//      </D:propstat>
//    </D:response>
//    <D:response>
//      <D:href>/path/to/dir/</D:href>
//      <D:propstat>
//        <D:prop>
//          <D:resourcetype><D:collection/></D:resourcetype>
//        </D:prop>
//      </D:propstat>
//    </D:response>
//  </D:multistatus>
//

import Foundation

// MARK: - WebDAVFileEntry（内部模型）

struct WebDAVFileEntry {
    var href: String = ""
    var displayName: String = ""
    var contentLength: Int64 = 0
    var contentType: String?
    var lastModified: Date?
    var creationDate: Date?
    var etag: String?
    var isCollection: Bool = false
}

// MARK: - WebDAVXMLParser

final class WebDAVXMLParser: NSObject, XMLParserDelegate {
    // MARK: Properties

    private let data: Data
    private(set) var entries: [WebDAVFileEntry] = []
    private(set) var parseError: Error?

    // 解析状态
    private var currentEntry: WebDAVFileEntry?
    private var currentText: String = ""
    private var insidePropstat: Bool = false
    private var insideResourceType: Bool = false

    // MARK: Init

    init(data: Data) {
        self.data = data
    }

    // MARK: Parse

    /// 执行解析，返回解析结果
    @discardableResult
    func parse() -> [WebDAVFileEntry]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldReportNamespacePrefixes = false
        parser.shouldProcessNamespaces = true
        let success = parser.parse()
        return success && parseError == nil ? entries : nil
    }

    // MARK: - XMLParserDelegate

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes _: [String: String] = [:]
    ) {
        let local = localName(elementName)
        currentText = ""

        switch local {
        case "response":
            currentEntry = WebDAVFileEntry()

        case "propstat":
            insidePropstat = true

        case "resourcetype":
            insideResourceType = true

        case "collection":
            // <D:collection/> 表示这是一个目录
            currentEntry?.isCollection = true

        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let local = localName(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch local {
        case "response":
            if let entry = currentEntry {
                entries.append(entry)
            }
            currentEntry = nil
            insidePropstat = false
            insideResourceType = false

        case "propstat":
            insidePropstat = false

        case "resourcetype":
            insideResourceType = false

        case "href":
            // href 有两处：response 级别（文件路径）和 propstat 内（某些服务器）
            // 只取 response 级别的
            if !insidePropstat, !text.isEmpty {
                currentEntry?.href = extractPath(from: text)
            }

        case "displayname":
            if !text.isEmpty {
                currentEntry?.displayName = text
            }

        case "getcontentlength":
            currentEntry?.contentLength = Int64(text) ?? 0

        case "getcontenttype":
            currentEntry?.contentType = text.isEmpty ? nil : text

        case "getetag":
            // 去除首尾引号
            let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            currentEntry?.etag = cleaned.isEmpty ? nil : cleaned

        case "getlastmodified":
            currentEntry?.lastModified = parseDate(text)

        case "creationdate":
            currentEntry?.creationDate = parseDate(text)

        default:
            break
        }

        currentText = ""
    }

    func parser(_: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    func parser(_: XMLParser, validationErrorOccurred validationError: Error) {
        parseError = validationError
    }

    // MARK: - Helpers

    /// 从带命名空间前缀的元素名中提取本地名（如 "D:href" → "href"）
    private func localName(_ elementName: String) -> String {
        elementName.components(separatedBy: ":").last ?? elementName
    }

    /// 从完整 URL 或相对路径中提取路径部分
    private func extractPath(from href: String) -> String {
        // 如果是完整 URL（http://host/path），取 path 部分
        if let url = URL(string: href), let host = url.host, !host.isEmpty {
            return url.path
        }
        // 否则直接使用（相对路径）
        return href
    }

    // MARK: - Date Parsers

    private static let rfc1123Formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    private static let iso8601FormatterFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        // RFC 1123（getlastmodified 常用格式）
        if let d = Self.rfc1123Formatter.date(from: string) { return d }
        // ISO 8601 with fractional seconds
        if let d = Self.iso8601FormatterFull.date(from: string) { return d }
        // ISO 8601 basic
        if let d = Self.iso8601FormatterBasic.date(from: string) { return d }
        return nil
    }
}
