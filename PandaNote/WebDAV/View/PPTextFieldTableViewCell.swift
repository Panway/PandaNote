//
//  PPTextFieldTableViewCell.swift
//  PandaNote
//
//  Created by panwei on 2019/8/29.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import UIKit

class PPTextFieldTableViewCell: PandaFastTableViewCell {
    var serverNameTF:UITextField = UITextField.init()
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    override func pp_addSubviews() {
        serverNameTF = UITextField.init()
        self.contentView.addSubview(serverNameTF)
        serverNameTF.snp.makeConstraints { (make) in
//            make.top.equalTo(self.view).offset(88+1)
            make.left.equalTo(self.contentView).offset(15)
            make.right.equalTo(self.contentView).offset(-15)
            make.height.equalTo(30)
            make.centerY.equalTo(self.contentView)
        }
        serverNameTF.placeholder = "服务器地址"

    }
    override func updateUI(withData data: Any) {
        let str : String = data as! String
        self.serverNameTF.placeholder = str
        if self.serverNameTF.placeholder == "服务器地址" {
            self.serverNameTF.text = "http://dav.jianguoyun.com/dav"
        }
        else if self.serverNameTF.placeholder == "账号" {
            self.serverNameTF.text = "9@qq.com"
        }
        else if self.serverNameTF.placeholder == "密码" {
            self.serverNameTF.text = ""
            self.serverNameTF.isSecureTextEntry = true
        }
        else if self.serverNameTF.placeholder == "备注" {
            self.serverNameTF.text = "坚果云"
        }
    }
}
