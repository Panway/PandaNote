# Dropbox

```bash
#ES 文件浏览器的授权URL，state每次都会改变
https://www.dropbox.com/oauth2/authorize?response_type=token&client_id=7ydzyghbedham3v&redirect_uri=db-7ydzyghbedham3v://2/token&disable_signup=true&force_reauthentication=false&locale=zh-Hans&state=6658A66B-200D-41CC-81DB-D427F4644ADF-9892-000007E00B5A7147

https://www.dropbox.com/oauth2/authorize?response_type=token&client_id=7ydzyghbedham3v&redirect_uri=db-7ydzyghbedham3v://2/token&disable_signup=true&force_reauthentication=false&locale=zh-Hans&state=2E107647-FD2B-44FF-A9DB-AE0771AC333C-7182-000005F948983BB9

```

# 百度云

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
http://www.estrongs.com/#expires_in=2592000&access_token=XXXXX&session_secret=&session_key=&scope=basic+netdisk&state=STATE

```

## 获取文件列表

请求根目录：

https://pan.baidu.com/rest/2.0/xpan/file?access_token=XXXXX&desc=1&dir=/&limit=200&method=list&order=time&start=0

每次变化的参数只有dir=XXXX

```
//ES的请求头如下：

GET /rest/2.0/xpan/file?access_token=XXX&desc=1&dir=/2019&limit=200&method=list&order=time&start=0&web=web HTTP/1.1
Host: pan.baidu.com
Accept: */*
Accept-Language: zh-Hans-CN;q=1, en-CN;q=0.9
Connection: keep-alive
Accept-Encoding: gzip, deflate, br
User-Agent: pan.baidu.com
```



响应json格式：

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
		"oper_id": 3372798398,
		"fs_id": 409855000047929
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
		"fs_id": 1142488526
	}],
	"request_id": 8135131500004482788,
	"guid": 0
}
```

## 获取文件下载链接

https://pan.baidu.com/rest/2.0/xpan/multimedia

GET请求参数：

```swift
["access_token": access_token,
        "dlink": "1",
        "extra": "1",
        "fsids": "["+fs_id+"]",
        "method": "filemetas"]
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
		"fs_id": 75944XXXX73868,
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

