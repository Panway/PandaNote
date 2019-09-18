# 基于WebDav的iOS客户端

## Why ？

锤子便签非常好用，同步功能却经常出现错误（文件容易重复），好用的Bear熊掌记觉得不值得买，且只支持iCloud，无法同步到安卓设备。因为坚果云有文件历史版本功能，所以想基于坚果云的WebDAV服务做个简易笔记App

开始不熟悉WebDAV协议，本来是想在这个工程的基础上改的，后来发现项目太久了，实在受不了，只好新开一个Swift工程，只有少量Objc代码

## What ？

主要用来写 markdown 笔记，并实现云同步，国内可使用坚果云或自己搭建WebDAV服务，所有文件保存在第三方服务器，Dropbox、GoogleDrive暂不支持
- [ ] markdown原生渲染
- [x] markdown网页渲染
- [x] markdown编辑保存
- [ ] API请求、所有大文件缓存到磁盘
- [x] 图片预览、原图分享到微信、以微信表情分享
- [ ] 读取剪切板查看淘宝京东价格曲线

##  How ？

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