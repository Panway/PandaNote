//
//  PPSettingViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPSettingViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate,PPSettingCellDelegate {
    
    
    var dataSource:Array<String> = ["退出时自动保存文本",
                                    "上传图片名称使用创建日期",
                                    "上传照片后删除原照片",
                                    "保存设置到",
                                    "FLEX Debug Enable"]
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: self.view.bounds,style: UITableView.Style.grouped)
        self.view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPSettingCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView()
        
        
    }
    
    @objc func injected() {
        dataSource = ["WebDAV Setting","Web"]
        self.tableView.reloadData()
    }
    
    
    func didClickSwitch(sender: UISwitch, name: String) {
        debugPrint("======\(sender.isOn):\(name)")
        if name == "退出时自动保存文本" {
            PPUserInfo.shared.pp_Setting.updateValue(sender.isOn ? "1" : "0", forKey: "saveMarkdownWhenClose")
        }
        else if name == "上传图片名称使用创建日期" {
            PPUserInfo.shared.pp_Setting.updateValue(sender.isOn ? "1" : "0", forKey: "uploadImageNameUseCreationDate")
        }
        else if name == "上传照片后删除原照片" {
            PPUserInfo.shared.pp_Setting.updateValue(sender.isOn ? "1" : "0", forKey: "deletePhotoAfterUploading")
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPSettingCell
        cell.titleLB.text = self.dataSource[indexPath.row]
        let obj = self.dataSource[indexPath.row]
        if obj == "退出时自动保存文本" {
            cell.switchBtn.isOn = PPUserInfo.pp_boolValue("saveMarkdownWhenClose")
        }
        else if obj == "上传图片名称使用创建日期" {
            cell.switchBtn.isOn = PPUserInfo.pp_boolValue("uploadImageNameUseCreationDate")
        }
        else if obj == "上传照片后删除原照片" {
            cell.switchBtn.isOn = PPUserInfo.pp_boolValue("deletePhotoAfterUploading")
        }
        cell.delegate = self
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let obj = self.dataSource[indexPath.row]
        if obj == "WebDAV Setting" {
            let vc = PPWebDAVConfigViewController.init()
            self.navigationController?.pushViewController(vc, animated: true)
            
        }
        else if obj == "FLEX Debug Enable" {
            #if DEBUG
            FLEXManager.shared.showExplorer()
            #endif
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
