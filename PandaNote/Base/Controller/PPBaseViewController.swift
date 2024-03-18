//
//  PPBaseViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/28.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation
import UIKit

public let PPCOLOR_GREEN = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)
let PPCOLOR_GREEN_LIGHT = UIColor(red:0.27, green:0.68, blue:0.49, alpha:0.5)

class PPBaseViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.white
        if #available(iOS 13.0, *) {
            // Always adopt a light interface style.
//            overrideUserInterfaceStyle = .light
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @objc func pp_backAction() -> Void {
        self.navigationController?.popViewController(animated: true)
    }
    
    func setLeftBarButton() -> Void {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(image: UIImage.init(named: "icon_back_black"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(pp_backAction))
    }
    
}
//MARK: - Private
//
extension PPBaseViewController {
    //显示图片选择器
    func showImagePicker(completion: ((_ selectedAssets:[PHAsset]) -> Void)? = nil) {
        //#if targetEnvironment(macCatalyst)
#if !USE_YPImagePicker
        print("targetEnvironment(macCatalyst)")
        let picker = TZImagePickerController()
        picker.allowPickingMultipleVideo = true
        picker.maxImagesCount = 999//一次最多可选择999张图片
        picker.didFinishPickingPhotosWithInfosHandle = { (photos, assets, isSelectOriginalPhoto, infoArr) -> (Void) in
            // debugPrint("\(photos?.count) ---\(assets?.count)")
            guard let photoAssets = assets as? [PHAsset] else { return }
            if let completion = completion {
                completion(photoAssets)
            }
        }
        self.present(picker, animated: true, completion: nil)
#else
        var config = YPImagePickerConfiguration()
        config.library.maxNumberOfItems = 99
        //        config.library.mediaType = .photoAndVideo//支持上传图片和视频
        config.showsPhotoFilters = false
        config.startOnScreen = YPPickerScreen.library
        config.hidesStatusBar = false
        let picker = YPImagePicker(configuration: config)
        picker.didFinishPicking { [unowned picker] items, cancelled in
            if cancelled {
                //点击左上角的取消让选择器消失
                picker.dismiss(animated: true, completion: nil)
                return
            }
            guard let photo = items.singlePhoto else {
                return
            }
            if photo.fromCamera == true {
                debugPrint("====\(photo.originalImage.imageOrientation.rawValue)")
                return
            }
            //遍历每个assets
            let photoAssets = items.map { item -> PHAsset in
                switch item {
                case .photo(let photo):
                    if let asset = photo.asset {
                        return asset
                    }
                case .video(let video):
                    if let asset = video.asset {
                        return asset
                    }
                }
                return PHAsset()//这种情况一般不存在
            }
            
            if let completion = completion {
                completion(photoAssets)
            }
            
            picker.dismiss(animated: true, completion: nil)
        }
        self.present(picker, animated: true, completion: nil)
#endif
    }
    
    func pushDetail(_ viewController:UIViewController, isMarkdown:Bool? = false) {
        if UIDevice.current.userInterfaceIdiom != .phone,
           let navController = self.splitViewController?.viewControllers.last as? UINavigationController{
            //macOS & iPad
                // navController.viewControllers = [viewController]
                //self.splitViewController?.showDetailViewController(navController, sender: self)
            if let isMarkdown = isMarkdown, isMarkdown == true {
                if let topVC = navController.viewControllers.last as? PPMultiTabsViewController {
                    for (index, element) in topVC.vcs.enumerated() {
                        if element.title == viewController.title {
                            //已经打开过的页面 file than already opened
                            topVC.moveToViewController(at: index, animated: true)
                            return
                        }
                    }
                    
                    topVC.vcs.append(viewController)
                    topVC.reloadPagerTabStripView()
                    topVC.moveToViewController(at: topVC.vcs.count - 1, animated: true)
                }
                else {
                    let multiTabs = PPMultiTabsViewController(vcs: [viewController])
                    navController.pushViewController(multiTabs, animated: true)
                }
            }
            else {
                navController.pushViewController(viewController, animated: true)
            }
            
            
        }
        else {
            // iPhone
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
}
