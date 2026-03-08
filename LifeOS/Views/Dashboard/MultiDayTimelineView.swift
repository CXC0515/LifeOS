//
//  MultiDayTimelineView.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/28.
//

import SwiftUI

/// 多日时间轴视图
/// 将多个单日时间轴并排展示，用于双日/多日模式
struct MultiDayTimelineView: View {
    /// 多日的渲染数据（下标与 dates 保持一致）
    var dayItems: [[DailyRenderItem]]
    
    /// 多日对应的日期
    var dates: [Date]
    
    /// 当前选中的基准日期（与 DashboardViewModel.currentDate 绑定）
    @Binding var currentDate: Date
    
    @ObservedObject var theme = ThemeManager.shared
    
    // 布局常量（与 DailyTimelineView 保持一致，视觉统一）
    private let morningBlockHeight: CGFloat = 80.0   // 0-6点合并区块高度
    private let hourHeight: CGFloat = 60.0           // 6-24点每小时高度
    private let timeColumnWidth: CGFloat = 55.0
    private let headerHeight: CGFloat = 32.0

    // 拖拽偏移，用于让滑动过程更顺滑
    @State private var dragOffset: CGFloat = 0
    
    // 拖拽方向：仅在明确判断为水平拖拽时才响应左右滑动
    private enum DragDirection {
        case horizontal
        case vertical
    }
    
    @State private var activeDragDirection: DragDirection? = nil
    
