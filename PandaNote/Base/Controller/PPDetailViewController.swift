//
//  PPDetailViewController.swift
//  PandaNote
//
//  Created by Panway on 2023/2/26.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

class PPDetailViewController: UIViewController {
    var filePathStr: String = ""
    var fileID = ""
    var downloadURL = ""
    
    
    let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
//    let viewControllers = [PPMarkdownViewController(), PPWebViewController()]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.frame = view.bounds
        
//        guard let markdown = viewControllers[0] as? PPMarkdownViewController else {return};
//        markdown.filePathStr = filePathStr
//        markdown.fileID = fileID
//        markdown.downloadURL = downloadURL
//        pageViewController.setViewControllers([markdown], direction: .forward, animated: true, completion: nil)
//        pageViewController.didMove(toParent: self)
    }
}
