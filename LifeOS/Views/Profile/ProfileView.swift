import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserProfile]
    
    // 获取当前用户，如果没有则创建一个临时的用于预览（防止Crash）
    // 在实际 App 流程中，应该在启动时确保 UserProfile 存在
    private var currentUser: UserProfile? {
        users.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = currentUser {
                        // 1. 身份卡片
                        IdentityCard(user: user)
                        
                        // 2. 数据概览
                        StatsGrid(user: user)
                        
                        // 3. 功能菜单
                        VStack(spacing: 16) {
                            MenuLinkRow(
                                title: "主题工坊",
                                icon: "paintpalette.fill",
                                color: .pink,
                                destination: ThemeSettingsView()
                            )
                            
                            MenuLinkRow(
                                title: "分类管理",
                                icon: "square.grid.2x2.fill",
                                color: .blue,
                                destination: CategoryManagerView()
                            )
                            
                            MenuLinkRow(
                                title: "标签管理",
                                icon: "tag.fill",
                                color: .orange,
                                destination: TagManagerView()
                            )
                            
                            MenuLinkRow(
                                title: "文件管理",
                                icon: "folder.fill",
                                color: .cyan,
                                destination: FileManagerView()
                            )
                        }
                        .padding(.horizontal)
                        
                        // 底部占位，防止被 TabBar 遮挡
                        Color.clear.frame(height: 80)
                        
                    } else {
                        // 如果没有用户数据的兜底视图
                        ContentUnavailableView(
                            "暂无档案",
                            systemImage: "person.slash",
                            description: Text("请尝试重启应用以重新加载数据")
                        )
                        .onAppear {
                            // 尝试自动修复：创建一个默认用户
                            if users.isEmpty {
                                let newUser = UserProfile()
                                modelContext.insert(newUser)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(ThemeManager.shared.currentTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("个人中心")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline) // 使用 Inline 模式，避免大标题占用空间
            #endif
        }
    }
}

// 辅助组件：菜单行
struct MenuLinkRow<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.4)) // 提亮背景
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
            )
        }
        .buttonStyle(.plain) // 保持点击效果但不变蓝
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
