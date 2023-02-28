//
//  PPFileListToolBar.swift
//  PandaNote
//
//  Created by topcheer on 2022/7/3.
//  Copyright © 2022 WeirdPan. All rights reserved.
//

import UIKit

public protocol PPFileListToolBarDelegate:AnyObject {
    func didClickFileListToolBar(index:Int,title:String,button:UIButton)
}

class PPFileListToolBar: PPBaseView {
    var index = 0
    weak var delegate: PPFileListToolBarDelegate?

    override func pp_addSubviews() {
        self.backgroundColor = .white
        generateButton("order_ascend")
        generateButton("view_list")
        generateButton("multi_select")

    }
    func generateButton(_ imageName:String) -> Void {
        let width = 44
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(self, action: #selector(toolButtonAction(sender:)), for:.touchUpInside)
//        button.backgroundColor = .white
        self.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15 + index*width)
            make.width.equalTo(width)
            make.top.bottom.equalToSuperview()
        }
        button.tag = index
        index += 1
    }
    @objc func toolButtonAction(sender:UIButton)  {
        self.delegate?.didClickFileListToolBar(index: sender.tag,title:"",button: sender)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
