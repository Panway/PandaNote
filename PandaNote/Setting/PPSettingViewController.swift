//
//  PPSettingViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPSettingViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate {
    var dataSource:Array<String> = ["WebDAV Setting","FLEX Debug Enable"]
    var tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView.init(frame: self.view.bounds)
        self.view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: kPPBaseTableViewCellCellIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
    }
    
    @objc func injected() {
        dataSource = ["WebDAV Setting","Web"]
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseTableViewCellCellIdentifier, for: indexPath) as! PPFileListTableViewCell
        cell.textLabel?.text = self.dataSource[indexPath.row]
//        let fileObj = self.dataSource[indexPath.row]
//        cell.titleLabel.text = fileObj.name
//        cell.timeLabel.text = String(describing: fileObj.modifiedDate).substring(startIndex: 9, endIndex: 29)
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
