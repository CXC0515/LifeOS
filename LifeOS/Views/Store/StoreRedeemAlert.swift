import SwiftUI

struct StoreRedeemAlert: View {
    let product: StoreProduct
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        ZStack {
            // 1. 全屏半透明遮罩
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // 2. 弹窗主体
            VStack(spacing: 20) {
                // 标题
                Text("确认兑换")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                // 内容
                Text("确定使用 \(product.pointsCost) 积分兑换\n「\(product.name)」吗？")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                // 按钮组
                HStack(spacing: 16) {
                    // 取消按钮
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // 确认兑换按钮
                    Button(action: onConfirm) {
                        Text("确认兑换")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            // 核心要求：底色80%的P1
                            .background(theme.currentTheme.p1.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 10)
            }
            .padding(24)
            // 玻璃拟态背景
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.5))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .transition(.opacity) // 简单的淡入淡出动画
        .zIndex(100) // 确保在最上层
    }
}
