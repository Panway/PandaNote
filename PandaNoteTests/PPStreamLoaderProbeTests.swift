//
//  PPStreamLoaderProbeTests.swift
//  临时探针测试：用本机 AList WebDAV 实测 PPStreamResourceLoader
//  验证两件事：1) 带认证头能让 AVPlayer 边缓冲边播；2) 播完后缓存文件完整提交
//

import XCTest
import AVFoundation
@testable import PandaNote

final class PPStreamLoaderProbeTests: XCTestCase {

    private let realURL = URL(string: "http://127.0.0.1:5244/dav/alist/tmp/2026-10-30%2017.18.58.mp4")!
    private let expectedSize: Int64 = 1_606_027

    private func authHeaders() -> [String: String] {
        let auth = Data("panda:Pan123456".utf8).base64EncodedString()
        return ["Authorization": "Basic \(auth)"]
    }

    /// 本机 AList 测试服务器是否在线（有 HTTP 响应就算在线，包括 401）
    private func serverAvailable() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var available = false
        var request = URLRequest(url: URL(string: "http://127.0.0.1:5244/dav/")!, timeoutInterval: 3)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            available = (response != nil)
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return available
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(serverAvailable(), "本机 AList 测试服务器（127.0.0.1:5244）没开，跳过")
    }

    /// 正向测试：带认证头 → 能播 + 缓存完整落盘
    func testStreamWithAuthPlaysAndCaches() throws {
        let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PPStreamProbe", isDirectory: true)
        try? FileManager.default.removeItem(at: cacheDir)
        let cacheURL = cacheDir.appendingPathComponent("probe.mp4")

        let loader = PPStreamResourceLoader(headers: authHeaders(), cacheFileURL: cacheURL)
        let fakeURL = try XCTUnwrap(PPStreamResourceLoader.fakeSchemeURL(for: realURL))
        let asset = AVURLAsset(url: fakeURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "probe.loader"))

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        // 等 AVPlayer 说"可以播了"（说明它已经从我们手里拿到了文件头并解析成功）
        let ready = expectation(description: "player readyToPlay")
        var observeToken: NSKeyValueObservation?
        observeToken = item.observe(\.status, options: [.new]) { item, _ in
            let status = item.status
            print(">>> PROBE item.status = \(status.rawValue)")
            if status == .readyToPlay || status == .failed {
                ready.fulfill()
                observeToken?.invalidate()
                observeToken = nil
            }
        }
        wait(for: [ready], timeout: 30)

        XCTAssertEqual(item.status, .readyToPlay, "带认证头应该能播，错误: \(String(describing: item.error))")
        let duration = CMTimeGetSeconds(item.duration)
        print(">>> PROBE duration = \(duration)s")
        XCTAssertTrue(duration.isFinite && duration > 0, "时长应该是有效正数")

        // 让 AVPlayer 把整个文件拉完：先播一下，再直接跳到接近结尾，
        // 逼它去下载尾部数据（不然它缓冲够了就停，缓存永远凑不齐）
        player.play()
        player.seek(to: CMTime(seconds: max(duration - 0.3, 0), preferredTimescale: 600))
        var committed = false
        let partURL = URL(fileURLWithPath: cacheURL.path + ".part")
        for i in 0..<40 {
            Thread.sleep(forTimeInterval: 0.5)
            let finalSize = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.size] as? Int64) ?? nil
            let partSize = (try? FileManager.default.attributesOfItem(atPath: partURL.path)[.size] as? Int64) ?? nil
            if i % 4 == 0 || finalSize == expectedSize {
                print(">>> PROBE final = \(String(describing: finalSize)) part = \(String(describing: partSize)) / \(expectedSize)")
            }
            if finalSize == expectedSize { committed = true; break }
        }
        player.pause()
        loader.shutdown()

        XCTAssertTrue(committed, "缓存文件应完整提交为 \(expectedSize) 字节")

        // 提交后的缓存内容应该是合法 mp4（开头 4 字节是 box 大小，5-8 字节是 'ftyp'）
        let head = try Data(contentsOf: cacheURL).prefix(12)
        let ftyp = head.dropFirst(4).prefix(4)
        print(">>> PROBE cache head = \(Array(head))")
        XCTAssertEqual(String(data: ftyp, encoding: .ascii), "ftyp", "缓存文件开头应是 mp4 的 ftyp box")
    }

    /// 反向对照：不带认证头 → 服务器 401 → 播放失败（证明请求头真的起作用了）
    func testStreamWithoutAuthFails() throws {
        let loader = PPStreamResourceLoader(headers: [:])
        let fakeURL = try XCTUnwrap(PPStreamResourceLoader.fakeSchemeURL(for: realURL))
        let asset = AVURLAsset(url: fakeURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "probe.loader.noauth"))

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item) // 必须挂到 player 上，资源加载器才会开始干活
        let failed = expectation(description: "player failed without auth")
        var observeToken: NSKeyValueObservation?
        observeToken = item.observe(\.status, options: [.new]) { item, _ in
            let status = item.status
            print(">>> PROBE noauth item.status = \(status.rawValue)")
            if status == .readyToPlay || status == .failed {
                failed.fulfill()
                observeToken?.invalidate()
                observeToken = nil
            }
        }
        wait(for: [failed], timeout: 30)
        loader.shutdown()
        _ = player // 保持 player 存活到测试结束，item 才会持续驱动资源加载

        XCTAssertEqual(item.status, .failed, "没有认证头应该被服务器拒绝，播放失败")
        print(">>> PROBE noauth error = \(String(describing: item.error))")
    }
}
