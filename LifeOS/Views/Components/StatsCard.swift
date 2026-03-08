import SwiftUI
import SwiftData

// 定义视图模式枚举
enum TaskViewMode {
    case list
    case matrix
}

struct StatsCard: View {
    let currentScore: Int
    var viewMode: Binding<TaskViewMode>?
    @ObservedObject var theme = ThemeManager.shared
    
    init(currentScore: Int, viewMode: Binding<TaskViewMode>? = nil) {
        self.currentScore = currentScore
        self.viewMode = viewMode
    }
    
    // UI 常量，与 GlassTaskRow 保持一致
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // A. 背景层 (复用 GlassTaskRow 的三层叠加样式)
            glassBackground
            
            // B. 内容层
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前积分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(currentScore)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .foregroundStyle(Color.primary)
                        Text("pts")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                // 右侧视图切换器 (仅在提供 viewMode 时显示)
                if let viewMode = viewMode {
                    HStack(spacing: 0) {
                        modeButton(
                            systemImage: "list.bullet",
                            isActive: viewMode.wrappedValue == .list
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                viewMode.wrappedValue = .list
                            }
                        }
                        
                        modeButton(
                            systemImage: "square.grid.2x2",
                            isActive: viewMode.wrappedValue == .matrix
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                viewMode.wrappedValue = .matrix
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(theme.currentTheme.p1.opacity(0.12))
                    )
                }
            }
            .padding(24)
        }
        .frame(height: 100) // 固定高度或自适应
        .padding(.horizontal)
    }
    
    // 复用 GlassTaskRow 的背景样式
    private var glassBackground: some View {
        ZStack {
            // 底层：超薄材质
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            
            // 中层：白色半透明遮罩，增加亮度
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.4))
            
            // 顶层：边框描边
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func modeButton(systemImage: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isActive ? theme.currentTheme.p1 : Color.clear)
                )
                .foregroundStyle(isActive ? Color.white : theme.currentTheme.textColor.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2).ignoresSafeArea()
        StatsCard(currentScore: 1250, viewMode: .constant(.list))
    }
}
