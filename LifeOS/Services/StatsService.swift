//
//  StatsService.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - 数据结构定义

/// 六维属性枚举
enum AttributeType: String, CaseIterable, Codable {
    case intellect = "Intellect"   // 智力
    case strength = "Strength"     // 体力
    case charm = "Charm"           // 魅力
    case wealth = "Wealth"         // 财富
    case creativity = "Creativity" // 创造
    case willpower = "Willpower"   // 毅力
    
    var displayName: String {
        switch self {
        case .intellect: return "智力"
        case .strength: return "体力"
        case .charm: return "魅力"
        case .wealth: return "财富"
        case .creativity: return "创造"
        case .willpower: return "毅力"
        }
    }
    
    var icon: String {
        switch self {
        case .intellect: return "brain.head.profile"
        case .strength: return "figure.run"
        case .charm: return "sparkles"
        case .wealth: return "dollarsign.circle"
        case .creativity: return "paintbrush"
        case .willpower: return "mountain.2"
        }
    }
    
    var color: Color {
        switch self {
        case .intellect: return .blue
        case .strength: return .red
        case .charm: return .pink
        case .wealth: return .yellow
        case .creativity: return .purple
        case .willpower: return .green
        }
    }
}

/// 雷达图数据点
struct RadarChartData: Identifiable {
    var id: String { attribute.rawValue }
    var attribute: AttributeType
    var value: Double // 归一化后的值 (0.0 - 1.0)
    var rawValue: Int // 原始积分值
}

/// 圆环图分段数据
struct DonutSegment: Identifiable {
    var id: UUID = UUID()
    var name: String
    var value: Double // 数量或时长
    var color: Color
    var icon: String?
}

/// 脉冲连线数据点 (周视图)
struct PulsePoint: Identifiable {
    var id: UUID = UUID()
    var dayIndex: Int // 0-6 (周日-周六)
    var timeRatio: Double // 0.0-1.0 (00:00 - 24:00)
    var isSolid: Bool // true=实心点(Point Task), false=竖条中心(Duration Task)
    var color: Color
    var taskID: UUID // 用于识别同一任务
    
    // 兼容 WeeklyPulseView 的 value 属性
    var value: Double {
        return timeRatio
    }
}

// MARK: - 统计服务
@MainActor
final class StatsService {
    
    static let shared = StatsService()
    
    private init() {}
    
    
    // MARK: - 1. 雷达图计算
    
    /// 计算六维属性雷达图数据
    /// - Parameter user: 用户档案
    /// - Returns: 归一化后的雷达图数据数组
    func calculateRadarData(user: UserProfile) -> [RadarChartData] {
        // 1. 获取所有属性的原始值
        let rawValues: [AttributeType: Int] = [
            .intellect: user.attrIntellect,
            .strength: user.attrStrength,
            .charm: user.attrCharm,
            .wealth: user.attrWealth,
            .creativity: user.attrCreativity,
            .willpower: user.attrWillpower
        ]
        
        // 2. 找到最大值用于归一化 (最小上限为 100，避免初期图形太小)
        let maxVal = max(Double(rawValues.values.max() ?? 100), 100.0)
        
        // 3. 生成数据模型
        return AttributeType.allCases.map { attr in
            let val = rawValues[attr] ?? 0
            return RadarChartData(
                attribute: attr,
                value: Double(val) / maxVal,
                rawValue: val
            )
        }
    }
    
    // MARK: - 2. 专注分布 (圆环图)
    
    enum DistributionMode {
        case category
        case tag
    }
    
