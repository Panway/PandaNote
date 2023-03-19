//
//  PPSplitViewController.swift
//  PandaNote
//
//  Created by Panway on 2023/3/4.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

class PPSplitViewController: UISplitViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareSplitViewController()
    }
    // 设置master 控制器横竖屏显示以及宽度
    func prepareSplitViewController() {
        // iPad竖屏也显示master控制器
        self.preferredDisplayMode = .allVisible;
    }

}
