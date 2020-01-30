//
//  PPSQLiteManager.swift
//  PandaNote
//
//  Created by panwei on 2020/1/27.
//  Copyright © 2020 WeirdPan. All rights reserved.
//https://github.com/nick6969/SQLManager/blob/master/SQLManager/Classes/SQLManager.swift

import Foundation
import FMDB
/*
 SQLDelegate使用方法：
class PriceDBModel: NSObject {
    
}
extension PriceDBModel: SQLDelegate {
    var sqlSyntaxs: [String] {
        return []
    }
    
    var dbPathName: String {
        return "/WeatherResult.db"
    }
    
    func tablePrimaryKey(table: String) -> String {
        return "id"
    }
}
*/
public protocol SQLDelegate: class {
    
    func tablePrimaryKey(table: String) -> String
    var sqlSyntaxs: [String] { get }
    var dbPathName: String { get }
}


class PPSQLiteManager: NSObject {
    // 单例,线程安全的
//    public static let shared =  PPSQLiteManager()
//    var dbPathName: String! = "/priceTag.db"
    fileprivate var delegate: SQLDelegate?
    
    fileprivate var dbQueue: FMDatabaseQueue!
    public init(delegate: SQLDelegate) {
        super.init()
        self.delegate = delegate
        
        
    }
    //private 
    override init() {
        fatalError("You Need Use 'init(delegate:)'")
    }

    public func createDB() {
        let dbPath = NSHomeDirectory().appending("/Documents" + (delegate?.dbPathName ?? String()))
        if !FileManager.default.fileExists(atPath: dbPath) {
            dbQueue = FMDatabaseQueue(path: dbPath)
            guard let syntaxs = delegate?.sqlSyntaxs else { return }
            dbQueue.inTransaction { (database, _) in
//                guard let database = database else { return }
                do {
                    for S in syntaxs {
                        try database.executeUpdate(S, values: nil)
                    }
                } catch {
                    print("create error")
                    print(error)
                }
            }
        } else {
            dbQueue = FMDatabaseQueue(path: dbPath)
        }
    }
    
    public func loadDB() {
        
        guard let resourcePath = Bundle.main.resourcePath else { return }
        guard let dbPathName = delegate?.dbPathName else { return }
        
        let dbPath = NSHomeDirectory().appending("/Documents" + dbPathName)
        let defaultPath = resourcePath.appending(dbPathName)
        if !FileManager.default.fileExists(atPath: dbPath) {
            do {
                try FileManager.default.copyItem(atPath: defaultPath, toPath: dbPath)
            } catch {
                print(error)
            }
        }
        dbQueue = FMDatabaseQueue(path: dbPath)
    }
    
    public func closeDB() {
        dbQueue.close()
    }
    
    public func operation(process: String, value: [Any]) {
        dbQueue.inTransaction { (database, _) in
//            guard let database = database else { return }
            do {
                try database.executeUpdate(process, values: value)
            } catch {
                print("process error")
                print(error)
            }
        }
    }
    
    public func checkTableColumn(table: String, column: String) -> Bool {
        let tables = self.loadMatch(allMatch: "SELECT * FROM sqlite_master", value: [])
        return tables.contains { "\($0["name"]!)" == table && "\($0["sql"]!)".contains(column)}
    }
    
    public func checkTable(table: String) -> Bool {
        let tables = self.loadMatch(allMatch: "SELECT * FROM sqlite_master", value: [])
        return tables.contains { "\($0["name"]!)" == table }
    }
    
    
    
    
    
}
// MARK: - Load
extension PPSQLiteManager {
    func loadAll(table: String) -> [[String: Any]] {
        var data: [[String: Any]] = []
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                let rs = try database.executeQuery("SELECT * FROM \(table)", values: nil)
                while rs.next() {
                    var dd = [String: Any]()
                    for (key, index) in rs.columnNameToIndexMap {
                        guard let key = key as? String, let index = index as? Int32 else { continue }
                        if let value = rs.object(forColumnIndex: index) {
                            dd[key] = value
                        }
                    }
                    data.append(dd)
                }
            } catch {
                print("loadAll error")
                print(error)
            }
        }
        return data
    }
    
    func loadMatch(allMatch: String, value: [Any]) -> [[String: Any]] {
        var data: [[String: Any]] = []
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                let rs = try database.executeQuery(allMatch, values: value)
                while rs.next() {
                    var dd = [String: Any]()
                    for (key, index) in  rs.columnNameToIndexMap {
                        guard let key = key as? String, let index = index as? Int32 else { continue }
                        if let value = rs.object(forColumnIndex: index) {
                            dd[key] = value
                        }
                    }
                    data.append(dd)
                }
            } catch {
                print(error)
            }
        }
        return data
    }
    
    func loadMatch(table: String, match: String, value: [Any]) -> [[String: Any]] {
        var data: [[String: Any]] = []
        dbQueue.inDatabase { (database) in
//            guard let database = database else { return }
            do {
                let rs = try database.executeQuery("SELECT * FROM \(table) WHERE " + match, values: value)
                while rs.next() {
                    var dd = [String: Any]()
                    for (key, index) in rs.columnNameToIndexMap {
                        guard let key = key as? String, let index = index as? Int32 else { continue }
                        if let value = rs.object(forColumnIndex: index) {
                            dd[key] = value
                        }
                    }
                    data.append(dd)
                }
            } catch {
                print("\(match) error")
                print(error)
            }
        }
        return data
    }
}

