# Dropbox

```bash
#ES 文件浏览器的授权URL，state每次都会改变
https://www.dropbox.com/oauth2/authorize?response_type=token&client_id=7ydzyghbedham3v&redirect_uri=db-7ydzyghbedham3v://2/token&disable_signup=true&force_reauthentication=false&locale=zh-Hans&state=6658A66B-200D-41CC-81DB-D427F4644ADF-9892-000007E00B5A7147

https://www.dropbox.com/oauth2/authorize?response_type=token&client_id=7ydzyghbedham3v&redirect_uri=db-7ydzyghbedham3v://2/token&disable_signup=true&force_reauthentication=false&locale=zh-Hans&state=2E107647-FD2B-44FF-A9DB-AE0771AC333C-7182-000005F948983BB9

```

# 百度云

GET请求头示范：

```
Host: pan.baidu.com
Accept: */*
Accept-Language: zh-Hans-CN;q=1, en-CN;q=0.9
Connection: keep-alive
Accept-Encoding: gzip, deflate, br
User-Agent: pan.baidu.com
```

POST请求头示范：

```
Host: pan.baidu.com
Content-Type: application/x-www-form-urlencoded
Connection: keep-alive
Accept: */*
User-Agent: pan.baidu.com
Accept-Language: zh-Hans-CN;q=1, en-CN;q=0.9
Content-Length: 60
Accept-Encoding: gzip, deflate, br
```



## 授权登录

```bash
#1 打开URL
https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=NqOMXF6XGhGRIGemsQ9nG0Na&redirect_uri=http://www.estrongs.com&scope=basic,netdisk&display=mobile&state=STATE&force_login=1

# 2 重定向，跳转到带了token的URL，我们就可以拿到token了
#没用
https://openapi.baidu.com/static/oauth/html/bdstoken_jump.html?error_code=0&bdstoken=XXXXX
#没用
https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=NqOMXF6XGhGRIGemsQ9nG0Na&redirect_uri=http://www.estrongs.com&scope=basic,netdisk&display=mobile&state=STATE&force_login=1

#有用
http://www.estrongs.com/#expires_in=2592000&access_token=666666&session_secret=&session_key=&scope=basic+netdisk&state=STATE

```

## 获取文件列表

请求：

```bash
# 方法
GET
# URL（每次变化的参数只有dir=XXXX，eg：/2019）
# 请求根目录用/
https://pan.baidu.com/rest/2.0/xpan/file?access_token=666666&desc=1&dir=/2019&limit=200&method=list&order=time&start=0&web=web HTTP/1.1
```

响应json示例：

```json
{
	"errno": 0,
	"guid_info": "",
	"list": [{
		"server_mtime": 1605277800,
		"privacy": 0,
		"category": 6,
		"unlist": 0,
		"isdir": 1,
		"server_atime": 0,
		"server_ctime": 1605277800,
		"wpfile": 0,
		"local_mtime": 1605277800,
		"size": 0,
		"share": 0,
		"server_filename": "2020",
		"path": "\/2020",
		"local_ctime": 1605277800,
		"oper_id": 3370000398,
		"fs_id": 409800000047929
	}, {
		"server_mtime": 1340110930,
		"privacy": 0,
		"category": 6,
		"unlist": 0,
		"isdir": 1,
		"server_atime": 0,
		"server_ctime": 1340110930,
		"wpfile": 0,
		"local_mtime": 1340110930,
		"size": 0,
		"share": 0,
		"server_filename": "XXX",
		"path": "\/AAA",
		"local_ctime": 1340110930,
		"oper_id": 0,
		"fs_id": 114008526
	}],
	"request_id": 8135130000004482788,
	"guid": 0
}
```

## 获取文件下载链接

GET请求参数：

```bash
# URL
https://pan.baidu.com/rest/2.0/xpan/multimedia?access_token=666666&dlink=1&extra=1&fsids=%5B715872000045900%5D&method=filemetas
```

响应JSON：

```json
{
	"errmsg": "succ",
	"errno": 0,
	"list": [{
		"category": 4,
		"dlink": "https://d.pcs.baidu.com/file/xxx",
		"filename": "xxx.doc",
		"fs_id": 75944000073868,
		"isdir": 0,
		"md5": "66bbd21bac49e60c7e6266d395d8a99e",
		"oper_id": 0,
		"path": "/Music/Taylor/xxx.mp3",
		"server_ctime": 1428664537,
		"server_mtime": 1468224187,
		"size": 267776
	}],
	"names": {},
	"request_id": "908276XXX876447"
}
```

`dlink`就是需要的链接

## 新建文件夹

方法：POST 

类型：'Content-Type: application/x-www-form-urlencoded'

path：/rest/2.0/xpan/file?access_token=666666&method=create

请求参数：

```bash
isdir=1&path=/2021/NewFolder/0322&rtype=1&size=0
```

响应JSON：

```json
{
	"fs_id": 179000000000949,
	"path": "\/2021\/NewFolder\/0322",
	"ctime": 1616379777,
	"mtime": 1616379777,
	"status": 0,
	"isdir": 1,
	"errno": 0,
	"name": "\/2021\/NewFolder\/0322",
	"category": 6
}
```

## 删除文件

POST /rest/2.0/xpan/file?access_token=666666&method=filemanager&opera=delete

参数：

```
async=0&filelist=%5B%22%5C/2021%5C/Useless%5C/old.html%22%5D
转义后：
async=0&filelist=["\/2021\/Useless\/old.html"]
```

响应：

