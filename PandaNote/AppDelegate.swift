//
//  AppDelegate.swift
//  PandaNote
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 WeirdPan. All rights reserved.
//   https://github.com/KillerFei/DTW



import UIKit

import MonkeyKing
#if targetEnvironment(macCatalyst)
import AppKit
#endif


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// 主窗口。采用 UIScene 生命周期之后，窗口由 SceneDelegate 创建，并在 willConnectTo 里回填到这里，因为工程里还有老代码通过 UIApplication.shared.delegate?.window 去取它（见 UIViewController.pp_topViewController）
    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // 采用 scene 生命周期后这个方法依然会被调用，但里面只该放「进程级」的初始化。【界面相关的代码已经搬到 SceneDelegate.swift】，包括：建窗口、设根控制器、makeKeyAndVisible。另外 launchOptions 在 scene 生命周期下是空的（冷启动带进来的 URL 要从SceneDelegate 的 connectionOptions 里读），所以不要再依赖 launchOptions 取值。
        PPAppConfig.shared.initSetting()
        PPUserInfo.shared.initConfig()
        #if targetEnvironment(macCatalyst)
        print("targetEnvironment(macCatalyst)")
        #else
        MonkeyKing.registerAccount(.weChat(appID: "wx37af47629351b5c0", appKey: "", miniAppID: nil, universalLink: "https://p.agolddata.com/pandanote/"))
        //        PPShareManager.initWeixinAppId("wx37af47629351b5c0", appKey: "")
        #endif

        #if DEBUG
        self.debugSetting()

        #endif

        //macOS进入前台通知 https://stackoverflow.com/a/62626134
        #if targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActiveAction), name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),object: nil)
        #endif

        PPAppConfig.shared.initSettingAfterLoadMainUI()
        URLProtocol.registerClass(PPReplacingImageURLProtocol.self)//当你的应用程序启动时，它会向 URL 加载系统注册协议。 这意味着它将有机会处理每个发送到 URL加载系统的请求。
        //PPWebViewController.registerHTTPScheme()
        return true
    }

    // 下面这些「界面生命周期」方法，在采用 UIScene 之后 UIKit 就**不会再调用**了。原来的空实现已经删掉，就是为了防止以后有人在里面加代码、却发现一直不执行（这种情况不报错、不告警，最难查）。对应的落点：
    //   applicationDidBecomeActive                      → SceneDelegate.sceneDidBecomeActive
    //   applicationWillResignActive                     → SceneDelegate.sceneWillResignActive
    //   applicationDidEnterBackground                   → SceneDelegate.sceneDidEnterBackground
    //   applicationWillEnterForeground                  → SceneDelegate.sceneWillEnterForeground
    //   application(_:open:options:)                    → SceneDelegate.scene(_:openURLContexts:)
    //   application(_:continue:restorationHandler:)     → SceneDelegate.scene(_:continue:)

    func applicationWillTerminate(_ application: UIApplication) {
        // 说明：采用 UIScene 之后这个方法也不再被调用了（对应 SceneDelegate.sceneDidDisconnect）。
        // 这里保留一个空实现，是因为 MyURLProtocol.swift 里的 PPAppDelegate 子类 override 了它并调用了 super，
        // 删掉会编译不过。
    }
#if targetEnvironment(macCatalyst)
//    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
//        return false
//    }
//    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
//            return false
//        }
#endif

    // 注意：下面这两个方法也已经搬到 SceneDelegate.swift 了，理由同上 —— 在 scene 生命周期下 UIKit 不会再调用它们：
    //   application(_:open:options:)  → SceneDelegate.scene(_:openURLContexts:)
    //   application(_:continue:restorationHandler:)  → SceneDelegate.scene(_:continue:)
    // 它们负责的是外部跳转：
    //   wx37af47629351b5c0://... 微信登录 / 分享回调（走 MonkeyKing）
    //   msredirect://、baiduwangpan:// OneDrive、百度网盘授权回调
    //   Universal Links（Associated Domains 配的是 applinks:p.agolddata.com，个人开发者账户不支持，暂时没启用）
    //
    //MARK: - Universal Links 服务端配置备忘（代码见 SceneDelegate）
    // https://www.xiaohongshu.com/.well-known/apple-app-site-association
    // "appID": "YOUR_TEAM_ID.com.agolddata.pandanote",
    // "paths": ["/pandanote/*","/wechat/*"]
    // 测试链接 ： https://p.agolddata.com/pandanote
    //代码来源：https://developer.apple.com/documentation/xcode/allowing_apps_and_websites_to_link_to_your_content/supporting_universal_links_in_your_app
    // 查看Team ID:https://developer.apple.com/account/#!/membership

}