    /// 总高度 = 头部 + 早晨区块 + 18小时 + 额外缓冲，便于滚动到晚上
    private var totalHeight: CGFloat {
        headerHeight + morningBlockHeight + hourHeight * 18 + 80
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧时间轴刻度固定不动
            timeAxisColumn
                .frame(width: timeColumnWidth)
            
            // 右侧多日内容：仅在明确识别为水平拖拽时响应左右滑动
            timelineContent
        }
        .frame(height: totalHeight)
    }
    
    // MARK: - 时间轴刻度列
    
    private var timeAxisColumn: some View {
        VStack(spacing: 0) {
            // 头部占位
            Color.clear.frame(height: headerHeight)
            
            // 早晨区块刻度
            Text("00:00")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 45, height: morningBlockHeight, alignment: .topTrailing)
                .offset(y: -6)
            
            // 标准区块刻度 (6-24)
            ForEach(6..<25) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 45, height: hourHeight, alignment: .topTrailing)
                    .offset(y: -6)
            }
        }
    }
    
    // MARK: - 单日列
    
    private func dayColumn(for index: Int) -> some View {
        let items = safeItems(at: index)
        let date = safeDate(at: index)
        
        return VStack(spacing: 0) {
            // 日期标题：仅在标题区域识别左右滑动，避免影响时间轴主体的垂直滚动
            dateHeader(for: date, isToday: Calendar.current.isDateInToday(date))
                .frame(height: headerHeight)
                .contentShape(Rectangle())
                .simultaneousGesture(horizontalDrag)
            
            // 时间轴背景和任务
            ZStack(alignment: .topLeading) {
                // 网格背景
                gridBackground
                
                GeometryReader { geometry in
                    ForEach(items) { item in
                        let yOffset = calculateYOffset(for: item.task.startTime)
                        let baseHeight = calculateDuration(for: item.task)
                        let totalCols = max(item.totalColumns, 1)
                        let cardWidth = max(geometry.size.width - 8, 40) / CGFloat(totalCols)
                        let xOffset = CGFloat(item.columnIndex) * cardWidth + 4
                        let isPoint = item.isPointTask
                        let cardHeight = isPoint ? 24 : max(baseHeight, 24)
                        
                        Group {
                            if isPoint {
                                renderPointTask(item: item, width: cardWidth - 4)
                            } else {
                                TimelineTaskBlockView(
                                    task: item.task,
                                    width: cardWidth - 4,
                                    height: cardHeight
                                )
                            }
                        }
                        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                        .position(
                            x: xOffset + cardWidth / 2,
                            y: yOffset + cardHeight / 2
                        )
                    }
                }
                
                // 当前时间红线（仅今天）
                if Calendar.current.isDateInToday(date) {
                    currentTimeLine
                }
            }
            .frame(height: morningBlockHeight + hourHeight * 18)
        }
    }
    
    // MARK: - 日期标题
    
    private func dateHeader(for date: Date, isToday: Bool) -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d E"
        
        return VStack(spacing: 2) {
            Text(formatter.string(from: date))
                .font(.system(size: 13, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? theme.currentTheme.p2 : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? theme.currentTheme.p2.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
    
    // MARK: - 网格背景
    
    private var gridBackground: some View {
        VStack(spacing: 0) {
            // 早晨区块
            Rectangle()
                .fill(Color.gray.opacity(0.03))
                .frame(height: morningBlockHeight)
            
            Divider()
            
            // 标准区块
            ForEach(6..<24, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: hourHeight)
                Divider()
                    .opacity(0.3)
            }
        }
    }
    
    // MARK: - 当前时间线
    
    private var currentTimeLine: some View {
        let yOffset = calculateYOffset(for: Date())
        return Rectangle()
            .fill(.red)
            .frame(height: 1)
            .offset(y: yOffset)
    }
    
    // MARK: - 手势与辅助方法
    
    private func renderPointTask(item: DailyRenderItem, width: CGFloat) -> some View {
        let task = item.task
        return HStack(alignment: .center, spacing: 8) {
            Circle()
                .stroke(theme.currentTheme.color(for: task.priority), lineWidth: 2)
                .frame(width: 10, height: 10)
            
            Text(task.startTime.formattedTime)
                .font(.system(size: 11, weight: .medium))
            
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(theme.currentTheme.pageBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(theme.currentTheme.color(for: task.priority).opacity(0.3), lineWidth: 1)
        )
    }
    
    /// 多日内容区域：承载横向拖拽手势，避免与外层垂直滚动冲突
    private var timelineContent: some View {
        HStack(alignment: .top, spacing: 0) {
            let columnCount = max(dates.count, 2)
            
            ForEach(0..<columnCount, id: \.self) { index in
                dayColumn(for: index)
                    .frame(maxWidth: .infinity)
                
                if index < columnCount - 1 {
                    Divider()
                        .padding(.top, headerHeight)
                }
            }
        }
        .offset(x: dragOffset)
        .contentShape(Rectangle())
    }
    
    /// 水平拖拽手势：先判定拖拽方向，仅在水平拖拽时更新偏移与切换日期
    private var horizontalDrag: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let absX = abs(dx)
                let absY = abs(dy)
                
                // 尚未锁定方向时，根据阈值与相对大小判定方向
                if activeDragDirection == nil {
                    if absX > absY, absX > 10 {
                        activeDragDirection = .horizontal
                    } else if absY > absX, absY > 10 {
                        activeDragDirection = .vertical
                    }
                }
                
                // 仅在锁定为水平拖拽时，才更新左右偏移
                if activeDragDirection == .horizontal {
                    dragOffset = dx
                } else {
                    dragOffset = 0
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                
                defer {
                    activeDragDirection = nil
                }
                
                // 非水平拖拽时，重置偏移，让外层 ScrollView 负责垂直滚动
                guard activeDragDirection == .horizontal else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                    return
                }
                
                handleSwipe(translationWidth: dx)
            }
    }
    
    private func safeItems(at index: Int) -> [DailyRenderItem] {
        guard index >= 0 && index < dayItems.count else { return [] }
        return dayItems[index]
    }
    
    private func safeDate(at index: Int) -> Date {
        guard index >= 0 && index < dates.count else { return Date() }
        return dates[index]
    }
    
    /// 处理左右滑动手势，根据偏移量切换当前基准日期
    private func handleSwipe(translationWidth: CGFloat) {
        let threshold: CGFloat = 60
        var dayOffset = 0
        
        if translationWidth < -threshold {
            dayOffset = 1
        } else if translationWidth > threshold {
            dayOffset = -1
        }
        
        if dayOffset == 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = 0
            }
            return
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
            shiftCurrentDate(by: dayOffset)
        }
    }
    
    /// 通过日偏移更新当前基准日期
    private func shiftCurrentDate(by dayOffset: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: dayOffset, to: currentDate) {
            currentDate = newDate
        }
    }
    
    /// 计算Y轴偏移（与 DailyTimelineView 逻辑一致）
    private func calculateYOffset(for startTime: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        
        if hour < 6 {
            let totalMinutes = Double(hour * 60 + minute)
            let ratio = totalMinutes / (6 * 60)
            return ratio * morningBlockHeight
        } else {
            let hoursAfter6 = hour - 6
            let offset = morningBlockHeight + CGFloat(hoursAfter6) * hourHeight
            let minuteOffset = (CGFloat(minute) / 60.0) * hourHeight
            return offset + minuteOffset
        }
    }
    
    /// 计算卡片高度
    private func calculateDuration(for task: TaskItem) -> CGFloat {
        guard let endTime = task.endTime else { return 24.0 }
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: task.startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let startMinute = calendar.component(.minute, from: task.startTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        // 简化计算：统一使用标准区块的高度比例
        if startHour < 6 && endHour < 6 {
            let totalStartMinutes = Double(startHour * 60 + startMinute)
            let totalEndMinutes = Double(endHour * 60 + endMinute)
            let duration = totalEndMinutes - totalStartMinutes
            return max((duration / (6 * 60)) * morningBlockHeight, 24)
        }
        
        if startHour >= 6 && endHour >= 6 {
            let durationMinutes = (endHour - startHour) * 60 + (endMinute - startMinute)
            return max((CGFloat(durationMinutes) / 60.0) * hourHeight, 24)
        }
        
        return hourHeight
    }
}

#Preview {
    @Previewable @State var date = Date()
    return MultiDayTimelineView(
        dayItems: [[], []],
        dates: [Date(), Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()],
        currentDate: $date
    )
}
