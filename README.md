# 一个iOS markdown笔记应用

## 预览

右侧网页预览可关闭

![preview](https://s2.loli.net/2022/03/15/zMlfrHWapvC1n84.gif)



市面上有那么多markdown笔记，为什么还要做一个？

一部分原因是自己想用Swift练手，另一部分原因是市面上的笔记要么付费，要么没法满足我的需求，比如锤子便签同步功能却经常出现错误（文件重复），Bear熊掌记觉得不值得花钱，且只支持iCloud，无法同步到安卓、Windows、Mac设备。

因为坚果云有文件历史版本功能，所以想基于坚果云的WebDAV服务做个简易的笔记App。

由于本人是重度拖延症，所以进度缓慢，欢迎提出自己的建议和反馈，项目会龟速完善。

## 功能

可使用坚果云等网盘实现云同步，所有文件保存在第三方服务器

**设备兼容性：**

iOS 10.0+、macOS（初步支持，使用了Mac Catalyst）

**已支持的网盘（协议）**：

- [x] WebDAV（坚果云等）
- [x] iCloud Documents
- [x] 阿里云盘
- [x] 群晖 Synology NAS
- [x] Alist
- [x] Dropbox
- [x] OneDrive
- [x] 百度网盘

**支持的markdown相关功能**：

- [x] markdown 原生渲染（待优化）
- [x] markdown 使用 [marked.js](https://github.com/markedjs/marked) 渲染、目录生成、代码高亮、导出成PDF
- [x] markdown 等纯文本的新建、编辑、保存
- [ ] 公众号等网页文章一键保存为markdown

**其他功能**：

- [x] 支持预览mp3、mp4、pdf
- [x] WebDAV HTTP响应和下载的文件缓存到磁盘，无网状态也可以查看文件
- [x] 文件移动、删除、重命名、新建文件夹
- [x] 上传相册原始图片或视频到指定目录
- [x] 图片预览、原图和Gif（微信表情）分享到微信
- [ ] 读取剪切板查看淘宝京东价格曲线
- [x] 抖音视频无水印下载，微博等视频解析下载




## 编译及运行

项目基于最新Xcode13构建

```bash
#克隆仓库到本地
git clone https://github.com/Panway/PandaNote.git
#进入文件夹
cd PandaNote
#安装依赖
pod install
#打开工程
open PandaNote.xcworkspace
```


## 说明

坚果云用户可在[安全选项](https://www.jianguoyun.com/#/safety)里添加应用并获取应用密码，密码是独立的，可以随时撤销，自己也可以定时修改保证账号安全


## 解析markdown相关

apple出品的 Markdown 解析器 https://github.com/apple/swift-markdown

利用 Apple 的 Markdown 解析器输出 NSAttributedString https://github.com/christianselig/Markdownosaur

AFNetworking作者的： https://github.com/mattt/CommonMarkAttributedString

Cmark的Swift封装：https://github.com/iwasrobbed/Down

markdown与AttributeString互转： https://github.com/chockenberry/MarkdownAttributedString.git

1200+star https://github.com/mdiep/MMMarkdown

1300+star https://github.com/SimonFairbairn/SwiftyMarkdown

577star https://github.com/bmoliveira/MarkdownKit

77star https://github.com/calebkleveter/SwiftMark

将 HTML 字符串转换为 NSAttributedString https://github.com/ZhgChgLi/ZMarkupParser

MWeb作者使用的：

https://github.com/hoedown/hoedown

https://github.com/ali-rantakari/peg-markdown-highlight

[写一个 markdown 解析器，用什么方式比较好呢？](https://www.v2ex.com/t/682051)

Java 解析 https://github.com/vsch/flexmark-java

[CherryMarkdown](https://mp.weixin.qq.com/s/T8-zbxI2eeMM4vSgt8dk3w)- 腾讯开源的更友好的编辑器前端组件

[bytemd](https://github.com/bytedance/bytemd) - 字节跳动开源的前端markdown编辑器

[Runestone](https://github.com/simonbs/Runestone) - iOS 原生高性能纯文本编辑器，包括语法高亮、行号

https://github.com/Milkdown/milkdown  https://milkdown.dev/zh-hans/playground