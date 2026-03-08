//
//  DashboardCalculationService.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/26.
//

import Foundation
import SwiftUI

// MARK: - 渲染数据结构 (Render Models)

/// 日视图渲染项：包含任务本身及布局信息
struct DailyRenderItem: Identifiable {
    let id: UUID
    let task: TaskItem
    
    // 布局计算结果
    let startRatio: Double    // 开始时间在全天(0-24h)的比例 (0.0 - 1.0)
    let durationRatio: Double // 持续时长比例
    let columnIndex: Int      // 当前列索引 (用于并排显示)
    let totalColumns: Int     // 总列数 (用于计算宽度)
    let nestingLevel: Int     // 嵌套等级 (0=顶层, 1=缩进一级...)
    
    // 辅助属性
    var isPointTask: Bool {
        return durationRatio < (15.0 / (24.0 * 60.0)) // 小于15分钟视为点状任务
    }
}

/// 周视图渲染项：包含任务及其在周视图中的布局信息
struct WeeklyRenderItem: Identifiable {
    let id: UUID
    let task: TaskItem
    
    // 任务所在的列（0-6 表示周日-周六）
    let dayColumn: Int
    
    // 如果是短期任务（当日完成）
    let startRatio: Double     // 开始时间在一天内的比例 (0.0-1.0)
    let durationRatio: Double  // 持续时间比例
    let columnIndex: Int       // 同一天多个任务的列索引
    let totalColumns: Int      // 同一天的总列数
    let nestingLevel: Int      // 嵌套等级
    let isShortTerm: Bool      // true = 细长竖条，false = 点+连线
    
    // 如果是长期任务（跨天）
    let connectionPoints: [DayTimePoint]?  // 每天的时间点（用于绘制连线）
}

/// 周视图中某一天的时间点（用于长期任务连线）
struct DayTimePoint: Identifiable {
    let id = UUID()
    let dayColumn: Int      // 0-6 表示周日-周六
    let timeRatio: Double   // 时间在一天内的比例 (0.0-1.0)
}

/// 月视图渲染项：包含任务及其在月历中的布局信息
struct MonthlyRenderItem: Identifiable {
    let id: UUID
    let task: TaskItem
    
    // 任务跨越的日期范围（在当前月内）
    let startDate: Date  // 开始日期（月内）
    let endDate: Date    // 结束日期（月内）
    
    // 网格位置
    let startColumn: Int  // 开始列（0-6）
    let startRow: Int     // 开始行（0-5）
    let endColumn: Int    // 结束列（0-6）
    let endRow: Int       // 结束行（0-5）
    
    // 显示属性
    let priorityColor: Color  // 优先级颜色
    let spansDays: Int        // 跨越天数
    let needsWrap: Bool       // 是否需要换行（跨周）
    let rowIndex: Int         // 在日期格子内的行索引
}

// MARK: - 核心计算服务
/// 负责 Dashboard 的所有核心算法：布局重叠、数据聚合、路径生成
/// 遵循 "Services only do logic, no UI" 原则
@MainActor
final class DashboardCalculationService {
    
    static let shared = DashboardCalculationService()
    private init() {}
    
    /// 最小嵌套边界间隔（秒），只有父任务在开始和结束处都额外包裹至少这段时间才视为真正嵌套
    private let nestingMarginSeconds: TimeInterval = 30 * 60
    
    /// 参与嵌套计算的最小任务时长（分钟），过短的任务仅用于列布局，不产生嵌套层级
    private let minNestedDurationMinutes: Double = 30.0
    
    /// 最大嵌套层级上限，避免极端情况下缩进过深影响可读性
    private let maxNestingLevel: Int = 2
    
    // MARK: - 1. 日视图布局算法 (Daily Layout)
    
