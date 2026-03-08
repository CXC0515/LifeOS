//
//  DailyTimelineView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    // 外部传入布局好的渲染项
    var items: [DailyRenderItem]
    var selectedDate: Date
    
    // 引入 ThemeManager
    @ObservedObject var theme = ThemeManager.shared
    
    // 常量：时间轴布局
    private let morningBlockHeight: CGFloat = 80.0  // 0-6点合并区块高度
    private let hourHeight: CGFloat = 60.0           // 6-24点每小时高度
    private let timeColumnWidth: CGFloat = 55.0
    
    /// 总高度 = 早晨区块(80pt) + 18小时(6-24点, 60pt/h)
    private var totalHeight: CGFloat {
        morningBlockHeight + hourHeight * 18
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            // 1. 底层：时间刻度网格（0-6合并，6-24标准）
            VStack(spacing: 0) {
                // 顶部占位，对齐标题（如果有的话）
                // 这里日视图暂时没有顶部日期标题，但为了统一逻辑，保留小的偏移补齐
                Color.clear.frame(height: 0) 
                
                // 0-6点合并区块
                HStack(alignment: .top) {
                    // 左侧时间文字
                    Text("00:00")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .trailing)
                        .offset(y: -6)
                    
                    // 右侧分割线
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1)
                }
                .frame(height: morningBlockHeight, alignment: .top)
                
                // 6-24点标准区块
                ForEach(6..<25) { hour in
                    HStack(alignment: .top) {
                        // 左侧时间文字
                        Text(String(format: "%02d:00", hour))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 45, alignment: .trailing)
                            .offset(y: -6)
                        
                        // 右侧分割线
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 1)
                    }
                    .frame(height: hourHeight, alignment: .top)
                }
            }
            
            // 2. 中层：任务卡片
            GeometryReader { geometry in
                let timelineWidth = geometry.size.width - timeColumnWidth
                
                ForEach(items) { item in
                    // 计算卡片尺寸和位置
                    let totalCols = max(item.totalColumns, 1)
                    let baseCardWidth = (timelineWidth - 4) / CGFloat(totalCols)
                    let cardWidth = max(baseCardWidth, 40)
                    let xOffset = timeColumnWidth + CGFloat(item.columnIndex) * baseCardWidth
                    
                    // 使用新的 yOffset 计算方法（考虑0-6点压缩）
                    let yOffset = calculateYOffset(for: item.task.startTime)
                    let cardHeight = calculateDuration(for: item.task)
                    
                    Group {
                        if item.isPointTask {
                            renderPointTask(item: item, width: cardWidth)
                        } else {
                            TimelineTaskBlockView(task: item.task, width: cardWidth - 2, height: max(cardHeight, 30))
                        }
                    }
                    .frame(width: cardWidth, height: item.isPointTask ? 24 : cardHeight, alignment: .topLeading)
                    .position(
                        x: xOffset + cardWidth / 2,
                        y: yOffset + (item.isPointTask ? 12 : cardHeight / 2)
                    )
                    .onTapGesture {
                        print("点击了任务: \(item.task.title)")
                    }
                }
            }
            .frame(height: totalHeight)
            
            // 3. 顶层：当前时间红线
            if Calendar.current.isDateInToday(selectedDate) {
                currentTimeLine
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - 辅助方法：计算Y坐标偏移（考虑0-6点压缩）
    
    /// 根据任务开始时间计算Y轴偏移
    /// - Parameter startTime: 任务开始时间
    /// - Returns: Y轴偏移量（pt）
    private func calculateYOffset(for startTime: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        
        if hour < 6 {
            // 早晨区块内（0-6点）：压缩显示
            let totalMinutes = Double(hour * 60 + minute)
            let ratio = totalMinutes / (6 * 60) // 0-360分钟映射到0-1
            return ratio * morningBlockHeight
        } else {
            // 标准区块（6-24点）：正常显示
            let hoursAfter6 = hour - 6
            let offset = morningBlockHeight + CGFloat(hoursAfter6) * hourHeight
            let minuteOffset = (CGFloat(minute) / 60.0) * hourHeight
            return offset + minuteOffset
        }
    }
    
    /// 根据任务时长计算卡片高度（考虑跨越0-6点边界的情况）
    /// - Parameter task: 任务项
    /// - Returns: 卡片高度（pt）
    private func calculateDuration(for task: TaskItem) -> CGFloat {
        guard let endTime = task.endTime else {
            // 无结束时间，默认30分钟
            return 30.0
        }
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: task.startTime)
        let endHour = calendar.component(.hour, from: endTime)
        
        let startMinute = calendar.component(.minute, from: task.startTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        // 情况1：完全在早晨区块内（0-6点）
        if startHour < 6 && endHour < 6 {
            let totalStartMinutes = Double(startHour * 60 + startMinute)
            let totalEndMinutes = Double(endHour * 60 + endMinute)
            let duration = totalEndMinutes - totalStartMinutes
            return (duration / (6 * 60)) * morningBlockHeight
        }
        
        // 情况2：完全在标准区块内（6点之后）
        if startHour >= 6 && endHour >= 6 {
            let durationMinutes = (endHour - startHour) * 60 + (endMinute - startMinute)
            return (CGFloat(durationMinutes) / 60.0) * hourHeight
        }
        
        // 情况3：跨越边界（开始在早晨区块，结束在标准区块）
        if startHour < 6 && endHour >= 6 {
            // 早晨部分高度
            let morningMinutes = (6 - startHour) * 60 - startMinute
            let morningHeight = (Double(morningMinutes) / (6 * 60)) * morningBlockHeight
            
            // 标准部分高度
            let standardMinutes = (endHour - 6) * 60 + endMinute
            let standardHeight = (CGFloat(standardMinutes) / 60.0) * hourHeight
            
            return morningHeight + standardHeight
        }
        
        // 默认返回
        return hourHeight
    }
    
    // MARK: - 子视图：任务卡片渲染
    
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
    
    // MARK: - 当前时间线
    
    private var currentTimeLine: some View {
        let yOffset = calculateYOffset(for: Date())
        
        return HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .frame(width: timeColumnWidth, alignment: .trailing)
                .padding(.trailing, 4)
            
            Rectangle()
                .fill(.red)
                .frame(height: 1)
        }
        .offset(y: yOffset)
    }
}

#Preview {
    DailyTimelineView(items: [], selectedDate: Date())
}
