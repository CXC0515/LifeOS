import SwiftUI
import SwiftData

// 应用的主 Tab 容器
// 负责承载底部导航栏、不同功能页面的切换，以及全局的添加任务弹窗入口
struct MainTabView: View {
    @EnvironmentObject var appUIState: AppUIState
    @State private var selectedTab: AppTab = .home
    @State private var showAddTaskSheet: Bool = false
    @State private var showAddProductSheet: Bool = false // 新增：控制添加商品 Sheet
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - 1. 内容层
            // 负责承载具体的页面，完全撑满屏幕
            contentLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // MARK: - 2. 底部渐变模糊层
            // 提供从物理底部向上的渐变模糊效果，增强沉浸感
            bottomGradientBlur
            
            // MARK: - 3. 导航交互层
            // 悬浮在内容之上，不影响内容的布局计算
            tabBarOverlay
        }
        .ignoresSafeArea(.keyboard)
        // 全局弹窗：添加任务入口
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskView()
                .presentationDetents([.medium, .large])
        }
        // 全局弹窗：添加商品入口
        .sheet(isPresented: $showAddProductSheet) {
            StoreProductAddSheet {
                // 添加成功后的回调
                NotificationCenter.default.post(name: .didAddStoreProduct, object: nil)
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - 内容层
    private var contentLayer: some View {
        ZStack {
            // 背景层
            theme.currentTheme.pageBackground
                .ignoresSafeArea()
            
            // 页面路由
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .dashboard:
                    DashboardView()
                case .store:
                    StoreMainView()
                case .profile:
                    ProfileView()
                }
            }
        }
        // 使用透明占位符来保留底部安全区域，防止内容被 TabBar 遮挡
        // 这样既实现了 UI 分层，又保证了内容布局不被覆盖
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
    }
    
    // MARK: - 底部渐变模糊层
    private var bottomGradientBlur: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8) // 降低模糊层的不透明度，使效果更通透
                .frame(height: 160)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.3),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - 导航交互层
    private var tabBarOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            if !appUIState.isTabBarHidden {
                CustomTabBar(selectedTab: $selectedTab)
                
                if shouldShowFloatingButton {
                    AddTaskFloatingButton {
                        if selectedTab == .home {
                            showAddTaskSheet = true
                        } else if selectedTab == .store {
                            showAddProductSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private var shouldShowFloatingButton: Bool {
        selectedTab == .home || selectedTab == .store
    }
}

#Preview {
    // 预览时注入内存中的模型容器，方便在 Xcode 预览里看到真实数据效果
    MainTabView()
        .environmentObject(AppUIState())
        .modelContainer(previewContainer)
}

// 右下角统一样式的玻璃悬浮按钮
// 封装了“加号”图标和位置偏移，便于在不同 Tab 复用
struct AddTaskFloatingButton: View {
    let action: () -> Void
    
    var body: some View {
        GlassIconButton(systemName: "plus", size: 56) {
            action()
        }
        .offset(x: -30, y: -90)
    }
}

@MainActor
// 仅用于预览环境的 ModelContainer
// 使用内存存储和示例数据，避免对真实数据造成影响
let previewContainer: ModelContainer = {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TaskItem.self,
            TaskCategory.self,
            TaskTag.self,
            UserProfile.self,
            StoreProduct.self,
            configurations: config
        )
        
        // 预先加载数据
        DataLoader.loadSampleDataIfNeeded(context: container.mainContext)
        
        return container
    } catch {
        fatalError("Failed to create preview container: \(error.localizedDescription)")
    }
}()
