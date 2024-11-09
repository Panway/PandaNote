# -------------------匹配到的字符串所在的一整行全换成参数2-------------------
# 第一个参数是要被换掉的字符串
# 第二个参数是在要插入的字符串
# 第三个参数是文件路径
# 使用方法：replaceWholeLineOfPattern "before" "after" PPJava.md
# 使用方法2：replaceWholeLineOfPattern 'before' 'after' 'PPJava.md'
# Tips:单引号''里面需要转义的字符集有[/]
# Tips:双引号"" 里面需要转义的字符集有:[/"]
replaceWholeLineOfPattern() {
  echo "文件 [$3] 的<$1>所在行被更换为<$2>"
  # sed -i "" "s/.*$1.*/$2/" PPJava.md
  sed -i "" "s/.*$1.*/$2/" $3
}



COMMAND="${1-}"
if [ "$COMMAND" = "overwrite_pods" ]; then
	echo "overwrite_pods_code 覆盖Pods代码"
	cp -vf ./PPDoc/Pods_modified/libxmlHTMLNode.swift ./Pods/Kanna/Sources/Kanna/libxmlHTMLNode.swift
	cp -vf ./PPDoc/Pods_modified/DownDebugLayoutManager.swift ./Pods/Down/Sources/Down/AST/Styling/Layout\ Managers/DownDebugLayoutManager.swift
elif [ "$COMMAND" = "update_build_version" ]; then
	echo "update_build_version"
elif [ "$COMMAND" = "modify_pods_code" ]; then
	sed -i "" 's/cell.model = model;$/cell.model = model;NSString *text = [NSString stringWithFormat:@"%@（%@）",_tzImagePickerVc.fullImageBtnTitleStr,model.asset.creationDate.description];[_originalPhotoButton setTitle:text forState:UIControlStateNormal];[_originalPhotoButton sizeToFit];\/\/图片选择器增加图片创建时间显示/' ./Pods/TZImagePickerController/TZImagePickerController/TZImagePickerController/TZPhotoPreviewController.m
	sed -i "" 's/internal var isViewRotating = false/public var isViewRotating = false/' ./Pods/XLPagerTabStrip/Sources/PagerTabStripViewController.swift
	sed -i "" 's/internal var isViewAppearing = false/public var isViewAppearing = false/' ./Pods/XLPagerTabStrip/Sources/PagerTabStripViewController.swift
	sed -i "" 's/internal var selectedBarHeight/public var selectedBarHeight/' ./Pods/XLPagerTabStrip/Sources/ButtonBarView.swift
	sed -i "" 's/var selectedBarVerticalAlignment/public var  selectedBarVerticalAlignment/' ./Pods/XLPagerTabStrip/Sources/ButtonBarView.swift
else
  echo "未获取到参数，你可以这样运行 sh config_tool.sh your_command"
fi