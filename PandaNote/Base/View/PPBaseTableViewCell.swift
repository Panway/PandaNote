//
//  PPBaseTableViewCell.swift
//  TeamDisk
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//

import UIKit
import SnapKit


let kPPBaseCellIdentifier = "kPPBaseCellIdentifier"

class PPBaseTableViewCell: UITableViewCell {
    //记录第几区 第几行
    var pp_section = 0
    var pp_row = 0
    
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        pp_addSubViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func pp_addSubViews() {
        
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    func updateUIWithData(_ model:AnyObject?)  {
        
    }
}
extension PPBaseTableViewCell {
    
    
    
}
