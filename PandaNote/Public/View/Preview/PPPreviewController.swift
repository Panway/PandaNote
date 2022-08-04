//
//  PPPreviewController.swift
//  PandaNote
//
//  Created by topcheer on 2022/8/1.
//  Copyright © 2022 WeirdPan. All rights reserved.
//

import UIKit
import QuickLook

class PPPreviewController: QLPreviewController,
                           QLPreviewControllerDataSource,
                            QLPreviewControllerDelegate {
    var filePathArray = [String]()
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return filePathArray.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        let path = self.filePathArray[index]
        let url = URL(fileURLWithPath: path)
        return url as QLPreviewItem
        // 上面三行等价于:
        // URL(fileURLWithPath: self.filePathArray[index]) as QLPreviewItem
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self;
        self.dataSource = self;
    }
    
}
