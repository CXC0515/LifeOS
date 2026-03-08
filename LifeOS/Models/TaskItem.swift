//
//  TaskItem.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import Foundation
import SwiftData

// 1. 定义任务类型
enum TaskType: String, Codable, CaseIterable {
    case single      // 单次任务
    case periodic    // 周期任务
    case quantity    // 长期-数量型
    case node        // 长期-节点型 (依赖子任务)
}

// 2. 定义优先级 (P0 - P3)
enum Priority: Int, Codable, Comparable {
    case p0 = 0
    case p1 = 1
    case p2 = 2
    case p3 = 3
    
    static func < (lhs: Priority, rhs: Priority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var description: String {
        switch self {
        case .p0:
            return "重要且紧急"
        case .p1:
            return "重要不紧急"
        case .p2:
            return "紧急不重要"
        case .p3:
            return "不重要不紧急"
        }
    }
}

// 3. 周期单位
enum RecurrenceUnit: String, Codable {
    case day, week, month, year
}

@Model
final class TaskItem {
    // MARK: - 基础属性
    var id: UUID
    var title: String
    var note: String
    var createdAt: Date
    
    // 任务类型
    var type: TaskType
    
    // 状态与时间
    var startTime: Date
    var endTime: Date? // 有些任务可能没有硬性截止
    var isAllDay: Bool // 是否为全天任务（只有日期，无具体时刻）
    var isCompleted: Bool
    var completedAt: Date?
    
    // 优先级与权重
    var priority: Priority
    var weight: Double // 权重，用于父任务计算积分分配
    var earnedScore: Int // 完成该任务实际获得的积分
    var plannedScore: Int // 根任务设置的总积分，子任务积分从这里往下分配
    
    // MARK: - 关系 (Relationships)
    // 这里的 deleteRule: .cascade 意味着删掉父任务，子任务也会被连带删除，防止垃圾数据
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var children: [TaskItem]?
    
    var parent: TaskItem?
    
    // 关联分类与标签 (下文会定义)
    var category: TaskCategory?
    @Relationship(deleteRule: .nullify)
    var tags: [TaskTag]?
    
    // MARK: - 专用属性 (根据 Type 决定是否使用)
    
    // [数量型任务专用]
    var targetValue: Double?  // 目标值 (比如: 读 100 页)
    var currentValue: Double? // 当前值 (比如: 读了 20 页)
    var valueUnit: String?    // 单位 (比如: "页", "%")
    
    // [周期任务专用]
    // 逻辑：每 [interval] [unit] 重复一次
    var recurrenceInterval: Int? // 比如: 3 (天)
    var recurrenceUnit: RecurrenceUnit? // 比如: .day
    var recurrenceWeekdays: [Int]? // 按周重复时的星期几，1=周一 ... 7=周日
    var recurrenceMonthDays: [Int]?   // 按月重复时的日期，1-31，0=最后一天，支持多选
    var repeatStopDate: Date?    // 到这个时间停止
    var repeatMaxCount: Int?     // 循环多少次停止
    var currentRepeatCount: Int? // 当前是第几次循环
    
    // MARK: - 兼容性属性
    // 为了兼容旧代码 (LMS 迁移)，提供 subtasks 别名指向 children
    var subtasks: [TaskItem]? {
        return children
    }
    
    // 根任务：没有父任务
    var isRoot: Bool {
        return parent == nil
    }
    
    // 叶子任务：没有子任务
    var isLeaf: Bool {
        return (children ?? []).isEmpty
    }
    
    // 有父任务的周期任务，常用于节点型子任务里的周期子任务
    var isPeriodicChild: Bool {
        return type == .periodic && parent != nil
    }
    
    // MARK: - 初始化
    init(
        title: String,
        type: TaskType = .single,
        startTime: Date = Date(),
        priority: Priority = .p2,
        isAllDay: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.note = ""
        self.createdAt = Date()
        self.type = type
        self.startTime = startTime
        self.isAllDay = isAllDay
        self.isCompleted = false
        self.priority = priority
        self.weight = 1.0
        self.earnedScore = 0
        self.plannedScore = 0
        self.children = []
        self.tags = []
    }
}

@MainActor
extension TaskItem {
    var recurrenceDescription: String {
        TaskService.formatRecurrenceDescription(for: self)
    }
    
    var recurrenceFullDescription: String {
        let base = recurrenceDescription
        guard !base.isEmpty else { return "" }
        
        if let current = currentRepeatCount {
            return "\(base) · 第 \(current + 1) 次"
        } else {
            return base
        }
    }
    
    var isOverdue: Bool {
        TaskService.isOverdue(self)
    }
}
