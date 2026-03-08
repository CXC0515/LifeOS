import SwiftUI

// MARK: - 1. 通用液态玻璃修饰符 (用于卡片、弹窗、输入框)
struct LiquidGlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. 物理磨砂 (背景模糊)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // 2. 染色层 (让玻璃带一点点白色，防止太透)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    
                    // 3. 边缘内发光 (模拟玻璃厚度，非常有质感)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.6), location: 0),
                                    .init(color: .white.opacity(0.1), location: 0.3),
                                    .init(color: .white.opacity(0.05), location: 0.5),
                                    .init(color: .white.opacity(0.3), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .blendMode(.overlay)
                }
                // 给整个卡片加一点投影，让它浮起来
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
    }
}

// MARK: - 2. 任务卡片专用样式 (带左侧颜色条)
struct TaskCardModifier: ViewModifier {
    let priority: Priority
    @ObservedObject var theme = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .padding()
            // 应用上面的玻璃效果
            .glassCardStyle(cornerRadius: 16)
            // 在左侧添加优先级颜色条
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(theme.currentTheme.color(for: priority))
                    .frame(width: 4)
                    .cornerRadius(2)
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
            }
    }
}

// MARK: - 3. 便捷调用扩展 (Extensions)
extension View {
    // 任何 View 都能调用 .glassCardStyle() 变身玻璃风格
    func glassCardStyle(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
    
    // 专门给任务列表用的
    func taskCardStyle(priority: Priority) -> some View {
        self.modifier(TaskCardModifier(priority: priority))
    }
    
    // 专门给按钮用的液态效果 (简化版)
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}
