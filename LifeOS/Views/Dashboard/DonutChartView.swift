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
        VStack(alignment: .leading, spacing: 10) {
            // 标题
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
            
            // 圆环图
            Chart(segments) { segment in
                SectorMark(
                    angle: .value("Value", segment.value),
                    innerRadius: .ratio(0.65),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(segment.color)
            }
            .frame(height: 120)
            .chartBackground { proxy in
                // 中心总数
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let frame = geometry[plotFrame]
                        VStack(spacing: 0) {
                            Text("\(Int(totalValue))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.currentTheme.p1)
                            Text("任务")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            
            // 紧凑图例
            VStack(alignment: .leading, spacing: 4) {
                ForEach(segments.prefix(4)) { segment in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 6, height: 6)
                        
                        Text(segment.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                        
                        Text("\(Int(segment.value))")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    private var totalValue: Double {
        segments.reduce(0) { $0 + $1.value }
    }
}
