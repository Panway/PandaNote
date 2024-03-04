//
//  PPCloudServiceError.swift
//  PandaNote
//
//  Created by pan on 2024/2/18.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation

class PPCloudServiceBaseModel{

    var error : PPCloudServiceError!
    var success : Bool!


    /**
     * Instantiate the instance using the passed dictionary values to set the properties values
     */
//    init(fromDictionary dictionary: [String:Any]){
//        if let errorData = dictionary["error"] as? [String:Any]{
//            error = PPCSError(fromDictionary: errorData)
//        }
//        success = dictionary["success"] as? Bool
//    }

}

class PPCSError{

    var code : Int!


    /**
     * Instantiate the instance using the passed dictionary values to set the properties values
     */
    init(fromDictionary dictionary: [String:Any]){
        code = dictionary["code"] as? Int
    }

}
