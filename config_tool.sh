COMMAND="${1-}"
if [ "$COMMAND" = "overwrite_pods" ]; then
	echo "overwrite_pods_code 覆盖Pods代码"
	# cp -vf ./PPDoc/Pods_modified/libxmlHTMLNode.swift ./Pods/Kanna/Sources/Kanna/libxmlHTMLNode.swift
	cp -vf ./PPDoc/Pods_modified/DownDebugLayoutManager.swift ./Pods/Down/Sources/Down/AST/Styling/Layout\ Managers/DownDebugLayoutManager.swift
elif [ "$COMMAND" = "update_build_version" ]; then
	echo "update_build_version"
else
  echo "未获取到参数，你可以这样运行 sh config_tool.sh your_command"
fi