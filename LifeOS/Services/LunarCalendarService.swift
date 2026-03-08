//
//  LunarCalendarService.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/28.
//

import Foundation

// MARK: - 农历计算服务
/// 提供农历日期转换功能，使用 Apple 内置的中国日历支持
/// 遵循 "Services only do logic, no UI" 原则
final class LunarCalendarService {
    
    // MARK: - 单例
    
    static let shared = LunarCalendarService()
    private init() {}
    
    // MARK: - 私有属性
    
    /// 中国农历日历
    private let chineseCalendar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()
    
    /// 农历日期中文表示（初一到三十）
    private let lunarDayNames = [
        "初一", "初二", "初三", "初四", "初五",
        "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五",
        "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五",
        "廿六", "廿七", "廿八", "廿九", "三十"
    ]
    
    /// 农历月份中文表示
    private let lunarMonthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]
    
    // MARK: - 公开方法
    
    /// 获取农历日期文本
    /// - Parameter date: 公历日期
    /// - Returns: 农历日期文本（如"初一"），若为月初则返回月份名（如"正月"）
    func lunarDayText(for date: Date) -> String {
        let components = chineseCalendar.dateComponents([.month, .day], from: date)
        
        guard let day = components.day, day >= 1, day <= 30 else {
            return ""
        }
        
        // 农历初一时显示月份名称，其他日期显示日期
        if day == 1 {
            if let month = components.month, month >= 1, month <= 12 {
                return lunarMonthNames[month - 1]
            }
        }
        
        return lunarDayNames[day - 1]
    }
    
    /// 获取农历月份
    /// - Parameter date: 公历日期
    /// - Returns: 农历月份（1-12）
    func lunarMonth(for date: Date) -> Int {
        let components = chineseCalendar.dateComponents([.month], from: date)
        return components.month ?? 1
    }
    
    /// 获取农历日期
    /// - Parameter date: 公历日期
    /// - Returns: 农历日期（1-30）
    func lunarDay(for date: Date) -> Int {
        let components = chineseCalendar.dateComponents([.day], from: date)
        return components.day ?? 1
    }
    
    /// 判断是否为农历月初（初一）
    /// - Parameter date: 公历日期
    /// - Returns: 是否为农历月初
    func isFirstDayOfLunarMonth(for date: Date) -> Bool {
        let day = lunarDay(for: date)
        return day == 1
    }
    
    /// 获取完整农历日期文本
    /// - Parameter date: 公历日期
    /// - Returns: 完整农历日期（如"正月初一"）
    func fullLunarDateText(for date: Date) -> String {
        let components = chineseCalendar.dateComponents([.month, .day], from: date)
        
        guard let month = components.month, month >= 1, month <= 12,
              let day = components.day, day >= 1, day <= 30 else {
            return ""
        }
        
        return "\(lunarMonthNames[month - 1])\(lunarDayNames[day - 1])"
    }
}
