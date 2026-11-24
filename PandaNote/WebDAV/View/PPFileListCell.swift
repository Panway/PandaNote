//
//  PPFileListCell.swift
//  PandaNote
//
//  Created by Panway on 2022/7/2.
//  Copyright © 2022 Panway. All rights reserved.
//

import UIKit
import Kingfisher

// 解决Xcode15重名错误 Incorrect argument labels in call (have 'downloadURL:cacheKey:', expected 'name:bundle:')
typealias KFImageResource = Kingfisher.ImageResource

@objc enum PPFileListCellViewMode : Int {
    case list
    case listLarge
    case listSuperLarge
    case grid
    case gridLarge
    case gridSuperLarge
    case photoAlbum
    case photoAlbumLarge
    case photoAlbumSuperLarge
}

public protocol PPFileListCellDelegate:AnyObject {
    func didClickMoreBtn(cellIndex:Int, sender:UIButton)

}

class PPFileListCell: PPBaseCollectionViewCell {
    var itemsPerRow: CGFloat = 3
    weak var delegate: PPFileListCellDelegate?
    private let imageWidth = 50.0
    var cellIndex = 0
    var isSelect = false ///< 跟isSelected区分
//    override var isSelected: Bool {
//        didSet {
//            // 在 isSelected 发生变化时执行的操作
//            updateSelectedState()
//        }
//    }
    private var viewMode = PPFileListCellViewMode.list //默认是列表
    /// 当前正在等缩略图的文件路径。cell 是复用的，异步回调回来必须核对一遍，否则快速滚动时会出现「A 的位置显示 B 的图」
    private var thumbnailPath = ""
    private var cellPadding = 8
    var moreBtn = UIButton(type: .custom)
    private let progressBar = CALayer()
//    private let screenWidth: CGFloat = UIScreen.main.bounds.width
    var iconImage : UIImageView = {
        let img = UIImageView()
        img.contentMode = .scaleAspectFit
        img.layer.masksToBounds = true
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
    
    var remarkLabel : UILabel = {
        let label = UILabel();
        label.textColor = "999999".HEXColor()
        label.font = UIFont.systemFont(ofSize: 11)
//        label.layer.borderColor = "eeeeee".HEXColor().cgColor
//        label.layer.borderWidth = 1
        return label
    }()
    
    private var downloadFinishedImage : UIImageView = {
        let img = UIImageView()
        img.contentMode = .scaleAspectFill
        img.image = UIImage(named: "download_finish")
        img.isHidden = true
        return img
    }()
    
    var selectedView : PPDrawIconView = {
        let v = PPDrawIconView(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
        v.iconName = "selected"
        v.backgroundColor = .white
        v.isHidden = true
        return v
    }()
    
    var unselectedView : PPDrawIconView = {
        let v = PPDrawIconView(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
        v.iconName = "unselected"
        v.backgroundColor = .white
        v.isHidden = true
        return v
    }()
    
    override func pp_addSubViews() {
        self.contentView.addSubview(self.iconImage)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.timeLabel)
        self.contentView.addSubview(self.remarkLabel)
        self.contentView.addSubview(self.downloadFinishedImage)
        self.contentView.addSubview(self.selectedView)
        self.contentView.addSubview(self.unselectedView)

        self.contentView.clipsToBounds = true
        
        //let moreBtn = UIButton(type: .custom)
        self.contentView.addSubview(moreBtn)
//        moreBtn.snp.makeConstraints { make in
//            make.right.equalTo(self.contentView)//.offset(-5)
//            make.centerY.equalTo(self.contentView)
//            make.size.equalTo(CGSize(width: 44,height: 66))
//        }
        moreBtn.addTarget(self, action: #selector(moreBtnClick(sender:)), for: .touchUpInside)
        moreBtn.setImage(UIImage(named: "more_actions"), for: .normal)
        //moreBtn.setTitle("·", for: .normal)
        //moreBtn.setTitleColor(.lightGray, for: .normal)
        //moreBtn.titleLabel?.font = UIFont.systemFont(ofSize: 30)
//        pp_listMode()
        progressBar.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:0.2).cgColor
        progressBar.frame = CGRect(x: 0, y: 0, width: 0, height: self.bounds.height)
        
        self.layer.addSublayer(progressBar)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 这一格要拿去显示别的文件了，之前那次缩略图请求的回调已经对不上号，清掉免得贴错图
        // 图片本身不用在这里清：updateUIWithData 每个分支都会重新赋值，而且 Kingfisher 没传 keepCurrentImageWhileLoading 时自己也会把 image 置空
        thumbnailPath = ""
        iconImage.kf.cancelDownloadTask()
        updateProgressBar(0)
    }

    func pp_listMode() {
        let cellW = self.contentView.frame.size.width
        let cellH = self.contentView.frame.size.height
        if(cellW == 0) {return}
        var titleH : CGFloat = 21.0 + CGFloat(viewMode.rawValue)*2
        if titleLabel.numberOfLines > 1 {
            titleH = titleLabel.text?.pp_calcTextHeight(font: titleLabel.font, fixedWidth: cellW - cellH - 50) ?? 30
            titleH = min(44, titleH)
        }
        let timeH = timeLabel.text?.pp_calcTextHeight(font: timeLabel.font, fixedWidth: cellW - cellH - 100) ?? 30
        let remarkW = remarkLabel.text?.pp_calcTextWidth(font: remarkLabel.font) ?? 100
        let top = 4.0 + CGFloat(viewMode.rawValue)*2
        iconImage.frame = CGRect(x: 8, y: top, width: cellH - top*2, height: cellH - top*2)
        titleLabel.frame = CGRect(x: 8 + cellH, y: titleH > 25 ? top : 8 + CGFloat(viewMode.rawValue)*2, width: cellW - cellH - 50, height: titleH)
        timeLabel.frame = CGRect(x: 8 + cellH, y: cellH - timeH - 5, width: cellW - cellH - 100, height: timeH)
        remarkLabel.frame = CGRect(x: cellW - remarkW - 50, y: cellH - timeH - 5, width: remarkW, height: timeH)
        moreBtn.frame = CGRect(x: cellW - 44, y: 0, width: 44, height: cellH)
        self.downloadFinishedImage.frame = CGRect(x: cellW - 30, y: cellH - 20, width: 20, height: 20)
        self.selectedView.frame = CGRect(x: cellW - 30, y: (cellH - 25)/2, width: 25, height: 25)
        self.unselectedView.frame = CGRect(x: cellW - 30, y: (cellH - 25)/2, width: 25, height: 25)
    }
    //已废弃
    func pp_listMode2() {
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
        
        titleLabel.snp.remakeConstraints { (make) in
            make.top.equalTo(iconImage).offset(0)
            make.left.equalTo(iconImage.snp.right).offset(8)
            make.right.equalToSuperview().offset(-25)
        }
        
        timeLabel.snp.remakeConstraints { (make) in
            make.left.equalTo(self.titleLabel)
            make.top.equalTo(self.titleLabel.snp.bottom).offset(8)
        }
        
        remarkLabel.snp.remakeConstraints { (make) in
            make.right.equalToSuperview().offset(-18)
            make.bottom.equalTo(timeLabel)
        }
        
    }
    //已废弃
    func pp_gridMode2() {
        self.iconImage.snp.remakeConstraints { (make) in
            make.top.equalTo(self.contentView.snp.top).offset(8).priority(999)
            make.left.equalTo(self.contentView).offset(8).priority(999)
            make.right.equalTo(self.contentView).offset(-8).priority(999)
            make.height.equalTo(iconImage.snp.width)//.multipliedBy(1)
        }
        
        titleLabel.snp.remakeConstraints { (make) in
            make.top.equalTo(iconImage.snp.bottom).offset(1)
            make.left.equalTo(self.contentView).offset(5).priority(999)
            make.right.equalTo(self.contentView).offset(-5).priority(999)
        }
        
        remarkLabel.snp.remakeConstraints { (make) in
            make.bottom.equalToSuperview().offset(-2)
            make.centerX.equalToSuperview()
        }
        
        timeLabel.snp.remakeConstraints { (make) in
            make.bottom.equalTo(self.remarkLabel.snp.top).offset(-5)
            make.centerX.equalToSuperview()
        }
    }
    
    func pp_gridMode() {
        let cellW = self.contentView.frame.size.width
        let cellH = self.contentView.frame.size.height

        if(cellW == 0) {return}
        let top : CGFloat = 8.0
        iconImage.frame = CGRect(x: 8, y: top, width: cellW - top*2, height: cellW - top*2)
        var titleH : CGFloat = titleLabel.text?.pp_calcTextHeight(font: titleLabel.font, fixedWidth: cellW - top*2) ?? 30
        titleH = min(titleH, 40)
        titleLabel.frame = CGRect(x: 8, y: cellW, width: cellW - top*2, height: titleH)
        moreBtn.frame = CGRect(x: 0, y: cellW + 33, width: cellW, height: 44)
        downloadFinishedImage.frame = CGRect(x: cellW - 30, y: cellH - 20, width: 20, height: 20)
        
    }
    
    func pp_photoAlbumMode() {
        let cellW = self.contentView.frame.size.width
        let cellH = self.contentView.frame.size.height
        if(cellW == 0) {return}
        let top : CGFloat = 1.0
        iconImage.frame = CGRect(x: top, y: top, width: cellW - top*2, height: cellW - top*2)
        downloadFinishedImage.frame = CGRect(x: cellW - 20, y: cellH - 20, width: 20, height: 20)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.viewMode.rawValue <= PPFileListCellViewMode.listSuperLarge.rawValue {
            pp_listMode()
        }
        else if self.viewMode.rawValue <= PPFileListCellViewMode.gridSuperLarge.rawValue {
            pp_gridMode()
        }
        else {
            pp_photoAlbumMode()
        }
    }
    func updateLayout(_ mode:PPFileListCellViewMode) {
        if self.viewMode == mode {
            return
        }
        self.viewMode = mode
        //debugPrint("布局",self.viewMode.rawValue)
        if mode.rawValue <= PPFileListCellViewMode.listSuperLarge.rawValue {
            titleLabel.isHidden = false
            timeLabel.isHidden = false
            titleLabel.numberOfLines = viewMode == .listSuperLarge ? 2 : 1
            titleLabel.textAlignment = .left
            titleLabel.font = UIFont.boldSystemFont(ofSize: CGFloat(15 + viewMode.rawValue*1))
            timeLabel.textAlignment = .left
        }
        else if mode.rawValue <= PPFileListCellViewMode.gridSuperLarge.rawValue {
            // 略缩图模式
            titleLabel.isHidden = false
            timeLabel.isHidden = true
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2
            titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
            timeLabel.textAlignment = .center
            moreBtn.setImage(UIImage(named: "more_actions"), for: .normal)
        }
        else {
            // 相册模式 Photo Gallery / photo album mode
            titleLabel.isHidden = true
            timeLabel.isHidden = true
        }
    }
    // 更新进度条
    func updateProgressBar(_ value: CGFloat) {
        let maxWidth = self.bounds.width
        let progressWidth = maxWidth * value
        if value > 0.9999 {
            self.progressBar.frame.size.width = 0 //下载完了就不显示进度条了
            self.downloadFinishedImage.isHidden = false
        }
        else {
            self.progressBar.frame.size.width = progressWidth
            self.downloadFinishedImage.isHidden = true
        }
    }
    // MARK: - 更新文件列表界面 update UI
    override func updateUIWithData(_ model: AnyObject) {
        let fileObj: PPFileObject = model as! PPFileObject
        // 记录这一格当前显示的文件路径，迟到的缩略图回调靠它判断格子是否已换文件。
        // 在方法开头统一赋值：不管这次走哪个分支（文件夹、带缩略图直连地址），旧路径都会被覆盖，
        // 上一次请求的回调就不会盖到新内容上
        self.thumbnailPath = fileObj.path
        self.titleLabel.text = fileObj.name
//        debugPrint("====downloadProgress=====",fileObj.downloadProgress)
        if !fileObj.isDirectory {
            updateProgressBar(fileObj.downloadProgress) //文件夹不显示下载完成图标
        }
        if fileObj.isDirectory {
            self.iconImage.image = UIImage(named: "ico_folder")
            updateProgressBar(0)
        }
        else if (fileObj.name.pp_isImageFile())  {
            if fileObj.thumbnail.length > 0 {
                // 先用占位图顶住，真正的大图在方法末尾统一交给 Kingfisher
                // 万一 thumbnail 串解析不出 URL（老数据里带空格或中文）那里会被整块跳过，不清这一下就会残留上一个文件的图
                self.iconImage.image = UIImage(named: "ico_jpg")
            }
            else {
            let imagePath = "\(PPDiskCache.shared.path)/\(PPUserInfo.shared.webDAVRemark)/\(fileObj.path)"
            if FileManager.default.fileExists(atPath: imagePath) {
                //使用略缩图 显示略缩图 减少内存占用
                //https://github.com/onevcat/Kingfisher/wiki/Cheat-Sheet#processor
                let processor = DownsamplingImageProcessor(size: CGSize(width: imageWidth*3, height: imageWidth*3))
                self.iconImage.kf.setImage(with: URL(fileURLWithPath: imagePath), options: [.processor(processor)])
            }
            else {
                self.iconImage.image = UIImage(named: "ico_jpg")
                // 没有缩略图直连地址的服务（Dropbox）自己产图：协议默认实现直接回 nil，
                // 不支持的服务走到这里就保持占位图标，不会发请求
                PPFileManager.shared.currentService?.loadThumbnail(path: fileObj.path,
                                                                   fileID: fileObj.pathID) { [weak self] image in
                    guard let self = self, let image = image else { return }
                    // 回调回来时这一格很可能已经换成别的文件了，路径对不上就别覆盖，否则会串图
                    guard self.thumbnailPath == fileObj.path else { return }
                    self.iconImage.image = image
                }
            }
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
        if let thumbnail = URL(string: fileObj.thumbnail), fileObj.thumbnail.length > 0 {
            let imageResource: KFImageResource
            if fileObj.thumbnailCacheKey.length > 0 {
                // 服务在解析时填好的稳定缓存 key（如阿里云盘去掉问号后每次都变的签名参数），
                // 避免同一张图每次刷新都重新下载
                imageResource = KFImageResource(downloadURL: thumbnail, cacheKey: fileObj.thumbnailCacheKey)
            }
            else {
                // 没有服务提供的稳定 key 就走 Kingfisher 默认（URL 自己当 key），
                // 不要强行传 thumbnail 字符串，否则所有服务的缓存 key 都会变、升级后缩略图重下一次
                imageResource = KFImageResource(downloadURL: thumbnail)
            }
            self.iconImage.kf.setImage(with: imageResource)
        }
        if(fileObj.modifiedDate.hasSuffix("Z")) {
            if let date = PPAppConfig.shared.utcDateFormatter.date(from: fileObj.modifiedDate) {
                //dateStyle为.medium时，日期样式为“yyyy-MM-dd”，timeStyle为.medium时，时间样式为“ah:mm:ss”
                //fileObj.modifiedDate = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
                fileObj.modifiedDate = PPAppConfig.shared.dateFormatter.string(from: date)
            }
        }
        let sizeStr = fileObj.size > 0 ? " - \(fileObj.size.pp_SizeString())" : ""
        self.timeLabel.text = fileObj.modifiedDate + sizeStr
        remarkLabel.text = fileObj.associatedServerName
    }
    /// cached file alpha=0.5 ; newset file alpha=1
    func updateCacheStatus(_ isCachedFile:Bool) {
        self.contentView.alpha = isCachedFile ? 0.7 : 1.0;
    }

    //macOS 改变App窗口大小后，屏幕宽度还是固定值，不能用
    class func getSize(_ mode:PPFileListCellViewMode,_ screenWidth:CGFloat ) -> CGSize {
//        print("screenWidth===\(screenWidth)")
        var itemsPerRow = 3.0;
        let viewMode = mode
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
            let columnNum = screenWidth > 414 ? max(4, floor(screenWidth / 80)) : 4
            let widthPerItem = screenWidth / columnNum
            return CGSize(width: widthPerItem, height: widthPerItem + 70)
        }
        else if viewMode == .gridLarge {
            let columnNum = screenWidth > 414 ? max(3, floor(screenWidth / 110)) : 3
            let widthPerItem = screenWidth / columnNum
            return CGSize(width: widthPerItem, height: widthPerItem + 70)
        }
        else if viewMode == .gridSuperLarge {
            itemsPerRow = floor(screenWidth / 140.0)
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem + 70)
        }
        else if viewMode == .photoAlbum {
            itemsPerRow = 5
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem)
        }
        else if viewMode == .photoAlbumLarge {
            itemsPerRow = 4
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem)
        }
        else if viewMode == .photoAlbumSuperLarge {
            itemsPerRow = 3
            let widthPerItem = screenWidth / itemsPerRow
            return CGSize(width: widthPerItem, height: widthPerItem)
        }
        return CGSize.zero
    }
    func updateSelectedState() {
        if isSelect {
            // 选中状态的外观
            debugPrint("isSelected",self.cellIndex)
            self.selectedView.isHidden = false
            self.unselectedView.isHidden = true
        } else {
            // 未选中状态的外观
            debugPrint("unSelected",self.cellIndex)
            self.selectedView.isHidden = true
            self.unselectedView.isHidden = false
        }
    }
    @objc func moreBtnClick(sender:UIButton) {
        debugPrint("moreBtnClick:\(cellIndex)")
        self.delegate?.didClickMoreBtn(cellIndex: cellIndex,sender: sender)
    }
    
    func downloadFile(_ fileObj:PPFileObject,
                      completion: @escaping (( _ localFilePath: String) -> Void)) {
        PPFileManager.shared.getLocalURL(path: fileObj.path, fileID: fileObj.pathID, downloadURL: fileObj.downloadURL) { progress in
            //debugPrint("downloadFile Progress: \(progress.fractionCompleted)")
            fileObj.downloadProgress = progress.fractionCompleted
            self.updateProgressBar(progress.fractionCompleted)
        } completion: { filePath in
            self.updateProgressBar(1.0)
            completion(filePath)
        }
    }
}
