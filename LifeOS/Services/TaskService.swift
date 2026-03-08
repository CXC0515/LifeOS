//
//  TaskService.swift
//  LifeOS
//
//  Created by 程馨 on 2026/01/20.
//

import Foundation
import SwiftData
import SwiftUI // 用于数学计算

// MARK: - 1. DTO (用于 JSON 导入导出的中间结构)
struct TaskDTO: Codable {
    let id: UUID
    let title: String
    let note: String
    let taskTypeRaw: String
    let priorityRaw: Int
    let plannedScore: Int
    let startTime: Date
    let endTime: Date?
    let isCompleted: Bool
    
    // 关系
    let parentID: UUID?
    
    // 周期与数量配置
    let recurrenceInterval: Int?
    let recurrenceUnitRaw: String?
    let recurrenceWeekdays: [Int]?
    let recurrenceMonthDays: [Int]?
    let repeatStopDate: Date?
    let repeatMaxCount: Int?
    let currentRepeatCount: Int?
    let targetValue: Double?
    let currentValue: Double?
    let weight: Double
}

    // MARK: - 2. 业务逻辑核心
@MainActor
final class TaskService {
    
    static let shared = TaskService()
    
    private init() {}
    
    // MARK: - 0. 辅助：获取用户钱包
    private func getUserProfile(context: ModelContext) -> UserProfile {
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return profile
        } else {
            let newProfile = UserProfile()
            context.insert(newProfile)
            return newProfile
        }
    }
    
    // 根任务：从任意任务向上找到没有父任务的节点
    private func rootOf(_ task: TaskItem) -> TaskItem {
        var current = task
        while let parent = current.parent {
            current = parent
        }
        return current
    }
    
    // 递归遍历子树，收集叶子任务以及它们相对于根任务的有效权重
    private func collectLeafWeights(from task: TaskItem,
                                   accumulatedWeight: Double,
                                   into result: inout [TaskItem: Double]) {
        if let children = task.children, !children.isEmpty {
            let positiveChildren = children.filter { $0.weight > 0 }
            let useChildren = positiveChildren.isEmpty ? children : positiveChildren
            let totalWeight = useChildren.reduce(0.0) { $0 + $1.weight }
            if totalWeight <= 0 {
                for child in useChildren {
                    collectLeafWeights(from: child,
                                       accumulatedWeight: accumulatedWeight / Double(useChildren.count),
                                       into: &result)
                }
            } else {
                for child in useChildren {
                    let ratio = child.weight / totalWeight
                    let nextWeight = accumulatedWeight * ratio
                    collectLeafWeights(from: child,
                                       accumulatedWeight: nextWeight,
                                       into: &result)
                }
            }
        } else {
            result[task, default: 0] += accumulatedWeight
        }
    }
    
    // 根据根任务的 plannedScore，将积分精确分配到所有叶子任务（整数且总和一致）
    private func distributeLeafScores(from root: TaskItem) -> [TaskItem: Int] {
        let rootScore = max(root.plannedScore, 0)
        if rootScore <= 0 { return [:] }
        
        var leafWeights: [TaskItem: Double] = [:]
        collectLeafWeights(from: root, accumulatedWeight: 1.0, into: &leafWeights)
        let totalWeight = leafWeights.values.reduce(0.0, +)
        if totalWeight <= 0 { return [:] }
        
        var result: [TaskItem: Int] = [:]
        var tempFractions: [(task: TaskItem, fraction: Double)] = []
        var sumFloor = 0
        
        for (task, weight) in leafWeights {
            let raw = Double(rootScore) * (weight / totalWeight)
            let floorValue = Int(floor(raw))
            let fraction = raw - Double(floorValue)
            result[task] = floorValue
            sumFloor += floorValue
            tempFractions.append((task: task, fraction: fraction))
        }
        
        var remainder = rootScore - sumFloor
        if remainder > 0 {
            tempFractions.sort { $0.fraction > $1.fraction }
            var index = 0
            while remainder > 0 && index < tempFractions.count {
                let task = tempFractions[index].task
                result[task, default: 0] += 1
                remainder -= 1
                index += 1
            }
        } else if remainder < 0 {
            var needReduce = -remainder
            tempFractions.sort { $0.fraction < $1.fraction }
            var index = 0
            while needReduce > 0 && index < tempFractions.count {
                let task = tempFractions[index].task
                let current = result[task, default: 0]
                if current > 0 {
                    result[task] = current - 1
                    needReduce -= 1
                }
                index += 1
            }
        }
        
        return result
    }
    
    // 计算周期任务的循环次数：优先使用 repeatMaxCount，其次根据结束时间和规则推算
    private func totalCycleCount(for task: TaskItem) -> Int {
        guard task.type == .periodic else { return 1 }
        
        if let maxCount = task.repeatMaxCount, maxCount > 0 {
            return maxCount
        }
        
        guard let stopDate = task.repeatStopDate,
              let interval = task.recurrenceInterval,
              let unit = task.recurrenceUnit else {
            return 1
        }
        
        let calendar = Calendar.current
        var count = 0
        var current = task.startTime
        let safetyLimit = 10000
        
        while current <= stopDate && count < safetyLimit {
            count += 1
            var components = DateComponents()
            switch unit {
            case .day:
                components.day = interval
            case .week:
                components.weekOfYear = interval
            case .month:
                components.month = interval
            case .year:
                components.year = interval
            }
            guard let next = calendar.date(byAdding: components, to: current) else {
                break
            }
            current = next
        }
        
        return max(count, 1)
    }
    
    // 对外统一入口：根据根任务积分和权重，计算指定任务“单次完成”应该获得的积分
    func plannedScore(for task: TaskItem) -> Int {
        if task.isRoot {
            return max(task.plannedScore, 0)
        }
        
        guard let _ = task.parent else {
            return max(task.plannedScore, 0)
        }
        
        let root = rootOf(task)
        let leafScores = distributeLeafScores(from: root)
        
        // 如果 task 是叶子节点，直接返回分配的值
        if task.isLeaf {
            let baseScore = max(leafScores[task] ?? 0, 0)
            return applyPeriodicLogic(task: task, baseScore: baseScore)
        } else {
            // 如果是中间节点，汇总其下所有叶子节点的积分
            let leaves = getAllLeaves(of: task)
            var total = 0
            for leaf in leaves {
                let leafBase = max(leafScores[leaf] ?? 0, 0)
                total += applyPeriodicLogic(task: leaf, baseScore: leafBase)
            }
            return total
        }
    }
    
    // 提取周期任务积分逻辑
    private func applyPeriodicLogic(task: TaskItem, baseScore: Int) -> Int {
        if task.isPeriodicChild {
            let cycles = totalCycleCount(for: task)
            if cycles > 1 {
                let per = Double(baseScore) / Double(cycles)
                let perInt = max(Int(round(per)), 0)
                return perInt
            }
        }
        return baseScore
    }
    
    // 递归获取所有叶子节点
    private func getAllLeaves(of task: TaskItem) -> [TaskItem] {
        var leaves: [TaskItem] = []
        if let children = task.children, !children.isEmpty {
            for child in children {
                leaves.append(contentsOf: getAllLeaves(of: child))
            }
        } else {
            leaves.append(task)
        }
        return leaves
    }
    
    // MARK: - 0. 系统配置
    
    /// 确保系统分类使用正确的主题配色
    /// 规则：routine->Base, goal->P0, skill->P1, life->P2, inbox->P3
    func ensureSystemCategoryColors(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let categories = try? context.fetch(descriptor) else { return }
        
        let theme = ThemeManager.shared.currentTheme
        // 目标颜色映射
        let targetColors: [Color] = [
            theme.baseColor, // routine
            theme.p0,        // goal
            theme.p1,        // skill
            theme.p2,        // life
            theme.p3         // inbox
        ]
        
        // 系统分类 Key 顺序 (与上述颜色一一对应)
        let systemKeys = ["routine", "goal", "skill", "life", "inbox"]
        
        var hasChanges = false
        
        for (index, key) in systemKeys.enumerated() {
            if index < targetColors.count,
               let category = categories.first(where: { $0.systemKey == key }) {
                let newHex = targetColors[index].toHex()
                if category.colorHex != newHex {
                    category.colorHex = newHex
                    // 也可以强制开启 useThemeColor，但目前只修改颜色值
                    // category.useThemeColor = true 
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            try? context.save()
            print("🎨 系统分类颜色已更新为当前主题配色")
        }
    }
    
    // MARK: - 1. 核心功能：切换任务完成状态 (Check/Uncheck)
    func toggleTaskCompletion(_ task: TaskItem, context: ModelContext) {
        let userProfile = getUserProfile(context: context)
        
        // --- A. 反悔 (取消完成) ---
        if task.isCompleted {
            // 扣除之前该任务赚取的所有积分
            let scoreToDeduct = task.earnedScore
            userProfile.totalScore -= scoreToDeduct
            
            // 如果是数量型任务，同时重置进度
            if task.type == .quantity {
                task.currentValue = 0
            }
            
            task.isCompleted = false
            task.completedAt = nil
            task.earnedScore = 0 // 清零
            
            print("🔄 撤销完成：扣除 \(scoreToDeduct) 分，当前余额：\(userProfile.totalScore)")
            
            // [RPG] 扣除属性点
            updateAttributePoints(for: task, score: scoreToDeduct, user: userProfile, isAdding: false)
            // [Stats] 更新历史记录
            updateScoreHistory(user: userProfile)
            
            // [新增] 级联更新父任务状态
            updateParentStatusIfNeeded(task, user: userProfile)
            return
        }
        
        // --- B. 完成 ---
        
        // 1. 节点任务检查
        if task.type == .node {
            // 节点型任务依然需要检查子任务（防止用户手动误点）
            let children = task.children ?? []
            if !children.isEmpty && calculateProgress(task) < 1.0 {
                print("⚠️ 无法完成：进度未达 100%")
                return
            }
            completeTask(task, user: userProfile)
            
        } else if task.type == .quantity {
            // 数量型任务：不再自动填满，必须手动更新进度
            // UI 层应该拦截点击事件并弹出进度录入窗口
            // 这里只作为兜底：如果当前进度已达标，则允许标记完成；否则不做改变
            if let target = task.targetValue {
                let current = task.currentValue ?? 0
                if current >= target {
                    completeTask(task, user: userProfile)
                } else {
                    // 进度未达标，不自动补齐，直接返回（UI层应处理输入）
                    print("⚠️ 数量型任务需手动更新进度")
                    return
                }
            } else {
                // 如果没有设置目标值，就当普通任务处理
                completeTask(task, user: userProfile)
            }
            
        } else if task.type == .periodic {
            completeTask(task, user: userProfile)
            generateNextPeriodicTask(from: task, context: context)
            
        } else {
            // 单次任务
            completeTask(task, user: userProfile)
        }
    }
    
    // [新增] MARK: - 1.5 核心功能：更新数量进度 (处理积分增减)
    /// 当用户修改数量进度时调用此方法 (例如 40 -> 20, 或者 20 -> 40)
    func updateTaskProgress(task: TaskItem, newProgress: Double, context: ModelContext) {
        guard task.type == .quantity,
              let target = task.targetValue, target > 0 else { return }
        
        let userProfile = getUserProfile(context: context)
        let oldProgress = task.currentValue ?? 0
        
        // 1. 计算进度的差值 (可能是负数)
        let diff = newProgress - oldProgress
        
        let totalBaseScore = plannedScore(for: task)
        let scorePerUnit = Double(totalBaseScore) / target
        
        // 3. 计算这次变动对应的积分 (四舍五入)
        let scoreChange = Int(round(diff * scorePerUnit))
        
        // 4. 更新钱包 (如果是负数，会自动扣分)
        userProfile.totalScore += scoreChange
        if scoreChange > 0 {
            userProfile.totalEarned += scoreChange
        }
        
        // [RPG] 更新属性点 (增量)
        updateAttributePoints(for: task, score: abs(scoreChange), user: userProfile, isAdding: scoreChange > 0)
        // [Stats] 更新历史记录
        updateScoreHistory(user: userProfile)
        
        // 5. 更新任务数据
        task.currentValue = newProgress
        task.earnedScore += scoreChange // 更新收据
        
        print("📊 进度变更: \(diff), 积分变动: \(scoreChange), 当前余额: \(userProfile.totalScore)")
        
        // 6. 自动判断完成状态
        if newProgress >= target && !task.isCompleted {
            // 满了 -> 自动完成
            completeTask(task, user: userProfile)
            print("✅ 进度达标，自动完成任务")
            
            // 如果是周期任务，且通过进度完成了，也应该触发裂变
            // (通常周期任务不设数量，但如果设了，这里预留逻辑)
            
        } else if newProgress < target && task.isCompleted {
            // 退回去了 -> 自动取消完成
            // 这里不能直接设为 false，因为需要处理积分扣回逻辑
            // 但 toggleTaskCompletion 是切换逻辑，这里我们需要显式的“取消完成”
            // 为保持代码复用，我们可以简单调用 toggleTaskCompletion，但那是 public 的且含逻辑检查
            // 最安全的方式是手动回退状态并处理父级
            
            let scoreToDeduct = task.earnedScore
            userProfile.totalScore -= scoreToDeduct
            
            // [RPG] 扣除属性点
            updateAttributePoints(for: task, score: scoreToDeduct, user: userProfile, isAdding: false)
            // [Stats] 更新历史记录
            updateScoreHistory(user: userProfile)
            
            task.isCompleted = false
            task.completedAt = nil
            task.earnedScore = 0
            
            print("🔙 进度回退，取消完成状态")
            
            // 同样需要通知父任务检查
            updateParentStatusIfNeeded(task, user: userProfile)
        } else {
            // 进度变化但未触发完成状态改变，也可能影响父任务进度（虽然只有完成才算进度 1.0，但这里保留扩展性）
            // 目前逻辑：只有子任务 isCompleted=true 才算进度。所以这里不需要操作。
        }
    }
    
    // 内部通用完成动作
    private func completeTask(_ task: TaskItem, user: UserProfile) {
        // 防止重复完成
        if task.isCompleted { return }
        
        task.isCompleted = true
        task.completedAt = Date()
        
        let finalScore = plannedScore(for: task)
        
        task.earnedScore = finalScore
        user.totalScore += finalScore
        user.totalEarned += finalScore
        
        // [RPG] 增加属性点
        updateAttributePoints(for: task, score: finalScore, user: user, isAdding: true)
        // [Stats] 更新历史记录
        updateScoreHistory(user: user)
        
        print("🎉 任务完成！获得 \(finalScore) 分")
        
        // 级联检查父任务
        updateParentStatusIfNeeded(task, user: user)
    }
    
    // 递归检查父任务状态
    private func updateParentStatusIfNeeded(_ task: TaskItem, user: UserProfile) {
        guard let parent = task.parent else { return }
        
        let progress = calculateProgress(parent)
        
        if progress >= 1.0 && !parent.isCompleted {
            print("🚀 子任务推动：父任务 [\(parent.title)] 进度达标，自动完成")
            completeTask(parent, user: user)
        } else if progress < 1.0 && parent.isCompleted {
            print("🔄 子任务回退：父任务 [\(parent.title)] 进度不足，取消完成")
            // 撤销父任务完成状态（复用逻辑需要小心，这里手动处理以避免死循环）
            let scoreToDeduct = parent.earnedScore
            user.totalScore -= scoreToDeduct
            
            // [RPG] 扣除父任务属性点
            updateAttributePoints(for: parent, score: scoreToDeduct, user: user, isAdding: false)
            // [Stats] 更新历史记录
            updateScoreHistory(user: user)
            
            parent.isCompleted = false
            parent.completedAt = nil
            parent.earnedScore = 0
            
            // 继续向上检查（因为父任务变回未完成，可能导致爷爷任务也变回未完成）
            updateParentStatusIfNeeded(parent, user: user)
        }
    }
    
    // MARK: - 积分计算与商店逻辑
    
    private func calculateScore(for task: TaskItem) -> Double {
        let baseScore = getBaseScore(priority: task.priority)
        
        if let parent = task.parent {
            let siblings = parent.children ?? []
            let totalWeight = siblings.reduce(0.0) { $0 + $1.weight }
            if totalWeight == 0 { return 0 }
            
            let parentBaseScore = getBaseScore(priority: parent.priority)
            return parentBaseScore * (task.weight / totalWeight)
        }
        return baseScore
    }
    
    private func getBaseScore(priority: Priority) -> Double {
        switch priority {
        case .p0: return 50.0
        case .p1: return 30.0
        case .p2: return 20.0
        case .p3: return 10.0
        }
    }
    
    func purchaseItem(cost: Int, context: ModelContext) -> Bool {
        let userProfile = getUserProfile(context: context)
        if userProfile.totalScore >= cost {
            userProfile.totalScore -= cost
            print("💰 消费 \(cost) 分，剩余: \(userProfile.totalScore)")
            return true
        } else {
            print("💸 余额不足")
            return false
        }
    }
    
    // MARK: - 周期任务生成
    private func generateNextPeriodicTask(from task: TaskItem, context: ModelContext) {
        guard let interval = task.recurrenceInterval,
              let unit = task.recurrenceUnit else { return }
        
        if let maxCount = task.repeatMaxCount,
           let currentCount = task.currentRepeatCount,
           currentCount >= maxCount { return }
        
        if let stopDate = task.repeatStopDate, Date() > stopDate { return }
        
        let calendar = Calendar.current
        var nextStart: Date
        
        switch unit {
        case .day:
            guard let date = calendar.date(byAdding: .day, value: interval, to: task.startTime) else { return }
            nextStart = date
            
        case .week:
            if let weekdays = task.recurrenceWeekdays, !weekdays.isEmpty,
               let date = nextWeeklyDate(after: task.startTime,
                                         interval: interval,
                                         weekdays: weekdays,
                                         calendar: calendar) {
                nextStart = date
            } else {
                guard let date = calendar.date(byAdding: .weekOfYear, value: interval, to: task.startTime) else { return }
                nextStart = date
            }
            
        case .month:
            if let days = task.recurrenceMonthDays, !days.isEmpty,
               let date = nextMonthlyDate(after: task.startTime,
                                          interval: interval,
                                          days: days,
                                          calendar: calendar) {
                nextStart = date
            } else {
                guard let date = calendar.date(byAdding: .month, value: interval, to: task.startTime) else { return }
                nextStart = date
            }
            
        case .year:
            guard let date = calendar.date(byAdding: .year, value: interval, to: task.startTime) else { return }
            nextStart = date
        }
        
        let newTask = TaskItem(
            title: task.title,
            type: .periodic,
            startTime: nextStart,
            priority: task.priority
        )
        newTask.note = task.note
        newTask.plannedScore = task.plannedScore
        newTask.weight = task.weight
        newTask.category = task.category
        newTask.tags = task.tags
        newTask.recurrenceInterval = task.recurrenceInterval
        newTask.recurrenceUnit = task.recurrenceUnit
        newTask.recurrenceWeekdays = task.recurrenceWeekdays
        newTask.recurrenceMonthDays = task.recurrenceMonthDays
        newTask.repeatStopDate = task.repeatStopDate
        newTask.repeatMaxCount = task.repeatMaxCount
        newTask.currentRepeatCount = (task.currentRepeatCount ?? 0) + 1
        
        context.insert(newTask)
    }
    
    private func weekdayCode(for date: Date, calendar: Calendar) -> Int {
        let value = calendar.component(.weekday, from: date)
        if value == 1 { return 7 }
        return value - 1
    }
    
    private func nextMonthlyDate(after current: Date,
                                 interval: Int,
                                 days: [Int],
                                 calendar: Calendar) -> Date? {
        let normalizedInterval = max(interval, 1)
        let sortedRaw = days.sorted()
        
        let currentComponents = calendar.dateComponents([.year, .month, .day], from: current)
        guard let year = currentComponents.year,
              let month = currentComponents.month,
              let day = currentComponents.day else {
            return nil
        }
        
        var monthStartComponents = DateComponents()
        monthStartComponents.year = year
        monthStartComponents.month = month
        monthStartComponents.day = 1
        guard let currentMonthStart = calendar.date(from: monthStartComponents),
              let currentRange = calendar.range(of: .day, in: .month, for: currentMonthStart) else {
            return nil
        }
        
        let currentLastDay = currentRange.count
        var mappedDays: [Int] = []
        mappedDays.reserveCapacity(sortedRaw.count)
        for value in sortedRaw {
            let mapped: Int
            if value > 0 {
                mapped = min(value, currentLastDay)
            } else {
                mapped = currentLastDay
            }
            if mappedDays.last != mapped {
                mappedDays.append(mapped)
            }
        }
        
        if let index = mappedDays.firstIndex(of: day),
           index < mappedDays.count - 1 {
            let nextDay = mappedDays[index + 1]
            let offset = nextDay - day
            return calendar.date(byAdding: .day, value: offset, to: current)
        }
        
        guard let targetMonthStart = calendar.date(byAdding: .month, value: normalizedInterval, to: currentMonthStart),
              let targetRange = calendar.range(of: .day, in: .month, for: targetMonthStart) else {
            return nil
        }
        let targetLastDay = targetRange.count
        
        var firstDayValue: Int?
        for value in sortedRaw {
            let mapped: Int
            if value > 0 {
                mapped = min(value, targetLastDay)
            } else {
                mapped = targetLastDay
            }
            if firstDayValue == nil {
                firstDayValue = mapped
                break
            }
        }
        
        let finalDay = firstDayValue ?? 1
        return calendar.date(byAdding: .day, value: finalDay - 1, to: targetMonthStart)
    }
    
    private func nextWeeklyDate(after current: Date,
                                interval: Int,
                                weekdays: [Int],
                                calendar: Calendar) -> Date? {
        let sorted = weekdays.sorted()
        let currentCode = weekdayCode(for: current, calendar: calendar)
        
        if let index = sorted.firstIndex(of: currentCode) {
            if index < sorted.count - 1 {
                let nextCode = sorted[index + 1]
                let offset = nextCode - currentCode
                return calendar.date(byAdding: .day, value: offset, to: current)
            } else {
                let firstCode = sorted[0]
                let weeksGap = max(interval, 1) - 1
                let offset = (7 - currentCode) + weeksGap * 7 + firstCode
                return calendar.date(byAdding: .day, value: offset, to: current)
            }
        } else {
            let maxDays = max(interval, 1) * 7
            if maxDays <= 0 { return nil }
            for delta in 1...maxDays {
                guard let candidate = calendar.date(byAdding: .day, value: delta, to: current) else { continue }
                let code = weekdayCode(for: candidate, calendar: calendar)
                if sorted.contains(code) {
                    return candidate
                }
            }
            return nil
        }
    }
    
    // MARK: - 进度计算 (UI用)
    func calculateProgress(_ task: TaskItem) -> Double {
        switch task.type {
        case .quantity:
            guard let target = task.targetValue, target > 0 else {
                return task.isCompleted ? 1.0 : 0.0
            }
            let current = task.currentValue ?? 0
            let ratio = min(current / target, 1.0)
            return task.isCompleted ? 1.0 : ratio
            
        case .node:
            guard let children = task.children, !children.isEmpty else { return 0.0 }
            let totalWeight = children.reduce(0.0) { $0 + $1.weight }
            if totalWeight <= 0 { return 0.0 }
            let weightedProgress = children.reduce(0.0) { $0 + (calculateProgress($1) * $1.weight) }
            let ratio = weightedProgress / totalWeight
            return min(max(ratio, 0.0), 1.0)
            
        default:
            return task.isCompleted ? 1.0 : 0.0
        }
    }
    
    // MARK: - JSON 导入导出
    func exportToJSON(context: ModelContext) -> String? {
        do {
            let descriptor = FetchDescriptor<TaskItem>()
            let tasks = try context.fetch(descriptor)
            let dtos = tasks.map { task in
                TaskDTO(
                    id: task.id,
                    title: task.title,
                    note: task.note,
                    taskTypeRaw: task.type.rawValue,
                    priorityRaw: task.priority.rawValue,
                    plannedScore: task.plannedScore,
                    startTime: task.startTime,
                    endTime: task.endTime,
                    isCompleted: task.isCompleted,
                    parentID: task.parent?.id,
                    recurrenceInterval: task.recurrenceInterval,
                    recurrenceUnitRaw: task.recurrenceUnit?.rawValue,
                    recurrenceWeekdays: task.recurrenceWeekdays,
                    recurrenceMonthDays: task.recurrenceMonthDays,
                    repeatStopDate: task.repeatStopDate,
                    repeatMaxCount: task.repeatMaxCount,
                    currentRepeatCount: task.currentRepeatCount,
                    targetValue: task.targetValue,
                    currentValue: task.currentValue,
                    weight: task.weight
                )
            }
            let jsonData = try JSONEncoder().encode(dtos)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Export Failed: \(error)")
            return nil
        }
    }
    
    func importFromJSON(jsonString: String, context: ModelContext) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let dtos = try JSONDecoder().decode([TaskDTO].self, from: data)
            var taskMap: [UUID: TaskItem] = [:]
            
            for dto in dtos {
                let type = TaskType(rawValue: dto.taskTypeRaw) ?? .single
                let priority = Priority(rawValue: dto.priorityRaw) ?? .p2
                let unit = RecurrenceUnit(rawValue: dto.recurrenceUnitRaw ?? "")
                
                let newItem = TaskItem(
                    title: dto.title,
                    type: type,
                    startTime: dto.startTime,
                    priority: priority
                )
                newItem.id = dto.id
                newItem.note = dto.note
                newItem.endTime = dto.endTime
                newItem.isCompleted = dto.isCompleted
                newItem.plannedScore = dto.plannedScore
                newItem.recurrenceInterval = dto.recurrenceInterval
                newItem.recurrenceUnit = unit
                newItem.recurrenceWeekdays = dto.recurrenceWeekdays
                newItem.recurrenceMonthDays = dto.recurrenceMonthDays
                newItem.repeatStopDate = dto.repeatStopDate
                newItem.repeatMaxCount = dto.repeatMaxCount
                newItem.currentRepeatCount = dto.currentRepeatCount
                newItem.targetValue = dto.targetValue
                newItem.currentValue = dto.currentValue
                newItem.weight = dto.weight
                
                context.insert(newItem)
                taskMap[dto.id] = newItem
            }
            
            for dto in dtos {
                if let parentID = dto.parentID,
                   let childTask = taskMap[dto.id],
                   let parentTask = taskMap[parentID] {
                    childTask.parent = parentTask
                }
            }
            print("✅ 成功导入 \(dtos.count) 个任务")
        } catch {
            print("Import Failed: \(error)")
        }
    }
    
    // MARK: - 标签管理
    
    func linkTag(_ tag: TaskTag, to attribute: AttributeType, context: ModelContext) {
        guard !tag.attributeLinks.contains(where: { $0.attributeKey == attribute.rawValue }) else {
            return
        }
        let link = TagAttributeLink(attributeKey: attribute.rawValue, tag: tag)
        context.insert(link)
        tag.attributeLinks.append(link)
        print("🔗 Tag [\(tag.name)] linked to [\(attribute.displayName)]")
    }
    
    func unlinkTag(_ tag: TaskTag, from attribute: AttributeType, context: ModelContext) {
        guard let index = tag.attributeLinks.firstIndex(where: { $0.attributeKey == attribute.rawValue }) else {
            return
        }
        let link = tag.attributeLinks.remove(at: index)
        context.delete(link)
        print("🔗 Tag [\(tag.name)] unlinked from [\(attribute.displayName)]")
    }
    
    func unlinkAllAttributes(for tag: TaskTag, context: ModelContext) {
        let links = tag.attributeLinks
        tag.attributeLinks.removeAll()
        for link in links {
            context.delete(link)
        }
        print("🔗 Tag [\(tag.name)] unlinked from all attributes")
    }
    
    func attributeTypes(for tag: TaskTag) -> [AttributeType] {
        tag.attributeLinks.compactMap { AttributeType(rawValue: $0.attributeKey) }
    }
}

