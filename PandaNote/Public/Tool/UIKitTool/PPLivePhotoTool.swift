//
//  PPLivePhotoTool.swift
//  PandaNote
//
//  Created by pan on 2026/4/20.
//  Copyright © 2026 Panway. All rights reserved.
//

import Photos
import PhotosUI
import AVFoundation
import ImageIO
import UIKit

// MARK: - Error

enum PPLivePhotoToolError: LocalizedError {
    case permissionDenied
    case assetNotFound
    case exportFailed(String)
    case metadataInjectFailed
    case saveFailed(Error?)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:           return "相册权限不足"
        case .assetNotFound:              return "找不到对应资产"
        case .exportFailed(let msg):      return "导出失败: \(msg)"
        case .metadataInjectFailed:       return "Metadata 注入失败"
        case .saveFailed(let e):          return "保存相册失败: \(e?.localizedDescription ?? "未知")"
        case .downloadFailed(let msg):    return "下载失败: \(msg)"
        }
    }
}

// MARK: - PPLivePhotoTool

final class PPLivePhotoTool {

    static let shared = PPLivePhotoTool()
    private init() {}

    // MARK: - 临时目录管理

    /// 生成唯一临时文件 URL
    private func tempURL(name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PPLivePhotoTool")
            .appendingPathComponent(name)
    }

