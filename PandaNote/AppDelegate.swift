//
//  AppDelegate.swift
//  PandaNote
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 WeirdPan. All rights reserved.
//   https://github.com/KillerFei/DTW



import UIKit

#if DEBUG
import DoraemonKit
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        PPUserInfo.shared.initConfig()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: PPTabBarController())
        window?.makeKeyAndVisible()
        PPShareManager.initWeixinAppId("wx37af47629351b5c0", appKey: "")
        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        DoraemonManager.shareInstance().install()
        #endif
        
        //disable dark mode globally
        if #available(iOS 13.0, *) {
            self.window?.overrideUserInterfaceStyle = .light
        }
        
        
        let dbModel = PPPriceDBModel()
        let sqliteManager = PPSQLiteManager(delegate: dbModel)
//        let sqliteManager = PPSQLiteManager.shared
        sqliteManager.createDB()
        let sql = "create table if not exists pp_price(id integer primary key autoincrement,code varchar(20) not null,price varchar(20) default 0,name varchar(50), whole_price varchar(20) ,remark varchar(20),category varchar(20) )"
        
        sqliteManager.operation(process: sql, value: [])
//        test()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        PPPasteboardTool.getMoreInfomationOfURL()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

