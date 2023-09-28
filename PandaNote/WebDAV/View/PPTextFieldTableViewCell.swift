//
//  PPTextFieldTableViewCell.swift
//  PandaNote
//
//  Created by Panway on 2019/8/29.
//  Copyright © 2019 Panway. All rights reserved.
//

import UIKit

class PPTextFieldTableViewCell: PandaFastTableViewCell {
    var rightTF = UITextField()
    let leftLB = UILabel()
//    var textFieldNonnull = true
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
            make.width.equalTo(80)
            make.centerY.equalTo(self.contentView)
        }
//        leftLB.text = "服务器"
        leftLB.adjustsFontSizeToFitWidth = true
        
        rightTF = UITextField()
        self.contentView.addSubview(rightTF)
        rightTF.snp.makeConstraints { (make) in
//            make.top.equalTo(self.view).offset(88+1)
            make.left.equalTo(self.leftLB.snp.right).offset(15)
            make.right.equalTo(self.contentView).offset(-15)
            make.height.equalTo(30)
            make.centerY.equalTo(self.contentView)
        }
//        rightTF.placeholder = "服务器地址"
        rightTF.clearButtonMode = .whileEditing
//        rightTF.borderStyle = .bezel
    }
    override func updateUI(withData data: Any) {
        guard let model = data as? PPAddCloudServiceModel else {
            return
        }
        rightTF.placeholder = model.placeHolder
        leftLB.text = model.leftName
        rightTF.text = model.textValue
//        textFieldNonnull  = !model.isOptional
    }
}


class PPAddCloudServiceModel: NSObject {
    var leftName = ""
    var placeHolder = ""
    var textValue = ""
    var isOptional = false ///< 可选（可为空）

}
