//
//  PPFileManager.swift
//  PandaNote
//
//  Created by panwei on 2019/9/19.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation
import Photos

class PPFileManager: NSObject {
    static let sharedManager = PPFileManager()

    override init() {
        
    }
    /// 获取NSData
    func getImageDataFromAsset(asset: PHAsset, completion: @escaping (_ data: NSData?,_ fileURL:URL?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        manager.requestImageData(for: asset, options: options) { (result, string, orientation, info) -> Void in
            let url = info?["PHImageFileURLKey"] as! URL

            if let imageData = result {
                completion(imageData as NSData,url)
            } else {
                completion(nil,url)
            }
        }
    }
    
    func getImageDataFromPHAsset(asset: PHAsset) -> Data {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        
        return Data()
    }
}
