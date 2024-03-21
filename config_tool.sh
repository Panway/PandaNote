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