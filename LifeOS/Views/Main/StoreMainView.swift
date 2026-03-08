import SwiftUI
import SwiftData

// MARK: - 积分商城主视图
// 这个视图是积分商城的主要入口，展示用户积分和可兑换的商品列表
struct StoreMainView: View {
    // 获取 SwiftData 的模型上下文，用于数据库操作
    @Environment(\.modelContext) private var context
    // 查询用户配置文件，用于获取当前积分
    @Query private var userProfiles: [UserProfile]
    // 监听主题管理器，以便实时响应主题切换
    @ObservedObject var theme = ThemeManager.shared
    
    // 状态变量：标记是否已经执行过初始化逻辑
    @State private var hasBootstrapped = false
    // 状态变量：存储从数据库加载的商品列表
    @State private var products: [StoreProduct] = []
    // 状态变量：当前用户点击选中的商品，用于弹窗确认
    @State private var selectedProduct: StoreProduct?
    // 状态变量：控制确认弹窗的显示与隐藏
    @State private var showConfirm = false
    // 状态变量：防止重复点击兑换，标记是否正在处理兑换逻辑
    @State private var isRedeeming = false
    // 状态变量：控制兑换结果反馈提示（HUD）的显示
    @State private var showFeedback = false
    // 状态变量：反馈提示显示的具体文字消息
    @State private var feedbackMessage = ""
    // 状态变量：标记反馈是成功还是失败，影响图标颜色
    @State private var feedbackIsSuccess = false
    
    // 计算属性：获取当前用户的总积分，如果不存在用户则默认为0
    private var currentScore: Int {
        Int(userProfiles.first?.totalScore ?? 0)
    }
    
    // 视图主体
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    // 背景层：使用当前主题定义的页面背景色，并忽略安全区域填满全屏
                    theme.currentTheme.pageBackground
                        .ignoresSafeArea()
                    
                    // 内容层：可滚动区域
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. 顶部积分卡片：展示当前积分
                            StatsCard(currentScore: currentScore)
                            
                            // 2. 商品列表：使用网格布局展示商品
                            // LazyVGrid 自适应布局，列宽最小160，间距16
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                                // 遍历商品数组
                                ForEach(products) { product in
                                    // 单个商品卡片组件
                                    StoreProductCard(
                                        product: product,
                                        currentPoints: currentScore,
                                        // 点击兑换按钮的回调
                                        onRedeemTap: {
                                            handleRedeemTap(for: product)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20) // 水平内边距
                            .padding(.bottom, 32)     // 底部留白
                        }
                        .padding(.top, 16) // 顶部留白
                    }
                }
                .navigationTitle("积分商城") // 导航栏标题
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline) // 设置为内联标题模式，更紧凑
                #endif
                // 顶部覆盖层：用于显示操作反馈 HUD
                .overlay(alignment: .top) {
                    if showFeedback {
                        StoreFeedbackHUD(
                            message: feedbackMessage,
                            isSuccess: feedbackIsSuccess
                        )
                        .padding(.top, 16)
                        // 动画过渡效果：从顶部移入 + 透明度变化
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                // 视图加载时的异步任务
                .task {
                    // 如果还没初始化过数据，执行初始化（创建示例商品）
                    if !hasBootstrapped {
                        hasBootstrapped = true
                        StoreService.shared.bootstrapIfNeeded(context: context)
                    }
                    // 加载商品列表
                    refreshProducts()
                }
                // 监听添加商品的通知，实时刷新列表
                .onReceive(NotificationCenter.default.publisher(for: .didAddStoreProduct)) { _ in
                    refreshProducts()
                }
            }
            
            // 确认兑换弹窗 - 移到最外层 ZStack 以避免层级遮挡
            if showConfirm, let product = selectedProduct {
                StoreRedeemAlert(
                    product: product,
                    onConfirm: {
                        redeemSelectedProduct()
                    },
                    onCancel: {
                        withAnimation {
                            showConfirm = false
                            selectedProduct = nil
                        }
                    }
                )
                // 确保弹窗在最上层
                .zIndex(999)
            }
        }
    }
    
    // 处理点击逻辑
    private func handleRedeemTap(for product: StoreProduct) {
        if product.isRedeemed { return }
        
        if currentScore < product.pointsCost {
            // 积分不足提示
            feedbackMessage = "积分不足，还差 \(product.pointsCost - currentScore) 分"
            feedbackIsSuccess = false
            withAnimation { showFeedback = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showFeedback = false }
            }
        } else {
            // 弹出确认框
            selectedProduct = product
            withAnimation {
                showConfirm = true
            }
        }
    }
    
    // 刷新商品列表并排序
    private func refreshProducts() {
        products = StoreService.shared.fetchProducts(context: context)
            .sorted {
                // 1. 未兑换在前，已兑换在后
                if $0.isRedeemed != $1.isRedeemed {
                    return !$0.isRedeemed
                }
                // 2. 同状态下，按价格从低到高
                return $0.pointsCost < $1.pointsCost
            }
    }
    
    // MARK: - 辅助视图组件
    

    
    // 执行兑换逻辑
    private func redeemSelectedProduct() {
        // 卫语句：确保有选中商品且不在处理中
        guard let product = selectedProduct, !isRedeeming else { return }
        
        isRedeeming = true
        // 调用 Service 层执行兑换（扣除积分、更新商品状态）
        let success = StoreService.shared.redeem(product: product, context: context)
        
        // 刷新列表以更新排序（已兑换的沉底）
        refreshProducts()
        
        // 设置反馈信息
        feedbackIsSuccess = success
        feedbackMessage = success ? "兑换成功，记得去享受你的奖励～" : "积分不足，去完成更多任务获得积分吧"
        
        // 显示反馈 HUD
        withAnimation {
            showFeedback = true
        }
        
        // 2秒后自动隐藏 HUD
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showFeedback = false
            }
        }
        
        // 重置状态
        selectedProduct = nil
        showConfirm = false
        isRedeeming = false
    }
}

