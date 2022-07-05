//
//  PPFileListCell.swift
//  PandaNote
//
//  Created by Panway on 2022/7/2.
//  Copyright © 2022 Panway. All rights reserved.
//

import UIKit
import Kingfisher

@objc enum PPFileListCellViewMode : Int {
    case list
    case listLarge
    case listSuperLarge
    case grid
    case gridLarge
    case gridSuperLarge
}

public protocol PPFileListCellDelegate:AnyObject {
    func didClickMoreBtn(cellIndex:Int, sender:UIButton)

}

class PPFileListCell: PPBaseCollectionViewCell {
    var itemsPerRow: CGFloat = 3
    weak var delegate: PPFileListCellDelegate?
    private let imageWidth = 50.0
    var cellIndex = 0
    
    private var viewMode = PPFileListCellViewMode.list //默认是列表
    private var cellPadding = 8
    private let screenWidth: CGFloat = UIScreen.main.bounds.width
    private var iconImage : UIImageView = {
        let img = UIImageView()
        return img
    }()
    
    private var titleLabel : UILabel = {
        let label = UILabel();
        label.textColor = "333333".HEXColor()
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    private var timeLabel : UILabel = {
        let label = UILabel();
        label.textColor = "999999".HEXColor()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()
    
    
    
    override func pp_addSubViews() {
        self.contentView.addSubview(self.iconImage)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.timeLabel)
        timeLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.titleLabel)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(8)
        }
        self.contentView.clipsToBounds = true
        
        let moreBtn = UIButton(type: .custom)
        self.contentView.addSubview(moreBtn)
        moreBtn.snp.makeConstraints { make in
            make.right.equalTo(self.contentView).offset(-5)
            make.centerY.equalTo(self.contentView)
        }
        moreBtn.addTarget(self, action: #selector(moreBtnClick(sender:)), for: .touchUpInside)
        moreBtn.setTitle("·", for: .normal)
        moreBtn.setTitleColor(.lightGray, for: .normal)
        moreBtn.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        pp_listMode()
    }
    
    func pp_listMode() {
        //https://aplus.rs/2017/one-solution-for-90pct-auto-layout/
        //But for way too brief moment, UICollectionViewCell was 0-wide sometime along the way and that caused the error output. eg:
//        "<NSAutoresizingMaskLayoutConstraint:0x280f88050 h=--& v=--& UIView:0x1033d6280.minX == 0   (active, names: '|':PandaNote.PPFileListCell:0x1033d6850 )>",
//        "<NSAutoresizingMaskLayoutConstraint:0x280f880a0 h=--& v=--& UIView:0x1033d6280.width == 0   (active)>",
        iconImage.snp.remakeConstraints { (make) in
//set priority to 999 for half of your constraints in horizontal and/or vertical dimension
            make.top.equalTo(self.contentView).offset(8).priority(999)
            make.left.equalTo(self.snp.left).offset(8).priority(999)
            make.bottom.equalTo(self.contentView).offset(-8)
            make.width.equalTo(iconImage.snp.height)//.multipliedBy(1)
        }
        
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.boldSystemFont(ofSize: CGFloat(15 + viewMode.rawValue*2))
        titleLabel.snp.remakeConstraints { (make) in
            make.top.equalTo(iconImage).offset(0)
            make.left.equalTo(iconImage.snp.right).offset(8)
            make.right.equalTo(self.contentView).offset(-25)
        }
        
        timeLabel.isHidden = false
        
    }
    
    func pp_gridMode() {
        self.iconImage.snp.remakeConstraints { (make) in
            make.top.equalTo(self.contentView.snp.top).offset(6).priority(999)
            make.left.equalTo(self.contentView).offset(8).priority(999)
            make.right.equalTo(self.contentView).offset(-8).priority(999)
            make.height.equalTo(iconImage.snp.width)//.multipliedBy(1)
        }
        
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        titleLabel.snp.remakeConstraints { (make) in
            make.top.equalTo(iconImage.snp.bottom).offset(8)
            make.left.equalTo(self.contentView).offset(5).priority(999)
            make.right.equalTo(self.contentView).offset(-5).priority(999)
        }
        
        timeLabel.isHidden = true
    }
    
    func updateLayout(_ mode:PPFileListCellViewMode) {
        if self.viewMode == mode {
            return
        }
        self.viewMode = mode
        if mode == .list {
            pp_listMode()
        }
        else if mode == .listLarge {
            pp_listMode() //emmm...
        }
        else if mode == .listSuperLarge {
            pp_listMode()
        }
        else {
            pp_gridMode()
        }
    }
    ///更新文件列表数据
    override func updateUIWithData(_ model: AnyObject?) {
        let fileObj: PPFileObject = model as! PPFileObject
        self.titleLabel.text = fileObj.name
        if fileObj.isDirectory {
            self.iconImage.image = UIImage(named: "ico_folder")
        }
        else if (fileObj.name.pp_isImageFile())  {
            let imagePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(fileObj.path)"
            if FileManager.default.fileExists(atPath: imagePath) {
                //使用略缩图 显示略缩图 减少内存占用
                //https://github.com/onevcat/Kingfisher/wiki/Cheat-Sheet#processor
                let processor = DownsamplingImageProcessor(size: CGSize(width: imageWidth*3, height: imageWidth*3))
                self.iconImage.kf.setImage(with: URL(fileURLWithPath: imagePath), options: [.processor(processor)])
            }
            else {
                self.iconImage.image = UIImage(named: "ico_jpg")
            }
        }
        else {
            if let icon = PPUserInfo.shared.pp_fileIcon[fileObj.name.pp_fileExtension] {
                self.iconImage.image = UIImage(named: icon)
            }
            else {
                self.iconImage.image = UIImage(named: "ico_jpg")
            }
        }
        
        let sizeStr = (fileObj.size>0) ? " - \(Int(fileObj.size).pp_SizeString())" :""
        self.timeLabel.text = fileObj.modifiedDate + sizeStr
    }
    
    func getSize(_ mode:PPFileListCellViewMode) -> CGSize {
        viewMode = mode
        if viewMode == .list {
            return CGSize(width: screenWidth, height: 50)
        }
        else if viewMode == .listLarge {
            return CGSize(width: screenWidth, height: 60)
        }
        else if viewMode == .listSuperLarge {
            return CGSize(width: screenWidth, height: 70)
        }
        else if viewMode == .grid {
            itemsPerRow = CGFloat(Int(screenWidth / 70.0))
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem + 52)
        }
        else if viewMode == .gridLarge {
            itemsPerRow = CGFloat(Int(screenWidth / 110.0))
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem + 52)
        }
        else if viewMode == .gridSuperLarge {
            itemsPerRow = CGFloat(Int(screenWidth / 140.0))
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem + 52)
        }
        return CGSize.zero
    }
    
    @objc func moreBtnClick(sender:UIButton) {
        debugPrint("moreBtnClick:\(cellIndex)")
        self.delegate?.didClickMoreBtn(cellIndex: cellIndex,sender: sender)
    }
}
