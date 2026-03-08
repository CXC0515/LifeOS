//
//  DashboardViewModel.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/28.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// Dashboard 主视图的 ViewModel
/// 负责管理视图状态和协调数据流
@MainActor
final class DashboardViewModel: ObservableObject {
    
    // MARK: - 视图状态
    
    /// 主模式：回响 / 视界
    @Published var viewMode: DashboardMode = .echo
    
    /// Echo 子模式：单日 / 多日 / 月
    @Published var echoMode: EchoMode = .day
    
    /// 当前选中日期
    @Published var currentDate: Date = Date()
    
    // MARK: - 计算后的渲染数据
    
    /// 日视图渲染项
    @Published var dailyRenderItems: [DailyRenderItem] = []
    
    /// 多日视图渲染项（按天分组：当前日期起连续多天）
    @Published var multiDayRenderItems: [[DailyRenderItem]] = [[], []]
    
    /// 多日视图对应的日期（与 multiDayRenderItems 下标一一对应）
    var multiDayDates: [Date] {
        let calendar = Calendar.current
        let dayCount = max(multiDayRenderItems.count, 2)
        
        return (0..<dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: currentDate)
        }
    }
    
    // MARK: - Vision 视图数据
    
    /// 雷达图数据
    @Published var radarData: [RadarChartData] = []
    
    /// 积分历史
    @Published var scoreHistory: [ScoreHistoryItem] = []
    
    /// 分类分布
    @Published var categoryDistribution: [DonutSegment] = []
    
    /// 标签分布
    @Published var tagDistribution: [DonutSegment] = []
    
    // MARK: - 私有属性
    
    private var modelContext: ModelContext?
    private let calculationService = DashboardCalculationService.shared
    private let statsService = StatsService.shared
    
    // MARK: - 初始化
    
    init() {}
    
    // MARK: - 公开方法
    
    /// 设置 ModelContext（从 View 的 @Environment 传入）
    /// - Parameter context: SwiftData ModelContext
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        refreshData()
    }
    
    /// 刷新所有数据
    func refreshData() {
        guard let context = modelContext else { return }
        
        // 根据当前模式刷新相应数据
        switch viewMode {
        case .echo:
            refreshEchoData(context: context)
        case .vision:
            refreshVisionData(context: context)
        }
    }
    
    // MARK: - 私有方法
    
    /// 刷新 Echo 模式数据
    private func refreshEchoData(context: ModelContext) {
        // 获取所有任务
        let allTasks = fetchAllTasks(context: context)
        
        switch echoMode {
        case .day:
            // 日视图：获取当天任务并计算布局
            let dayTasks = filterTasks(allTasks, for: currentDate)
            dailyRenderItems = calculationService.calculateDailyLayout(tasks: dayTasks)
            
        case .multiDay:
            // 两日视图：从当前选中日期开始，连续两天的布局
            multiDayRenderItems = calculationService.calculateMultiDayLayout(
                startDate: currentDate,
                dayCount: 2,
                allTasks: allTasks
            )
        }
    }
    
    /// 刷新 Vision 模式数据
    private func refreshVisionData(context: ModelContext) {
        // 获取用户资料
        if let user = fetchUserProfile(context: context) {
            radarData = statsService.calculateRadarData(user: user)
            scoreHistory = user.scoreHistory
        }
        
        // 获取已完成的任务计算分布
        let completedTasks = fetchCompletedTasks(context: context)
        categoryDistribution = statsService.calculateFocusDistribution(tasks: completedTasks, mode: .category)
        tagDistribution = statsService.calculateFocusDistribution(tasks: completedTasks, mode: .tag)
    }
    
    // MARK: - 数据获取
    
    /// 获取所有任务
    private func fetchAllTasks(context: ModelContext) -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>()
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 获取已完成的任务
    private func fetchCompletedTasks(context: ModelContext) -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isCompleted }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 获取用户资料
    private func fetchUserProfile(context: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - 任务过滤
    
    /// 过滤指定日期的任务
    private func filterTasks(_ tasks: [TaskItem], for date: Date) -> [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
}
