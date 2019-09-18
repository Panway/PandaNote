//
//  AppDelegate.swift
//  PandaNote
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 WeirdPan. All rights reserved.
//   https://github.com/KillerFei/DTW



import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        PPUserInfoManager.sharedManager.initConfig()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: PPTabBarController())
        window?.makeKeyAndVisible()
        PPShareManager.initWeixinAppId("wx37af47629351b5c0", appKey: "")
        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
        test()
        return true
    }
    func test() -> Void {
//        let concurrentQueue = DispatchQueue(label: "panda", attributes: .concurrent)
        let serialQueue = DispatchQueue(label: "queuename")
        // 串行异步中嵌套同步
//        print(1)
//        serialQueue.async {
//            print(2)
//            serialQueue.sync {
//                print(3)
//            }
//            print(4)
//        }
//        print(5)
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
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

