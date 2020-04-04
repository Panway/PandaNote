//
//  PPCacheManager.swift
//  PandaNote
//
//  Created by panwei on 2019/11/24.
//  Copyright © 2019 WeirdPan. All rights reserved.
//

import Foundation

class PPDiskCache {
    static let shared = PPDiskCache()
    
    
    public let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/PPAPICache/"


    open lazy var cacheQueue : DispatchQueue = {
        let queueName = "com.panda.cacheQueue"
        let cacheQueue = DispatchQueue(label: queueName, attributes: [])
        return cacheQueue
    }()
    
    public init() {
        self.cacheQueue.async(execute: {
            do {
                try FileManager.default.createDirectory(atPath: self.path, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                debugPrint("==FileManager Crash")
            }
        })
    }
    
    open func setData( _ getData: @autoclosure @escaping () -> Data?, key: String) {
        cacheQueue.async(execute: {
            if let data = getData() {
                self.setDataSync(data, key: key)
            } else {
                debugPrint("Failed to get data for key \(key)")
            }
        })
    }
    
    open func fetchData(key: String, failure fail: ((Error?) -> ())? = nil, success succeed: @escaping (Data) -> ()) {
        cacheQueue.async {
            let path = self.path(forKey: key)
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: Data.ReadingOptions())
                DispatchQueue.main.async {
                    succeed(data)
                }
                self.updateDiskAccessDate(atPath: path)
            } catch {
                if let block = fail {
                    DispatchQueue.main.async {
                        block(error)
                    }
                }
            }
        }
    }

    open func removeData(with key: String) {
        cacheQueue.async(execute: {
            let path = self.path(forKey: key)
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
            let path = self.path(forKey: key)
            let fileManager = FileManager.default
            if (!(fileManager.fileExists(atPath: path) && self.updateDiskAccessDate(atPath: path))){
                if let data = getData() {
                    self.setDataSync(data, key: key)
                } else {
                    debugPrint( "Failed to get data for key \(key)")
                }
            }
        })
    }

    open func path(forKey key: String) -> String {
        let keyPath = (self.path as NSString).appendingPathComponent(key)
        return keyPath
    }
    
    // MARK: Private
    
    fileprivate func setDataSync(_ data: Data, key: String) {
        let path = self.path(forKey: key)
        
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
