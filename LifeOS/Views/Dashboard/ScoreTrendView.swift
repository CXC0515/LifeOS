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
            // 标题行
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(theme.currentTheme.p1)
                Text("积分趋势 (30天)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 最新积分
                if let latest = recentHistory.last {
                    Text("\(latest.score)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(theme.currentTheme.p1)
                }
            }
            .padding(.horizontal, 16)
            
            if recentHistory.isEmpty {
                ContentUnavailableView("暂无积分记录", systemImage: "chart.line.flattrend.xyaxis")
                    .frame(height: 160)
            } else {
                Chart(recentHistory, id: \.date) { item in
                    // 区域填充 (渐变)
                    AreaMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Score", item.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.p1.opacity(0.3),
                                theme.currentTheme.p1.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // 线条
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Score", item.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.currentTheme.p1, theme.currentTheme.p2],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}
