//
//  UIView+PPTool.swift
//  PandaNote
//
//  Created by topcheer on 2021/1/18.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import ObjectiveC

// Declare a global var to produce a unique address as the assoc object handle
private var AssociatedObjectHandle: UInt8 = 0

extension UIView {
    //给任意UIView对象动态增加一个属性https://stackoverflow.com/a/25428409
    var pp_stringTag:String {
        get {
            return objc_getAssociatedObject(self, &AssociatedObjectHandle) as? String ?? ""
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    
}