// MARK: - Insert
extension PPSQLiteManager {
    func insert(table: String, data: [String: Any]) {
        var name: String = String()
        var keys: String = String()
        var values: [Any] = []
        var SQL: String = String()
        for (offset: i, (key: key, value: value)) in data.enumerated() {
            name = i == 0 ? "(" + key : ( i == data.keys.count-1 ? name + "," + key + ")" : name + "," + key )
            keys = i == 0 ? "(" + "?" : ( i == data.keys.count-1 ? keys + ",?)" : keys + ",?" )
            values.append(value)
        }
        if data.keys.count > 1 {
            SQL = "INSERT INTO \(table) \(name) values \(keys)"
        } else {
            SQL = "INSERT INTO \(table) \(name)) values \(keys))"
        }
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                try database.executeUpdate(SQL, values: values)
            } catch {
                print("insert error")
                print(error)
            }
        }
    }
    
    func insert(table: String, datas: [[String: Any]]) {
        var SQLArray: [String] = [String]()
        var valuesArray: [[Any]] = []
        for dd in datas {
            var name: String = String()
            var keys: String = String()
            var values: [Any] = []
            for (offset: i, (key: key, value: value)) in dd.enumerated() {
                name = i == 0 ? "(" + key : ( i == dd.keys.count-1 ? name + "," + key + ")" : name + "," + key )
                keys = i == 0 ? "(" + "?" : ( i == dd.keys.count-1 ? keys + ",?)" : keys + ",?" )
                values.append(value)
            }
            SQLArray.append("INSERT INTO \(table) \(name) values \(keys)")
            valuesArray.append(values)
        }
        
        dbQueue.inTransaction { (database, _) in
//            guard let database = database else { return }
            do {
                for i in 0..<SQLArray.count {
                    try database.executeUpdate(SQLArray[i], values: valuesArray[i])
                }
            } catch {
                print("instert error")
                print(error)
            }
        }
    }
}

// MARK: - Update
extension PPSQLiteManager {
    func update(table: String, data: [String: Any]) {
        var name: String = String()
        var values: [Any] = []
        guard let primaryKey = delegate?.tablePrimaryKey(table: table) else { return }
        for (offset: _, (key: key, value: value)) in data.enumerated() where key != primaryKey {
            name += key + " = ? ,"
            values.append(value)
        }
        name.removeLast()
        if let value = data[primaryKey] {
            values.append(value)
        }
        let SQL: String = "UPDATE \(table) SET \(name) WHERE \(primaryKey) = ?"
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                try database.executeUpdate(SQL, values: values)
            } catch {
                print("update error")
                print(error)
            }
        }
    }
    
    func update(table: String, datas: [[String: Any]]) {
        guard let primaryKey = delegate?.tablePrimaryKey(table: table) else { return }
        var SQLArray: [String] = [String]()
        var valuesArray: [[Any]] = []
        for dd in datas {
            var name: String = String()
            var values: [Any] = []
            for (offset: _, (key: key, value: value)) in dd.enumerated() where key != primaryKey {
                name += key + " = ? ,"
                values.append(value)
            }
            name.removeLast()
            if let value = dd[primaryKey] {
                values.append(value)
            }
            SQLArray.append("UPDATE \(table) SET \(name) WHERE \(primaryKey) = ?")
            valuesArray.append(values)
        }
        
        dbQueue.inTransaction { (database, _) in
//            guard let database = database else { return }
            do {
                for i in 0..<SQLArray.count {
                    try database.executeUpdate(SQLArray[i], values: valuesArray[i])
                }
            } catch {
                print("update error")
                print(error)
            }
        }
    }
}

// MARK: - Delete
extension PPSQLiteManager {
    func delete(table: String, data: [String: Any]) {
        guard let primaryKey = delegate?.tablePrimaryKey(table: table) else { return }
        dbQueue.inDatabase { (database) in
//            guard let database = database else { return }
            guard let value = data[primaryKey] else { return }
            do {
                try database.executeUpdate("DELETE FROM \(table) WHERE \(primaryKey) = ?", values: [value])
            } catch {
                print("delete error")
                print(error)
            }
        }
    }
    
    func delete(table: String, datas: [[String: Any]]) {
        guard let primaryKey = delegate?.tablePrimaryKey(table: table) else { return }
        dbQueue.inTransaction { (database, _) in
//            guard let database = database else { return }
            do {
                for data in datas {
                    guard let value = data[primaryKey] else { continue }
                    try database.executeUpdate("DELETE FROM \(table) WHERE \(primaryKey) = ?", values: [value])
                }
            } catch {
                print("delete error")
                print(error)
            }
        }
    }
    
    func deleteMatch(SQL: String, values: [Any]) {
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                try database.executeUpdate(SQL, values: values)
            } catch {
                print("delete error")
                print(error)
            }
        }
    }
    
    func deleteAll(table: String) {
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                try database.executeUpdate("DELETE FROM \(table)", values: [])
            } catch {
                print("delete error")
                print(error)
            }
        }
    }
    
    func delete(table: String, match: String, values: [Any]) {
        dbQueue.inDatabase { database in
//            guard let database = database else { return }
            do {
                try database.executeUpdate("DELETE FROM \(table) WHERE \(match)", values: values)
            } catch {
                print("delete error")
                print(error)
            }
        }
    }
}
