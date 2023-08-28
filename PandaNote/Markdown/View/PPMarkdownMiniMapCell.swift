//
//  PPMarkdownMiniMapCell.swift
//  PandaNote
//
//  Created by Panway on 2023/8/26.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

class PPMarkdownMiniMapCell: PandaFastTableViewCell {
    var titleLB = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))

    
    override func pp_addSubviews() {
        titleLB.textColor = .darkGray
        titleLB.numberOfLines = 2
        titleLB.font = .systemFont(ofSize: 16)
//        titleLB.text = ""
        self.contentView.addSubview(titleLB)
    }
    override func updateUI(withData data: Any) {
        if let text = data as? String {
            titleLB.text = text
            
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
