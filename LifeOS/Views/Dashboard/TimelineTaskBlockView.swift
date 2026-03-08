//
//  TimelineTaskBlockView.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/28.
//

import SwiftUI

/// 通用的时间轴任务块：左侧粗线条 + 背景色 + 标题
struct TimelineTaskBlockView: View {
    let task: TaskItem
    let width: CGFloat
    let height: CGFloat
    
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        let categoryColor = getCategoryColor()
        let isCompact = height < 28
        
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(categoryColor.opacity(0.15))
            
            Rectangle()
                .fill(categoryColor)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: 1.5,
                        bottomLeading: 1.5,
                        bottomTrailing: 0,
                        topTrailing: 0
                    ))
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: isCompact ? 11 : 13, weight: .bold))
                    .foregroundStyle(categoryColor.opacity(0.9))
                    .lineLimit(1)
                
                Text(timeString)
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundStyle(categoryColor.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.top, 2)
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(categoryColor.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var timeString: String {
        guard let endTime = task.endTime else { return task.startTime.formattedTime }
        return "\(task.startTime.formattedTime) - \(endTime.formattedTime)"
    }
    
    private func getCategoryColor() -> Color {
        if let category = task.category {
            return theme.color(for: category)
        }
        return .gray
    }
}
