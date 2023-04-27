//
//  String+PPFileManage.swift
//  PandaNote
//
//  Created by Panway on 2023/4/4.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation

extension String {
    /// 计算目录总共占用多少空间
    /// - Returns: 总字节数 total Byte
    func pp_calculateDirectorySize() -> Int64 {
//        let directory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "/Panda"
        let directory = self
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        /// 使用 FileManager 的 attributesOfItem(atPath:) 方法获取文件属性，然后累加每个文件的大小即可
        if let files = fileManager.enumerator(atPath: directory) {
            for case let file as String in files {
                let filePath = URL(fileURLWithPath: directory).appendingPathComponent(file).path
                if let attributes = try? fileManager.attributesOfItem(atPath: filePath) {
                    totalSize += attributes[.size] as? Int64 ?? 0
                }
            }
        }
        
        return totalSize
    }
    
    /// 移除目录所有文件
    func pp_removeAllFiles() {
        let directory = self
        let fileManager = FileManager.default
        
        if let files = fileManager.enumerator(atPath: directory) {
            for case let file as String in files {
                let filePath = URL(fileURLWithPath: directory).appendingPathComponent(file).path
                try? fileManager.removeItem(atPath: filePath)
            }
        }
    }

    func pp_getFileModificationDate() -> Date {
//        let fileURL = URL(fileURLWithPath: self)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self)
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                print("File modified on \(modificationDate)")
                return modificationDate
            }
            else {
                if let creationDate = attributes[.creationDate] as? Date {
                    print("File created on \(creationDate)")
                    return creationDate
                }
            }
        } catch {
            print("Error getting file attributes: \(error.localizedDescription)")
        }
        return Date()

    }
}
