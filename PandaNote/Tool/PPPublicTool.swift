//
//  PPPublicTool.swift
//  PandaNote
//
//  Created by panway on 2020/8/26.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  

//import Foundation

//MARK:Log
func debugPrint2(_ message:Any?, columnNumber: Int = #column, fileName: String = #file, methodName: String = #function, lineNumber:Int = #line) {

    #if DEBUG
    let title = "[\(fileName.components(separatedBy: "/").last ?? "")] [\(lineNumber)行] [\(methodName)] <time>:"
        print(title)
        if message == nil  {
//            print("")
            return
        }
        print(message!)
    #endif
}
//https://gist.github.com/Abizern/a81f31a75e1ad98ff80d
func debugPrint<T>(_ closure: @autoclosure () -> T, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    #if DEBUG
        let instance = closure()
        let description: String

        if let debugStringConvertible = instance as? CustomDebugStringConvertible {
            description = debugStringConvertible.debugDescription
        } else {
            // Will use `CustomStringConvertible` representation if possuble, otherwise
            // it will print the type of the returned instance like `T()`
            description = "\(instance)"
        }

        let file = URL(fileURLWithPath: file).lastPathComponent
        let queue = Thread.isMainThread ? "UI" : "BG"

        print("\n[\(file) \(function)] 第\(line)行:<\(queue)> \n \(description)")
    #endif
}


func debugPrint3(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "*\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
}





///release模式下print不打印
/*
public func print(_ object: Any...) {
    #if DEBUG
    for item in object {
        Swift.print (item)
    }
    #endif
}
public func print(_ object:Any) {
    #if DEBUG
    Swift.print (object)
    #endif
}
*/
