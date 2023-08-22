//
//  NSAttributedString+PPExtension.swift
//  PandaNote
//
//  Created by Panway on 2023/8/22.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

extension NSAttributedString {
    
    func pp_attributes(at index: Int) -> [NSAttributedString.Key: Any]? {
        if index > self.length || self.length == 0 {
            return nil
        }
        if self.length > 0 && index == self.length {
            return self.attributes(at: index - 1, effectiveRange: nil)
        }
        return self.attributes(at: index, effectiveRange: nil)
    }
    
    var wholeRange: NSRange {
        return NSRange(location: 0, length: length)
    }
}


