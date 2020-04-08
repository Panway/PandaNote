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
    
    
    
    
    
    
    ///更新文件列表数据
    override func updateUIWithData(_ model: AnyObject?) {
        let fileObj: PPFileObject = model as! PPFileObject
//        self.titleLabel.text = fileObj.name
        
        self.titleLabel.text = fileObj.name
        if fileObj.isDirectory {
            //            cell.iconImage.kf.setImage(with: "" as! Resource)
            self.iconImage.image = UIImage.init(named: "ico_folder")
        }
        else if (fileObj.name.pp_isImageFile())  {
            let imagePath = PPUserInfo.shared.pp_mainDirectory + fileObj.path
//            self.currentImageURL = imagePath
            if FileManager.default.fileExists(atPath: imagePath) {
                let imageData = try?Data(contentsOf: URL(fileURLWithPath: imagePath))
                self.iconImage.image = UIImage.init(data: imageData!)
            }
            else {
                self.iconImage.image = UIImage.init(named: "ico_jpg")
            }
        }
        else {
            self.iconImage.image = UIImage.init(named: PPUserInfo.shared.pp_fileIcon[String(fileObj.name.split(separator: ".").last!)] ?? "ico_jpg")
        }
        
        let sizeStr = (fileObj.size>0) ? " - \(Int(fileObj.size).pp_SizeString())" :""
        self.timeLabel.text = fileObj.modifiedDate + sizeStr
        
        
        

    }
    
    
    override func pp_addSubViews() {
        self.addSubview(self.iconImage)
        self.iconImage.snp.makeConstraints { (make) in
            make.left.equalTo(self.snp.left).offset(15);
            make.centerY.equalTo(self.snp.centerY);
            make.width.equalTo(50)
            make.height.equalTo(50)

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
