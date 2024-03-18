//
//  PPMultiTabsViewController.swift
//  PandaNote
//
//  Created by pan on 2024/3/5.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation
import XLPagerTabStrip

class PPMultiTabsViewController: PPButtonBarTabViewController {

    
    override public func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
      return vcs
    }
    
    init(vcs: [UIViewController]) {
        super.init(nibName: nil, bundle: nil)
        self.vcs = vcs
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        self.settings.style.buttonBarHeight = 80
        super.viewDidLoad()
    }
    
    

}
