import SwiftUI

struct StatsGrid: View {
    let user: UserProfile
    
    // Grid layout - 使用 2x2 布局
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // 1. Total Earned
            StatsMiniCard(
                title: "累计获得",
                value: "\(user.totalEarned)",
                unit: "pts",
                icon: "star.fill",
                color: .yellow
            )
            
            // 2. Tasks Completed
            StatsMiniCard(
                title: "完成任务",
                value: "\(user.completedTaskCount)",
                unit: "个",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            // 3. Days Active
            StatsMiniCard(
                title: "活跃天数",
                value: "\(user.daysActive)",
                unit: "天",
                icon: "flame.fill",
                color: .orange
            )
            
            // 4. Unlocked Achievements
            StatsMiniCard(
                title: "解锁成就",
                value: "\(user.unlockedAchievements.count)",
                unit: "个",
                icon: "trophy.fill",
                color: .purple
            )
        }
        .padding(.horizontal, 24) // 增加水平边距，不贴边
    }
}

struct StatsMiniCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 图标背景
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading) // 确保卡片填满 Grid
        .background(
            ZStack {
                // 1. 磨砂背景
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                // 2. 提亮层
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.5))
                
                // 3. 立体高光边框
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4) // 增加阴影使其立体
        )
    }
}
