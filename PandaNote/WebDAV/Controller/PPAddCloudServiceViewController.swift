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
                                    "Dropbox",
                                    "OneDrive",
                                    "蓝奏云",
                                    "百度云"]
    var tableView = UITableView()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: self.view.bounds,style: .grouped)
        self.view.addSubview(tableView)
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
        if obj == "WebDAV（坚果云等）" {
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = obj
            vc.serverURL = "http://dav.jianguoyun.com/dav"
            #if DEBUG
            vc.serverURL = "http://192.168.123.46:5005"
            vc.userName = "panda"
            vc.password = "Pan10000"
//            vc.userName = "948567749@qq.com"
//            vc.password = "ajvb68qgqp75n9br"//pj
            #endif
            vc.remark = obj
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "Dropbox" {
//            let vc = PPWebViewController()
//            vc.urlString = "https://www.dropbox.com/oauth2/authorize?client_id=pjmhj9rfhownr7z&redirect_uri=filemgr://oauth-callback/dropbox&response_type=token&state=DROPBOX"
//            self.navigationController?.pushViewController(vc, animated: true)
            
            
            PPAlertAction.showSheet(withTitle: "您想如何获取访问令牌（access_token）", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["Safari浏览器内授权","App内授权","手动输入（抓包获取）"]) { (index) in
                if index == 3 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "Dropbox"
                    vc.remark = "Dropbox"
                    vc.password = ""
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 2 {
                    let vc = PPWebViewController()
                    vc.urlString = "https://www.dropbox.com/oauth2/authorize?client_id=pjmhj9rfhownr7z&redirect_uri=filemgr://oauth-callback/dropbox&response_type=token&state=DROPBOX"
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    
                }
                
            }
        }
        else if obj == "OneDrive" {
            PPAlertAction.showSheet(withTitle: "您想如何获取访问令牌（access_token）", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["Safari浏览器内授权","App内授权","手动输入（抓包获取）"]) { (index) in
                
                let url = "https://login.live.com/oauth20_authorize.srf?client_id=064f5b62-97a8-4dae-b5c1-aaf44439939d&scope=onedrive.readwrite%20offline_access&response_type=code&redirect_uri=pandanote://msredirect"//pandanote的
                if index == 1 {
                    let authURL = URL(string: url)
                    UIApplication.shared.open(authURL!, options: [:], completionHandler: nil)
//                    PPAddCloudServiceViewController.handleCloudServiceRedirect(URL(string: "pandanote://msredirect/?code=XXX")!)
                }
                else if index == 2 {
                    let vc = PPWebViewController()
                    vc.urlString = onedrive_login_url_es//ES的
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 3 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "OneDrive"
                    vc.remark = "OneDrive"
                    vc.password = ""
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                
            }
            
        }
        else if obj == "百度云" {
            PPAlertAction.showSheet(withTitle: "您想如何获取访问令牌（access_token）", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["Safari浏览器内授权","App内授权","手动输入（抓包获取）"]) { (index) in
                if index == 3 {
                    let vc = PPWebDAVConfigViewController()
                    vc.cloudType = "baiduyun"
                    vc.serverURL = "https://pan.baidu.com/rest/2.0/xpan/file"
                    vc.remark = "百度云"
                    self.navigationController?.pushViewController(vc, animated: true)                }
                else if index == 2 {
                    let vc = PPWebViewController()
                    vc.urlString = "https://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=NqOMXF6XGhGRIGemsQ9nG0Na&redirect_uri=http://www.estrongs.com&scope=basic,netdisk&display=mobile&state=STATE&force_login=1"
                    self.navigationController?.pushViewController(vc, animated: true)
                }
                else if index == 1 {
                    let authURL = URL(string: "http://openapi.baidu.com/oauth/2.0/authorize?response_type=token&client_id=4CXtrIz7T0yEYsLC8majw1ff42Uh64Yw&redirect_uri=pandanote://baiduwangpan&scope=basic,netdisk&display=mobile&state=pandanotestate")
                    UIApplication.shared.open(authURL!, options: [:], completionHandler: nil)
                }
                
            }
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    

    class func handleCloudServiceRedirect(_ url:URL) {
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
                vc.cloudType = "baiduyun"
                vc.serverURL = "https://pan.baidu.com/rest/2.0/xpan/file"
                vc.remark = "百度云"
                vc.password = access_token
                UIViewController.pp_topViewController()?.navigationController?.pushViewController(vc, animated: true)
            }
            
        }
    }

}