    /// 计算一天的任务布局，处理时间重叠
    /// - Parameter tasks: 当天的任务列表
    /// - Returns: 包含布局信息的渲染项数组
    func calculateDailyLayout(tasks: [TaskItem]) -> [DailyRenderItem] {
        let visibleTasks = tasks.filter { task in
            var current: TaskItem? = task
            var inNodeTree = false
            
            while let node = current {
                if node.type == .node {
                    inNodeTree = true
                    break
                }
                current = node.parent
            }
            
            if inNodeTree {
                return task.isLeaf
            } else {
                return true
            }
        }
        
        // 1. 预处理：按开始时间排序
        let sortedTasks = visibleTasks.sorted { $0.startTime < $1.startTime }
        
        var renderItems: [DailyRenderItem] = []
        
        // 2. 分组算法 (Packing Algorithm)
        // 我们需要找到一组相互重叠的任务，这组任务将共享屏幕宽度
        // 简单贪心策略：如果当前任务与正在处理的组重叠，加入组；否则结束当前组，开始新组。
        // 注意：更复杂的算法是 "Column Packing"，这里实现一个标准版。
        
        var currentGroup: [TaskItem] = []
        var groupEndTime: Date = .distantPast
        
        // 辅助函数：处理并生成当前组的 RenderItems
        func processCurrentGroup() {
            guard !currentGroup.isEmpty else { return }
            
            // 在这个组内，我们需要分配列 (Column)
            // 简单的列分配：寻找第一个不冲突的列
            // columns[i] 存储第 i 列当前的最晚结束时间
            var columnEndTimes: [Date] = []
            
            // 第一次遍历：计算最大列数
            // 通过为每个任务分配列来确定组的总列数
            for task in currentGroup {
                let end = task.endTime ?? task.startTime.addingTimeInterval(30 * 60) // 默认30分钟用于视觉占位
                
                // 寻找可以放置任务的列
                var placed = false
                for (index, colEndTime) in columnEndTimes.enumerated() {
                    if task.startTime >= colEndTime {
                        columnEndTimes[index] = end
                        placed = true
                        break
                    }
                }
                
                // 如果没有找到合适的列，创建新列
                if !placed {
                    columnEndTimes.append(end)
                }
            }
            
            // 第二次遍历：生成 Item
            let maxColumns = columnEndTimes.count
            
            // 重新分配一遍列状态以保持一致 (因为上面的循环逻辑混合了状态更新)
            // 简单起见，我们重新跑一遍分配逻辑来生成 Item
            var tempColumnEndTimes: [Date] = []
            
            for task in currentGroup {
                let calendar = Calendar.current
                let startMinutes = Double(calendar.component(.hour, from: task.startTime) * 60 + calendar.component(.minute, from: task.startTime))
                let startRatio = startMinutes / 1440.0
                
                let end = task.endTime ?? task.startTime.addingTimeInterval(30 * 60)
                let duration = end.timeIntervalSince(task.startTime)
                let durationRatio = duration / 86400.0
                
                // 计算嵌套等级 (被多少个当前组内的其它任务完全包含)
                let durationMinutes = duration / 60.0
                
                // 计算嵌套等级：仅在父任务在两端都有足够“包裹余量”且当前任务时长达到阈值时才记为嵌套
                let rawNestingLevel = currentGroup.filter { other in
                    guard other.id != task.id else { return false }
                    
                    let otherEnd = other.endTime ?? other.startTime.addingTimeInterval(30 * 60)
                    
                    // 当前任务过短时不产生嵌套，仅用于列布局
                    guard durationMinutes >= minNestedDurationMinutes else {
                        return false
                    }
                    
                    // 父任务需要在开始和结束两端都比当前任务多出至少 nestingMarginSeconds
                    let hasHeadMargin = other.startTime <= task.startTime.addingTimeInterval(-nestingMarginSeconds)
                    let hasTailMargin = otherEnd >= end.addingTimeInterval(nestingMarginSeconds)
                    
                    return hasHeadMargin && hasTailMargin
                }.count
                
                let nestingLevel = min(rawNestingLevel, maxNestingLevel)
                
                var assignedColumn = 0
                var placed = false
                
                for (index, colEndTime) in tempColumnEndTimes.enumerated() {
                    // 如果是包含关系，我们允许在同一列渲染（通过 nestingLevel 缩进）
                    // 只有在非包含关系的重叠时才开启新列
                    if task.startTime >= colEndTime.addingTimeInterval(-60) {
                        assignedColumn = index
                        tempColumnEndTimes[index] = end
                        placed = true
                        break
                    }
                }
                
                if !placed {
                    assignedColumn = tempColumnEndTimes.count
                    tempColumnEndTimes.append(end)
                }
                
                renderItems.append(DailyRenderItem(
                    id: task.id,
                    task: task,
                    startRatio: startRatio,
                    durationRatio: max(durationRatio, 0.02), // 最小高度保证
                    columnIndex: assignedColumn,
                    totalColumns: maxColumns,
                    nestingLevel: nestingLevel
                ))
            }
        }
        
        // 遍历所有任务进行分组
        for task in sortedTasks {
            // 如果当前任务的开始时间 晚于 整个组的结束时间，说明断开了 -> 结算上一组
            if task.startTime >= groupEndTime {
                processCurrentGroup()
                currentGroup = []
                groupEndTime = .distantPast
            }
            
            currentGroup.append(task)
            
            // 更新组的结束边界
            let taskEnd = task.endTime ?? task.startTime.addingTimeInterval(30 * 60)
            if taskEnd > groupEndTime {
                groupEndTime = taskEnd
            }
        }
        
        // 结算最后一组
        processCurrentGroup()
        
        return renderItems
    }
    
