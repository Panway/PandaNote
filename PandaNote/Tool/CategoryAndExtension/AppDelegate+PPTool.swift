//
//  AppDelegate+PPTool.swift
//  PandaNote
//
//  Created by topcheer on 2021/1/11.
//  Copyright © 2021 WeirdPan. All rights reserved.
//

import Foundation


extension AppDelegate {
    @objc func appDidBecomeActiveAction() {
        //App进入前台就开始解析剪贴板内容
        PPPasteboardTool.getMoreInfomationOfURL()

    }
    
    func debugSetting() {
//        FLEXManager.shared.showExplorer()
//        DoraemonManager.shareInstance().install()
        #if os(iOS)
        
        #if targetEnvironment(macCatalyst)
        //        debugPrint( "macOS(Catalyst)")
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
        #else
        //        debugPrint( "iOS")
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
        
        #elseif os(watchOS)
        debugPrint( "watchOS")
        #elseif os(tvOS)
        debugPrint( "tvOS")
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
        #elseif os(macOS)
        debugPrint( "纯macOS")
        #elseif os(Linux)
        debugPrint( "Linux")
        #elseif os(Windows)
        debugPrint( "Windows")
        #else
        debugPrint( "Unknown")
        #endif
    }
}
