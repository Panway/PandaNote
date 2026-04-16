//
//  PHAsset+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2022/2/14.
//  Copyright © 2022 Panway. All rights reserved.
//

import Foundation

extension PHAsset {
    // https://stackoverflow.com/a/44630089/4493393
    func getURL(completionHandler: @escaping ((_ responseURL: URL?) -> Void)) {
        if mediaType == .image {
            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = { (_: PHAdjustmentData) -> Bool in
                return true
            }

            requestContentEditingInput(with: options) { (contentEditingInput: PHContentEditingInput?, info: [AnyHashable: Any]) in
                // 安全解包，避免崩溃
                guard let contentEditingInput = contentEditingInput else {
                    print("contentEditingInput is nil, info: \(info)")
                    completionHandler(nil)
                    return
                }
                completionHandler(contentEditingInput.fullSizeImageURL)
            }

        } else if mediaType == .video {
            let options = PHVideoRequestOptions()
            options.version = .original

            PHImageManager.default().requestAVAsset(forVideo: self, options: options) { (asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable: Any]?) in
                if let urlAsset = asset as? AVURLAsset {
                    completionHandler(urlAsset.url)
                } else {
                    completionHandler(nil)
                }
            }
        } else {
            // 处理其他媒体类型
            completionHandler(nil)
        }
    }
}
