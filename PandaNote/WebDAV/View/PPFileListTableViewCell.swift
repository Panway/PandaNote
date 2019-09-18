//
//  PPFileListTableViewCell.swift
//  TeamDisk
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//

import UIKit
import FilesProvider

class PPFileListTableViewCell: PPBaseTableViewCell {
    var titleLabel : UILabel = {
        let label = UILabel();
        label.textColor = "333333".HEXColor()
        label.font = UIFont.boldSystemFont(ofSize: 15)
        return label
    }()
    
    var couponNumLabel : UILabel = {
        let label = UILabel();
        label.textColor = "999999".HEXColor()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        return label
    }()
    
    var timeLabel : UILabel = {
        let label = UILabel();
        label.textColor = "999999".HEXColor()
        label.font = UIFont.boldSystemFont(ofSize: 11)
//        label.textAlignment = NSTextAlignment.right
        return label
    }()
    var iconImage : UIImageView = {
        let img = UIImageView()
        
        return img
    }()
    
    
    
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateUIWithData(_ model: AnyObject?) {
        let portTmp: FileObject = model as! FileObject
        self.titleLabel.text = portTmp.name
        //        self.couponNumLabel.text = "券码 " + formatCouponNum(model.qrCode ?? "")
        //        self.timeLabel.text = Date.getDateFormatter("yyyy/MM/dd HH:mm:ss", (model.time?.toDouble())!)
        
        //1544514588
        //        self.titleLabel.text = "老凤祥黄金券名称"
        //        self.couponNumLabel.text = "券码 " + formatCouponNum("145673443768778")
        //        self.timeLabel.text = Date.getDateFormatter("yyyy/MM/dd HH:mm:ss", 1544514588)

    }
    func configureView()  {
        self.addSubview(self.iconImage)
        self.iconImage.snp.makeConstraints { (make) in
            make.left.equalTo(self.snp.left).offset(15);
            make.centerY.equalTo(self.snp.centerY);
//            make.width.equalTo(30)
//            make.height.equalTo(30)

        }
        
        
        
        
        
        self.addSubview(self.titleLabel)
        self.titleLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.iconImage.snp.right).offset(12)
            make.top.equalTo(self.snp.top).offset(15)
//            make.right.equalTo(self.timeLabel.snp.left).offset(-5)
//            make.height.equalTo(21)
        }
        
        self.addSubview(self.timeLabel)
        self.timeLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.titleLabel).offset(0)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(11)
        }
        
        
        self.addSubview(self.couponNumLabel)
        self.couponNumLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.snp.left).offset(12)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(5)
        }
        
        let sepView = UIView.init()
        sepView.backgroundColor = "EEEEEE".HEXColor()
        self.addSubview(sepView)
        sepView.snp.makeConstraints { (make) in
            make.left.equalTo(self.snp.left).offset(12)
            make.right.bottom.equalTo(self)
            make.height.equalTo(1)
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
