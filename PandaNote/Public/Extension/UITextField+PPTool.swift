//
//  UITextField+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2023/11/2.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

extension UITextField {
    //https://stackoverflow.com/a/58006735/4493393
    //here is how I selecte file name `Panda` from `Panda.txt`
    func selectNamePartOfFileName() {
        guard let string = self.text else { return }
        let nameParts = string.split(separator: ".")
        var offset = 0
        if nameParts.count > 1 {
            // if textField.text is `Panda.txt`, so offset will be 3+1=4
            offset = String(string.split(separator: ".").last!).length + 1
        }
        let from = self.position(from: self.beginningOfDocument, offset: 0)
        let to = self.position(from: self.beginningOfDocument,
                                    offset:string.length - offset)
        //now `Panda` will be selected
        self.selectedTextRange = self.textRange(from: from!, to: to!)//danger! unwrap with `!` is not recommended  危险，不推荐用！解包
    }
}
