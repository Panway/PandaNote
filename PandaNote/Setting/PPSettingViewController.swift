//
//  PPSettingViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPSettingViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate {
    var dataSource:Array<String> = ["WebDAV Setting","自动保存","FLEX Debug Enable"]
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView.init(frame: self.view.bounds,style: UITableView.Style.grouped)
        self.view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPSettingCell.self, forCellReuseIdentifier: kPPBaseTableViewCellCellIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
    }
    
    @objc func injected() {
        dataSource = ["WebDAV Setting","Web"]
        self.tableView.reloadData()
    }
    @objc func saveMarkdownWhenClose(_ sender:UISwitch) {
        debugPrint("======\(sender.isOn)")
        PPUserInfo.shared.pp_Setting.updateValue(sender.isOn ? "1" : "0", forKey: "saveMarkdownWhenClose")

    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseTableViewCellCellIdentifier, for: indexPath) as! PPSettingCell
        cell.titleLB.text = self.dataSource[indexPath.row]
        let obj = self.dataSource[indexPath.row]
        if obj == "自动保存" {
            cell.switchBtn.isOn = PPUserInfo.pp_valueForSettingDict(key: "saveMarkdownWhenClose")
            cell.switchBtn.addTarget(self, action: #selector(saveMarkdownWhenClose(_:)), for: UIControl.Event.touchUpInside)
        }
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
            FLEXManager.shared()?.showExplorer()
            #endif

        }
        else if obj == "自动保存" {
            PPUserInfo.shared.pp_Setting.updateValue("1", forKey: "saveMarkdownWhenClose")
            
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
