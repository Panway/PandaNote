#启动 CDN 支持，以避免在本地机器或 CI 系统上克隆 master specs repo，让使用 CocoaPods 更加方便
#source 'https://cdn.jsdelivr.net/cocoa/'
source 'https://cdn.cocoapods.org/'
# Uncomment the next line to define a global platform for your project
platform :ios, 10.0
#禁止所有来自CocoaPods的警告
inhibit_all_warnings!

install! 'cocoapods',
#生成多个 Xcodeproj
generate_multiple_pod_projects: true,
#增量安装
incremental_installation: true

target 'PandaNote' do
  # Comment the next line if you don't want to use dynamic frameworks
  # 告诉 CocoaPods 你想要使用frameworks而不是静态库。因为 Swift 不支持静态库，所以你必须使用frameworks
  use_frameworks!

  # Pods for PandaNote
  
  # 最新文档 https://github.com/Alamofire/Alamofire/blob/master/Documentation/Usage.md
  # 4.9版本文档 https://github.com/Alamofire/Alamofire/blob/4.9.1/Documentation/Usage.md
  pod 'Alamofire','~> 5.0'
#  https://github.com/onevcat/Kingfisher
  pod 'Kingfisher','~> 6.3.1'
  pod 'PINOperation', '~> 1.2.1'
  pod 'PINCache'
  # https://github.com/amosavian/FileProvider
  pod 'FilesProvider'
  #布局 https://github.com/SnapKit/SnapKit
  pod 'SnapKit'
  # https://github.com/johnxnguyen/Down
  pod 'Down'
  pod 'Highlightr'
#  pod 'ZMarkupParser'
#  pod 'DoraemonKit/Core'
  # https://github.com/Flipboard/FLEX
  pod 'FLEX', :configurations => ['Debug']
  pod 'MJRefresh'
  #  pod 'YYText'
  #美图公司的富文本组件 https://github.com/meitu/MPITextKit
  pod 'MPITextKit'
#  https://github.com/suzuki-0000/SKPhotoBrowser
  pod 'SKPhotoBrowser'
  #https://github.com/Yummypets/YPImagePicker
  #  pod 'YPImagePicker'
  # https://github.com/Flipboard/FLAnimatedImage
  pod 'FLAnimatedImage'
  pod 'TZImagePickerController'
  #https://github.com/SwipeCellKit/SwipeCellKit
  #https://github.com/CaliCastle/PopMenu
  pod 'NewPopMenu'
  pod 'ContextMenu' #https://github.com/GitHawkApp/ContextMenu
  pod 'BTNavigationDropdownMenu'
  pod 'DropDown'
#  pod 'FRadioPlayer'
  # If you have NOT upgraded to Xcode 11, use the last Swift Xcode 10.X compatible release
#  pod 'SwipeCellKit', '2.6.0'
  #  pod 'SVProgressHUD'
  pod 'MBProgressHUD'
#  pod 'AFWebDAVManager', :git => 'https://github.com/AFNetworking/AFWebDAVManager.git'
#  pod 'WechatOpenSDK'#,'1.8.4'
  pod 'MonkeyKing'
  pod 'FMDB'
  pod 'IQKeyboardManager'
  #滴滴开源的应用内调试工具，界面比较美观 https://github.com/didi/DoraemonKit
  #pod 'DoraemonKit/Core', '3.0.7', :configurations => ['Debug']
#  pod 'Weibo_SDK', :git => 'https://github.com/sinaweibosdk/weibo_ios_sdk.git'
  # XML解析 https://github.com/tid-kijyun/Kanna
  pod 'Kanna', '~> 5.2.2'
  # JSON解析 https://github.com/tristanhimmelman/ObjectMapper
  # 中文指南 https://github.com/SwiftOldDriver/ObjectMapper-CN-Guide
  pod 'ObjectMapper'
  # 安全加密算法 https://github.com/krzyzanowskim/CryptoSwift
  # 在这里发现的 https://github.com/topics/md5?l=swift
  pod 'CryptoSwift'
  # HTTP Server https://github.com/swisspol/GCDWebServer
  pod "GCDWebServer"
  
  #----------私有----------
  #0行代码实现右滑pop返回
  pod 'PPiOSKit/SwipePopGesture', :git=>'https://github.com/Panway/CodeSnipetCollection.git'
  #0行代码捕获常见数组字典异常，防止闪退
  pod 'PPiOSKit/CrashCatcher', :git=>'https://github.com/Panway/CodeSnipetCollection.git'
  pod 'PPiOSKit/CommomViews', :git=>'https://github.com/Panway/CodeSnipetCollection.git'
  #快捷AlertView和AlertAction (Block封装)
  pod 'PPiOSKit/PPAlertAction', :git=>'https://github.com/Panway/CodeSnipetCollection.git'
  #----------私有----------
  
  
  
  
  target 'PandaNoteTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'PandaNoteUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end





post_install do |installer|
  puts '因Personal Team账户不支持，默认关闭UniversalLink选项，如果你知道如何配置请撤销PandaNote.entitlements的改动'
  output = %x( #{"sed -i '' -e '/associated-domains/,+3d' PandaNote/PandaNote.entitlements"} )
  puts '在pod install之后执行脚本，修复警告或错误，如果出错请再执行一遍 pod install'
  output = %x( #{"ruby XcodeTool.rb fix_deployment_target 10"} ) #执行 XcodeTool.rb 脚本文件消除警告
  puts output
  #支持Mac Catalyst
#  output = %x( #{"curl https://p.agolddata.com/l/h/src/iOS/DoraemonAppInfoViewController.m -o DoraemonAppInfoViewController.m && cp -v -f DoraemonAppInfoViewController.m Pods/DoraemonKit/iOS/DoraemonKit/Src/Core/Plugin/Common/AppInfo/DoraemonAppInfoViewController.m"})
#  output = %x( #{"sh ios_tool.sh correct_import"} )# 执行shell脚本文件
  #    output = %x( #{"cp -f -R -v PodsNew/ZFPlayer Pods"} )# 执行shell脚本
  
end
