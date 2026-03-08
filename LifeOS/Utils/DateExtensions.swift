//
//  DateExtensions.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import Foundation

extension Date {
    // 1. 判断是否是同一天
    func isSameDay(as otherDate: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: otherDate)
    }
    
    // 2. 获取当天的 00:00:00
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    // 3. 计算当前时间距离 00:00 过了多少分钟 (用于计算 Y 轴高度)
    var minutesSinceMidnight: Double {
        let calendar = Calendar.current
        let component = calendar.dateComponents([.hour, .minute], from: self)
        let hour = Double(component.hour ?? 0)
        let minute = Double(component.minute ?? 0)
        return hour * 60 + minute
    }
    
    // 4. 格式化显示 (09:00)
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    var chineseDateShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: self)
    }
    
    var chineseDateLong: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }
    
    // 5. 辅助工具：生成本周的日期数组 (供后续周视图使用)
    static var currentWeekDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
}