    // MARK: - 1.5 多日视图布局算法 (Multi-Day Layout)
    
    /// 计算多日视图数据
    /// - Parameters:
    ///   - startDate: 起始日期（作为第一个列对应的日期）
    ///   - dayCount: 需要展示的连续天数（默认用于双日视图）
    ///   - allTasks: 所有任务列表
    /// - Returns: 多日渲染数据，顺序与日期从早到晚一一对应
    func calculateMultiDayLayout(startDate: Date, dayCount: Int, allTasks: [TaskItem]) -> [[DailyRenderItem]] {
        let calendar = Calendar.current
        let normalizedCount = max(dayCount, 1)
        
        return (0..<normalizedCount).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return []
            }
            
            let tasksForDay = allTasks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            return calculateDailyLayout(tasks: tasksForDay)
        }
    }
    
    // MARK: - 2. 周视图布局算法 (Weekly Layout)
    
    /// 计算一周的任务布局，区分短期任务（竖条）和长期任务（点连线）
    /// - Parameters:
    ///   - tasks: 当周的任务列表
    ///   - weekStart: 本周开始日期（周日）
    /// - Returns: 包含布局信息的周视图渲染项数组
    func calculateWeeklyLayout(tasks: [TaskItem], weekStart: Date) -> [WeeklyRenderItem] {
        let calendar = Calendar.current
        var renderItems: [WeeklyRenderItem] = []
        
        // 1. 按任务类型分组
        var shortTermTasks: [Int: [TaskItem]] = [:] // dayColumn -> tasks
        var longTermTasks: [TaskItem] = []
        
        for task in tasks {
            guard let endTime = task.endTime else { continue }
            
            let startDay = calendar.startOfDay(for: task.startTime)
            let endDay = calendar.startOfDay(for: endTime)
            
            // 判断是否为短期任务（当日完成）
            if calendar.isDate(startDay, inSameDayAs: endDay) {
                // 短期任务：计算所在列
                let daysFromWeekStart = calendar.dateComponents([.day], from: weekStart, to: startDay).day ?? 0
                if daysFromWeekStart >= 0 && daysFromWeekStart < 7 {
                    if shortTermTasks[daysFromWeekStart] == nil {
                        shortTermTasks[daysFromWeekStart] = []
                    }
                    shortTermTasks[daysFromWeekStart]?.append(task)
                }
            } else {
                // 长期任务
                longTermTasks.append(task)
            }
        }
        
        // 2. 处理短期任务（竖条）
        for (dayColumn, tasksInDay) in shortTermTasks {
            // 按开始时间排序
            let sortedTasks = tasksInDay.sorted { $0.startTime < $1.startTime }
            
            // 列打包算法（类似日视图）
            var columnEndTimes: [Date] = []
            var taskColumns: [(task: TaskItem, columnIndex: Int)] = []
            
            for task in sortedTasks {
                let end = task.endTime ?? task.startTime.addingTimeInterval(30 * 60)
                
                var assignedColumn = 0
                var placed = false
                
                for (index, colEndTime) in columnEndTimes.enumerated() {
                    if task.startTime >= colEndTime.addingTimeInterval(-60) {
                        assignedColumn = index
                        columnEndTimes[index] = end
                        placed = true
                        break
                    }
                }
                
                if !placed {
                    assignedColumn = columnEndTimes.count
                    columnEndTimes.append(end)
                }
                
                taskColumns.append((task, assignedColumn))
            }
            
            let maxColumns = columnEndTimes.count
            
            // 生成渲染项
            for (task, columnIndex) in taskColumns {
                let hour = calendar.component(.hour, from: task.startTime)
                let minute = calendar.component(.minute, from: task.startTime)
                let totalMinutes = Double(hour * 60 + minute)
                let startRatio = totalMinutes / 1440.0
                
                let end = task.endTime ?? task.startTime.addingTimeInterval(30 * 60)
                let duration = end.timeIntervalSince(task.startTime)
                let durationRatio = duration / 86400.0
                
                // 计算嵌套等级
                let nestingLevel = tasksInDay.filter { other in
                    let otherEnd = other.endTime ?? other.startTime.addingTimeInterval(30 * 60)
                    return other.id != task.id &&
                           other.startTime <= task.startTime &&
                           otherEnd >= end &&
                           (other.startTime < task.startTime || otherEnd > end)
                }.count
                
                renderItems.append(WeeklyRenderItem(
                    id: task.id,
                    task: task,
                    dayColumn: dayColumn,
                    startRatio: startRatio,
                    durationRatio: max(durationRatio, 0.02),
                    columnIndex: columnIndex,
                    totalColumns: maxColumns,
                    nestingLevel: nestingLevel,
                    isShortTerm: true,
                    connectionPoints: nil
                ))
            }
        }
        
        // 3. 处理长期任务（点连线）
        for task in longTermTasks {
            guard let endTime = task.endTime else { continue }
            
            var points: [DayTimePoint] = []
            
            // 生成每一天的时间点
            var currentDate = task.startTime
            while currentDate <= endTime {
                let dayStart = calendar.startOfDay(for: currentDate)
                let daysFromWeekStart = calendar.dateComponents([.day], from: weekStart, to: dayStart).day ?? -1
                
                if daysFromWeekStart >= 0 && daysFromWeekStart < 7 {
                    // 计算时间点在这一天的位置
                    let hour = calendar.component(.hour, from: currentDate)
                    let minute = calendar.component(.minute, from: currentDate)
                    let totalMinutes = Double(hour * 60 + minute)
                    let timeRatio = totalMinutes / 1440.0
                    
                    points.append(DayTimePoint(
                        dayColumn: daysFromWeekStart,
                        timeRatio: timeRatio
                    ))
                }
                
                // 移到下一天
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                currentDate = nextDay
            }
            
            if !points.isEmpty {
                // 使用第一个点的列作为 dayColumn
                    renderItems.append(WeeklyRenderItem(
                        id: task.id,
                        task: task,
                        dayColumn: points.first!.dayColumn,
                        startRatio: points.first!.timeRatio,
                        durationRatio: 0.0,
                        columnIndex: 0,
                        totalColumns: 1,
                        nestingLevel: 0,
                        isShortTerm: false,
                        connectionPoints: points
                    ))
            }
        }
        
        return renderItems
    }
    
    // MARK: - 3. 月视图布局算法 (Monthly Layout)
    
    /// 计算月历网格中任务的位置和布局
    /// - Parameters:
    ///   - tasks: 当月的任务列表
    ///   - monthDate: 月份中的任意日期
    /// - Returns: 包含网格位置信息的月视图渲染项数组
    func calculateMonthlyLayout(tasks: [TaskItem], monthDate: Date) -> [MonthlyRenderItem] {
        let calendar = Calendar.current
        var renderItems: [MonthlyRenderItem] = []
        
        // 1. 获取当月范围
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return []
        }
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        
        // 2. 计算月历网格起始日期（包含上月末尾和下月开头）
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysBeforeMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        guard let gridStart = calendar.date(byAdding: .day, value: -daysBeforeMonth, to: monthStart) else {
            return []
        }
        
        // 3. 为每个任务计算网格位置
        for task in tasks {
            guard let endTime = task.endTime else { continue }
            
            // 计算任务的起止日期
            let taskStartDay = calendar.startOfDay(for: task.startTime)
            let taskEndDay = calendar.startOfDay(for: endTime)
            
            // 限制到当月范围内
            let displayStart = max(taskStartDay, monthStart)
            let displayEnd = min(taskEndDay, calendar.date(byAdding: .day, value: -1, to: monthEnd) ?? taskEndDay)
            
            // 计算网格位置
            let startDayOffset = calendar.dateComponents([.day], from: gridStart, to: displayStart).day ?? 0
            let endDayOffset = calendar.dateComponents([.day], from: gridStart, to: displayEnd).day ?? 0
            
            let startRow = startDayOffset / 7
            let startColumn = startDayOffset % 7
            let endRow = endDayOffset / 7
            let endColumn = endDayOffset % 7
            
            // 计算跨度
            let spansDays = calendar.dateComponents([.day], from: displayStart, to: displayEnd).day ?? 0 + 1
            let needsWrap = startRow != endRow  // 是否跨周
            
            // 获取优先级颜色
            let priorityColor: Color = {
                switch task.priority.rawValue {
                case 0: return ThemeManager.shared.currentTheme.p0
                case 1: return ThemeManager.shared.currentTheme.p1
                case 2: return ThemeManager.shared.currentTheme.p2
                case 3: return ThemeManager.shared.currentTheme.p3
                default: return .gray
                }
            }()
            
            renderItems.append(MonthlyRenderItem(
                id: task.id,
                task: task,
                startDate: displayStart,
                endDate: displayEnd,
                startColumn: startColumn,
                startRow: startRow,
                endColumn: endColumn,
                endRow: endRow,
                priorityColor: priorityColor,
                spansDays: spansDays,
                needsWrap: needsWrap,
                rowIndex: 0  // 将在渲染时动态计算
            ))
        }
        
        return renderItems
    }
    
    // MARK: - 4. 动态雷达图聚合 (Dynamic Radar Aggregation)
    
    /// 根据任务标签动态聚合六维能力值
    /// - Parameter tasks: 选定范围内的任务 (建议只传已完成的任务)
    /// - Returns: 雷达图数据点数组
    func calculateRadarData(from tasks: [TaskItem]) -> [RadarChartData] {
        // 1. 初始化累加器
        var scores: [AttributeType: Int] = [
            .intellect: 0,
            .strength: 0,
            .charm: 0,
            .wealth: 0,
            .creativity: 0,
            .willpower: 0
        ]
        
        // 2. 遍历任务聚合积分
        for task in tasks {
            // 只计算有分数的已完成任务
            guard task.isCompleted, task.earnedScore > 0 else { continue }
            
            // 获取任务标签
            let tags = task.tags ?? []
            
            if tags.isEmpty {
                // 兜底策略：如果没有标签，尝试根据分类 SystemKey 映射
                // 这里的映射逻辑可以写死或配置化
                if let categoryKey = task.category?.systemKey {
                    let fallbackAttr = mapSystemKeyToAttribute(categoryKey)
                    scores[fallbackAttr] = (scores[fallbackAttr] ?? 0) + task.earnedScore
                } else {
                    // 完全无信息的任务，默认加到毅力 (Willpower) —— 只要完成了就有毅力
                    scores[.willpower] = (scores[.willpower] ?? 0) + task.earnedScore
                }
            } else {
                // 如果有标签，将分数平分给所有关联属性
                // 例如：一个任务 10 分，有 "阅读"(智力) 和 "跑步"(体力) 两个标签
                // 简单策略：每个属性都加 10 分 (鼓励多维度) 还是平分? 
                // 现在的 RPG 逻辑通常是全额奖励。
                for tag in tags {
                    let attrs = TaskService.shared.attributeTypes(for: tag)
                    for attr in attrs {
                        scores[attr] = (scores[attr] ?? 0) + task.earnedScore
                    }
                }
            }
        }
        
        // 3. 归一化处理
        let maxVal = max(Double(scores.values.max() ?? 100), 100.0) // 最小基准 100
        
        return AttributeType.allCases.map { attr in
            let rawVal = scores[attr] ?? 0
            return RadarChartData(
                attribute: attr,
                value: Double(rawVal) / maxVal,
                rawValue: rawVal
            )
        }
    }
    
    /// 辅助：将系统分类 Key 映射到属性
    private func mapSystemKeyToAttribute(_ key: String) -> AttributeType {
        switch key.lowercased() {
        case "work", "career": return .wealth
        case "study", "learn": return .intellect
        case "workout", "health": return .strength
        case "social", "family": return .charm
        case "hobby", "art": return .creativity
        default: return .willpower
        }
    }
    
}
