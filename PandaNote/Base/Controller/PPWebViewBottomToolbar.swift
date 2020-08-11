//
//  PPWebViewBottomToolbar.swift
//  PandaNote
//
//  Created by topcheer on 2020/8/6.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

//import Foundation

class PPWebViewBottomToolbar: UIView {
    var backButton : UIButton!
    var forwardButton : UIButton!
    override init(frame: CGRect) {
        super.init(frame: frame)
        pp_addSubviews()
    }
    func pp_addSubviews() {
        backButton = UIButton.init(type: UIButton.ButtonType.custom)
        self.addSubview(backButton)
        backButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        backButton.setTitle("⬅️", for: UIControl.State.normal)
        backButton.setTitle("", for: .disabled)
        backButton.snp.makeConstraints { (make) in
            make.top.equalTo(self)
            make.right.equalTo(self.snp.centerX).offset(-5)
            make.width.equalTo(44)
            make.height.equalTo(44)
        }
        
        forwardButton = UIButton.init(type: UIButton.ButtonType.custom)
        self.addSubview(forwardButton)
        forwardButton.frame = CGRect.init(x: 40, y: 0, width: 40, height: 40)
        forwardButton.setTitle("➡️", for: UIControl.State.normal)
        forwardButton.setTitle("", for: .disabled)
        forwardButton.snp.makeConstraints { (make) in
            make.top.equalTo(self)
            make.left.equalTo(self.snp.centerX).offset(5)
            make.size.equalTo(backButton)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
