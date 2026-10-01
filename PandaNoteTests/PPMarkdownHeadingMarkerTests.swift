import XCTest
@testable import PandaNote

/// 大纲标题的唯一依赖：去掉 ATX 标记后必须仍是源码里的连续子串，
/// 且「什么算标记」的答案必须与块扫描器逐字符一致，否则两处判定会各自漂移。
final class HeadingMarkerTests: XCTestCase {

    /// 关闭序列只剥 `#` 本身，其前的空白属于正文。
    func testStripsLeadingAndClosingMarkers() {
        XCTAssertEqual("# 标题".removingMarkdownHeadingMarkers(), "标题")
        XCTAssertEqual("## 标题 ##".removingMarkdownHeadingMarkers(), "标题 ")
        XCTAssertEqual("###  多个空白  ###".removingMarkdownHeadingMarkers(), "多个空白  ")
        XCTAssertEqual("## 标题##".removingMarkdownHeadingMarkers(), "标题##")
        XCTAssertEqual("   # 缩进标题".removingMarkdownHeadingMarkers(), "   # 缩进标题")
        XCTAssertEqual("###".removingMarkdownHeadingMarkers(), "")
    }

    /// `#tag` 不是标题，`C#` 不该被削掉最后一个字符，7 个 `#` 只是普通段落。
    func testNonHeadingHashesSurvive() {
        XCTAssertEqual("#tag".removingMarkdownHeadingMarkers(), "#tag")
        XCTAssertEqual("C#".removingMarkdownHeadingMarkers(), "C#")
        XCTAssertEqual("####### 七级不是标题".removingMarkdownHeadingMarkers(),
                       "####### 七级不是标题")
        XCTAssertEqual("正文 ##".removingMarkdownHeadingMarkers(), "正文 ##")
    }

    func testResultIsAlwaysASubstringOfOriginal() {
        let samples = ["# a", "## 中文 ##", "###  混 合   ", "#", "#### ", "标题", "# # 嵌套"]
        for sample in samples {
            let stripped = sample.removingMarkdownHeadingMarkers()
            XCTAssertTrue(stripped.isEmpty || sample.contains(stripped), "\(sample) -> \(stripped)")
        }
    }

    /// 把 `contentRange` 挖掉扫描器给出的 marker，结果必须等于扩展的输出。
    func testAgreesWithBlockScannerMarkers() {
        let samples = ["# a", "## 中文 ##", "###  混 合   ", "####", "##### x #", "###### y",
                       "#tag", "C#", "####### 七级", "## **bold** title ##", "正文 ##"]
        for sample in samples {
            let src = PPMarkdownSource(sample)
            let blocks = PPMarkdownBlockScanner().scan(src)
            let heading = blocks.first { block in
                if case .heading = block.kind { return true }
                return false
            }
            guard let block = heading else {
                XCTAssertEqual(sample.removingMarkdownHeadingMarkers(), sample, sample)
                continue
            }
            let body = NSMutableString(string: src.string(in: block.contentRange))
            for marker in block.markerRanges.reversed() {
                body.deleteCharacters(in: NSRange(location: marker.location - block.contentRange.location,
                                                  length: marker.length))
            }
            XCTAssertEqual(sample.removingMarkdownHeadingMarkers(), body as String, sample)
        }
    }
}
