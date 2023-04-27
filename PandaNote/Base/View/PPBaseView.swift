//
//  PPBaseView.swift
//  PandaNote
//
//  Created by panwei on 2020/4/8.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit

public class PPBaseView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        pp_addSubviews()
    }
    func pp_addSubviews() {
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
