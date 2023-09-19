//
//  PPImagePreviewer.swift
//  PandaNote
//
//  Created by Panway on 2023/9/7.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
import SKPhotoBrowser


class PPImagePreviewer: SKPhotoBrowserDelegate {
    var photoBrowser: SKPhotoBrowser!
    var imageArray = [PPFileObject]()

    func showImage(fromView: UIView?,
                   imageName:String,
                   localPath:String,
                   completion: (() -> Void)? = nil) -> Void {
        var photos = [SKLocalPhoto]()
        
        let photoObj = SKLocalPhoto.photoWithImageURL(localPath)
        photos.append(photoObj)
        
        self.photoBrowser = SKPhotoBrowser(photos: photos)
        self.photoBrowser.shouldAutoHideControlls = false
        var clickIndex = 0//点击的图片是第几张 The sequence number of the clicked photo
        
        self.photoBrowser.initializePageIndex(clickIndex)
        self.photoBrowser.delegate = self
        
        UIViewController.pp_topViewController()?.present(self.photoBrowser, animated: true, completion: {})
        if let completion = completion {
            completion()
        }
    }
    
}
