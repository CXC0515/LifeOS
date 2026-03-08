//
//  MonthlyCalendarView.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/27.
//

import SwiftUI

/// 月视图：网格日历显示，任务以优先级着色的横条展示
struct MonthlyCalendarView: View {
    var items: [MonthlyRenderItem]
    var monthDate: Date
    
    @ObservedObject var theme = ThemeManager.shared
    
    // 常量
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let cellSpacing: CGFloat = 2
    private let taskBarHeight: CGFloat = 18
    private let maxVisibleTasks = 3  // 每个日期格子最多显示3个任务
    
    var body: some View {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: monthDate)!
        let monthStart = monthInterval.start
        
        // 计算月历网格起始日期
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysBeforeMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -daysBeforeMonth, to: monthStart)!
        
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - cellSpacing * 6) / 7
            let rowHeight: CGFloat = 100
            
            VStack(spacing: 0) {
                // 1. 周标题（周日-周六）
                HStack(spacing: cellSpacing) {
                    ForEach(0..<7) { index in
                        Text(weekdays[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: columnWidth, alignment: .center)
                    }
                }
                .padding(.bottom, 8)
                
                // 2. 日历网格（6行×7列）
                VStack(spacing: cellSpacing) {
                    ForEach(0..<6) { rowIndex in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<7) { columnIndex in
                                let dayOffset = rowIndex * 7 + columnIndex
                                let currentDate = calendar.date(byAdding: .day, value: dayOffset, to: gridStart)!
                                
                                renderDateCell(
                                    date: currentDate,
                                    monthStart: monthStart,
                                    monthEnd: monthInterval.end,
                                    cellWidth: columnWidth,
                                    cellHeight: rowHeight,
                                    rowIndex: rowIndex,
                                    columnIndex: columnIndex
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 700)
    }
    
    // MARK: - 日期格子渲染
    
    @ViewBuilder
    private func renderDateCell(
        date: Date,
        monthStart: Date,
        monthEnd: Date,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        rowIndex: Int,
        columnIndex: Int
    ) -> some View {
        let calendar = Calendar.current
        let isCurrentMonth = date >= monthStart && date < monthEnd
        let day = calendar.component(.day, from: date)
        
        // 筛选当前日期的任务
        let tasksForDate = items.filter { item in
            // 检查任务是否在这个格子显示
            let itemStartDay = calendar.startOfDay(for: item.startDate)
            let itemEndDay = calendar.startOfDay(for: item.endDate)
            let currentDay = calendar.startOfDay(for: date)
            
            return currentDay >= itemStartDay && currentDay <= itemEndDay &&
                   item.startRow == rowIndex && item.startColumn == columnIndex
        }
        
        ZStack(alignment: .topLeading) {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentMonth ? theme.currentTheme.pageBackground : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // 日期数字
                Text("\(day)")
                    .font(.system(size: 14, weight: isCurrentMonth ? .semibold : .regular))
                    .foregroundStyle(isCurrentMonth ? .primary : .secondary)
                    .padding(.top, 4)
                    .padding(.leading, 6)
                
                // 任务列表
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tasksForDate.prefix(maxVisibleTasks)) { item in
                        renderTaskBar(item: item, cellWidth: cellWidth, cellHeight: cellHeight)
                    }
                    
                    // 如果任务超过最大显示数量，显示 "+N"
                    if tasksForDate.count > maxVisibleTasks {
                        Text("+\(tasksForDate.count - maxVisibleTasks)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 4)
                
                Spacer()
            }
        }
        .frame(width: cellWidth, height: cellHeight)
    }
    
    // MARK: - 任务横条渲染
    
    @ViewBuilder
    private func renderTaskBar(
        item: MonthlyRenderItem,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        let barWidth: CGFloat = {
            if item.spansDays == 1 {
                // 单日任务，完整宽度
                return cellWidth - 8
            } else if !item.needsWrap {
                // 跨天不跨周，长条
                return cellWidth * CGFloat(item.spansDays) + cellSpacing * CGFloat(item.spansDays - 1) - 8
            } else {
                // 跨周任务，只显示第一段
                let daysInFirstRow = 7 - item.startColumn
                return cellWidth * CGFloat(daysInFirstRow) + cellSpacing * CGFloat(daysInFirstRow - 1) - 8
            }
        }()
        
        HStack(spacing: 2) {
            // 任务横条
            RoundedRectangle(cornerRadius: taskBarHeight / 2)
                .fill(item.priorityColor.opacity(0.8))
                .frame(width: barWidth, height: taskBarHeight)
                .overlay(
                    Text(item.task.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: barWidth, alignment: .leading)
                )
        }
        .onTapGesture {
            print("点击任务: \(item.task.title)")
        }
    }
}

#Preview {
    MonthlyCalendarView(
        items: [],
        monthDate: Date()
    )
}