// MARK: - 商品卡片组件
// 这是一个私有子视图，专门用于渲染单个商品卡片
private struct StoreProductCard: View {
    // 商品数据模型
    let product: StoreProduct
    // 当前用户积分（用于判断是否可兑换）
    let currentPoints: Int
    // 点击兑换按钮的回调闭包
    let onRedeemTap: () -> Void
    // 主题管理器
    @ObservedObject var theme = ThemeManager.shared
    
    // 计算属性：判断是否可以兑换（积分足够 且 未被兑换）
    private var canRedeem: Bool {
        currentPoints >= product.pointsCost && !product.isRedeemed
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. 商品图片区域
            ZStack {
                // 图片背景：半透明白色圆角矩形
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.85))
                
                // 根据商品图片类型渲染不同图片
                Group {
                    switch product.imageKind {
                    case .symbol: // SF Symbols 图标
                        Image(systemName: product.imageRef)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.secondary)
                    case .asset: // 本地资源图片
                        Image(product.imageRef)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .file: // 文件路径
                        if let image = loadImage(fileName: product.imageRef) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.secondary)
                        }
                    }
                }
            }
            .frame(height: 88) // 固定高度
            // 覆盖层：如果已兑换，显示“已兑换”遮罩
            .overlay {
                if product.isRedeemed {
                    ZStack {
                        Color.black.opacity(0.1)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text("已兑换")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                    }
                }
            }
            
            // 2. 商品信息区域
            VStack(spacing: 6) {
                // 商品名称
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                
                // 商品描述
                Text(product.desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            
            // 3. 积分价格标签
            HStack {
                Text("\(product.pointsCost) 积分")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.currentTheme.p1) // 字体颜色：使用主题定义的 P1 色
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.currentTheme.p1.opacity(0.12)) // 背景颜色：P1 色 + 低透明度
                    .clipShape(Capsule())
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // 4. 兑换按钮
            Button {
                onRedeemTap()
            } label: {
                Text(product.isRedeemed ? "已兑换" : (canRedeem ? "立即兑换" : "积分不足"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if product.isRedeemed {
                                Color.gray.opacity(0.5)
                            } else if canRedeem {
                                theme.currentTheme.p1
                            } else {
                                theme.currentTheme.p1.opacity(0.3)
                            }
                        }
                    )
                    .clipShape(Capsule())
            }
            .disabled(product.isRedeemed) // 只在已兑换时禁用，允许点击积分不足按钮
        }
        .padding(16)
        .glassCardStyle(cornerRadius: 24)
    }
    
    private func loadImage(fileName: String) -> Image? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        #if os(macOS)
        if let nsImage = NSImage(contentsOf: fileURL) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(contentsOfFile: fileURL.path) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
}

// MARK: - 反馈提示组件 (HUD)
// 用于操作成功或失败时的顶部弹出提示
private struct StoreFeedbackHUD: View {
    let message: String
    let isSuccess: Bool
    
    var body: some View {
        HStack {
            // 图标：成功显示绿色对勾，失败显示黄色警告
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .green : .yellow)
            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCardStyle(cornerRadius: 20)
        .padding(.horizontal, 24)
    }
}
