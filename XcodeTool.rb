# 使用方法：cd到脚本所在目录，终端运行`ruby XcodeTool.rb`

require 'xcodeproj'

# your_target是你的工程Target名字（每个项目都不一样，请按需修改）
def fix_deployment_target(your_target)
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
                if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
                    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
                end
            end
            if config.name == 'Debug'
                if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
                    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
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

# 消除Update to recommended settings警告 isAllPods是true的话修改所有工程（Podfile设置了generate_multiple_pod_projects: true的话）
def disableRecommendedIssue(your_target,isAllPods)
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
        puts "=========="
        puts file_name
        project = Xcodeproj::Project.open(file_name)
        #真不容易啊，在这个地方搜“PBXProject”才知道是root_object https://www.rubydoc.info/gems/xcodeproj/Xcodeproj/Project
        puts project.root_object.attributes.inspect
        # number = project.root_object.attributes["LastUpgradeCheck"].to_i#Integer("123")也行
        # number = number + 10
        # numberStr = number.to_s
        # nnn = Integer("123")
        # puts numberStr
        project.root_object.attributes["LastUpgradeCheck"] = "1200" #前面想着加10，结果不行，那直接1200吧
        project.save
    end

end

disableRecommendedIssue("PandaNote",true)








