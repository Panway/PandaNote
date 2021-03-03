//
//  PPTabBarController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit
#warning("test image")
import Alamofire

class PPTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let barAppearance = UINavigationBar.appearance()
        barAppearance.barTintColor = UIColor.white
        barAppearance.tintColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)//VUE绿
        barAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        
        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
        let _ = AF.download("https://is3-ssl.mzstatic.com/image/thumb/Purple113/v4/06/c7/6a/06c76afc-7276-8cf6-be38-4cb30cebb8e3/AppIcon-1-0-0-1x_U007emarketing-0-0-0-7-0-0-85-220.png/246x0w.png", to: destination)
    }
    class func ppTabBar() -> PPTabBarController {
        let recentsVC = PPFileListViewController()
        recentsVC.isRecentFiles = true
        recentsVC.tabBarItem = UITabBarItem(title: "最近", image: UIImage(named: "tab_history"), tag: 0)
        let recentsNav = UINavigationController(rootViewController: recentsVC)
        
        let testVC = PPFileListViewController()
        testVC.tabBarItem = UITabBarItem(title: "文件", image: UIImage(named: "tab_folder"), tag: 0)
        let testNav = UINavigationController(rootViewController: testVC)

        let webVC = PPWebViewController()
        webVC.urlString = "https://tophub.today"
        webVC.tabBarItem = UITabBarItem(title: "看一看", image: UIImage(named: "tab_stories"), tag: 0)
        let webNav = UINavigationController(rootViewController: webVC)

        let settingVC = PPSettingViewController()
        settingVC.tabBarItem = UITabBarItem(title: "我", image: UIImage(named: "tab_user"), tag: 0)
        let settingNav = UINavigationController(rootViewController: settingVC)

        let tabBarList = [recentsNav, testNav, webNav, settingNav]
        
        let tab = PPTabBarController()
        tab.viewControllers = tabBarList
        //默认选择第几个tab
        if let selectedIndex = PPUserInfo.shared.pp_Setting["pp_tab_selected_index"] {
            tab.selectedIndex = selectedIndex as! Int
        }
        else {
            tab.selectedIndex = 0
        }
        tab.tabBar.tintColor = PPCOLOR_GREEN
//        UITabBar.appearance().tintColor
        return tab
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
