//
//  PPTextField.swift
//  PandaNote
//
//  Created by Panway on 2023/4/23.
//  Copyright © 2023 Panway. All rights reserved.
//


class PPTextField: UITextField {
    //使用textRectForBounds修改UITextField的内间距
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let padding = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        return bounds.inset(by: padding)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let padding = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        return bounds.inset(by: padding)
    }
}
