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
                    let vc = PPWebViewController()
                    vc.urlString = dropbox_auth_url
                    sourceVC.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    
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
        vc.serverURL = "https://graph.microsoft.com/"
        // userName 会被当成 clientID 存进配置，刷新 token 时要靠它和 refresh_token 配对，
        // 所以这里必须传真正签发 token 的那个，别两个入口混着用
        vc.userName = clientID
        vc.remark = "OneDrive"
        vc.password = accessToken
        vc.extraString = refreshToken
        UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
    }

    class func handleCloudServiceRedirect(_ url:URL) {
        debugPrint("callbackURL:", url)
        if url.host == "msredirect" {
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
