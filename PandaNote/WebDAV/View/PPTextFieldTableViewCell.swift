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
    let leftLB = UILabel()
    var textFieldNonnull = true
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    override func pp_addSubviews() {
        self.contentView.addSubview(leftLB)
        leftLB.snp.makeConstraints { (make) in
            make.left.equalTo(self.contentView).offset(15)
            make.width.equalTo(66)
            make.centerY.equalTo(self.contentView)
        }
        leftLB.text = "服务器"
        
        serverNameTF = UITextField()
        self.contentView.addSubview(serverNameTF)
        serverNameTF.snp.makeConstraints { (make) in
//            make.top.equalTo(self.view).offset(88+1)
            make.left.equalTo(self.leftLB.snp.right).offset(15)
            make.right.equalTo(self.contentView).offset(-15)
            make.height.equalTo(30)
            make.centerY.equalTo(self.contentView)
        }
        serverNameTF.placeholder = "服务器地址"
        serverNameTF.clearButtonMode = .whileEditing
        serverNameTF.borderStyle = .bezel
    }
    override func updateUI(withData data: Any) {
        guard let model = data as? PPAddCloudServiceModel else {
            return
        }
        serverNameTF.placeholder = model.placeHolder
        leftLB.text = model.leftName
        serverNameTF.text = model.textValue
        textFieldNonnull  = model.textFieldNonnull
    }
}


class PPAddCloudServiceModel: NSObject {
    var leftName = ""
    var placeHolder = ""
    var textValue = ""
    var textFieldNonnull = true

}
