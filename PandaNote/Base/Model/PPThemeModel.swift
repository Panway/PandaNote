//
//  PPThemeModel.swift
//  PandaNote
//
//  Created by Panway on 2021/11/23.
//  Copyright © 2021 Panway. All rights reserved.
//

import Foundation
import ObjectMapper

// MARK: - PPThemeModel
struct PPThemeModel: Mappable {
    var backgroundImageName : String!
    var baseTextColor : String!
    var backgroundColor : String!
    var codeBackgroundColor : String!
    var lightTextColor : String!
    var linkTextColor : String!
    var quoteTextColor : String!
    var selectedTextBackgroundColor : String!
    var titleTextColor : String!
    
    init(){
        
    }
    
    init?(map: Map){
        
    }

    mutating func mapping(map: Map) {
        backgroundImageName <- map["backgroundImageName"]
        baseTextColor <- map["baseTextColor"]
        backgroundColor <- map["backgroundColor"]
        codeBackgroundColor <- map["codeBackgroundColor"]
        lightTextColor <- map["lightTextColor"]
        linkTextColor <- map["linkTextColor"]
        quoteTextColor <- map["quoteTextColor"]
        selectedTextBackgroundColor <- map["selectedTextBackgroundColor"]
        titleTextColor <- map["titleTextColor"]

    }
    
}
