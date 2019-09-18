//
//  PPWebDAVConfigViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPWebDAVConfigViewController: PPBaseViewController {

    let table = XDFastTableView.init()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.00)

        
        
        self.view.addSubview(table)
        table.snp.makeConstraints { (make) in
            make.top.equalTo(self.view).offset(88)
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view)
        }
        table.registerCellClass(PPTextFieldTableViewCell.self)
        table.dataSource = ["服务器地址","账号","密码","备注"]
        table.didSelectRowAtIndexHandler = {(index: Int) ->Void in
            print("click==\(index)")
        }
        let saveBtn = UIButton.init()
        self.view.addSubview(saveBtn)
        saveBtn.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view).offset(-88)
            make.centerX.equalTo(self.view)
            
            make.height.equalTo(50)
            make.width.equalTo(150)
        }
        saveBtn.setTitle("保存", for: UIControl.State.normal)
        saveBtn.backgroundColor = UIColor(red:0.13, green:0.75, blue:0.39, alpha:1.00)
        saveBtn.addTarget(self, action: #selector(submit), for: UIControl.Event.touchUpInside)
    }
    
    @objc func submit() -> Void {
        print("submit!")
        let cell1:PPTextFieldTableViewCell = table.tableView.cellForRow(at: IndexPath.init(row: 0, section: 0)) as! PPTextFieldTableViewCell
        let cell2:PPTextFieldTableViewCell = table.tableView.cellForRow(at: IndexPath.init(row: 1, section: 0)) as! PPTextFieldTableViewCell
        let cell3:PPTextFieldTableViewCell = table.tableView.cellForRow(at: IndexPath.init(row: 2, section: 0)) as! PPTextFieldTableViewCell
        let cell4:PPTextFieldTableViewCell = table.tableView.cellForRow(at: IndexPath.init(row: 3, section: 0)) as! PPTextFieldTableViewCell

        if cell1.serverNameTF.text!.length < 1 {
            PPHUD.showHUDText(message: "请填写服务器地址", view: self.view)
            return
        }
        if cell2.serverNameTF.text!.length < 1 {
            PPHUD.showHUDText(message: "请填写账号", view: self.view)
            return
        }
        if cell3.serverNameTF.text!.length < 1 {
            PPHUD.showHUDText(message: "请填写密码", view: self.view)
            return
        }
        if cell4.serverNameTF.text!.length < 1 {
            PPHUD.showHUDText(message: "请填写备注", view: self.view)
            return
        }
        PPUserInfoManager.sharedManager.save(cell1.serverNameTF.text!, forKey: "PPWebDAVServerURL")
        PPUserInfoManager.sharedManager.save(cell2.serverNameTF.text!, forKey: "PPWebDAVUserName")
        PPUserInfoManager.sharedManager.save(cell3.serverNameTF.text!, forKey: "PPWebDAVPassword")
        PPUserInfoManager.sharedManager.save(cell4.serverNameTF.text!, forKey: "PPWebDAVRemark")
        PPHUD.showHUDText(message: "保存成功", view: self.view)
        PPUserInfoManager.sharedManager.initConfig()

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
