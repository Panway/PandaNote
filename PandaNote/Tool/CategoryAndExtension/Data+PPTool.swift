//
//  Data+PPTool.swift
//  PandaNote
//
//  Created by topcheer on 2021/3/22.
//  Copyright © 2021 WeirdPan. All rights reserved.
//

import Foundation
import CryptoSwift

extension Data {
    func pp_md5() -> String {
        self.md5().toHexString()
    }
}
