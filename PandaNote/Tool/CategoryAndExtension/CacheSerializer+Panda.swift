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
    
    public static let `default` = PandaCacheSerializer()
    private init() {}
    
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
}
