//
//  DashboardView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import SwiftUI
import SwiftData

enum DashboardMode: String, CaseIterable {
    case echo = "回响"
    case vision = "视界"
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部导航区
            VStack(spacing: 12) {
                // 模式切换器 (Echo / Vision) - 使用 P2 主题色
                Picker("Dashboard Mode", selection: $viewModel.viewMode) {
                    ForEach(DashboardMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .tint(theme.currentTheme.p2) // 应用 P2 主题色
                
                // Echo 模式下：单日/多日/月切换器 + 日期选择器
                if viewModel.viewMode == .echo {
                    HStack(spacing: 16) {
                        // 子模式切换器 (单日 / 多日 / 月) - 紧凑版
                        EchoModePickerView(selectedMode: $viewModel.echoMode)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        
                        // 日期选择器
                        if viewModel.echoMode == .day || viewModel.echoMode == .multiDay || viewModel.echoMode == .month {
                            DateSelectorView(selectedDate: $viewModel.currentDate)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 10)
            .background(theme.currentTheme.pageBackground)
            .animation(.snappy, value: viewModel.viewMode)
            .animation(.snappy, value: viewModel.echoMode)
            
            // 2. 内容主体
            ZStack {
                theme.currentTheme.pageBackground.ignoresSafeArea()
                
                switch viewModel.viewMode {
                case .echo:
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch viewModel.echoMode {
                            case .day:
                                // 1. 日时间轴 (Daily Timeline)
                                DailyTimelineView(items: viewModel.dailyRenderItems, selectedDate: viewModel.currentDate)
                                
                            case .multiDay:
                                // 2. 多日时间轴 (Multi-Day Timeline，双日视图)
                                MultiDayTimelineView(
                                    dayItems: viewModel.multiDayRenderItems,
                                    dates: viewModel.multiDayDates,
                                    currentDate: $viewModel.currentDate
                                )
                                
                            case .month:
                                // 月视图 (Monthly Calendar)
                                MonthlyCalendarView(items: viewModel.monthlyRenderItems, monthDate: viewModel.currentDate)
                            }
                            
                            // 底部留白
                            Color.clear.frame(height: 80)
                        }
                        .padding(.top, viewModel.echoMode == .multiDay ? 4 : 16)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                    
                case .vision:
                    VisionView(
                        radarData: viewModel.radarData,
                        scoreHistory: viewModel.scoreHistory,
                        categoryData: viewModel.categoryDistribution,
                        tagData: viewModel.tagDistribution
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                }
            }
            .animation(.snappy, value: viewModel.viewMode)
        }
        .background(theme.currentTheme.pageBackground.ignoresSafeArea())
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onAppear {
            viewModel.setContext(modelContext)
        }
        // 监听日期变化刷新数据
        .onChange(of: viewModel.currentDate) { _, _ in
            viewModel.refreshData()
        }
        // 监听模式变化刷新数据
        .onChange(of: viewModel.viewMode) { _, _ in
            viewModel.refreshData()
        }
    }
}

// MARK: - Vision Subview (Refactored to be Dumb)

struct VisionView: View {
    // 纯数据接收
    var radarData: [RadarChartData]
    var scoreHistory: [ScoreHistoryItem]
    var categoryData: [DonutSegment]
    var tagData: [DonutSegment]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. 六维属性雷达 (RPG Attributes)
                if radarData.isEmpty {
                    ContentUnavailableView("暂无能力数据", systemImage: "hexagon")
                        .frame(height: 240)
                } else {
                    RadarChartView(data: radarData)
                }
                
                // 2. 积分趋势 (Score Trend)
                ScoreTrendView(history: scoreHistory)
                
                // 3. 专注分布 (Focus Distribution)
                if !categoryData.isEmpty {
                    DonutChartView(segments: categoryData, title: "Focus by Category")
                }
                
                // 4. 标签分布 (Tag Distribution) - 可选展示
                if !tagData.isEmpty {
                    DonutChartView(segments: tagData, title: "Focus by Tag")
                }
                
                // 底部留白
                Color.clear.frame(height: 80)
            }
            .padding()
        }
    }
}

#Preview {
    DashboardView()
}
