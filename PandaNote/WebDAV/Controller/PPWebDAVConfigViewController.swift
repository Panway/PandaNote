//
//  PPWebDAVConfigViewController.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPWebDAVConfigViewController: PPBaseViewController {

    let table = XDFastTableView()
    
    var isEditMode = false
    var editIndex = 0
    
    var showServerURL = true
    var showUserName = true
    var showPassword = true //密码
    var showToken = false //access token
    var showRefreshToken = false //refresh token
    var showExtra = false
    var showRemark = true
    
    var cloudType = ""
    var serverURL = ""
    var userName = ""
    var password = ""
    var passwordDesc = "密码"
    var passwordRemark = "密码"
    var accessToken = ""
    var refreshToken = ""
    var remark = ""
    var extraString = "" //额外的字段
    var tips = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "新增云服务"
        self.view.backgroundColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.00)
        var leftNames = [String]() //["服务器","账号","密码","备注"]
        var placeHolders = [String]() //["服务器地址","账号（Dropbox不需要）","密码或token","备注（显示用）"]
        var texts = [String]() //[serverURL,userName,password,remark]
        
        if showServerURL {
            leftNames.append("URL")
            placeHolders.append("服务器地址")
            texts.append(serverURL)
        }
        if showUserName {
            leftNames.append("账号")
            placeHolders.append("用户名")
            texts.append(userName)
        }
        if showPassword {
            leftNames.append(passwordDesc)
            placeHolders.append(passwordRemark)
            texts.append(password)
        }
        if showToken {
            leftNames.append("access token")
            placeHolders.append("access token")
            texts.append(accessToken)
        }
        if showRefreshToken {
            leftNames.append("refresh token")
            placeHolders.append("refresh token")
            texts.append(refreshToken)
        }
        if showExtra {
            leftNames.append("其他")
            placeHolders.append(extraString)
            texts.append(extraString)
        }
        if showRemark {
            leftNames.append("备注")
            placeHolders.append("备注")
            texts.append(remark)
        }
        
        
        self.view.addSubview(table)
        table.snp.makeConstraints { (make) in
            make.top.equalTo(self.pp_safeLayoutGuideTop())
            make.left.right.bottom.equalToSuperview()
        }
        table.registerCellClass(PPTextFieldTableViewCell.self)
        var list = [PPAddCloudServiceModel]()
        for i in 0..<leftNames.count {
            let model = PPAddCloudServiceModel()
            model.leftName = leftNames[i]
            model.placeHolder = placeHolders[i]
            model.textValue = texts[i]
            list.append(model)
        }
        table.dataSource = list
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
        
        
        let tipsLB = UILabel()
        self.view.addSubview(tipsLB)
        tipsLB.snp.makeConstraints { (make) in
            make.bottom.equalTo(saveBtn.snp.top).offset(-44)
            make.left.equalTo(self.view).offset(20)
            make.right.equalTo(self.view).offset(-20)
        }
        tipsLB.numberOfLines = 0
        tipsLB.textColor = UIColor(hexRGBValue: 0xcd594b)
        tipsLB.text = """
        注意：
        Dropbox、百度网盘的服务器和账号可不填写
        不确定的随便填写
        """
        if tips.length > 1 {
            tipsLB.text = tips
        }
        if cloudType == "alist" {
            tipsLB.text = """
        注意：
        密码可不填
        填写密码可以上传
        """
        }
    }
    
    // MARK: 提交
    @objc func submit() -> Void {

        var keyValue = [String:String]()
        if let visibleRows = table.tableView.indexPathsForVisibleRows {
            for indexPath in visibleRows {
                if let cell = table.tableView.cellForRow(at: indexPath) as? PPTextFieldTableViewCell {
                    keyValue[cell.leftLB.text ?? "key"] = cell.serverNameTF.text
                    // print(cell.leftLB.text, cell.serverNameTF.text)
                    if let value = cell.serverNameTF.text, value.length < 1 {
                        PPHUD.showHUDFromTop(cell.leftLB.text!+"不能为空", isError: true)
                        return
                    }
                    
                }
            }
        }

        if(keyValue["Token"] != nil) {
            self.accessToken = keyValue["Token"] ?? ""
        }
        let newServer = ["PPWebDAVServerURL":keyValue["URL"] ?? "",
                         "PPWebDAVUserName":keyValue["账号"] ?? "",
                         "PPWebDAVPassword":keyValue["密码"] ?? "",
                         "PPCloudServiceType":self.cloudType,
                         "PPCloudServiceExtra":self.extraString,
                         "PPAccessToken": self.accessToken,
                         "PPRefreshToken": self.refreshToken,
                         "PPWebDAVRemark":keyValue["备注"] ?? ""]
        
        if isEditMode {
            PPUserInfo.shared.pp_serverInfoList[editIndex] = newServer
        }
        else {
            let duplicated = PPUserInfo.shared.pp_serverInfoList.filter {
                $0["PPWebDAVRemark"] == newServer["PPWebDAVRemark"]// 找出重复的
            }
            if duplicated.count > 0 {
                PPHUD.showHUDFromTop("备注不能重复")
                return
            }
            // debugPrint(duplicated)
            PPUserInfo.shared.pp_serverInfoList.append(newServer)
        }
        PPHUD.showHUDFromTop("设置成功")
        PPUserInfo.shared.initConfig()
        //新添加的配置设为当前服务器配置（选中最后一个）
        PPUserInfo.shared.pp_lastSeverInfoIndex = PPUserInfo.shared.pp_serverInfoList.count - 1
        PPUserInfo.shared.pp_Setting["pp_lastSeverInfoIndex"] = PPUserInfo.shared.pp_lastSeverInfoIndex
        PPFileManager.shared.initCloudServiceSetting()
        //如果采用UISplitViewController，home是右侧的navigationController
        if let home = self.navigationController?.viewControllers[0],let vc = home as? PPFileListViewController {
            vc.setNavTitle(keyValue["备注"],true)
        }
        PPUserInfo.shared.refreshFileList = true
        DispatchQueue.main.asyncAfter(deadline: .now()+1) {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    

}
