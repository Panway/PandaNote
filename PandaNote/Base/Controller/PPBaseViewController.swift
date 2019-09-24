//
//  PPBaseViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/28.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation
import UIKit

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
