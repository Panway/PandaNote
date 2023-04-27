//
//  PPCacheManager.swift
//  PandaNote
//
//  Created by panwei on 2019/11/24.
//  Copyright © 2019 WeirdPan. All rights reserved.
//  https://github.com/Haneke/HanekeSwift/blob/master/Haneke/DiskCache.swift

public enum PPDiskCacheError: Error {
    /// 文件不存在错误
    case fileNotExist
}

import Foundation
import PINCache

class PPDiskCache {
    static let shared = PPDiskCache()
    
    ///缓存路径`/Library/Caches/PandaCache`
    public let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/PandaCache"


    open lazy var cacheQueue : DispatchQueue = {
        let queueName = "com.panda.cacheQueue"
        let cacheQueue = DispatchQueue(label: queueName, attributes: [])
        return cacheQueue
    }()
    
    public init() {
        self.cacheQueue.async(execute: {
            do {
                debugPrint("PP缓存路径：\(self.path)")
                try FileManager.default.createDirectory(atPath: self.path, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                debugPrint("==FileManager Crash")
            }
        })
    }
    ///保存到`/Library/Caches/PPAPICache`
    open func setData( _ getData: @autoclosure @escaping () -> Data?, key: String) {
        cacheQueue.async(execute: {
            if let data = getData() {
                self.setDataSync(data, key: key)
            } else {
                debugPrint("Failed to setData for key \(key)")
            }
        })
    }
    open func setDataSynchronously( _ getData: @autoclosure @escaping () -> Data?, key: String) {
        if let data = getData() {
            self.setDataSync(data, key: key)
        } else {
            debugPrint("Failed to setDataSynchronously for key \(key)")
        }
    }
    open func fetchData(key: String,
                        returnURL : Bool? = false,
                        success: @escaping (Data?) -> (),
                        failure: ((Error?) -> ())? = nil) {
        cacheQueue.async {
            let path = self.fullPath(forKey: key)
            if FileManager.default.fileExists(atPath: path) {
                if let onlyCheckIfFileExist = returnURL, onlyCheckIfFileExist == true {
                    DispatchQueue.main.async {
                        success(nil)
                    }
                    return
                }
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: Data.ReadingOptions())
                    DispatchQueue.main.async {
                        success(data)
                    }
                    self.updateDiskAccessDate(atPath: path)
                } catch {
                    if let failHandler = failure {
                        DispatchQueue.main.async {
                            failHandler(error)
                        }
                    }
                }
            }
            else {
                //文件不存在
                DispatchQueue.main.async {
                    failure?(PPDiskCacheError.fileNotExist)
                }
            }
        }
    }

    open func removeData(with key: String) {
        cacheQueue.async(execute: {
            let path = self.fullPath(forKey: key)
            self.removeFile(atPath: path)
        })
    }
    
    open func removeAllData(_ completion: (() -> ())? = nil) {
        let fileManager = FileManager.default
        let cachePath = self.path
        cacheQueue.async(execute: {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: cachePath)
                for pathComponent in contents {
                    let path = (cachePath as NSString).appendingPathComponent(pathComponent)
                    do {
                        try fileManager.removeItem(atPath: path)
                    } catch {
                        debugPrint( "Failed to remove path \(path)")
                    }
                }
            } catch {
                debugPrint( "Failed to list directory")
            }
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        })
    }

    open func updateAccessDate( _ getData: @autoclosure @escaping () -> Data?, key: String) {
        cacheQueue.async(execute: {
            let path = self.fullPath(forKey: key)
            let fileManager = FileManager.default
            if (!(fileManager.fileExists(atPath: path) && self.updateDiskAccessDate(atPath: path))){
                if let data = getData() {
                    self.setDataSync(data, key: key)
                } else {
                    debugPrint( "Failed to updateAccessDate for key \(key)")
                }
            }
        })
    }

    open func fullPath(forKey key: String) -> String {
        let fullFilePath = (self.path as NSString).appendingPathComponent(key)
        return fullFilePath
    }
    
    // MARK: Private
    
    fileprivate func setDataSync(_ data: Data, key: String) {
        let path = self.fullPath(forKey: key)
        
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        }
        
        do {
            try data.write(to: URL(fileURLWithPath: path), options: Data.WritingOptions.atomicWrite)
        } catch {
            debugPrint("Failed to write key \(key)")
        }
        
    }
    
    @discardableResult fileprivate func updateDiskAccessDate(atPath path: String) -> Bool {
        let fileManager = FileManager.default
        let now = Date()
        do {
            try fileManager.setAttributes([FileAttributeKey.modificationDate : now], ofItemAtPath: path)
            return true
        } catch {
            debugPrint( "Failed to update access date")
            return false
        }
    }
    
    fileprivate func removeFile(atPath path: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            if isNoSuchFileError(error) {
                debugPrint( "File not found")
            } else {
                debugPrint( "Failed to remove file")
            }
        }
    }

}

private func isNoSuchFileError(_ error : Error?) -> Bool {
    if let error = error {
        return NSCocoaErrorDomain == (error as NSError).domain && (error as NSError).code == NSFileReadNoSuchFileError
    }
    return false
}










class PPCacheManeger {
    static let shared = PPCacheManeger()
    let pinCache = PINCache.init(name: "PPPINCache")
    func set(_ object:String,key:String) {
        pinCache.setObject(object, forKey: key)
    }
    
    func get(_ key:String) -> String {
        if let value = pinCache.object(forKey: key) as? String {
            return value
        }
        return ""
    }
}
