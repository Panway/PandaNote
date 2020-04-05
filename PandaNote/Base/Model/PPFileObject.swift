//
//  PPFileObject.swift
//  PandaNote
//
//  Created by panwei on 2020/4/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
import FilesProvider

class PPFileObject: FileObject,NSCoding {
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(modifiedDate, forKey: "modifiedDate")
        coder.encode(size, forKey: "size")
        coder.encode(isDirectory, forKey: "isDirectory")
    }
    
    required init?(coder: NSCoder) {
//        super.init(coder: coder)
        let name : String = coder.decodeObject(forKey: "name") as? String ?? ""
//        let modifiedDate = coder.decodeObject(forKey: "modifiedDate") as? Date ?? ""
//        self.size = coder.decodeInt64(forKey: "size") as? String ?? ""
//        self.isDirectory = coder.decodeBool(forKey: "isDirectory")
//        coder.encode(name, forKey: "name")
        //        coder.encode(image, forKey: "image")
        super.init(url: nil, name: name, path: "")

    }
    
    
}
