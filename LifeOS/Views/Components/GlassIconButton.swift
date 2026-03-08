import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - 按压缩放效果
// 提供按钮按下时的统一“放大 + 轻微回弹 + 触觉反馈”交互样式
public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // 按下时轻微放大，松开时恢复原始大小
            .scaleEffect(configuration.isPressed ? 1.12 : 1.0)
            // 使用弹簧动画让缩放更加自然
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
            // 根据 isPressed 变化触发系统层级的触觉反馈
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    #if os(iOS)
                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                    impact.impactOccurred()
                    #elseif os(macOS)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    #endif
                }
            }
    }
}

// MARK: - 玻璃质感按钮
// 一个带有玻璃质感背景和阴影的圆形图标按钮，常用于主操作按钮
public struct GlassIconButton: View {
    // 显示的 SF Symbol 名称
    public let systemName: String
    // 按钮整体直径（宽高相同）
    public let size: CGFloat
    // 按钮点击回调
    public let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    // 主题管理器，用于根据当前主题获取颜色
    @ObservedObject var theme = ThemeManager.shared
    
    public init(systemName: String = "plus", size: CGFloat = 56, action: @escaping () -> Void) {
        self.systemName = systemName
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // 背景层：半透明圆形玻璃 + 高光边缘 + 阴影
                Circle()
                    .fill(theme.currentTheme.baseColor)
                    .background(.ultraThinMaterial, in: Circle())
                    // 1. 边缘内发光/折射模拟 (Inner Glow/Refraction)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.5), location: 0),
                                        .init(color: .white.opacity(0.1), location: 0.3),
                                        .init(color: .white.opacity(0.0), location: 0.5),
                                        .init(color: .white.opacity(0.2), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 3
                            )
                            .blendMode(.overlay)
                    )
                    // 2. 边框高光 (Outer Border Highlight)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.8), location: 0.0),
                                        .init(color: .white.opacity(0.2), location: 0.4),
                                        .init(color: .white.opacity(0.05), location: 0.6),
                                        .init(color: .white.opacity(0.4), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    // 阴影
                    .shadow(
                        color: theme.currentTheme.baseColor.opacity(0.6),
                        radius: 10,
                        x: 0,
                        y: 6
                    )
                
                // 图标：放置在玻璃按钮中央
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(theme.currentTheme.surfaceOnPrimary)
            }
            .frame(width: size, height: size)
        }
        // 统一应用按压缩放 + 触觉反馈的样式
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 动态液态光圈
// 绘制一个不断流动变化的“液态光圈”效果，可叠加在玻璃按钮或背景之上
public struct LiquidGlassCircle: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        // 使用 TimelineView(.animation) 提供连续动画时间线
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // 当前时间，用于驱动动画相位
                let t = timeline.date.timeIntervalSinceReferenceDate
                // 画布尺寸与中心点
                let w = size.width
                let h = size.height
                let cx = w / 2
                let cy = h / 2
                let r = min(w, h) / 2
                
                // 光泽渐变：从中心高亮到边缘透明，用于模拟光斑
                let edgeGradient = Gradient(colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.75 : 0.88),
                    Color.white.opacity(0)
                ])
                
                // 绘制 4 个在圆周上旋转的光斑，速度和相位略有差异
                for i in 0..<4 {
                    let speed = 0.9 + 0.22 * Double(i)
                    let phase = t * speed + Double(i) * .pi * 0.5
                    let angle = CGFloat(phase.truncatingRemainder(dividingBy: .pi * 2))
                    let ex = cx + (r * 0.9) * cos(angle)
                    let ey = cy + (r * 0.9) * sin(angle)
                    let radius = r * 0.55
                    
                    let center = CGPoint(x: ex, y: ey)
                    let shading = GraphicsContext.Shading.radialGradient(
                        edgeGradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                    
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    
                    // 使用叠加混合模式，使光斑与背景产生柔和融合
                    context.blendMode = .overlay
                    context.fill(Path(ellipseIn: rect), with: shading)
                }
            }
        }
    }
}
