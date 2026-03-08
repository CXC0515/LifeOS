//
//  HorizontalBarChartView.swift
//  LifeOS
//
//  Replaces DonutChartView for category/tag distributions.
//  Shows horizontal bars sorted from most to least.
//

import SwiftUI

struct HorizontalBarChartView: View {
    var segments: [DonutSegment]
    var title: String
    @ObservedObject var theme = ThemeManager.shared
    
    /// 最大值，用于计算条形宽度比例
    private var maxValue: Double {
        segments.map(\.value).max() ?? 1
    }
    
    /// 总数
    private var totalValue: Int {
        Int(segments.reduce(0) { $0 + $1.value })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题 + 总数
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("共 \(totalValue) 项")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            
            if segments.isEmpty {
                // 空状态
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title3)
                            .foregroundStyle(.quaternary)
                        Text("暂无数据")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                // 排序后的横条列表 (已由 StatsService 排序)
                VStack(spacing: 8) {
                    ForEach(segments) { segment in
                        HStack(spacing: 10) {
                            // 图标（如果有）
                            if let icon = segment.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(segment.color)
                                    .frame(width: 16)
                            }
                            
                            // 名称
                            Text(segment.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(width: 52, alignment: .leading)
                            
                            // 进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // 背景轨道
                                    Capsule()
                                        .fill(segment.color.opacity(0.1))
                                    
                                    // 进度填充
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [segment.color.opacity(0.7), segment.color],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(geo.size.width * CGFloat(segment.value / maxValue), 4))
                                }
                            }
                            .frame(height: 10)
                            
                            // 数值
                            Text("\(Int(segment.value))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
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
}