// MARK: - 周期任务文案格式化 (UI 用)
extension TaskService {
    static func formatRecurrenceDescription(for task: TaskItem) -> String {
        guard task.type == .periodic else { return "" }
        
        guard let unit = task.recurrenceUnit,
              let interval = task.recurrenceInterval,
              interval > 0 else {
            return "周期任务"
        }
        
        let intervalPrefix = interval > 1 ? "每\(interval)" : "每"
        
        switch unit {
        case .day:
            return intervalPrefix + "天"
            
        case .week:
            if let weekdays = task.recurrenceWeekdays, !weekdays.isEmpty {
                let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]
                let names = weekdays
                    .sorted()
                    .compactMap { index -> String? in
                        guard index >= 1, index <= 7 else { return nil }
                        return "周" + weekdayNames[index - 1]
                    }
                    .joined(separator: "、")
                
                if !names.isEmpty {
                    return intervalPrefix + "周 · " + names
                }
            }
            return intervalPrefix + "周"
            
        case .month:
            if let days = task.recurrenceMonthDays, !days.isEmpty {
                let parts = days
                    .sorted()
                    .map { value -> String in
                        if value == 0 {
                            return "最后一天"
                        } else {
                            return "\(value)号"
                        }
                    }
                if !parts.isEmpty {
                    let text = parts.joined(separator: "、")
                    return intervalPrefix + "月 " + text
                }
            }
            return intervalPrefix + "月"
            
        case .year:
            return intervalPrefix + "年"
        }
    }
    
    static func isOverdue(_ task: TaskItem) -> Bool {
        if task.isCompleted { return false }
        guard let deadline = task.endTime else { return false }
        return deadline < Date()
    }
    
    static func deleteTask(_ task: TaskItem, context: ModelContext) {
        // 1. 如果任务已完成，需要退回积分
        if task.isCompleted {
            let userProfile = TaskService.shared.getUserProfile(context: context)
            let scoreToDeduct = task.earnedScore
            
            userProfile.totalScore -= scoreToDeduct
            // totalEarned 是否扣除取决于业务定义，通常“删除”意味着撤销，所以建议扣除
            userProfile.totalEarned -= scoreToDeduct
            
            print("🗑️ 删除已完成任务 [\(task.title)]，退回 \(scoreToDeduct) 分")
            
            // [RPG] 扣除属性点
            TaskService.shared.updateAttributePoints(for: task, score: scoreToDeduct, user: userProfile, isAdding: false)
            // [Stats] 更新历史记录
            TaskService.shared.updateScoreHistory(user: userProfile)
        }
        
        // 2. 级联处理父任务 (在删除前获取 parent 引用)
        let parent = task.parent
        
        // 3. 从父任务的子列表中移除 (SwiftData 的 deleteRule 也会处理，但手动移除更安全)
        if let parent = parent {
            parent.children?.removeAll { $0.id == task.id }
        }
        
        // 4. 执行物理删除
        context.delete(task)
        
        // 5. 重新评估父任务状态 (因为删除了一个子任务，权重分布变化，且可能导致父任务进度达标或回退)
        if let parent = parent {
            // 需要延迟一点执行，或者立即执行？此时 task 已经从 children 移除了
            // 重新计算 parent 的进度
            let userProfile = TaskService.shared.getUserProfile(context: context)
            TaskService.shared.updateParentStatusIfNeeded(parent, user: userProfile)
        }
    }
    
    // MARK: - 编辑后重评估
    /// 编辑任务后，检查是否满足自动完成条件 (例如数量达标)
    func reassessTaskCompletion(_ task: TaskItem, context: ModelContext) {
        let userProfile = getUserProfile(context: context)
        
        // 1. 数量型任务检查
        if task.type == .quantity, let target = task.targetValue, target > 0 {
            let current = task.currentValue ?? 0
            
            if current >= target && !task.isCompleted {
                print("📝 编辑后达标：自动完成任务")
                completeTask(task, user: userProfile)
            } else if current < target && task.isCompleted {
                print("📝 编辑后不达标：取消完成状态")
                // 手动回退
                let scoreToDeduct = task.earnedScore
                userProfile.totalScore -= scoreToDeduct
                
                task.isCompleted = false
                task.completedAt = nil
                task.earnedScore = 0
                
                updateParentStatusIfNeeded(task, user: userProfile)
            }
        }
        
        // 2. 节点型任务检查 (如果子任务变化导致进度变化)
        if task.type == .node {
             updateParentStatusIfNeeded(task, user: userProfile)
        }
    }
    
    static func idPath(for task: TaskItem) -> String {
        var codes: [String] = []
        var current: TaskItem? = task
        while let node = current {
            let prefix = String(node.id.uuidString.prefix(4))
            codes.append(prefix)
            current = node.parent
        }
        return codes.reversed().joined(separator: "-")
    }
    
    private static func levelSegments(for task: TaskItem) -> [Int] {
        if let parent = task.parent {
            let parentSegments = levelSegments(for: parent)
            let siblings = (parent.children ?? []).sorted { $0.createdAt < $1.createdAt }
            if let index = siblings.firstIndex(where: { $0.id == task.id }) {
                return parentSegments + [index + 1]
            } else {
                return parentSegments + [1]
            }
        } else {
            return [1]
        }
    }
    
    static func outlineNumber(for task: TaskItem) -> String {
        var segments = levelSegments(for: task)
        if !segments.isEmpty {
            segments[0] = 0
        }
        return segments.map { String($0) }.joined(separator: ".")
    }
    
    static func displayPath(for task: TaskItem) -> String {
        let number = outlineNumber(for: task)
        let code = idPath(for: task)
        if number.isEmpty {
            return code
        }
        if code.isEmpty {
            return number
        }
        return number + "#" + code
    }
    
    // MARK: - RPG & Stats Logic

    func updateAttributePoints(for task: TaskItem, score: Int, user: UserProfile, isAdding: Bool) {
        guard let tags = task.tags, !tags.isEmpty else { return }
        
        // 简单平分积分给每个标签关联的属性
        let pointsPerTag = max(1, score / tags.count)
        
        for tag in tags {
            let attrs = attributeTypes(for: tag)
            guard !attrs.isEmpty else { continue }
            let change = isAdding ? pointsPerTag : -pointsPerTag
            for attr in attrs {
                switch attr {
                case .intellect: user.attrIntellect += change
                case .strength:  user.attrStrength += change
                case .charm:     user.attrCharm += change
                case .wealth:    user.attrWealth += change
                case .creativity: user.attrCreativity += change
                case .willpower: user.attrWillpower += change
                }
            }
        }
        
        // 确保不为负数
        if user.attrIntellect < 0 { user.attrIntellect = 0 }
        if user.attrStrength < 0 { user.attrStrength = 0 }
        if user.attrCharm < 0 { user.attrCharm = 0 }
        if user.attrWealth < 0 { user.attrWealth = 0 }
        if user.attrCreativity < 0 { user.attrCreativity = 0 }
        if user.attrWillpower < 0 { user.attrWillpower = 0 }
    }
    
    func updateScoreHistory(user: UserProfile) {
        let today = Date()
        // 查找今天的记录
        if let index = user.scoreHistory.firstIndex(where: { $0.date.isSameDay(as: today) }) {
            user.scoreHistory[index].score = user.totalScore
        } else {
            // 新增记录
            let newItem = ScoreHistoryItem(date: today, score: user.totalScore)
            user.scoreHistory.append(newItem)
            
            // 保持历史记录长度（例如只存最近 365 天）
            if user.scoreHistory.count > 365 {
                user.scoreHistory.removeFirst(user.scoreHistory.count - 365)
            }
        }
    }
}
