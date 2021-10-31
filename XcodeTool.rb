# 使用方法：cd到脚本所在目录，终端运行`ruby XcodeTool.rb`

require 'xcodeproj'
# 消除第三方库 deployment target警告,比如这样的:The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 8.0, but the range of supported deployment target versions is 9.0 to 14.2.99.
# your_target是你的工程Target名字（每个项目都不一样，请按需修改）
# 还可以消除 Command CompileSwiftSources failed with a nonzero exit code 错误
# min_surpport_version是你的项目支持的最低版本
def fix_deployment_target(your_target,min_surpport_version)
    project_name = your_target
    full_proj_path = Dir.pwd #当前目录，比如/Users/xxx/Documents/Project/iOS/PandaNote
    full_proj_path = full_proj_path + "/Pods/*.xcodeproj"
    puts full_proj_path
    all_file = Dir[full_proj_path]
    puts "==========="
    # puts all_file
    all_file.each do |file_name|
        puts file_name
        project = Xcodeproj::Project.open(file_name)
        project.targets.each do |target|
            target.build_configurations.each do |config|
            puts target.name
            # puts "config.name is #{config.name}"
            if config.name == 'Release'
                if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < min_surpport_version.to_f
                    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = min_surpport_version
                end
            end
            if config.name == 'Debug'
                if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < min_surpport_version.to_f
                    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = min_surpport_version
                end
            end

                
            end
        end
        project.save
    end

end

# 禁止该死的Documentation Issue
def disableDocumentationIssue(your_target,isAllPods)
    puts isAllPods.class
    project_name = your_target
    full_proj_path = Dir.pwd #当前目录，比如/Users/xxx/Documents/Project/iOS/PandaNote
    if isAllPods
        full_proj_path = full_proj_path + "/Pods/*.xcodeproj"
    else
        full_proj_path = full_proj_path + "/Pods/Pods.xcodeproj"
    end
    puts full_proj_path
    all_file = Dir[full_proj_path]
    all_file.each do |file_name|
        puts file_name
        project = Xcodeproj::Project.open(file_name)
        project.targets.each do |target|
        puts "==="
            puts target.inspect
            target.build_configurations.each do |config|
                config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
            end
        end
        project.save
    end

end
# 方式是先修改众多警告的一个，然后修改一个警告，看看sourceTree里面的`project.pbxproj`文件到底是哪一行有改动，然后用我这个脚本用到的xcodeproj工具修改
# 消除Update to recommended settings警告 isAllPods是true的话修改所有工程（Podfile设置了generate_multiple_pod_projects: true的话）
# LastUpgradeVersion是此文件里面的值（PandaNote是我的工程名）：PandaNote.xcodeproj/xcshareddata/xcschemes/PandaNote.xcscheme
def disableRecommendedIssue(your_target,isAllPods,lastUpgradeVersion)
    puts isAllPods.class
    project_name = your_target
    full_proj_path = Dir.pwd #当前目录，比如/Users/xxx/Documents/Project/iOS/PandaNote
    if isAllPods
        full_proj_path = full_proj_path + "/Pods/*.xcodeproj"
    else
        full_proj_path = full_proj_path + "/Pods/Pods.xcodeproj"#单个工程
    end
    puts full_proj_path
    all_file = Dir[full_proj_path]
    all_file.each do |file_name|
        puts "开始修改"
        puts file_name
        project = Xcodeproj::Project.open(file_name)
        #真不容易啊，在这个地方搜“PBXProject”才知道是root_object https://www.rubydoc.info/gems/xcodeproj/Xcodeproj/Project
        puts project.root_object.attributes.inspect
        # number = project.root_object.attributes["LastUpgradeCheck"].to_i#Integer("123")也行
        # number = number + 10
        # numberStr = number.to_s
        # nnn = Integer("123")
        # puts numberStr
        project.root_object.attributes["LastUpgradeCheck"] = lastUpgradeVersion
        project.save
    end

end

# 下面一行解注释会消除Update to recommended settings警告
# disableRecommendedIssue("PandaNote",true,"1230")

# fix_deployment_target("PandaNote","10.0")







