# 一个iOS markdown笔记应用

## Why ？

锤子便签还凑合，但是同步功能却经常出现错误（文件容易重复），好用的Bear熊掌记觉得不值得买，且只支持iCloud，无法同步到安卓、Windows、Mac设备。
因为坚果云有文件历史版本功能，所以想基于坚果云的WebDAV服务做个简易笔记App

## What ？

主要用来写 markdown 笔记，可使用坚果云等网盘实现云同步，所有文件保存在第三方服务器

**设备兼容性：**

iOS、macOS（初步支持，使用了Mac Catalyst）

**已支持的网盘（协议）**：

- [x] WebDAV（坚果云或自己搭建WebDAV服务）
- [x] Dropbox
- [x] 百度网盘

**已支持的文本编辑功能**：

- [x] markdown 原生渲染（待优化）
- [x] markdown 使用 [marked.js](https://github.com/markedjs/marked) 渲染、目录生成、代码高亮
- [x] markdown 等纯文本的新建、编辑、保存

**其他功能**：

- [x] 支持预览mp3、mp4、pdf
- [x] WebDAV HTTP响应和下载的文件缓存到磁盘，无网状态也可以查看文件
- [x] 文件移动、删除、重命名、新建文件夹
- [x] 上传相册原始图片到指定目录
- [x] 图片预览、原图和Gif（微信表情）分享到微信
- [ ] 读取剪切板查看淘宝京东价格曲线
- [x] 抖音视频无水印下载，微博等视频解析下载

##  How ？

坚果云用户可在[安全选项](https://www.jianguoyun.com/#/safety)里添加应用并获取应用密码，密码是独立的，可以随时撤销，自己也可以定时修改保证账号安全

### Build and Run

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

# 预览

![preview](https://i.loli.net/2019/09/03/ClPQ842ZIzpXUrc.gif)



# 解析markdown相关资源

AFNetworking作者的： https://github.com/mattt/CommonMarkAttributedString

Cmark的Swift封装：https://github.com/iwasrobbed/Down

markdown与AttributeString互转： https://github.com/chockenberry/MarkdownAttributedString.git

1200+star https://github.com/mdiep/MMMarkdown

1300+star https://github.com/SimonFairbairn/SwiftyMarkdown

577star https://github.com/bmoliveira/MarkdownKit

77star https://github.com/calebkleveter/SwiftMark

MWeb作者使用的：

https://github.com/hoedown/hoedown

https://github.com/ali-rantakari/peg-markdown-highlight

[写一个 markdown 解析器，用什么方式比较好呢？](https://www.v2ex.com/t/682051)

Java 解析 https://github.com/vsch/flexmark-java