    /// 清理指定临时文件列表
    private func cleanTempFiles(_ urls: [URL]) {
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    /// 确保临时目录存在
    private func ensureTempDirectory() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PPLivePhotoTool")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    // MARK: - ① 从相册导出 Live Photo 临时文件（用于上传）

    /// 从 PHAsset 导出 Live Photo 的图片和视频临时文件
    /// - Parameters:
    ///   - asset: 必须是 mediaSubtypes 包含 .photoLive 的 PHAsset
    ///   - completion: 成功返回 (imageURL, videoURL)，调用方上传完毕后负责清理

    func exportLivePhoto(
        from asset: PHAsset,
        completion: @escaping (Result<(imageURL: URL, videoURL: URL), PPLivePhotoToolError>) -> Void
    ) {
        guard asset.mediaSubtypes.contains(.photoLive) else {
            completion(.failure(.assetNotFound))
            return
        }
        ensureTempDirectory()
        let uuid = UUID().uuidString

        // 并发导出图片和视频，两者都完成后回调
        let group = DispatchGroup()
        var imageURL: URL?
        var videoURL: URL?
        var exportError: PPLivePhotoToolError?

        // --- 导出静态图 ---
        group.enter()
        exportImage(from: asset, uuid: uuid) { result in
            switch result {
            case .success(let url): imageURL = url
            case .failure(let e):   exportError = e
            }
            group.leave()
        }

        // --- 导出配对视频 ---
        group.enter()
        exportPairedVideo(from: asset, uuid: uuid) { result in
            switch result {
            case .success(let url): videoURL = url
            case .failure(let e):   exportError = e
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let error = exportError {
                // 清理已生成的临时文件
                [imageURL, videoURL].compactMap { $0 }.forEach {
                    try? FileManager.default.removeItem(at: $0)
                }
                completion(.failure(error))
                return
            }
            guard let img = imageURL, let vid = videoURL else {
                completion(.failure(.exportFailed("未能获取文件 URL")))
                return
            }
            completion(.success((img, vid)))
        }
    }

    // MARK: - ② 保存服务器下载的 Live Photo 到相册
    func requestPhotoLibraryPermission(completion: @escaping (Result<String, PPLivePhotoToolError>) -> Void) {
            // 检查系统版本，决定使用哪个API
            if #available(iOS 14, *) {
                // iOS 14及以上版本使用新的API
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                    guard self != nil else { return }
                    guard status == .authorized || status == .limited else {
                        DispatchQueue.main.async {
                            completion(.failure(.permissionDenied))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completion(.success("true"))
                    }
                }
            } else {
                // iOS 14以下版本使用旧的API
                PHPhotoLibrary.requestAuthorization { [weak self] status in
                    guard self != nil else { return }
                    guard status == .authorized else {
                        DispatchQueue.main.async {
                            completion(.failure(.permissionDenied))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completion(.success("true"))
                    }
                }
            }
        }
    /// 将已下载的图片 Data + 视频 Data 注入 Metadata 后保存为 Live Photo
    /// - Parameters:
    ///   - imageData: 服务器下载的图片数据
    ///   - videoData: 服务器下载的视频数据
    ///   - completion: 成功返回新资产的 localIdentifier
    func saveLivePhotoToAlbum(
        imageData: Data,
        videoData: Data,
        completion: @escaping (Result<String, PPLivePhotoToolError>) -> Void
    ) {
        requestPhotoLibraryPermission { result in
            switch result {
            case .success(let granted):
                print("权限请求成功: \(granted)")
            case .failure(let error):
                print("权限请求失败: \(error)")
                return
            }
            
            
            self.ensureTempDirectory()
            let uuid = UUID().uuidString

            // 1. 注入 Metadata 到图片
            guard let imageURL = self.injectIdentifierToImage(
                imageData, identifier: uuid
            ) else {
                DispatchQueue.main.async {
                    completion(.failure(.metadataInjectFailed))
                }
                return
            }

            // 2. 将视频 Data 写入临时文件，再注入 Metadata
            let rawVideoURL = self.tempURL(name: "\(uuid)_raw.mov")
            do {
                try videoData.write(to: rawVideoURL)
            } catch {
                self.cleanTempFiles([imageURL, rawVideoURL])
                DispatchQueue.main.async {
                    completion(.failure(.exportFailed(error.localizedDescription)))
                }
                return
            }

            self.injectIdentifierToVideo(
                sourceURL: rawVideoURL, identifier: uuid
            ) { [weak self] result in
                guard let self else { return }
                // 原始临时视频已不需要
                self.cleanTempFiles([rawVideoURL])

                switch result {
                case .failure(let e):
                    self.cleanTempFiles([imageURL])
                    DispatchQueue.main.async { completion(.failure(e)) }

                case .success(let videoURL):
                    // 3. 写入相册
                    self.writeToPhotoLibrary(
                        imageURL: imageURL, videoURL: videoURL
                    ) { [weak self] saveResult in
                        self?.cleanTempFiles([imageURL, videoURL])
                        DispatchQueue.main.async { completion(saveResult) }
                    }
                }
            }
        }
    }

    // MARK: - Private: 导出图片

    private func exportImage(
        from asset: PHAsset,
        uuid: String,
        completion: @escaping (Result<URL, PPLivePhotoToolError>) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        PHImageManager.default().requestImageData(//requestImageDataAndOrientation(
            for: asset, options: options
        ) { [weak self] data, uti, _, _ in
            guard let self, let data else {
                completion(.failure(.exportFailed("图片 Data 为空")))
                return
            }
            let destURL = self.tempURL(name: "\(uuid).jpg")
            do {
                try data.write(to: destURL)
                completion(.success(destURL))
            } catch {
                completion(.failure(.exportFailed(error.localizedDescription)))
            }
        }
    }

    // MARK: - Private: 导出配对视频

    private func exportPairedVideo(
        from asset: PHAsset,
        uuid: String,
        completion: @escaping (Result<URL, PPLivePhotoToolError>) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        // 请求配对视频资源
        PHImageManager.default().requestAVAsset(
            forVideo: asset, options: options
        ) { [weak self] avAsset, _, _ in
            guard let self, let avAsset else {
                completion(.failure(.exportFailed("视频资源为空")))
                return
            }
            let destURL = self.tempURL(name: "\(uuid).mov")
            guard let session = AVAssetExportSession(
                asset: avAsset,
                presetName: AVAssetExportPresetPassthrough
            ) else {
                completion(.failure(.exportFailed("无法创建 ExportSession")))
                return
            }
            session.outputURL = destURL
            session.outputFileType = .mov
            session.exportAsynchronously {
                switch session.status {
                case .completed: completion(.success(destURL))
                default:
                    completion(.failure(
                        .exportFailed(session.error?.localizedDescription ?? "未知")
                    ))
                }
            }
        }
    }

    // MARK: - Private: 图片注入 AssetIdentifier

    /// 用 CGImageDestination 将 UUID 写入图片 EXIF MakerApple 字段
    private func injectIdentifierToImage(
        _ data: Data, identifier: String
    ) -> URL? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let uti = CGImageSourceGetType(source)
        else { return nil }

        let destURL = tempURL(name: "\(identifier).jpg")
        guard let dest = CGImageDestinationCreateWithURL(
            destURL as CFURL, uti, 1, nil
        ) else { return nil }

        let metadata: [String: Any] = [
            kCGImagePropertyMakerAppleDictionary as String: ["17": identifier]
        ]
        CGImageDestinationAddImageFromSource(dest, source, 0, metadata as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return destURL
    }

    // MARK: - Private: 视频注入 AssetIdentifier

    /// 用 AVAssetExportSession 向视频写入 QuickTime content.identifier
    private func injectIdentifierToVideo(
        sourceURL: URL,
        identifier: String,
        completion: @escaping (Result<URL, PPLivePhotoToolError>) -> Void
    ) {
        let asset = AVURLAsset(url: sourceURL)
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            completion(.failure(.metadataInjectFailed))
            return
        }

        let outputURL = tempURL(name: "\(identifier).mov")

        // content.identifier：与图片 EXIF 中的 UUID 配对
        let identifierItem = AVMutableMetadataItem()
        identifierItem.keySpace = AVMetadataKeySpace(rawValue: "mdta")
        identifierItem.key = "com.apple.quicktime.content.identifier"
            as (NSCopying & NSObjectProtocol)
        identifierItem.value = identifier as (NSCopying & NSObjectProtocol)
        identifierItem.dataType = "com.apple.metadata.datatype.UTF-8"

        // still-image-time：标记为 Live Photo 视频
        let stillImageItem = AVMutableMetadataItem()
        stillImageItem.keySpace = AVMetadataKeySpace(rawValue: "mdta")
        stillImageItem.key = "com.apple.quicktime.still-image-time"
            as (NSCopying & NSObjectProtocol)
        stillImageItem.value = NSNumber(value: -1)
        stillImageItem.dataType = "com.apple.metadata.datatype.int8"

        session.metadata = [identifierItem, stillImageItem]
        session.outputURL = outputURL
        session.outputFileType = .mov

        session.exportAsynchronously {
            switch session.status {
            case .completed: completion(.success(outputURL))
            default:
                completion(.failure(
                    .exportFailed(session.error?.localizedDescription ?? "未知")
                ))
            }
        }
    }

    // MARK: - Private: 写入相册

    private func writeToPhotoLibrary(
        imageURL: URL,
        videoURL: URL,
        completion: @escaping (Result<String, PPLivePhotoToolError>) -> Void
    ) {
        var localIdentifier: String?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            localIdentifier = request.placeholderForCreatedAsset?.localIdentifier

            let imgOpt = PHAssetResourceCreationOptions()
            imgOpt.shouldMoveFile = true   // 移动而非复制，节省磁盘
            request.addResource(with: .photo, fileURL: imageURL, options: imgOpt)

            let vidOpt = PHAssetResourceCreationOptions()
            vidOpt.shouldMoveFile = true
            // ⚠️ 必须用 .pairedVideo，用 .video 则无法识别为 Live Photo
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: vidOpt)

        } completionHandler: { success, error in
            if success, let id = localIdentifier {
                completion(.success(id))
            } else {
                completion(.failure(.saveFailed(error)))
            }
        }
    }
}
