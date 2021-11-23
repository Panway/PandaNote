//
//  Data+PPTool.swift.swift
//  PandaNote
//
//  Created by Panway on 2021/11/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation

extension Data {
    func pp_JSONObject() -> [String: Any]? {
        return (try? JSONSerialization.jsonObject(with: self, options: [])) as? [String: Any]
    }
}
