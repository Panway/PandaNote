//
//  PPMarkdownOutlineCell.swift
//  PandaNote
//
//  Created by Panway on 2023/8/26.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

class PPMarkdownOutlineModel: NSObject {
    var title = ""
    var isSelected = false
}

class PPMarkdownOutlineCell: PandaFastTableViewCell {
    var titleLB = PPPaddedLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))

    
    override func pp_addSubviews() {
        titleLB.textColor = .darkGray
        titleLB.numberOfLines = 2
        titleLB.font = .systemFont(ofSize: 16)
        self.contentView.addSubview(titleLB)
    }
    
    override func updateUI(withData data: Any) {
        
        if let text = data as? PPMarkdownOutlineModel {
            if text.isSelected {
                titleLB.font = .boldSystemFont(ofSize: 18.0)
            }
            else {
                titleLB.font = .systemFont(ofSize: 16)
            }
            // 判断一个字符串前面有几个#
            let count = text.title.prefix(while: { $0 == "#" }).count
            // 设置左间距
            titleLB.textInsets = UIEdgeInsets(top: 0, left: CGFloat(20 * count), bottom: 0, right: 0)
            // 去掉前面所有的#
            titleLB.text = text.title.pp_removeLeadingCharacter("#")
            let labelSize = titleLB.sizeThatFits(CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
            PPAppConfig.shared.outlineMaxWidth = max(labelSize.width, PPAppConfig.shared.outlineMaxWidth)
        }
        if let text = data as? NSMutableAttributedString {
            titleLB.attributedText = text
            
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLB.frame = self.bounds
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
