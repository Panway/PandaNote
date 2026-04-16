//
//  PPPhotoTool.swift
//  PandaNote
//
//  Created by pan on 2025/10/15.
//  Copyright © 2025 Panway. All rights reserved.
//

import Photos
import UIKit

class PPPhotoTool {
    static func requestVideoURL(with asset: PHAsset?, success: @escaping (_ videoURL: URL?) -> Void) {
        if let asset = asset {
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { avasset, audioMix, info in
                if avasset is AVURLAsset {
                    let url = (avasset as? AVURLAsset)?.url
                        success(url)
                }
            })
        }
    }
    
    // MARK: - 判断是否为 Live Photo
    static func isLivePhoto(_ asset: PHAsset) -> Bool {
        return asset.mediaSubtypes.contains(.photoLive)
    }
    
    // MARK: - 获取 Live Photo 对象
    static func requestLivePhoto(for asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize, completion: @escaping (PHLivePhoto?, Error?) -> Void) {
        guard isLivePhoto(asset) else {
            completion(nil, NSError(domain: "LivePhoto", code: -1, userInfo: [NSLocalizedDescriptionKey: "不是 Live Photo"]))
            return
        }
        
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { livePhoto, info in
            completion(livePhoto, info?[PHImageErrorKey] as? Error)
        }
    }
    
    // MARK: - 获取 Live Photo 的原始文件数据
    
    static func exportLivePhotoData(for asset: PHAsset, completion: @escaping (Data?, Data?,String,String, Error?) -> Void) {
        guard isLivePhoto(asset) else {
            completion(nil, nil,"","", NSError(domain: "LivePhoto", code: -1, userInfo: [NSLocalizedDescriptionKey: "不是 Live Photo"]))
            return
        }
        
        let resources = PHAssetResource.assetResources(for: asset)
        
        var imageData: Data?
        var videoData: Data?
        var imgName = ""
        var videoName = ""
        var error: Error?
        let group = DispatchGroup()
        
        for resource in resources {
            debugPrint(resource.originalFilename)
            if resource.type == .photo {
                imgName = resource.originalFilename
                // 获取图片数据
                group.enter()
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                
                PHAssetResourceManager.default().requestData(for: resource, options: options) { data in
                    imageData = (imageData ?? Data()) + data
                } completionHandler: { err in
                    if let err = err {
                        error = err
                    }
                    group.leave()
                }
            } else if resource.type == .pairedVideo {
                videoName = resource.originalFilename
                // 获取视频数据
                group.enter()
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                
                PHAssetResourceManager.default().requestData(for: resource, options: options) { data in
                    videoData = (videoData ?? Data()) + data
                } completionHandler: { err in
                    if let err = err {
                        error = err
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(imageData, videoData,imgName,videoName, error)
        }
    }
    
    // MARK: - 导出 Live Photo 到文件
    func exportLivePhotoToFiles(for asset: PHAsset, completion: @escaping (URL?, URL?, Error?) -> Void) {
        guard PPPhotoTool.isLivePhoto(asset) else {
            completion(nil, nil, NSError(domain: "LivePhoto", code: -1, userInfo: [NSLocalizedDescriptionKey: "不是 Live Photo"]))
            return
        }
        
        let resources = PHAssetResource.assetResources(for: asset)
        
        var imageURL: URL?
        var videoURL: URL?
        var error: Error?
        let group = DispatchGroup()
        
        for resource in resources {
            if resource.type == .photo {
                // 导出图片
                group.enter()
                let fileName = "livephoto_\(UUID().uuidString).heic"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                
                PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { err in
                    if let err = err {
                        error = err
                    } else {
                        imageURL = fileURL
                    }
                    group.leave()
                }
            } else if resource.type == .pairedVideo {
                // 导出视频
                group.enter()
                let fileName = "livephoto_\(UUID().uuidString).mov"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                
                PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { err in
                    if let err = err {
                        error = err
                    } else {
                        videoURL = fileURL
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(imageURL, videoURL, error)
        }
    }
    // ChatGPT
    static func getLivePhotoData(asset: PHAsset, completion: @escaping (Data?, Data?) -> Void) {
        let imageManager = PHImageManager.default()

        // 获取静态图片（照片部分）
        let photoOptions = PHImageRequestOptions()
        photoOptions.isSynchronous = true
        photoOptions.version = .current
        
        imageManager.requestImageData(for: asset, options: photoOptions) { (data, _, _, _) in
            let photoData = data
            
            // 获取视频部分
            let videoOptions = PHVideoRequestOptions()
            // 注意：没有 isSynchronous 属性，必须依赖异步回调
            
            imageManager.requestAVAsset(forVideo: asset, options: videoOptions) { (avAsset, _, _) in
                if let asset = avAsset as? AVURLAsset {
                    do {
                        let videoData = try Data(contentsOf: asset.url)
                        completion(photoData, videoData)
                    } catch {
                        print("Error fetching video data: \(error)")
                        completion(photoData, nil)
                    }
                } else {
                    completion(photoData, nil)
                }
            }
        }
    }
    
    
    // MARK: - 获取资源信息
    /*
    func getLivePhotoResourceInfo(for asset: PHAsset) -> (imageSize: Int64, videoSize: Int64)? {
        guard isLivePhoto(asset) else { return nil }
        
        let resources = PHAssetResource.assetResources(for: asset)
        var imageSize: Int64 = 0
        var videoSize: Int64 = 0
        
        for resource in resources {
            if resource.type == .photo {
                imageSize = resource.value(forKey: "fileSize") as? Int64 ?? 0
            } else if resource.type == .pairedVideo {
                videoSize = resource.value(forKey: "fileSize") as? Int64 ?? 0
            }
        }
        
        return (imageSize, videoSize)
    }
     */
}

// MARK: - 使用示例
//extension PPPhotoTool {
//    func example(asset: PHAsset) {
//        let manager = PPPhotoTool()
//        
//        // 1. 判断是否为 Live Photo
//        if manager.isLivePhoto(asset) {
//            print("这是 Live Photo")
//            
//            // 2. 获取二进制数据
//            manager.exportLivePhotoData(for: asset) { imageData, videoData, error in
//                if let error = error {
//                    print("获取失败: \(error)")
//                    return
//                }
//                
//                if let imageData = imageData {
//                    print("图片大小: \(imageData.count) bytes")
//                }
//                
//                if let videoData = videoData {
//                    print("视频大小: \(videoData.count) bytes")
//                }
//            }
//            
//            // 3. 导出到文件
//            manager.exportLivePhotoToFiles(for: asset) { imageURL, videoURL, error in
//                if let error = error {
//                    print("导出失败: \(error)")
//                    return
//                }
//                
//                print("图片路径: \(imageURL?.path ?? "无")")
//                print("视频路径: \(videoURL?.path ?? "无")")
//            }
//            
//            // 4. 获取资源信息
//            if let info = manager.getLivePhotoResourceInfo(for: asset) {
//                print("图片大小: \(info.imageSize) bytes")
//                print("视频大小: \(info.videoSize) bytes")
//            }
//        }
//    }
//}
