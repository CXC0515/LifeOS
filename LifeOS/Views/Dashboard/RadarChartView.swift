//
//  RadarChartView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import SwiftUI

struct RadarChartView: View {
    var data: [RadarChartData]
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack {
            ZStack {
                // 1. 背景网格 (六边形)
                RadarGrid()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                // 2. 数据多边形
                if !data.isEmpty {
                    RadarPolygon(data: data)
                        .fill(theme.currentTheme.p1.opacity(0.3))
                    
                    RadarPolygon(data: data)
                        .stroke(theme.currentTheme.p1, lineWidth: 2)
                }
                
                // 3. 属性标签 & 图标
                RadarLabels(data: data)
            }
            .frame(height: 240)
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.currentTheme.pageBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - 辅助组件

struct RadarGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let steps = 4 // 网格层数
        
        for i in 1...steps {
            let r = radius * CGFloat(i) / CGFloat(steps)
            drawHexagon(path: &path, center: center, radius: r)
        }
        
        // 绘制从中心发出的放射线
        for i in 0..<6 {
            let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            path.move(to: center)
            path.addLine(to: point)
        }
        
        return path
    }
    
    private func drawHexagon(path: inout Path, center: CGPoint, radius: CGFloat) {
        for i in 0..<6 {
            let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}

struct RadarPolygon: Shape {
    var data: [RadarChartData]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // 确保数据按 AttributeType 顺序排列 (StatsService 已经保证了，但这里为了安全可以按 AttributeType.allCases 索引)
        // 假设 data 是按顺序的 (Intellect, Strength, ...)
        
        for (i, item) in data.enumerated() {
            let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
            let val = CGFloat(item.value) // 0.0 - 1.0
            let r = radius * val
            
            let point = CGPoint(
                x: center.x + r * cos(angle),
                y: center.y + r * sin(angle)
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct RadarLabels: View {
    var data: [RadarChartData]
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            ForEach(0..<data.count, id: \.self) { i in
                let item = data[i]
                let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
                // 标签稍微靠外一点
                let labelRadius = radius + 25
                let x = center.x + labelRadius * cos(angle)
                let y = center.y + labelRadius * sin(angle)
                
                VStack(spacing: 2) {
                    Image(systemName: item.attribute.icon)
                        .font(.caption)
                        .foregroundStyle(item.attribute.color)
                    Text("\(item.rawValue)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .position(x: x, y: y)
            }
        }
    }
}
