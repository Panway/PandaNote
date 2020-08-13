//
//  CacheSerializer+Panda.swift
//  PandaNote
//
//  Created by panwei on 2019/9/19.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation
import Kingfisher
let KingfisherEmptyOptionsInfo = [KingfisherOptionsInfoItem]()

public struct PandaCacheSerializer: CacheSerializer {
    ///把磁盘的Data对象变成UIImage来使用
    public func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        return KingfisherWrapper.image(data: data,
                                       options: ImageCreatingOptions(
                                        scale: options.scaleFactor,
                                        duration: 0,
                                        preloadAll: options.preloadAllAnimationData,
                                        onlyFirstFrame: options.onlyLoadFirstFrame))
    }
    ///把Image对象保存成Data，存到磁盘
    public func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        return original
    }
    
    public static let `default` = PandaCacheSerializer()
    private init() {}
    /* 4.0旧代码
    public func data(with image: Image, original: Data?) -> Data? {
        return original
    }

    public func image(with data: Data, options: KingfisherOptionsInfo?) -> Image? {
        let options = options ?? KingfisherEmptyOptionsInfo
        return Kingfisher<Image>.image(
            data: data,
            scale: options.scaleFactor,
            preloadAllAnimationData: options.preloadAllAnimationData,
            onlyFirstFrame: options.onlyLoadFirstFrame)
    }
 */
}