    /// 计算专注分布数据
    /// - Parameters:
    ///   - tasks: 任务列表 (建议传入已完成的任务)
    ///   - mode: 统计维度 (分类/标签)
    /// - Returns: 圆环图分段数据
    func calculateFocusDistribution(tasks: [TaskItem], mode: DistributionMode) -> [DonutSegment] {
        var segments: [DonutSegment] = []
        
        // 过滤掉未完成的任务? 这里假设传入的 tasks 已经是筛选过的(例如今日已完成)
        // 如果要统计"专注时长"，需要 task 有 duration。
        // 这里简化逻辑：统计"任务数量" 或者 "积分贡献"？
        // 方案提到：中心显示总任务数或总时长。这里我们统计"任务数量"。
        
        switch mode {
        case .category:
            // 按分类 ID 聚合 (避免 Category 需要实现 Hashable)
            let grouped = Dictionary(grouping: tasks) { $0.category?.id }
            
            for (catId, items) in grouped {
                // 从每组的第一个任务中获取 Category 对象
                if let catId = catId,
                   let firstTask = items.first,
                   let cat = firstTask.category {
                    
                    segments.append(DonutSegment(
                        name: cat.name,
                        value: Double(items.count),
                        color: Color(hex: cat.colorHex),
                        icon: cat.icon
                    ))
                } else {
                    // 无分类或获取失败
                    segments.append(DonutSegment(
                        name: "未分类",
                        value: Double(items.count),
                        color: .gray,
                        icon: "tray"
                    ))
                }
            }
            
        case .tag:
            // 按标签聚合 (一个任务可能有多个标签，这里会重复统计)
            var tagCounts: [String: (count: Int, color: String)] = [:]
            var noTagCount = 0
            
            for task in tasks {
                if let tags = task.tags, !tags.isEmpty {
                    for tag in tags {
                        let current = tagCounts[tag.name] ?? (count: 0, color: tag.colorHex)
                        tagCounts[tag.name] = (current.count + 1, current.color)
                    }
                } else {
                    noTagCount += 1
                }
            }
            
            // 转换为 Segments
            for (name, data) in tagCounts {
                segments.append(DonutSegment(
                    name: name,
                    value: Double(data.count),
                    color: Color(hex: data.color),
                    icon: "tag.fill"
                ))
            }
            
            // 处理 Top 5，其余合并为 "其他"
            segments.sort { $0.value > $1.value }
            
            if segments.count > 5 {
                let top5 = Array(segments.prefix(5))
                let others = segments.suffix(from: 5)
                let otherCount = others.reduce(0) { $0 + $1.value }
                
                segments = top5
                segments.append(DonutSegment(
                    name: "其他",
                    value: otherCount,
                    color: .gray.opacity(0.5),
                    icon: "ellipsis"
                ))
            }
            
            // 如果有无标签的任务，也可以加进去，或者忽略
            if noTagCount > 0 {
                segments.append(DonutSegment(
                    name: "无标签",
                    value: Double(noTagCount),
                    color: .gray.opacity(0.3),
                    icon: "tag.slash"
                ))
            }
        }
        
        // 排序：数量多的在前
        segments.sort { $0.value > $1.value }
        
        return segments
    }
    
    // MARK: - 3. 周视图脉冲数据
    
    /// 生成周视图的脉冲点
    /// - Parameter tasks: 本周的任务列表
    /// - Returns: 脉冲点数组
    func generateWeeklyPulse(tasks: [TaskItem]) -> [PulsePoint] {
        var points: [PulsePoint] = []
        let calendar = Calendar.current
        
        for task in tasks {
            // 确定是周几 (1=周日 ... 7=周六) -> 转换索引 0-6
            let weekday = calendar.component(.weekday, from: task.startTime)
            let dayIndex = weekday - 1 // 0=Sun, 6=Sat
            
            // 计算时间比率 (0.0 - 1.0)
            let hour = calendar.component(.hour, from: task.startTime)
            let minute = calendar.component(.minute, from: task.startTime)
            let totalMinutes = hour * 60 + minute
            let ratio = Double(totalMinutes) / (24 * 60)
            
            // 确定类型
            // 时间段任务(Duration) vs 时间点任务(Point)
            // 简单的判断逻辑：如果 endTime - startTime > 15分钟，算时间段，否则算时间点
            let isSolid: Bool
            if let end = task.endTime {
                let duration = end.timeIntervalSince(task.startTime)
                isSolid = duration <= 15 * 60 // 小于等于15分钟视为点
            } else {
                isSolid = true
            }
            
            // 颜色
            let color = task.category.map { Color(hex: $0.colorHex) } ?? .gray
            
            points.append(PulsePoint(
                dayIndex: dayIndex,
                timeRatio: ratio,
                isSolid: isSolid,
                color: color,
                taskID: task.id
            ))
        }
        
        return points
    }
}
