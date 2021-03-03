//
//  PPSettingCell.swift
//  PandaNote
//
//  Created by panwei on 2020/2/11.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
protocol PPSettingCellDelegate: AnyObject {
    func didClickSwitch(sender: UISwitch,name:String,saveKey:String,section:Int,row:Int)
}

class PPSettingCell: PPBaseTableViewCell {
    var titleLB:UILabel!
    weak var delegate: PPSettingCellDelegate?
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
    
    lazy var detailLB : UILabel = {
        let aLB = UILabel(frame: CGRect.zero)
        aLB.textColor = UIColor.lightGray
        aLB.numberOfLines = 1
        aLB.font = UIFont.systemFont(ofSize: 13)
        aLB.text = "详细说明"
        self.contentView.addSubview(aLB)
        aLB.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset(-10)
            make.left.equalToSuperview().offset(15)
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
        switchBtn.addTarget(self, action: #selector(switchBtnAction(_:)), for: .touchUpInside)
        return switchBtn
    }()
    @objc func switchBtnAction(_ sender:UISwitch) {
        delegate?.didClickSwitch(sender: self.switchBtn, name: self.titleLB.text ?? "",saveKey:self.pp_stringTag,section: self.pp_section,row: self.pp_row)
    }
    override func pp_addSubViews() {
//        titleLB = self.textLabel
//        self.detailTextLabel?.text = "2333"
        
        titleLB = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
//        aLB.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        titleLB.textColor = .darkGray
        titleLB.numberOfLines = 1
        titleLB.font = .systemFont(ofSize: 16)
        titleLB.text = "string"
        self.contentView.addSubview(titleLB)
        titleLB.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(15)
//            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(12)
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
