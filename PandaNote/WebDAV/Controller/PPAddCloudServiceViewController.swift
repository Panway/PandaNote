//
//  PPAddCloudServiceViewController.swift
//  PandaNote
//
//  Created by topcheer on 2020/12/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit

class PPAddCloudServiceViewController : PPBaseViewController,UITableViewDataSource,UITableViewDelegate {
    var dataSource:Array<String> = ["坚果云",
                                    "Dropbox",
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
        if obj == "坚果云" {
            let vc = PPWebDAVConfigViewController()
            vc.cloudType = obj
            vc.serverURL = "http://dav.jianguoyun.com/dav"
            vc.remark = obj
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "Dropbox" {
            let vc = PPWebViewController()
            vc.urlString = "https://www.dropbox.com/oauth2/authorize?client_id=pjmhj9rfhownr7z&redirect_uri=filemgr://oauth-callback/dropbox&response_type=token&state=DROPBOX"
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if obj == "百度云" {
            PPAlertAction.showSheet(withTitle: "您想如何获取access_token", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["手动输入（抓包获取）","授权登录自动获取"]) { (index) in
                if index == 1 {
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
                
            }
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    

    

}
