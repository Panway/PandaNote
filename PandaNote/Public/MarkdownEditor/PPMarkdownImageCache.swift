//
//  PPMarkdownImageCache.swift
//  PandaNote
//
//  图片预览的尺寸与位图缓存。旧实现在主线程用 `UIImage(contentsOfFile:)` 全量解码
//  每一张图，长文档打开会卡；这里改成「先只读元数据拿尺寸，再按需降采样解码」。
//

import UIKit
import ImageIO

/// 图片参考路径的解析 + 降采样缓存。
///
/// 用法：着色层先问 `displaySize(for:)` 要一个尺寸来预留行前空白（只读图片头，不解码），
/// 同时 `request(path:)` 触发异步降采样；图到位后回调里重跑一次着色，空白刚好被填满。
final class PPMarkdownImageCache {

    private var pixelSizes = [String: CGSize]()
    private let imageCache = NSCache<NSString, UIImage>()
    private var pendingPaths = Set<String>()
    private let queue = DispatchQueue(label: "PPMarkdownImageCache", qos: .userInitiated)

    init() {
        imageCache.countLimit = 120
    }

    // MARK: - 路径解析

    /// 把 markdown 里的图片 URL 换算成本地缓存路径。与旧 `PPAttributedStringVisitor` 保持一致：
    /// http(s) 图片按文件名或 md5 落在 cacheDir 下，相对路径直接拼在 cacheDir 后。
    static func localPath(for url: String, cacheDir: String) -> String {
        let joined: String
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            let name = url.pp_getFileName()
            joined = "\(cacheDir)/\(name.isEmpty ? url.pp_md5 : name)"
        } else {
            joined = "\(cacheDir)/\(url)"
        }
        return joined.replacingOccurrences(of: "//", with: "/")
    }

    static func isRemote(_ url: String) -> Bool {
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }

    // MARK: - 尺寸

    /// 只读图片头信息拿尺寸，不解码像素。返回 nil 表示文件不存在或尺寸未知。
    func displaySize(for path: String, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize? {
        guard let pixels = pixelSize(for: path), pixels.width > 0, pixels.height > 0 else { return nil }
        let width = min(pixels.width, maxWidth)
        var height = pixels.height * (width / pixels.width)
        if height > maxHeight {
            height = maxHeight
        }
        return CGSize(width: width, height: height)
    }

    private func pixelSize(for path: String) -> CGSize? {
        if let cached = pixelSizes[path] { return cached }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue else { return nil }
        let size = CGSize(width: width, height: height)
        pixelSizes[path] = size
        return size
    }

    // MARK: - 位图

    func image(for path: String) -> UIImage? {
        return imageCache.object(forKey: path as NSString)
    }

    /// 异步降采样解码。完成回调在主线程，`image == nil` 表示读取失败。
    func request(path: String, pointSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        if let cached = image(for: path) {
            completion(cached)
            return
        }
        guard !pendingPaths.contains(path) else { return }
        pendingPaths.insert(path)
        queue.async {
            let image = PPMarkdownImageCache.downsample(path: path, pointSize: pointSize)
            DispatchQueue.main.async {
                self.pendingPaths.remove(path)
                if let image = image {
                    self.imageCache.setObject(image, forKey: path as NSString)
                }
                completion(image)
            }
        }
    }

    /// 用 ImageIO 的 thumbnail API 直接按目标像素尺寸解码，避免整张原图进内存。
    private static func downsample(path: String, pointSize: CGSize) -> UIImage? {
        let scale = UIScreen.main.scale
        let maxPixel = max(pointSize.width, pointSize.height) * scale
        guard maxPixel > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    func removeAll() {
        imageCache.removeAllObjects()
        pixelSizes.removeAll()
    }
}
