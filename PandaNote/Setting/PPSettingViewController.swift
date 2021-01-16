//
//  PPSettingViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPSettingViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate,PPSettingCellDelegate {
    
    
    var dataSource : [[[String:String]]] = []
    var headerList : [String] = []
//        ["退出时自动保存文本",
//                                    "上传图片名称使用创建日期",
//                                    "上传照片后删除原照片",
//                                    "保存设置到",
//                                    "FLEX Debug Enable"]
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: self.view.bounds,style: .grouped)
        self.view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPSettingCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.register(PPTableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: kPPTableViewHeaderFooterView)
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        guard let path = Bundle.main.url(forResource: "pp_setting.json", withExtension: nil), let jsonData = try? Data(contentsOf: path) else {return}
        if let json = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) {
            dataSource = json as! [[[String:String]]]
            for item in dataSource {
                for subitem in item {
                    if let categoryStr = subitem["category"] {
                        headerList.append(categoryStr)
                    }
                }
            }
        }
        
    }
    
    @objc func injected() {
//        dataSource = ["WebDAV Setting","Web"]
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
    //MARK:- tab;le
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let customFooterView = tableView.dequeueReusableHeaderFooterView(withIdentifier: kPPTableViewHeaderFooterView)
        customFooterView?.textLabel?.text = headerList[section]
//        customFooterView?.detailTextLabel?.text = "detailTextLabel"
        return customFooterView
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPSettingCell
        let item = self.dataSource[indexPath.section][indexPath.row]
        cell.titleLB.text = item["name"]//self.dataSource[indexPath.row]
        let obj = cell.titleLB.text
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
        let obj = self.dataSource[indexPath.section][indexPath.row]["name"]
        if obj == "WebDAV Setting" {
            let vc = PPWebDAVConfigViewController.init()
            self.navigationController?.pushViewController(vc, animated: true)
            
        }
        else if obj == "FLEX Debug Enable" {
            #if DEBUG
            FLEXManager.shared.showExplorer()
            #endif
        }
        else if obj == "保存设置到" {
            let vc = PPFileListViewController()
            vc.filePathToBeMove = PPUserInfo.shared.pp_mainDirectory + "/PP_JSONConfig.json"
            vc.isMovingMode = true
            let nav = UINavigationController(rootViewController: vc)
            self.present(nav, animated: true, completion: nil)
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
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
