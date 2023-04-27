//
//  PPMarkdownKeyboardToolBar.swift
//  PandaNote
//
//  Created by Panway on 2021/12/22.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit

public protocol PPEditorToolBarDelegate: AnyObject {
    func didClickEditorToolBar(toolBar:PPMarkdownEditorToolBar, index:Int,totalCount:Int)
}

public class PPMarkdownEditorToolBar: PPBaseView {
    var index = 0
    weak var delegate: PPEditorToolBarDelegate?
    var images = [String]()
    override func pp_addSubviews() {
        //self.backgroundColor = .white
        
//        generateButton("editor_image")
//        generateButton("btn_down")
        
    }
//    required init?(coder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
//    init(frame:CGRect, images: [String]) {
//        super.init(frame: frame)

    convenience init(frame: CGRect, images:[String]) {
        self.init(frame: frame)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: frame.size.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        self.images = images
        for i in images {
            generateButton(i)
        }
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
        self.delegate?.didClickEditorToolBar(toolBar: self, index: sender.tag,totalCount:index)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
