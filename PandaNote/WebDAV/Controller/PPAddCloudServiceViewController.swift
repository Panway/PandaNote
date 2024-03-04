//
//  PPAddCloudServiceViewController.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
import Alamofire


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
        else if obj == "阿里云盘" {
            PPAlertTool.showAction(title: "请选择登录方式", message: nil,
                                   items: ["App内授权登录","扫二维码登录"]) //,"手动输入配置"])
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
    

    class func handleCloudServiceRedirect(_ url:URL) {
        debugPrint("callbackURL:", url)
        if url.host == "msredirect" {
            let urlWithCode = url.absoluteString
            debugPrint("microsoft redirect is:\(urlWithCode)")
            if let code = urlWithCode.pp_valueOf("code") {
                debugPrint("microsoft code is:\(code)")
                
                let parameters: [String: String] = [
                    "client_id": onedrive_client_id_pandanote,
//                    "redirect_uri": "pandanote://msredirect",
                    "redirect_uri": "https://login.microsoftonline.com/common/oauth2/nativeclient",//ES
                    "code": code,
//                    "scope":"User.Read Files.ReadWrite.All",//ES?
                    "grant_type": "authorization_code"
                ]
//                let url = "https://login.live.com/oauth20_token.srf"
                let url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
                AF.request(url, method: .post, parameters: parameters).responseJSON { response in
                    debugPrint("GET OneDrive token info:\(response.value ?? "")")
                    let jsonDic = response.value as? [String : Any]
//                    let access_token = jsonDic["access_token"] as? String
                    if let access_token = jsonDic?["access_token"] as? String,let refresh_token = jsonDic?["refresh_token"] as? String {
                        debugPrint("microsoft access_token is:\(access_token)")
                        let vc = PPWebDAVConfigViewController()
                        vc.cloudType = "OneDrive"
                        vc.serverURL = "https://graph.microsoft.com/"
                        vc.userName = onedrive_client_id_pandanote
                        vc.remark = "OneDrive"
                        vc.password = access_token
                        vc.extraString = refresh_token
                        UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
                    }
                    
                    
                }
                
                
                
                
            }
        }
        else if url.host == "login.microsoftonline.com" {//ES文件浏览器
            let urlWithCode = url.absoluteString
            debugPrint("microsoft redirect is:\(urlWithCode)")
            if let code = urlWithCode.pp_valueOf("code") {
                debugPrint("microsoft code is:",code)
                
                let parameters: [String: String] = [
                    "client_id": onedrive_client_id_es,
                    "redirect_uri": onedrive_redirect_uri_es,
                    "code": code,
//                    "code":"M.R3_BAY.37d890e7-9204-183f-a8b4-6dbd4b5030af",
//                    "scope":"User.Read Files.ReadWrite.All",
                    "grant_type": "authorization_code"
                ]
//                let url = "https://login.live.com/oauth20_token.srf"
                let url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"//同ES文件浏览器
                AF.request(url, method: .post, parameters: parameters).responseJSON { response in
                    debugPrint("GET OneDrive token info:\(response.value ?? "")")
                    let jsonDic = response.value as? [String : Any]
//                    let access_token = jsonDic["access_token"] as? String
                    if let access_token = jsonDic?["access_token"] as? String,let refresh_token = jsonDic?["refresh_token"] as? String {
                        debugPrint("microsoft access_token is:\(access_token)")
                        let vc = PPWebDAVConfigViewController()
                        vc.cloudType = "OneDrive"
                        vc.serverURL = "https://graph.microsoft.com/"
                        vc.userName = "064f5b62-97a8-4dae-b5c1-aaf44439939d"
                        vc.remark = "OneDrive"
                        vc.password = access_token
                        vc.extraString = refresh_token
                        UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
                    }
                    
                    
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
