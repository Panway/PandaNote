# 基于WebDAV的iOS客户端

## Why ？

锤子便签还凑合，但是同步功能却经常出现错误（文件容易重复），好用的Bear熊掌记觉得不值得买，且只支持iCloud，无法同步到安卓、Windows、Mac设备。
因为坚果云有文件历史版本功能，所以想基于坚果云的WebDAV服务做个简易笔记App

## What ？

主要用来写 markdown 笔记，并实现云同步，国内可使用坚果云或自己搭建WebDAV服务，所有文件保存在第三方服务器，Dropbox、GoogleDrive暂不支持
- [ ] markdown 原生渲染
- [x] markdown 网页js渲染、查看目录
- [x] markdown 等纯文本的新建、编辑、保存、删除
- [x] 支持预览mp3、mp4、pdf
- [x] WebDAV HTTP响应和下载的文件缓存到磁盘，无网状态也可以查看文件
- [x] 文件重命名
- [x] 上传相册原始图片到指定目录
- [x] 图片预览、原图分享到微信、以微信表情分享
- [ ] 读取剪切板查看淘宝京东价格曲线
- [x] 微博等视频解析下载

##  How ？

坚果云用户可在[安全选项](https://www.jianguoyun.com/#/safety)里添加应用并获取应用密码，密码是独立的，可以随时撤销，自己也可以定时修改保证账号安全

### Build and Run

```bash
git clone https://github.com/Panway/PandaNote.git

cd PandaNote
#安装依赖
pod install
#打开
open PandaNote.xcworkspace
```

# 预览

![preview](https://i.loli.net/2019/09/03/ClPQ842ZIzpXUrc.gif)



# markdown渲染相关

AFNetworking作者的： https://github.com/mattt/CommonMarkAttributedString

Cmark的Swift封装：https://github.com/iwasrobbed/Down

markdown与AttributeString互转： https://github.com/chockenberry/MarkdownAttributedString.git