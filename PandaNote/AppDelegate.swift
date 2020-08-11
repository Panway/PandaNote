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
        window?.rootViewController = PPTabBarController.ppTabBar()
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
        URLProtocol.registerClass(PPReplacingImageURLProtocol.self)//当你的应用程序启动时，它会向 URL 加载系统注册协议。 这意味着它将有机会处理每个发送到 URL加载系统的请求。
        PPWebViewController.registerHTTPScheme()
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
    //MARK: - Universal Links
    /// Associated Domains Entitlement配置:applinks:p.agolddata.com
    ///个人开发者账户不支持Associated Domains capability，所以暂时不加此功能！
    /// 服务端配置如下：
    /// https://p.agolddata.com/.well-known/apple-app-site-association
    // "appID": "YOUR_TEAM_ID.com.agolddata.pandanote",
    // "paths": ["/pandanote/*","/wechat/*"]
    // 测试链接 ： https://p.agolddata.com/pandanote
    //代码来源：https://developer.apple.com/documentation/xcode/allowing_apps_and_websites_to_link_to_your_content/supporting_universal_links_in_your_app
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
    {
        // Get URL components from the incoming user activity
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL,
            let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        // Check for specific URL components that you need
        guard let path = components.path,
        let params = components.queryItems else {
            return false
        }
        debugPrint("path = \(path)")
        
        if let albumName = params.first(where: { $0.name == "albumname" } )?.value,
            let photoIndex = params.first(where: { $0.name == "index" })?.value {
            //这个链接会走到这里 https://p.agolddata.com/pandanote?albumname=Life&index=1
            debugPrint("album = \(albumName)")
            debugPrint("photoIndex = \(photoIndex)")
            return true
            
        } else {
            debugPrint("Either album name or photo index missing")
            return false
        }
    }

}

