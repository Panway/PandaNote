//
//  PPAddCloudServiceViewController.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit


class PPAddCloudServiceViewController : PPBaseViewController,UITableViewDataSource,UITableViewDelegate {
    var dataSource:Array<String> = ["WebDAV（坚果云等）",
                                    "阿里云盘",
                                    "iCloud Drive",
                                    "Dropbox",
                                    "OneDrive",
                                    "alist",
                                    "群晖Synology",
                                    "百度网盘"]
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "选择云服务类型"
        tableView = UITableView(frame: self.view.bounds,style: .grouped)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.bottom.equalToSuperview()
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPSettingCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView()
    }
    
//    @objc func injected() {
//        self.tableView.reloadData()
//    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPSettingCell
        cell.titleLB.text = self.dataSource[indexPath.row]
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let obj = self.dataSource[indexPath.row]
        PPAddCloudServiceViewController.addCloudService(obj,self)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    class func addCloudService(_ obj: String,_ sourceVC:UIViewController,_ currentConfig:[String : String]? = nil) {
        let authMethods = ["App内授权登录","系统默认浏览器授权登录","手动输入配置"]
        if obj == "WebDAV（坚果云等）" {
            //https://www.jianguoyun.com/#/safety
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = obj
            vc.serverURL = "http://dav.jianguoyun.com/dav"
#if DEBUG
            
#endif
            vc.remark = obj
            sourceVC.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "阿里云盘" || obj == "AliyunDrive" {
            PPAlertTool.showAction(title: "请选择登录方式", message: nil,
                                   items: ["App内授权登录","扫二维码登录","手动输入配置"])
            { index in
                if index == 2 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "AliyunDrive"
                    vc.remark = "阿里云盘"
                    vc.passwordDesc = "Token"
                    vc.showServerURL = false
                    vc.showUserName = false
                    vc.showPassword = false
                    vc.showToken = true
                    vc.showRefreshToken = true
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 0 {
                    let vc = PPWebViewController()
                    vc.urlString = aliyundrive_auth_url
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    PPAliyunDriveService.getQRCode { qrCodeUrl, sid in
                        debugPrint(qrCodeUrl, sid)
                        // 加载二维码让用户扫
                        let vc = PPWebViewController()
                        vc.urlString = qrCodeUrl
                        sourceVC.navigationController?.pushViewController(vc, animated: true)
                        PPAliyunDriveService.getQRCodeStatus(sid: sid) { code in
                            //用户扫描二维码并点击授权后
                            PPAddCloudServiceViewController.aliyundriveLoginWithCode(code)
                        }
                    }
                }
            }
        }
        else if obj == "iCloud Drive" || obj == PPCloudServiceType.icloud.rawValue {
            // iCloud 的登录状态跟着系统账号走，App 里没有登录入口，所以添加之前先探一下能不能用。
            // 不可用也允许继续添加：开发包没带 iCloud 权限时也能先把配置建出来，但原因必须说清楚，不然用户只会看到列表刷不出来
            PPiCloudDriveService.unavailableReason(containerId: PPAppConfig.shared.iCloudContainerId) { reason in
                if let reason = reason {
                    // 如果不可用：先说原因，再让用户自己决定要不要硬加一个暂时用不了的配置
                    PPAlertTool.showAlert(title: "iCloud Drive 暂时不可用",
                                          message: "\(reason)\n\n是否仍然添加？添加后要等 iCloud 可用，列表里才会有文件") { index in
                        if index == 0 {
                            PPAddCloudServiceViewController.pushICloudConfig(sourceVC)
                        }
                    }
                }
                else {
                    // 可用，直接进配置页
                    PPAddCloudServiceViewController.pushICloudConfig(sourceVC)
                }
            }
        }
        else if obj == "Dropbox" {
            PPAlertTool.showAction(title: "请选择登录方式", message: nil, items: authMethods) { index in
                if index == 2 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "Dropbox"
                    vc.remark = "Dropbox"
                    vc.password = ""
                    vc.showServerURL = false
                    vc.showUserName = false
                    vc.passwordRemark = "access token"
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 0 {
                    // 授权地址里带 PKCE 的 code_challenge，每次登录都要重新生成，不能存成常量反复用
                    let vc = PPWebViewController()
                    vc.urlString = PPDropboxService.makeAuthorizationURL()
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    guard let authURL = URL(string: PPDropboxService.makeAuthorizationURL()) else { return }
                    UIApplication.shared.open(authURL, options: [:], completionHandler: nil)
                }
                
            }
        }
        else if obj == "OneDrive" {
            PPAlertTool.showAction(title: "请选择登录方式", message: nil, items: authMethods) { index in

                if index == 1 {
                    let authURL = URL(string: onedrive_auth_url)
                    UIApplication.shared.open(authURL!, options: [:], completionHandler: nil)
                    // PPAddCloudServiceViewController.handleCloudServiceRedirect(URL(string: "pandanote://msredirect/?code=XXX")!)
                }
                else if index == 0 {
                    let vc = PPWebViewController()
                    vc.urlString = onedrive_login_url_es//ES的
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 2 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "OneDrive"
                    vc.remark = "OneDrive"
                    vc.password = ""
                    vc.showServerURL = false
                    vc.showUserName = false
                    vc.passwordRemark = "access token"
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                
            }
            
        }
        else if obj == "alist" {
            let vc = PPWebDAVConfigViewController()
            vc.serverURL = ""
            vc.cloudType = "alist"
            vc.remark = "alist"
            vc.password = ""
            sourceVC.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "群晖Synology" || obj == PPCloudServiceType.synology.rawValue {
            let vc = PPWebDAVConfigViewController()
            vc.isEditMode = currentConfig?["PPWebDAVUserName"] != nil
            vc.editIndex = PPUserInfo.shared.pp_lastSeverInfoIndex
            vc.serverURL = currentConfig?["PPServerURL"] ?? ""
            vc.serverURLRemark = "地址或 QuickConnect ID"
            vc.userName = currentConfig?["PPWebDAVUserName"] ?? ""
            vc.cloudType = "synology"
            vc.remark = "synology"
            vc.password = currentConfig?["PPWebDAVPassword"] ?? ""
            vc.showOtpCode = true
            vc.optCodeRemark = "双重认证码（Secure Signin应用内）"
            sourceVC.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "百度网盘" || obj == PPCloudServiceType.baiduyun.rawValue {
            PPAlertTool.showAction(title: "请选择登录方式", message: nil, items: authMethods) { index in
                if index == 2 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = PPCloudServiceType.baiduyun.rawValue
                    vc.serverURL = "https://pan.baidu.com/rest/2.0/xpan/file"
                    vc.remark = "百度网盘"
                    vc.showServerURL = false
                    vc.showUserName = false
                    vc.passwordRemark = "access token"
                    sourceVC.navigationController?.pushViewController(vc, animated: true)                }
                else if index == 0 {
                    let vc = PPWebViewController()
                    vc.urlString = baiduwangpan_auth_url
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    let authURL = URL(string: baiduwangpan_auth_url)
                    UIApplication.shared.open(authURL!, options: [:], completionHandler: nil)
                }
                
            }
        }
    }
        
    class func aliyundriveLoginWithCode(_ code: String) {
        PPAliyunDriveService.getToken(code: code, callback: {access_token,refresh_token in
            debugPrint(access_token,refresh_token)
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = "AliyunDrive"
            vc.serverURL = ""
            vc.userName = ""
            vc.remark = "阿里云盘"
            vc.showUserName = false
            vc.showServerURL = false
            vc.showPassword = false
            vc.accessToken = access_token
            vc.refreshToken = refresh_token
            UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
            
        })
    }
    

    /// 换到 token 之后统一走这里建服务器配置。两个登录入口只有 client_id 不同，其余字段一模一样
    class func pushOneDriveConfig(accessToken: String, refreshToken: String, clientID: String) {
        let vc = PPWebDAVConfigViewController()
        vc.cloudType = "OneDrive"
        // 下面这两个值只写进配置，不在界面上展示（配置页会按类型把这两行收起来），免得用户手一滑改错地址或 client_id，导致请求打到错误域名或刷新 token 报 400
        vc.serverURL = "https://graph.microsoft.com/"
        // userName 会被当成 clientID 存进配置，刷新 token 时要靠它和 refresh_token 配对，所以这里必须传真正签发 token 的那个，别两个入口混着用
        vc.userName = clientID
        vc.remark = "OneDrive"
        vc.password = accessToken
        vc.extraString = refreshToken
        // 这一行必须打开。保存逻辑只收集界面上可见的行，不显示的话 refresh_token 进不了配置，access_token 一小时过期后就没法续期了
        vc.showExtra = true
        vc.extraDesc = "RefreshToken"
        UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
    }

    /// 换到 token 之后统一走这里建 Dropbox 配置。
    /// 服务器地址和账号都由程序固定，配置页会把这两行藏起来，免得用户改错导致请求打歪
    class func pushDropboxConfig(accessToken: String, refreshToken: String) {
        let vc = PPWebDAVConfigViewController()
        vc.cloudType = "Dropbox"
        vc.remark = "Dropbox"
        vc.password = accessToken
        vc.extraString = refreshToken
        // 这一行必须打开：保存逻辑只收集界面上可见的行，
        // 不显示的话 refresh_token 进不了配置，access_token 四小时过期后就再也续不上
        vc.showExtra = true
        vc.extraDesc = "RefreshToken"
        UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
    }

    /// iCloud Drive 没有服务器、账号、密码这些字段，只留一行「备注」让用户决定列表里显示什么名字。
    /// 复用通用配置页是为了不把保存、备注查重、切换当前服务、刷新列表这几段逻辑再抄一份，抄一份以后改一边总会漏一边
    class func pushICloudConfig(_ sourceVC: UIViewController) {
        let vc = PPWebDAVConfigViewController()
        // 必须写 rawValue（"icloud"）：PPUserInfo 是按 PPCloudServiceType(rawValue:) 解析这个字符串的，写中文名会解析失败回落到 webdav，最后拿一个空地址去发请求
        vc.cloudType = PPCloudServiceType.icloud.rawValue
        vc.remark = "iCloud Drive"
        // 这几项对 iCloud 本来就没有值，全部收起来，免得用户以为还得填点什么才能保存
        vc.showServerURL = false
        vc.showUserName = false
        vc.showPassword = false
        vc.tips = "注意：\niCloud Drive 不需要填服务器和账号\n文件来自系统 iCloud 云盘，登录状态跟着系统设置走"
        sourceVC.navigationController?.pushViewController(vc, animated: true)
    }

    class func handleCloudServiceRedirect(_ url:URL) {
        debugPrint("callbackURL:", url)
        if url.host == "oauth-callback" {
            // Dropbox 授权回调：pandanote://oauth-callback/dropbox?code=xxx&state=DROPBOX
            // 系统浏览器授权走的是这条，App 内 WebView 授权则在 PPWebViewController 里就近处理
            guard let code = PPDropboxService.authorizationCode(fromCallback: url) else {
                return
            }
            PPDropboxService.exchangeAuthorizationCode(code) { accessToken, refreshToken, errorMessage in
                guard let accessToken = accessToken, let refreshToken = refreshToken else {
                    PPAlertTool.showAlert(title: "Dropbox 授权失败", message: errorMessage ?? "未知原因")
                    return
                }
                PPAddCloudServiceViewController.pushDropboxConfig(accessToken: accessToken, refreshToken: refreshToken)
            }
        }
        else if url.host == "msredirect" {
            let urlWithCode = url.absoluteString
            debugPrint("microsoft redirect is:\(urlWithCode)")
            if let code = urlWithCode.pp_valueOf("code") {
                debugPrint("microsoft code is:\(code)")
                
                // redirect_uri 和 scope 必须和 onedrive_auth_url 里发的完全一致，
                // 不一致会被直接拒（AADSTS70000 / AADSTS70011）。
                // 千万别抄 ES 分支的 nativeclient，那是另一个应用注册的回调地址
                PPOneDriveService.exchangeAuthorizationCode(code,
                                                            clientID: onedrive_client_id_pandanote,
                                                            redirectUri: onedrive_redirect_uri_pandanote,
                                                            scope: onedrive_scope_pandanote) { accessToken, refreshToken, errorMessage in
                    guard let accessToken = accessToken, let refreshToken = refreshToken else {
                        // 以前失败是静默的，只能去控制台翻日志。微软会把原因写在 error_description 里，
                        // 直接弹出来省得来回猜
                        PPAlertTool.showAlert(title: "OneDrive 授权失败", message: errorMessage ?? "未知原因")
                        return
                    }
                    PPAddCloudServiceViewController.pushOneDriveConfig(accessToken: accessToken,
                                                                       refreshToken: refreshToken,
                                                                       clientID: onedrive_client_id_pandanote)
                }
            }
        }
        else if url.host == "login.microsoftonline.com" {//ES文件浏览器
            let urlWithCode = url.absoluteString
            debugPrint("microsoft redirect is:\(urlWithCode)")
            if let code = urlWithCode.pp_valueOf("code") {
                debugPrint("microsoft code is:",code)
                
                // ES 那条老流程一直没带 scope，这里也保持不带，改了反而可能被要求重新同意
                PPOneDriveService.exchangeAuthorizationCode(code,
                                                            clientID: onedrive_client_id_es,
                                                            redirectUri: onedrive_redirect_uri_es,
                                                            scope: nil) { accessToken, refreshToken, _ in
                    // 这条入口历史上失败是静默的，保持原样，失败信息只在控制台
                    guard let accessToken = accessToken, let refreshToken = refreshToken else { return }
                    PPAddCloudServiceViewController.pushOneDriveConfig(accessToken: accessToken,
                                                                       refreshToken: refreshToken,
                                                                       clientID: onedrive_client_id_es)
                }
            }
        }
        else if url.host == "baiduwangpan" {
            let urlWithToken = url.absoluteString.removingPercentEncoding?.replacingOccurrences(of: "baiduwangpan#", with: "baiduwangpan?")
            if let access_token = urlWithToken?.pp_valueOf("access_token") {
                debugPrint("baidu access_token:",access_token)
                let vc = PPWebDAVConfigViewController()
                vc.cloudType = PPCloudServiceType.baiduyun.rawValue
                vc.serverURL = "https://pan.baidu.com/rest/2.0/xpan/file"
                vc.remark = "百度网盘"
                vc.password = access_token
                vc.showUserName = false
                UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
            }
            
        }
        else if url.host == aliyundrive_callback_domain {
            let urlWithCode = url.absoluteString
            if let code = urlWithCode.pp_valueOf("code") {
                PPAddCloudServiceViewController.aliyundriveLoginWithCode(code)
                
            }
        }
    }

}
