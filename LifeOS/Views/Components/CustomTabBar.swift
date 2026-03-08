import SwiftUI

// 自定义底部 TabBar，带有玻璃胶囊选中背景和弹性动画

struct CustomTabBar: View {
    // 当前选中的 Tab 索引，由外部页面传入并绑定
    @Binding var selectedTab: AppTab
    // 全局主题管理器，用于获取当前主题的颜色配置
    @ObservedObject var theme = ThemeManager.shared
    // 跟随系统外观（浅色 / 深色），如需按需定制可使用该环境值
    @Environment(\.colorScheme) private var colorScheme
    
    private let containerBackgroundOpacity: CGFloat = 0.32
    
    var body: some View {
        // 横向排列所有 Tab 按钮，均分可点击区域
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                // 单个 Tab 按钮
                Button {
                    // 点击时切换选中索引，并使用弹簧动画让胶囊与图标平滑过渡
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack {
                        // 仅展示图标，不显示文字
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                            // 选中时使用主题前景色，未选中时将其降低不透明度做区分
                            .foregroundStyle(
                                selectedTab == tab
                                ? theme.currentTheme.surfaceOnPrimary
                                : theme.currentTheme.surfaceOnPrimary.opacity(0.5)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 底部小圆点指示器：高亮当前选中的 Tab
                    .overlay(alignment: .bottom) {
                        Circle()
                            .fill(theme.currentTheme.surfaceOnPrimary)
                            .frame(width: 4, height: 4)
                            .opacity(selectedTab == tab ? 1 : 0)
                            .offset(y: -8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        // 固定高度，保证外观统一
        .frame(height: 64)
        .background(
            // 使用 GeometryReader 获取外部容器尺寸，以便计算胶囊的位置与宽度
            GeometryReader { geo in
                // 胶囊选中背景（SelectionGlassPill），会根据 selectedTab 自动移动
                SelectionGlassPill(
                    selectedIndex: selectedTab.rawValue,
                    totalCount: AppTab.allCases.count,
                    size: geo.size
                )
            }
        )
        // 略微内缩，让外层胶囊边距更自然
        .padding(.horizontal, 6)
        .background(
            // 外层整体背景：半透明胶囊 + 边框描边，形成玻璃质感的容器
            Capsule()
                .fill(theme.currentTheme.baseColor.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.6), location: 0),
                                    .init(color: .white.opacity(0.1), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
        )
        // 与屏幕边缘再增加一层间距，避免贴边
        .padding(.horizontal, 24)
        // 再次裁剪成胶囊形状，保证所有子视图都在胶囊内部
        .clipShape(Capsule())
    }
}

// MARK: - 1. 移动的玻璃胶囊 (选中背景)
// 负责绘制并动画展示当前选中 Tab 背后的玻璃胶囊背景
private struct SelectionGlassPill: View {
    // 读取当前系统的浅色 / 深色模式，可用于按需调整外观
    @Environment(\.colorScheme) private var colorScheme
    // 共享主题管理器，用于获取颜色
    @ObservedObject var theme = ThemeManager.shared
    // 控制选中时的“弹跳”缩放动画状态
    @State private var bounceActive: Bool = false
    
    // 当前被选中的 Tab 索引
    let selectedIndex: Int
    // Tab 的总数量，用于按比例分配宽度
    let totalCount: Int
    // 外部容器的整体尺寸（由 GeometryReader 传入）
    let size: CGSize
    
    // 统一的内边距 / 间距常量，控制胶囊与外部边缘的距离
    private let spacing: CGFloat = 6
    
    var body: some View {
        // 计算每个 Item 的宽度：总宽度均分给每个 Tab
        let itemWidth = size.width / CGFloat(totalCount)
        let height = size.height
        
        // 垂直方向：上下各留 spacing，让胶囊不要贴边
        let finalHeight = height - (spacing * 2)
        
        // 水平方向：根据 selectedIndex 计算每个胶囊左右的边距
        let isFirst = selectedIndex == 0
        let isLast = selectedIndex == totalCount - 1
        
        let leadingPadding = isFirst ? 0 : spacing / 2
        let trailingPadding = isLast ? 0 : spacing / 2
        
        // 实际胶囊宽度 = 单个 Item 宽度 - 左右边距
        let finalWidth = itemWidth - leadingPadding - trailingPadding
        
        // 计算 Pill 的中心位置
        let xOffset = (leadingPadding - trailingPadding) / 2
        // 当前选中索引的中点位置 + 修正偏移量，得到胶囊中心
        let centerX = itemWidth * CGFloat(selectedIndex) + itemWidth / 2 + xOffset
        
        return Capsule()
            // 胶囊主体填充颜色：基于主题的半透明前景色
            .fill(theme.currentTheme.baseColor)
            // 叠加系统提供的超薄材质，增强玻璃模糊效果
            .background(.ultraThinMaterial, in: Capsule())
            // 外轮廓描边，使用线性渐变模拟光照效果
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.6), location: 0),
                                .init(color: .white.opacity(0.1), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            // 在胶囊下方添加阴影，让选中状态更加突出且有浮起感
            .shadow(color: theme.currentTheme.baseColor.opacity(0.5), radius: 10, x: 0, y: 5)
            .frame(width: finalWidth, height: finalHeight)
            // 弹性动画：bounceActive 为 true 时放大到 1.15，制造“按下 / 回弹”效果
            .scaleEffect(bounceActive ? 1.15 : 1.0)
            .position(x: centerX, y: height / 2)
            // 当 selectedIndex 变化时触发一次“放大再回弹”的短动画
            .onChange(of: selectedIndex) { _, _ in
                // 1. 立即触发短暂放大动画
                withAnimation(.easeOut(duration: 0.1)) {
                    bounceActive = true
                }
                
                // 2. 轻微延迟后采用弹簧动画恢复到原始大小
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        bounceActive = false
                    }
                }
            }
            // 确保位置移动也是平滑的：选中项变更时，胶囊会带弹簧效果平滑滑动
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedIndex)
    }
}
