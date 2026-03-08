//
//  ScoreTrendView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import SwiftUI
import Charts

struct ScoreTrendView: View {
    var history: [ScoreHistoryItem]
    @ObservedObject var theme = ThemeManager.shared
    
    // 默认展示最近 30 天
    var recentHistory: [ScoreHistoryItem] {
        let sorted = history.sorted { $0.date < $1.date }
        return Array(sorted.suffix(30))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Trend (30 Days)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Chart(recentHistory, id: \.date) { item in
                // 1. 区域填充 (渐变)
                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Score", item.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.currentTheme.p1.opacity(0.3), theme.currentTheme.p1.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // 2. 线条
                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Score", item.score)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(theme.currentTheme.p1)
            }
            .chartYScale(domain: .automatic(includesZero: false)) // 自动缩放Y轴，不强制包含0
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.currentTheme.pageBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}
