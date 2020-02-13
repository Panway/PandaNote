//
//  PPSettingCell.swift
//  PandaNote
//
//  Created by panwei on 2020/2/11.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit

class PPSettingCell: PPBaseTableViewCell {
    var titleLB:UILabel!
    lazy var rightLB : UILabel = {
        let aLB = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        aLB.textColor = UIColor.gray
        //        aLB.textAlignment = NSTextAlignment.center
        aLB.numberOfLines = 1
        aLB.font = UIFont.systemFont(ofSize: 16)
        aLB.text = "string"
        self.contentView.addSubview(aLB)
        aLB.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
//            make
        }
        return aLB
    }()
    lazy var switchBtn : UISwitch = {
        let switchBtn = UISwitch.init()
        self.contentView.addSubview(switchBtn)
        switchBtn.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
        }
        return switchBtn
    }()
    
    override func pp_addSubViews() {
        titleLB = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
//        aLB.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        aLB.backgroundColor = UIColor.white
        titleLB.textColor = UIColor.darkGray
//        aLB.textAlignment = NSTextAlignment.center
        titleLB.numberOfLines = 1
        titleLB.font = UIFont.systemFont(ofSize: 16)
        titleLB.text = "string"
        self.contentView.addSubview(titleLB)
        titleLB.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
//            make
        }

        
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
