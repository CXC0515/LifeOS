import SwiftUI

// 应用的主导航 Tab 枚举
// 定义了所有的一级页面入口
enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case dashboard = 1
    case store = 2
    case profile = 3
    
    var id: Int { rawValue }
    
    // Tab 对应的图标 SF Symbol 名称
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dashboard: return "chart.bar.fill"
        case .store: return "cart.fill"
        case .profile: return "person.fill"
        }
    }
    
    // Tab 对应的标题（如果将来需要显示文字）
    var title: String {
        switch self {
        case .home: return "首页"
        case .dashboard: return "统计"
        case .store: return "商店"
        case .profile: return "我的"
        }
    }
}
