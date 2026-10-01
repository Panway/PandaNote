//
//  SceneDelegate.swift
//  PandaNote
//
//  采用 UIScene 生命周期（Apple 技术说明 TN3187 的要求）
//

import UIKit
import MonkeyKing

/// UIScene 生命周期下的「窗口 + 界面」管家。
///
/// 背景：Apple 在 TN3187 里要求「用最新 SDK 构建的 App 必须采用 UIScene 生命周期」，
/// 没迁移的话 App 能编译、能安装，但一启动就崩，报错是
/// `Application failed to launch: UIScene life cycle is required for apps built with this SDK.`
///
/// 采用 scene 生命周期之后，UIKit 就**不再调用** AppDelegate 里的这几个方法了
/// （哪怕把实现留在那里，也是静默失效、不报错）：
///   applicationDidBecomeActive                     → sceneDidBecomeActive(_:)
///   applicationWillResignActive                    → sceneWillResignActive(_:)
///   applicationDidEnterBackground                  → sceneDidEnterBackground(_:)
///   applicationWillEnterForeground                 → sceneWillEnterForeground(_:)
///   application(_:open:options:)                   → scene(_:openURLContexts:)
///   application(_:continue:restorationHandler:)    → scene(_:continue:)
/// 所以写在那些方法里的逻辑必须搬到这里，光往 Info.plist 加配置是不够的。
///
/// 进程级的初始化（读配置、起本地服务、注册第三方 SDK 之类）仍然留在
/// AppDelegate 的 didFinishLaunchingWithOptions 里 —— 那个方法照样会被调用。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /// 当前场景的窗口。属性名必须叫 window，UIKit 会依赖它做窗口相关的事情
    var window: UIWindow?

    // MARK: - 建立界面

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // 只有 UIWindowScene 才是我们关心的，其他角色（比如 CarPlay）直接忽略
        guard let windowScene = scene as? UIWindowScene else { return }

        // 用 windowScene 来创建窗口，这是 scene 生命周期下的标准做法。
        // 老的 UIWindow(frame:) 写法在这里是不行的 —— 窗口不挂到 scene 上就不显示
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // ★ 关键一步：尽早把窗口同步回 AppDelegate，而且必须排在「创建任何界面」之前。
        // 因为工程里还有老代码通过 UIApplication.shared.delegate?.window 取根控制器
        // （见 UIViewController.pp_topViewController），不同步回去的话它拿到的是 nil，
        // 那些「弹全屏页 / 取安全区」的逻辑就会静默失效。
        (UIApplication.shared.delegate as? AppDelegate)?.window = window

        // ===== 下面这段原来在 AppDelegate.didFinishLaunchingWithOptions 里，现在整段搬过来 =====
        if UIDevice.current.userInterfaceIdiom != .phone {
            // macOS和iPad使用左右分屏
            let splitViewController = PPSplitViewController()
            let masterVC = PPTabBarController.ppTabBar()
            let detailVC = PPDetailViewController()
            let masterNavController = UINavigationController(rootViewController: masterVC)
            let detailNavController = UINavigationController(rootViewController: detailVC)
            splitViewController.viewControllers = [masterNavController, detailNavController]
            window.rootViewController = splitViewController
        }
        else {
            window.rootViewController = PPTabBarController.ppTabBar()
        }

        //disable dark mode globally
        window.overrideUserInterfaceStyle = .light

        window.makeKeyAndVisible()
        // ===== 搬过来的代码到此结束 =====

        // 冷启动时如果是被 URL / Universal Link 拉起来的，参数会放在 connectionOptions 里。
        // 特别注意：采用 scene 之后 AppDelegate 的 launchOptions 是空的，取不到这些值，
        // 所以这里必须补上，否则「从浏览器点链接打开 App」这种冷启动场景会丢参数。
        for urlContext in connectionOptions.urlContexts {
            handle(url: urlContext.url)
        }
        for userActivity in connectionOptions.userActivities {
            handle(userActivity: userActivity)
        }
    }

    // MARK: - 前后台回调

    /// App 进入前台（激活）时调用，对应原来的 applicationDidBecomeActive
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 逻辑本身还留在 AppDelegate+PPTool.swift 里，这里通过 delegate 转调一下，避免同一份代码写两遍。
        // 这样 Catalyst 那边监听 NSApplicationDidBecomeActiveNotification 的入口也照旧能用
        (UIApplication.shared.delegate as? AppDelegate)?.appDidBecomeActiveAction()
    }

    // 说明：sceneWillResignActive / sceneDidEnterBackground / sceneWillEnterForeground
    // 原来对应的 AppDelegate 方法里是空的，没有任何逻辑，所以这里就不写空实现了。

    // MARK: - 外部跳转

    /// 有新的 URL 要打开（App 已在运行，热启动），对应原来的 application(_:open:options:)。
    /// 注意两点不同：返回值变成了 void，而且一次可能传进来多个 URL
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            handle(url: urlContext.url)
        }
    }

    /// 有新的 Universal Link（App 已在运行，热启动），
    /// 对应原来的 application(_:continue:restorationHandler:)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = handle(userActivity: userActivity)
    }

    // MARK: - 跳转的统一处理

    /// 处理自定义 URL Scheme 的跳转，例如：
    ///   wx37af47629351b5c0://...  微信登录 / 分享回调
    ///   msredirect://、baiduwangpan://  OneDrive、百度网盘授权回调
    /// 冷启动和热启动两个入口都会走到这里，保证行为一致
    private func handle(url: URL) {
        if url.host == "oauth-callback" {
            // 支付跳转支付宝钱包进行支付，处理支付结果
            // 授权跳转支付宝钱包进行支付，处理支付结果
        }
        else if url.host == "msredirect" || url.host == "baiduwangpan" {
            PPAddCloudServiceViewController.handleCloudServiceRedirect(url)
        }
        else {
            _ = MonkeyKing.handleOpenURL(url)
        }
    }

    /// 处理 Universal Link。逻辑与原 AppDelegate 里的实现保持一致，只是搬了家
    ///
    /// Associated Domains Entitlement配置:applinks:p.agolddata.com
    /// 个人开发者账户不支持Associated Domains capability，所以暂时不加此功能！
    /// 测试链接 ： https://p.agolddata.com/pandanote
    @discardableResult
    private func handle(userActivity: NSUserActivity) -> Bool {
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
