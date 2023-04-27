//
//  PPDropDown.swift
//  PandaNote
//
//  Created by Panway on 2022/7/2.
//  Copyright © 2022 Panway. All rights reserved.
//

import UIKit
import DropDown

//方便以后统一更换
class PPDropDown: NSObject {
    let dropDown = DropDown()
    override init() {
        super.init()
        DropDown.appearance().cellHeight = 50
        DropDown.appearance().setupCornerRadius(10)
//        DropDown.appearance().dimmedBackgroundColor = UIColor.lightGray
    }
    
    public var dataSource = [String]() {
        didSet {
            dropDown.dataSource = dataSource
        }
    }
    
    public var width : CGFloat? {
        didSet {
            dropDown.width = width
        }
    }
    
    public weak var anchorView: AnchorView? {
        didSet {  dropDown.anchorView = anchorView }
    }
    
    

    var selectionAction: ((_ index : Int, _ string: String) -> ())? {
        didSet {
            dropDown.selectionAction = selectionAction;
        }
    }
    func show(){
        dropDown.show()
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
