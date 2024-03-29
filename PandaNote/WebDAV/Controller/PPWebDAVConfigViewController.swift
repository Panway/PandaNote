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
    var showOtpCode = false ///< 显示（两步验证）验证码 two-factor code
    
    var cloudType = ""
    var serverURL = ""
    var serverURLRemark = "服务器地址"
    var userName = ""
    
    var password = "" //编辑时用到
    var passwordDesc = "密码"
    var passwordRemark = "密码"
    
    var showRemark = true
    var remark = ""
    
    var optCodeRemark = "验证码" //占位符
    var optCode = ""
    
    var showToken = false //access token
    var accessToken = ""
    
    var showRefreshToken = false //refresh token
    var refreshToken = ""
    
    var showExtra = false
    var extraDesc = "其他"
    var extraString = "" //额外的字段
    
    var tips = ""
    var isOptional = [Int]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "云服务配置"
        self.view.backgroundColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.00)
        var leftNames = [String]() //["服务器","账号","密码","备注"]
        var placeHolders = [String]() //["服务器地址","账号（Dropbox不需要）","密码或token","备注（显示用）"]
        var texts = [String]() //[serverURL,userName,password,remark]
        if showServerURL {
            leftNames.append("URL")
            placeHolders.append(serverURLRemark)
            texts.append(serverURL)
            isOptional.append(0)
        }
        if showUserName {
            leftNames.append("账号")
            placeHolders.append("用户名")
            texts.append(userName)
            isOptional.append(0)
        }
        if showPassword {
            leftNames.append(passwordDesc)
            placeHolders.append(passwordRemark)
            texts.append(password)
            isOptional.append(0)
        }
        if showOtpCode {
            leftNames.append("验证码")
            placeHolders.append(optCodeRemark)
            texts.append("")
            isOptional.append(1)
        }
        if showToken {
            leftNames.append("access token")
            placeHolders.append("access token")
            texts.append(accessToken)
            isOptional.append(0)
        }
        if showRefreshToken {
            leftNames.append("refresh token")
            placeHolders.append("refresh token")
            texts.append(refreshToken)
            isOptional.append(0)
        }
        if showExtra {
            leftNames.append(extraDesc)
            placeHolders.append(extraString)
            texts.append(extraString)
            isOptional.append(0)
        }
        if showRemark {
            leftNames.append("备注")
            placeHolders.append("备注")
            texts.append(remark)
            isOptional.append(0)
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
            model.isOptional = isOptional[i] == 1
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
                    keyValue[cell.leftLB.text ?? "key"] = cell.rightTF.text
                    // print(cell.leftLB.text, cell.serverNameTF.text)
                    let isOptional = isOptional[indexPath.row]
                    if let value = cell.rightTF.text, isOptional == 0 && value.length < 1 {
                        PPHUD.showHUDFromTop(cell.leftLB.text!+"不能为空", isError: true)
                        return
                    }
                    
                }
            }
        }

        if(keyValue["Token"] != nil) {
            self.accessToken = keyValue["Token"] ?? ""
        }
        var newServer = ["PPCloudServiceType":self.cloudType]
        let desc_keys = [("URL","PPWebDAVServerURL"),("账号","PPWebDAVUserName"),(passwordDesc,"PPWebDAVPassword"),
                         ("备注","PPWebDAVRemark"),("验证码","PPOptCode"),(extraDesc,"PPCloudServiceExtra")]
        for desc_key in desc_keys {
            let (desc, key) = desc_key
            if let value = keyValue[desc], value.length > 0 {
                newServer[key] = value
            }
        }
        if accessToken.length > 0 {
            newServer["PPAccessToken"] = accessToken
        }
        if refreshToken.length > 0 {
            newServer["PPRefreshToken"] = refreshToken
        }
        debugPrint(newServer)
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
        PPAppConfig.shared.setItem("pp_lastSeverInfoIndex", "\(PPUserInfo.shared.pp_lastSeverInfoIndex)")
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
