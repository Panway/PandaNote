//
//  PPMarkdownKeyboardToolBar.swift
//  PandaNote
//
//  Created by Panway on 2021/12/22.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit

public protocol PPEditorToolBarDelegate: AnyObject {
    func didClickEditorToolBar(sender:UIButton,index:Int,totalCount:Int)
}

class PPMarkdownEditorToolBar: PPBaseView {
    var index = 0
    weak var delegate: PPEditorToolBarDelegate?

    override func pp_addSubviews() {
        self.backgroundColor = .white
        generateButton("editor_image")
        generateButton("btn_down")
        
    }
    func generateButton(_ imageName:String) -> Void {
        let width = 40
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(self, action: #selector(toolButtonAction(sender:)), for:.touchUpInside)
//        button.backgroundColor = .white
        self.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(index*width)
            make.width.equalTo(width)
            make.top.bottom.equalToSuperview()
        }
        button.tag = index
        index += 1
    }
    @objc func toolButtonAction(sender:UIButton)  {
        self.delegate?.didClickEditorToolBar(sender: sender, index: sender.tag,totalCount:index)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
