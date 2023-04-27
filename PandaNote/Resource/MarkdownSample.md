[TOC]

这是一个markdown示例

# 一级标题

## 二级标题

### 三级标题

# 文字引用

使用 > 表示文字引用。示例：

《采薇》

> 昔我往矣，杨柳依依。
>
> 今我来思，雨雪霏霏。
>
> 行道迟迟，载渴载饥。
>
> 我心伤悲，莫知我哀！
>

【译文】

昔日从军上战场，杨柳依依好春光。今日归来路途上，大雪纷纷满天扬。道路泥泞走得慢，又渴又饥苦难当。我心伤感悲满腔，谁人知我痛断肠。

# 字体

这是一个**加粗Bold**字体, 这是*斜体Italic*.

# 链接

[iOS 性能优化：优化 App 启动速度](https://mp.weixin.qq.com/s/h3vB_zEJBAHCfGmD5EkMcw)

# 列表


无序列表：
- 番茄
- 土豆
- 鸡肉


有序列表

1. 开发
2. 测试
3. 上线

# 代码块

``` c
// 快速排序，A 是数组，n 表示数组的大小
quick_sort(A, n) {
  quick_sort_c(A, 0, n-1)
}
// 快速排序递归函数，p,r 为下标
quick_sort_c(A, p, r) {
  if p >= r then return
  q = partition(A, p, r) // 获取分区点
  quick_sort_c(A, p, q-1)
  quick_sort_c(A, q+1, r)
}
```

使用 `代码` 表示行内代码块。示例：

让我们聊聊 `html`。



# 表格

| 时间复杂度    | 数组 | 链表   |
| ---- | ---- | ---- |
|  插入、删除  |  O(n)  |  O(1)  |
|  随机访问（取第几个值）  |  O(1)  |  O(n)  |





# 图片

使用` ![描述](图片链接地址) `插入图像。示例：

小图

![Mou icon](https://img.t.sinajs.cn/t4/appstyle/expression/ext/normal/b3/hot_wosuanle_thumb.png)

![qq](https://gxh.vip.qq.com/xydata/face/item/3965/medium.png)



大图

![big image](https://is5-ssl.mzstatic.com/image/thumb/Purple113/v4/54/ea/47/54ea470d-f7e1-6ec7-1f60-4e9159c68639/mzl.kuqyraac.png/690x0w.jpg)


# 其他

[YouTube视频](https://youtu.be/pFnSLVABk-8)
