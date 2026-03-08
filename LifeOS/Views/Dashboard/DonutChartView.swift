//
//  DonutChartView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import SwiftUI
import Charts

struct DonutChartView: View {
    var segments: [DonutSegment]
    var title: String
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            HStack {
                // 1. 图表部分
                Chart(segments) { segment in
                    SectorMark(
                        angle: .value("Value", segment.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5 // 扇区间隙
                    )
                    .cornerRadius(4)
                    .foregroundStyle(segment.color)
                }
                .frame(height: 180)
                .chartBackground { proxy in
                    // 中心显示总数
                    GeometryReader { geometry in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geometry[plotFrame]
                            VStack(spacing: 0) {
                                Text("\(Int(totalValue))")
                                    .font(.title2.bold())
                                    .foregroundStyle(theme.currentTheme.p1)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                
                // 2. 图例部分 (右侧)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(segments.prefix(5)) { segment in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 8, height: 8)
                            
                            Text(segment.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(Int(segment.value))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 100) // 固定宽度给图例
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.currentTheme.pageBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private var totalValue: Double {
        segments.reduce(0) { $0 + $1.value }
    }
}
