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
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 1. 背景网格 (六边形)
            RadarGrid()
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.8)
            
            // 2. 数据多边形 (带动画)
            if !data.isEmpty {
                RadarPolygon(data: data, progress: animationProgress)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.p1.opacity(0.35),
                                theme.currentTheme.p2.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RadarPolygon(data: data, progress: animationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [theme.currentTheme.p1, theme.currentTheme.p2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                
                // 数据点高光
                RadarDots(data: data, progress: animationProgress)
            }
            
            // 3. 属性标签 & 图标
            RadarLabels(data: data)
        }
        .padding(30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
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
    var progress: CGFloat = 1.0
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for (i, item) in data.enumerated() {
            let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
            let val = CGFloat(item.value) * progress
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

/// 雷达图数据点高光圆
struct RadarDots: View {
    var data: [RadarChartData]
    var progress: CGFloat
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            ForEach(0..<data.count, id: \.self) { i in
                let item = data[i]
                let angle = CGFloat(i) * 60 * .pi / 180 - .pi / 2
                let val = CGFloat(item.value) * progress
                let r = radius * val
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)
                
                Circle()
                    .fill(item.attribute.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: item.attribute.color.opacity(0.4), radius: 4)
                    .position(x: x, y: y)
            }
        }
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
                let labelRadius = radius + 22
                let x = center.x + labelRadius * cos(angle)
                let y = center.y + labelRadius * sin(angle)
                
                VStack(spacing: 2) {
                    Image(systemName: item.attribute.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(item.attribute.color)
                    Text(item.attribute.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .position(x: x, y: y)
            }
        }
    }
}