```json
{
	"errno": 0,
	"info": [{
		"errno": 0,
		"path": "\/2021\/Useless\/old.html"
	}],
	"request_id": 8783700000000006305
}
```



## precreate文件

请求

```bash
# 方法
POST

# URL
https://pan.baidu.com/rest/2.0/xpan/file?access_token=666666&method=precreate

# 参数（block_list里面的是文件md5值）
autoinit=1&block_list=["CDCA17BBA978856EB06CDF983DF7F56A"]&isdir=0&path=/apps/ES文件浏览器/2019-05-27 23.26.24.GIF&rtype=1&size=243582

# Percent Encoding后的参数：
autoinit=1&block_list=%5B%22CDCA17BBA978856EB06CDF983DF7F56A%22%5D&isdir=0&path=/apps/ES%E6%96%87%E4%BB%B6%E6%B5%8F%E8%A7%88%E5%99%A8/2019-05-27%2023.26.24.GIF&rtype=1&size=243582
```

响应

```json
{
	"path": "\/apps\/ES\u6587\u4ef6\u6d4f\u89c8\u5668\/2019-05-27 23.26.24.GIF",
	"uploadid": "N1-MTAxLjg0LjQ1LjE0NToxNjE2MzkxMTgyOjg3ODYwNDk4NjI1MzIzOTU3MjY=",
	"return_type": 1,
	"block_list": [],
	"errno": 0,
	"request_id": 8786049800000395726
}
```

## 上传二进制文件

请求

```bash
# 方法
POST

# URL(注意这里域名是d.pcs.baidu.com，URL需要Percent Encoding)
https://d.pcs.baidu.com/rest/2.0/pcs/superfile2?access_token=666666&method=upload&partseq=0&path=/apps/ES%E6%96%87%E4%BB%B6%E6%B5%8F%E8%A7%88%E5%99%A8/2019-05-27%2023.26.24.GIF&type=tmpfile&uploadid=N1-MTAxLjg0LjQ1LjE0NToxNjE2MzkxMTgyOjg3ODYwNDk4NjI1MzIzOTU3MjY%3D

# 参数（表单文件字段）：
file

# Tips：解析后的URL：
access_token=666666&method=upload&partseq=0&path=/apps/ES文件浏览器/2019-05-27 23.26.24.GIF&type=tmpfile&uploadid=N1-MTAxLjg0LjQ1LjE0NToxNjE2MzkxMTgyOjg3ODYwNDk4NjI1MzIzOTU3MjY=
```

响应

```json
{
	"md5": "cdca17bba978856eb06cdf983df7f56a",
	"request_id": 1868521000000317587
}
```



## 创建文件

```bash
POST

# URL
https://pan.baidu.com/rest/2.0/xpan/file?access_token=666666&method=create

# 参数，block_list是上传二进制接口返回的文件md5值
block_list=["cdca17bba978856eb06cdf983df7f56a"]&isdir=0&path=/apps/ES文件浏览器/2019-05-27 23.26.24.GIF&rtype=1&size=243582&uploadid=N1-MTAxLjg0LjQ1LjE0NToxNjE2MzkxMTgyOjg3ODYwNDk4NjI1MzIzOTU3MjY=

# Percent Encoding后的参数
block_list=%5B%22cdca17bba978856eb06cdf983df7f56a%22%5D&isdir=0&path=/apps/ES%E6%96%87%E4%BB%B6%E6%B5%8F%E8%A7%88%E5%99%A8/2019-05-27%2023.26.24.GIF&rtype=1&size=243582&uploadid=N1-MTAxLjg0LjQ1LjE0NToxNjE2MzkxMTgyOjg3ODYwNDk4NjI1MzIzOTU3MjY%3D

```

响应：

```json
{
	"category": 3,
	"ctime": 1616391185,
	"fs_id": 245570000015240,
	"isdir": 0,
	"md5": "a85bc0094k61da543cd4b00d39c71277",
	"mtime": 1616391185,
	"path": "\/apps\/ES\u6587\u4ef6\u6d4f\u89c8\u5668\/2019-05-27 23.26.24.GIF",
	"server_filename": "2019-05-27 23.26.24.GIF",
	"size": 243582,
	"errno": 0,
	"name": "\/apps\/ES\u6587\u4ef6\u6d4f\u89c8\u5668\/2019-05-27 23.26.24.GIF"
}
```



## 移动文件

请求

```bash
# 方法
POST

# URL
https://pan.baidu.com/rest/2.0/xpan/file?access_token=666666&method=filemanager&opera=move

# 参数
async=0&filelist=[{"path":"\/apps\/ES文件浏览器\/2019-05-27 23.26.24.GIF","dest":"\/2021\/NewFolder","newname":"2019-05-27 23.26.24.GIF","ondup":"newcopy"}]

# Percent Encoding后的参数：
async=0&filelist=%5B%7B%22path%22%3A%22%5C/apps%5C/ES%E6%96%87%E4%BB%B6%E6%B5%8F%E8%A7%88%E5%99%A8%5C/2019-05-27%2023.26.24.GIF%22%2C%22dest%22%3A%22%5C/2021%5C/NewFolder%22%2C%22newname%22%3A%222019-05-27%2023.26.24.GIF%22%2C%22ondup%22%3A%22newcopy%22%7D%5D
```

响应

```json
{
	"errno": 0,
	"info": [{
		"errno": 0,
		"path": "\/apps\/ES\u6587\u4ef6\u6d4f\u89c8\u5668\/2019-05-27 23.26.24.GIF"
	}],
	"request_id": 8786050650000084039
}
```

