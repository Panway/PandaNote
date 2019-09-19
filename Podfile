#启动 CDN 支持，以避免在本地机器或 CI 系统上克隆 master specs repo，让使用 CocoaPods 更加方便
#source 'https://cdn.jsdelivr.net/cocoa/'
source 'https://cdn.cocoapods.org/'
# Uncomment the next line to define a global platform for your project
platform :ios, 9.0
#禁止所有来自CocoaPods的警告
inhibit_all_warnings!

install! 'cocoapods',
#生成多个 Xcodeproj
generate_multiple_pod_projects: true,
#增量安装
incremental_installation: true

target 'PandaNote' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PandaNote
  pod 'Alamofire'
#  https://github.com/onevcat/Kingfisher
  pod 'Kingfisher'
  pod 'PINCache'
  # https://github.com/amosavian/FileProvider
  pod 'FilesProvider'
  pod 'SnapKit'
  pod 'Down'
#  pod 'DoraemonKit/Core'
  # https://github.com/Flipboard/FLEX
  pod 'FLEX', '~> 3.0.0', :configurations => ['Debug']
  pod 'MJRefresh'
  pod 'YYText'
#  https://github.com/suzuki-0000/SKPhotoBrowser
  pod 'SKPhotoBrowser'
  #https://github.com/Yummypets/YPImagePicker
  pod 'YPImagePicker'
  #https://github.com/SwipeCellKit/SwipeCellKit
  # If you have NOT upgraded to Xcode 11, use the last Swift Xcode 10.X compatible release
#  pod 'SwipeCellKit', '2.6.0'
  #  pod 'SVProgressHUD'
  pod 'MBProgressHUD'
#  pod 'AFWebDAVManager', :git => 'https://github.com/AFNetworking/AFWebDAVManager.git'
  pod 'WechatOpenSDK'
#  pod 'Weibo_SDK', :git => 'https://github.com/sinaweibosdk/weibo_ios_sdk.git'



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
  puts '如果自己修改了Pods源码，可以在pod install之后覆盖掉'
#  output = %x( #{"sh ios_tool.sh correct_import"} )# 执行shell脚本文件
  #    output = %x( #{"cp -f -R -v PodsNew/ZFPlayer Pods"} )# 执行shell脚本
  #    puts output
  
end
