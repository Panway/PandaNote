//
//  PPTabBarController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let barAppearance = UINavigationBar.appearance()
        barAppearance.barTintColor = UIColor.white
        barAppearance.tintColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)//VUE绿
        barAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        
        
        let firstViewController = PPHomeViewController.init()
        firstViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 0)
        
        let recentsVC = PPHomeViewController.init()
        recentsVC.tabBarItem = UITabBarItem(tabBarSystemItem: .recents, tag: 1)
        
        let secondViewController = PPSettingViewController.init()
        secondViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .more, tag: 2)
        
        let tabBarList = [firstViewController,recentsVC, secondViewController]
        
        viewControllers = tabBarList
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
