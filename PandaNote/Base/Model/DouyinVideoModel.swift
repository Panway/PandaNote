//
//  DouyinVideoModel.swift
//  PandaNote
//
//  Created by Panway on 2020/9/28.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import Foundation
import ObjectMapper




// MARK: - Cover
struct DouyinCover: Mappable {
    var uri: String?
    var urlList: [String]?
    
    init(){
        
    }
    
    init?(map: Map){
        
    }

    mutating func mapping(map: Map) {
        uri <- map["uri"]
        urlList <- map["url_list"]
    }
    
}


// MARK: - Video
struct DouyinVideo: Mappable {
    var playAddr: DouyinCover?
    var vid: String?
    var cover:DouyinCover?
    init(){
        
    }
    init?(map: Map) {

    }

    mutating func mapping(map: Map) {
        playAddr <- map["play_addr"]
        vid <- map["vid"]
        cover <- map["cover"]
    }
}

// MARK: - DouyinItem

struct DouyinItem: Mappable {
    var desc: String?
    var aweme_id: String?
    var duration: Int?
    var aweme_type: Int?
    var video:DouyinVideo?
    
    init(){
        
    }
    
    init?(map: Map){
        
    }

    mutating func mapping(map: Map) {
        desc <- map["desc"]
        aweme_id <- map["aweme_id"]
        duration <- map["duration"]
        aweme_type <- map["aweme_type"]
        video <- map["video"]
    }
}
