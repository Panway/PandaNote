//
//  Date+Extension.swift
//  PandaNote
//
//  Created by claude on 2026/2/9.
//  Copyright © 2026 Panway. All rights reserved.
//

import Foundation
/*
let now = Date()

// 1. 基础用法 - 使用当前时区
print(now.toString())
// 输出: 2026-02-09 14:30:15

print(now.toString(format: "yyyy/MM/dd"))
// 输出: 2026/02/09

// 2. 指定时区
print(now.toString(timeZone: TimeZone(identifier: "America/New_York")!))
// 输出: 2026-02-09 01:30:15 (假设北京时间是14:30)

print(now.toString(timeZoneIdentifier: "Asia/Tokyo"))
// 输出: 2026-02-09 15:30:15 (东京比北京快1小时)

// 3. 便捷属性
print(now.toDateString)          // 2026-02-09
print(now.toTimeString)          // 14:30:15
print(now.toDateTimeString)      // 2026-02-09 14:30:15
print(now.toISO8601String)       // 2026-02-09T14:30:15+08:00
print(now.toUTCISO8601String)    // 2026-02-09T06:30:15Z

// 4. 中文格式
print(now.toChineseDateString)       // 2026年02月09日
print(now.toChineseDateTimeString)   // 2026年02月09日 14时30分15秒
print(now.toChineseWeekday)          // 星期一

// 5. 相对时间
let oneHourAgo = Date(timeIntervalSinceNow: -3600)
print(oneHourAgo.toRelativeString)   // 1小时前

let yesterday = Date(timeIntervalSinceNow: -86400)
print(yesterday.toRelativeString)    // 1天前

// 6. 智能格式化
print(now.toSmartString)             // 今天 14:30
print(yesterday.toSmartString)       // 昨天 14:30
*/
extension Date {
    
    // MARK: - 基础转换方法
    
    /// 转换为字符串，使用当前时区
    /// - Parameters:
    ///   - format: 日期格式，默认 "yyyy-MM-dd HH:mm:ss"
    ///   - timeZone: 时区，默认为当前时区
    ///   - locale: 地区，默认为当前地区
    /// - Returns: 格式化后的字符串
    func toString(format: String = "yyyy-MM-dd HH:mm:ss",
                  timeZone: TimeZone = .current,
                  locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = locale
        return formatter.string(from: self)
    }
    
    /// 转换为字符串，指定时区标识符
    /// - Parameters:
    ///   - format: 日期格式
    ///   - timeZoneIdentifier: 时区标识符，如 "Asia/Shanghai"
    /// - Returns: 格式化后的字符串
    func toString(format: String = "yyyy-MM-dd HH:mm:ss",
                  timeZoneIdentifier: String) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return toString(format: format)
        }
        return toString(format: format, timeZone: timeZone)
    }
    
    // MARK: - 便捷方法
    
    /// 转换为日期字符串 (yyyy-MM-dd)
    var toDateString: String {
        return toString(format: "yyyy-MM-dd")
    }
    
    /// 转换为时间字符串 (HH:mm:ss)
    var toTimeString: String {
        return toString(format: "HH:mm:ss")
    }
    
    /// 转换为日期时间字符串 (yyyy-MM-dd HH:mm:ss)
    var toDateTimeString: String {
        return toString(format: "yyyy-MM-dd HH:mm:ss")
    }
    
    /// 转换为 ISO8601 格式字符串
    var toISO8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter.string(from: self)
    }
    
    /// 转换为 UTC ISO8601 格式字符串
    var toUTCISO8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
    
    // MARK: - 中文格式
    
    /// 转换为中文日期 (2024年2月9日)
    var toChineseDateString: String {
        return toString(format: "yyyy年MM月dd日", locale: Locale(identifier: "zh_CN"))
    }
    
    /// 转换为中文日期时间 (2024年2月9日 14时30分15秒)
    var toChineseDateTimeString: String {
        return toString(format: "yyyy年MM月dd日 HH时mm分ss秒", locale: Locale(identifier: "zh_CN"))
    }
    
    /// 转换为中文星期 (星期一)
    var toChineseWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        formatter.timeZone = .current
        return formatter.string(from: self)
    }
    
    // MARK: - 相对时间
    
    /// 转换为相对时间描述 (刚刚、1分钟前、2小时前等)
    var toRelativeString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                from: self,
                                                to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)年前"
        } else if let month = components.month, month > 0 {
            return "\(month)个月前"
        } else if let day = components.day, day > 0 {
            return "\(day)天前"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }
    
    // MARK: - 智能格式化
    
    /// 智能格式化：今天显示时间，昨天显示"昨天"，其他显示日期
    var toSmartString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "今天 " + toString(format: "HH:mm")
        } else if calendar.isDateInYesterday(self) {
            return "昨天 " + toString(format: "HH:mm")
        } else if calendar.isDateInTomorrow(self) {
            return "明天 " + toString(format: "HH:mm")
        } else {
            let now = Date()
            if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
                return toString(format: "MM-dd HH:mm")
            } else {
                return toString(format: "yyyy-MM-dd HH:mm")
            }
        }
    }
}
