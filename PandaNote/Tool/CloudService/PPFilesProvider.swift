//
//  PPFilesProvider.swift
//  PandaNote
//
//  Created by Panway on 2021/8/1.
//  Copyright © 2021 Panway. All rights reserved.
//

import UIKit
import FilesProvider

class PPFilesProvider {
    //MARK:- 数据处理
    /// FileObject is not what I want
    func myPPFileArrayFrom(_ contents:[FileObject]) -> [PPFileObject] {
        var fileArray = [PPFileObject]()
        var dirCount = 0
        //文件夹（目录）排在前面
        let directoryFirst = true
        for item in contents {
            let localDate = item.modifiedDate?.addingTimeInterval(TimeInterval(PPUserInfo.shared.pp_timezoneOffset))
            let dateStr = String(describing: localDate).substring(9..<25)
            let ppFile = PPFileObject()
            ppFile.name = item.name
            ppFile.path = item.path
            ppFile.size = item.size
            ppFile.isDirectory = item.isDirectory
            ppFile.modifiedDate = dateStr

            //添加到结果数组
            if item.isDirectory && directoryFirst {
                fileArray.insert(ppFile, at: dirCount)
                dirCount += 1
            }
            else {
                fileArray.append(ppFile)
            }
        }
        return fileArray
    }
}
