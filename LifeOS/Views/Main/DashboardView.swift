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
                        DateSelectorView(selectedDate: $viewModel.currentDate)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        
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
                                // 2. 两日时间轴 (Multi-Day Timeline)
                                MultiDayTimelineView(
                                    dayItems: viewModel.multiDayRenderItems,
                                    dates: viewModel.multiDayDates,
                                    currentDate: $viewModel.currentDate
                                )
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
        // 监听 Echo 子模式变化（单日/两日切换）刷新数据
        .onChange(of: viewModel.echoMode) { _, _ in
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
    
    @ObservedObject var theme = ThemeManager.shared
    
    /// 最强属性（用于动态渐变色）
    private var dominantAttribute: AttributeType {
        radarData.max(by: { $0.value < $1.value })?.attribute ?? .intellect
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                
                // MARK: - 1. Hero Card: 雷达图 + 核心指标
                heroCard
                
                // MARK: - 2. 积分趋势 (Glassmorphism)
                ScoreTrendView(history: scoreHistory)
                    .padding(.horizontal)
                
                // MARK: - 3. 分布统计 (两列网格)
                distributionGrid
                
                // 底部留白
                Color.clear.frame(height: 80)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Hero Card
    
    private var heroCard: some View {
        VStack(spacing: 0) {
            if radarData.isEmpty {
                ContentUnavailableView("暂无能力数据", systemImage: "hexagon")
                    .frame(height: 280)
            } else {
                // 雷达图
                RadarChartView(data: radarData)
                    .frame(height: 280)
                
                // 六属性网格指标条
                attributeGrid
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    dominantAttribute.color.opacity(0.15),
                                    dominantAttribute.color.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: dominantAttribute.color.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal)
    }
    
    // MARK: - 属性网格
    
    private var attributeGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(radarData) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.attribute.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(item.attribute.color)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.attribute.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(item.rawValue)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(item.attribute.color.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - 分布统计
    
    private var distributionGrid: some View {
        VStack(spacing: 12) {
            if !categoryData.isEmpty {
                HorizontalBarChartView(segments: categoryData, title: "分类分布")
            }
            if !tagData.isEmpty {
                HorizontalBarChartView(segments: tagData, title: "标签分布")
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
}
