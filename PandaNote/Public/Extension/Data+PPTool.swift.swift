//
//  Data+PPTool.swift.swift
//  PandaNote
//
//  Created by Panway on 2021/11/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation

extension Data {
    // Data类型的JSON 转 Dict 对象
    func pp_JSONObject() -> [String: Any]? {
        // return (try? JSONSerialization.jsonObject(with: self, options: [])) as? [String: Any]
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: []) as? [String: Any]
            return json
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }
}
