//
//  PPFileListToolBar.swift
//  PandaNote
//
//  Created by Panway on 2022/7/3.
//  Copyright © 2022 Panway. All rights reserved.
//

import UIKit

public protocol PPFileListToolBarDelegate:AnyObject {
    func didClickFileListToolBar(index:Int,title:String,button:UIButton)
}

class PPFileListToolBar: PPBaseView {
    var index = 0
    weak var delegate: PPFileListToolBarDelegate?
    private let names = ["排序","视图","多选","刷新"]
    private let icons = ["order_ascend","view_list","multi_select","refresh"]
    override func pp_addSubviews() {
        self.backgroundColor = .white
        names.enumerated().forEach { (index, name) in
            generateButton(icons[index], name)
        }

    }
    func generateButton(_ imageName:String,_ title:String) -> Void {
        let width = 44
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(self, action: #selector(toolButtonAction(sender:)), for:.touchUpInside)
//        button.backgroundColor = .white
        self.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(15 + index*width)
            make.width.equalTo(width)
            make.height.equalTo(44)
            make.top.equalToSuperview()
        }
        button.tag = index
        index += 1
        
        let label = UILabel();
        label.text = title
        label.textColor = .lightGray
        label.font = UIFont.systemFont(ofSize: 12)
        self.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalTo(button)
            make.top.equalTo(button.snp.bottom).offset(-5)
        }
    }
    @objc func toolButtonAction(sender:UIButton)  {
        self.delegate?.didClickFileListToolBar(index: sender.tag,title:names[sender.tag],button: sender)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
