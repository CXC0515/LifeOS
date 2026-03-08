//
//  DataLoader.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/1/21.
//

import Foundation
import SwiftData
import SwiftUI

/// 负责应用启动时的数据预加载
struct DataLoader {
    
    /// 检查并加载预置数据
    /// - Parameter context: SwiftData 模型上下文
    @MainActor
    static func loadSampleDataIfNeeded(context: ModelContext) {
        // 检查是否已有数据
        let descriptor = FetchDescriptor<TaskItem>()
        if let count = try? context.fetchCount(descriptor), count > 0 {
             return 
        }
        
        print("🪄 开始写入全面测试数据...")
        
        // 1. 创建分类 (Categories) - 从 DefaultMetadata 读取配置
        var categoryMap: [String: TaskCategory] = [:]
        
        for config in DefaultMetadata.categories {
            let themeColor = ThemeManager.shared.currentTheme.color(for: config.themeLevel)
            let colorHex = themeColor.toHex()
            
            let category = TaskCategory(
                name: config.name,
                colorHex: colorHex,
                icon: config.icon,
                isSystem: config.isSystem,
                systemKey: config.key
            )
            
            context.insert(category)
            categoryMap[config.key] = category
        }
        
        // 2. 创建标签 (Tags) - 从 DefaultMetadata 读取配置
        var tagMap: [String: TaskTag] = [:]
        
        for config in DefaultMetadata.tags {
            let tag = TaskTag(
                name: config.name,
                colorHex: config.colorHex,
                isSystem: config.isSystem
            )
            context.insert(tag)
            tagMap[config.key] = tag
        }
        
        // 3. 创建全面的示例任务
        
        let routineCat = categoryMap["routine"]
        let goalCat = categoryMap["goal"]
        let skillCat = categoryMap["skill"]
        let lifeCat = categoryMap["life"]
        
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // 辅助函数：生成指定偏移日期的时间
        func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        
        // ============================================================
        // 一、历史数据 (测试月视图热力图)
        // ============================================================
        
        for i in 1...30 {
            // 模拟70%完成率，随机跳过
            if i % 3 == 2 { continue }
            
            let pastDate = date(dayOffset: -i, hour: 7)
            let runTask = TaskItem(title: "晨跑 5 公里", type: .periodic, startTime: pastDate, priority: .p1)
            runTask.category = routineCat
            runTask.recurrenceInterval = 1
            runTask.recurrenceUnit = .day
            runTask.isCompleted = true
            runTask.completedAt = calendar.date(byAdding: .minute, value: 45, to: pastDate)
            runTask.plannedScore = 30
            runTask.earnedScore = 30
            if let sportTag = tagMap["sport"] { runTask.tags = [sportTag] }
            context.insert(runTask)
        }
        
        // ============================================================
        // 二、今日任务 (全面测试各种类型和优先级，控制同一时间段任务数量)
        // ============================================================
        
        // ────────────────────────────────────────
        // P0 - 重要且紧急 (左上象限)
        // ────────────────────────────────────────
        
        // 1. 节点型任务：核心项目重构 (9:00-18:00，作为父任务包裹子任务)
        let coreRefactor = TaskItem(title: "LifeOS 2.0 核心重构", type: .node, startTime: date(dayOffset: 0, hour: 9), priority: .p0)
        coreRefactor.category = goalCat
        coreRefactor.note = "重写数据层逻辑，优化性能"
        coreRefactor.endTime = date(dayOffset: 0, hour: 18)
        coreRefactor.plannedScore = 200
        if let devTag = tagMap["dev"] { coreRefactor.tags = [devTag] }
        context.insert(coreRefactor)
        
        // 子任务 1：已完成 (9:30-11:00)
        let subTask1 = TaskItem(title: "设计数据库模型", type: .single, startTime: date(dayOffset: 0, hour: 9, minute: 30), priority: .p1)
        subTask1.parent = coreRefactor
        subTask1.category = goalCat
        subTask1.endTime = date(dayOffset: 0, hour: 11)
        subTask1.weight = 0.3
        subTask1.isCompleted = true
        subTask1.completedAt = date(dayOffset: 0, hour: 10, minute: 45)
        context.insert(subTask1)
        
        // 子任务 2：进行中，有孙任务 (11:00-14:00)
        let subTask2 = TaskItem(title: "实现数据层逻辑", type: .node, startTime: date(dayOffset: 0, hour: 11), priority: .p0)
        subTask2.parent = coreRefactor
        subTask2.category = goalCat
        subTask2.endTime = date(dayOffset: 0, hour: 14)
        subTask2.weight = 0.5
        context.insert(subTask2)
        
        // 孙任务 2.1：已完成 (11:15-12:00)
        let grandTask1 = TaskItem(title: "TaskItem CRUD", type: .single, startTime: date(dayOffset: 0, hour: 11, minute: 15), priority: .p1)
        grandTask1.parent = subTask2
        grandTask1.category = goalCat
        grandTask1.weight = 0.5
        grandTask1.endTime = date(dayOffset: 0, hour: 12)
        grandTask1.isCompleted = true
        context.insert(grandTask1)
        
        // 孙任务 2.2：数量型，50%完成 (13:30-14:00)
        let grandTask2 = TaskItem(title: "CategoryService 开发", type: .quantity, startTime: date(dayOffset: 0, hour: 13, minute: 30), priority: .p0)
        grandTask2.parent = subTask2
        grandTask2.category = goalCat
        grandTask2.targetValue = 10
        grandTask2.currentValue = 5
        grandTask2.valueUnit = "个API"
        grandTask2.endTime = date(dayOffset: 0, hour: 14)
        grandTask2.weight = 0.5
        context.insert(grandTask2)
        
        // 子任务 3：未开始 (16:00-18:00)
        let subTask3 = TaskItem(title: "UI 层重构", type: .single, startTime: date(dayOffset: 0, hour: 16), priority: .p1)
        subTask3.parent = coreRefactor
        subTask3.category = goalCat
        subTask3.endTime = date(dayOffset: 0, hour: 18)
        subTask3.weight = 0.2
        context.insert(subTask3)
        
        // 2. 时间点任务：紧急bug修复 (10:30-11:00，已过期，控制并发数量)
        let urgentBug = TaskItem(title: "紧急bug修复", type: .single, startTime: date(dayOffset: 0, hour: 10, minute: 30), priority: .p0)
        urgentBug.category = goalCat
        urgentBug.note = "用户反馈的崩溃问题"
        urgentBug.plannedScore = 50
        urgentBug.endTime = date(dayOffset: 0, hour: 11)
        if let devTag = tagMap["dev"] { urgentBug.tags = [devTag] }
        context.insert(urgentBug)
        
        // ────────────────────────────────────────
        // P1 - 重要不紧急 (右上象限)
        // ────────────────────────────────────────
        
        // 3. 周期任务：晨跑 (7:00-8:00，已完成)
        let morningRun = TaskItem(title: "晨跑 5 公里", type: .periodic, startTime: date(dayOffset: 0, hour: 7), priority: .p1)
        morningRun.category = routineCat
        morningRun.endTime = date(dayOffset: 0, hour: 8)
        morningRun.recurrenceInterval = 1
        morningRun.recurrenceUnit = .day
        morningRun.currentRepeatCount = 25
        morningRun.repeatMaxCount = 30
        morningRun.isCompleted = true
        morningRun.completedAt = date(dayOffset: 0, hour: 7, minute: 45)
        morningRun.plannedScore = 30
        morningRun.earnedScore = 30
        if let sportTag = tagMap["sport"] { morningRun.tags = [sportTag] }
        context.insert(morningRun)
        
        // 4. 数量型任务：阅读技术书籍 (20:00-21:30，30%完成)
        let reading = TaskItem(title: "阅读《SwiftUI 编程思想》", type: .quantity, startTime: date(dayOffset: 0, hour: 20), priority: .p1)
        reading.category = skillCat
        reading.endTime = date(dayOffset: 0, hour: 21, minute: 30)
        reading.targetValue = 50
        reading.currentValue = 15
        reading.valueUnit = "页"
        reading.plannedScore = 40
        if let readTag = tagMap["read"] { reading.tags = [readTag] }
        context.insert(reading)
        
        // 5. 单次任务：整理需求文档 (14:00-16:00，作为子任务 2 的后续工作)
        let docWork = TaskItem(title: "整理需求文档", type: .single, startTime: date(dayOffset: 0, hour: 14), priority: .p1)
        docWork.category = goalCat
        docWork.endTime = date(dayOffset: 0, hour: 16)
        docWork.plannedScore = 50
        context.insert(docWork)
        
        // 6. 周期任务：每周健身 (周一三五，19:00-20:30)
        let gymWorkout = TaskItem(title: "健身房训练", type: .periodic, startTime: date(dayOffset: 0, hour: 19), priority: .p1)
        gymWorkout.category = routineCat
        gymWorkout.endTime = date(dayOffset: 0, hour: 20, minute: 30)
        gymWorkout.recurrenceInterval = 1
        gymWorkout.recurrenceUnit = .week
        gymWorkout.recurrenceWeekdays = [1, 3, 5] // 周一三五
        gymWorkout.plannedScore = 35
        if let sportTag = tagMap["sport"] { gymWorkout.tags = [sportTag] }
        context.insert(gymWorkout)
        
        // ────────────────────────────────────────
        // P2 - 紧急不重要 (左下象限)
        // ────────────────────────────────────────
        
        // 7. 时间点任务：接快递 (17:30，避开高并发时段)
        let pickupPackage = TaskItem(title: "接快递", type: .single, startTime: date(dayOffset: 0, hour: 17, minute: 30), priority: .p2)
        pickupPackage.category = lifeCat
        pickupPackage.plannedScore = 5
        context.insert(pickupPackage)
        
        // 8. 单次任务：产品需求会 (15:30-16:30，与整理文档轻度重叠)
        let meeting = TaskItem(title: "产品需求会", type: .single, startTime: date(dayOffset: 0, hour: 15, minute: 30), priority: .p2)
        meeting.category = goalCat
        meeting.endTime = date(dayOffset: 0, hour: 16, minute: 30)
        meeting.plannedScore = 20
        context.insert(meeting)
        
        // 9. 周期任务：午间冥想 (12:30-13:00，每天)
        let meditation = TaskItem(title: "午间冥想", type: .periodic, startTime: date(dayOffset: 0, hour: 12, minute: 30), priority: .p2)
        meditation.category = routineCat
        meditation.endTime = date(dayOffset: 0, hour: 13)
        meditation.recurrenceInterval = 1
        meditation.recurrenceUnit = .day
        meditation.isCompleted = true
        meditation.completedAt = date(dayOffset: 0, hour: 13)
        meditation.plannedScore = 15
        meditation.earnedScore = 15
        context.insert(meditation)
        
        // 10. 周期任务：还信用卡 (每月1号和15号)
        let creditCard = TaskItem(title: "还信用卡", type: .periodic, startTime: date(dayOffset: 0, hour: 10), priority: .p2)
        creditCard.category = lifeCat
        creditCard.recurrenceInterval = 1
        creditCard.recurrenceUnit = .month
        creditCard.recurrenceMonthDays = [1, 15]
        creditCard.plannedScore = 10
        context.insert(creditCard)
        
        // ────────────────────────────────────────
        // P3 - 不重要不紧急 (右下象限)
        // ────────────────────────────────────────
        
        // 11. 时间点任务：整理书架 (晚上空闲时)
        let organizeBooks = TaskItem(title: "整理书架", type: .single, startTime: date(dayOffset: 0, hour: 21), priority: .p3)
        organizeBooks.category = lifeCat
        organizeBooks.plannedScore = 10
        context.insert(organizeBooks)
        
        // 12. 时间点任务：超市采购 (18:00)
        let shopping = TaskItem(title: "超市采购", type: .single, startTime: date(dayOffset: 0, hour: 18), priority: .p3)
        shopping.category = lifeCat
        shopping.plannedScore = 10
        if let shopTag = tagMap["shop"] { shopping.tags = [shopTag] }
        context.insert(shopping)
        
        // 13. 单次任务：观看电影 (21:30-23:30)
        let movie = TaskItem(title: "观看《肖申克的救赎》", type: .single, startTime: date(dayOffset: 0, hour: 21, minute: 30), priority: .p3)
        movie.category = lifeCat
        movie.endTime = date(dayOffset: 0, hour: 23, minute: 30)
        movie.plannedScore = 15
        if let funTag = tagMap["fun"] { movie.tags = [funTag] }
        context.insert(movie)
        
        // ============================================================
        // 三、本周其他天的任务
        // ============================================================
        
        // 昨天：逾期未完成任务
        let overdueTask = TaskItem(title: "提交周报", type: .single, startTime: date(dayOffset: -1, hour: 17), priority: .p1)
        overdueTask.category = goalCat
        overdueTask.note = "昨天截止，需尽快补交"
        overdueTask.plannedScore = 50
        context.insert(overdueTask)
        
        // 前天：已完成任务
        let prevWork = TaskItem(title: "代码评审会议", type: .single, startTime: date(dayOffset: -2, hour: 14), priority: .p2)
        prevWork.category = goalCat
        prevWork.endTime = date(dayOffset: -2, hour: 16)
        prevWork.isCompleted = true
        prevWork.completedAt = date(dayOffset: -2, hour: 15, minute: 50)
        prevWork.plannedScore = 30
        prevWork.earnedScore = 30
        context.insert(prevWork)
        
        // 明天：未来任务
        let tomorrowTask1 = TaskItem(title: "晨跑 5 公里", type: .periodic, startTime: date(dayOffset: 1, hour: 7), priority: .p1)
        tomorrowTask1.category = routineCat
        tomorrowTask1.recurrenceInterval = 1
        tomorrowTask1.recurrenceUnit = .day
        tomorrowTask1.currentRepeatCount = 26
        if let sportTag = tagMap["sport"] { tomorrowTask1.tags = [sportTag] }
        context.insert(tomorrowTask1)
        
        let tomorrowTask2 = TaskItem(title: "UI原型设计", type: .single, startTime: date(dayOffset: 1, hour: 10), priority: .p1)
        tomorrowTask2.category = goalCat
        tomorrowTask2.endTime = date(dayOffset: 1, hour: 12)
        tomorrowTask2.plannedScore = 60
        context.insert(tomorrowTask2)
        
        let tomorrowTask3 = TaskItem(title: "午间冥想", type: .periodic, startTime: date(dayOffset: 1, hour: 12, minute: 30), priority: .p2)
        tomorrowTask3.category = routineCat
        tomorrowTask3.recurrenceInterval = 1
        tomorrowTask3.recurrenceUnit = .day
        context.insert(tomorrowTask3)
        
        // 后天：更多未来任务
        let futureTask1 = TaskItem(title: "团队建设活动", type: .single, startTime: date(dayOffset: 2, hour: 14), priority: .p2)
        futureTask1.category = lifeCat
        futureTask1.endTime = date(dayOffset: 2, hour: 18)
        futureTask1.plannedScore = 20
        if let funTag = tagMap["fun"] { futureTask1.tags = [funTag] }
        context.insert(futureTask1)
        
        // ────────────────────────────────────────
        // 跨天任务测试（用于月视图跨天横条显示）
        // ────────────────────────────────────────
        
        // 跨越3天的任务：团建出游（今天到后天）
        let crossDayTask3 = TaskItem(title: "团建出游三日", type: .single, startTime: date(dayOffset: 0, hour: 9), priority: .p1)
        crossDayTask3.category = lifeCat
        crossDayTask3.endTime = date(dayOffset: 2, hour: 18)
        crossDayTask3.plannedScore = 100
        crossDayTask3.note = "跨越3天的团建活动"
        if let funTag = tagMap["fun"] { crossDayTask3.tags = [funTag] }
        context.insert(crossDayTask3)
        
        // 跨越8天的任务：项目冲刺期（从明天开始持续8天，跨周显示）
        let crossDayTask8 = TaskItem(title: "项目冲刺周", type: .single, startTime: date(dayOffset: 1, hour: 9), priority: .p0)
        crossDayTask8.category = goalCat
        crossDayTask8.endTime = date(dayOffset: 8, hour: 18)
        crossDayTask8.plannedScore = 300
        crossDayTask8.note = "跨越8天的项目冲刺期，测试跨周显示"
        if let devTag = tagMap["dev"] { crossDayTask8.tags = [devTag] }
        context.insert(crossDayTask8)
        
        // ============================================================
        // 四、长期规划任务
        // ============================================================
        
        // 下周：重要项目
        let nextWeekProject = TaskItem(title: "发布 v2.1 版本", type: .node, startTime: date(dayOffset: 7, hour: 10), priority: .p0)
        nextWeekProject.category = goalCat
        nextWeekProject.plannedScore = 500
        if let devTag = tagMap["dev"] { nextWeekProject.tags = [devTag] }
        context.insert(nextWeekProject)
        
        // 下个月：学习目标
        let nextMonthGoal = TaskItem(title: "完成 Swift 进阶课程", type: .quantity, startTime: date(dayOffset: 30, hour: 9), priority: .p1)
        nextMonthGoal.category = skillCat
        nextMonthGoal.targetValue = 20
        nextMonthGoal.currentValue = 0
        nextMonthGoal.valueUnit = "节课"
        nextMonthGoal.plannedScore = 200
        if let readTag = tagMap["read"] { nextMonthGoal.tags = [readTag] }
        context.insert(nextMonthGoal)
        
        // ============================================================
        // 五、初始化用户积分
        // ============================================================
        
        let userDescriptor = FetchDescriptor<UserProfile>()
        if let userProfile = try? context.fetch(userDescriptor).first {
             userProfile.totalScore = 1500
             userProfile.totalEarned = 1500
        } else {
             let newProfile = UserProfile()
             newProfile.totalScore = 1500
             newProfile.totalEarned = 1500
             context.insert(newProfile)
        }

        // 6. 保存上下文
        do {
            try context.save()
            print("✅ 全面测试数据写入成功！")
            print("📊 数据统计:")
            print("   - 今日任务: 13个 (P0:2, P1:4, P2:4, P3:3)")
            print("   - 节点任务层级: 3层 (含孙任务)")
            print("   - 周期任务类型: 每天/每周/每月")
            print("   - 数量型任务: 3个 (不同进度)")
            print("   - 历史记录: 30天")
        } catch {
            print("❌ 预置数据写入失败: \(error)")
        }
    }
}
