# LifeOS

LifeOS 是一款基于 SwiftUI 构建的全面、美观的个人生活管理 iOS 应用程序。它通过游戏化的机制（如奖励商店）帮助用户追踪任务、可视化每日成就、管理自定义分类与标签，并维持平衡的生活方式。

## 主要功能

- **仪表盘 (Dashboard)**：通过丰富的图表（雷达图、环形图和趋势图）全面了解你的生活状态。包含时间轴和月历视图。
- **任务管理 (Task Management)**：采用精致的毛玻璃（Glassmorphism） UI 设计，轻松添加、追踪和管理每日或长期任务。
- **游戏化商店 (Store)**：通过完成任务赚取积分，并在商店模块中兑换自定义奖励。
- **个人主页与个性化 (Profile)**：深度的个性化主题设置，强大的标签和分类管理，以及详细的个人统计数据。
- **智能服务 (Smart Services)**：内置农历支持，通知管理，以及高级的数据统计处理能力。

## 技术栈

- **框架**: SwiftUI
- **架构**: MVVM
- **语言**: Swift 5+
- **平台**: iOS

## 项目结构

- `Models/`: 核心数据模型（例如 TaskItem, UserProfile, StoreProduct 等）
- `Services/`: 业务逻辑、数据持久化及外部服务（例如 TaskService, StoreService, LunarCalendarService 等）
- `Viewmodels/`: UI 状态管理及数据准备（例如 DashboardViewModel, AppUIState 等）
- `Views/`: SwiftUI 视图，按主标签页分类（Dashboard, Home, Profile, Store）
- `Utils/`: 实用工具类，包括设计系统 (DesignSystem)、主题管理器 (ThemeManager) 和通知服务等。

## 安装指南

1. 克隆此仓库到本地:
   ```bash
   git clone https://github.com/CXC0515/LifeOS.git
   ```
2. 在 Xcode 中打开项目:
   ```bash
   cd LifeOS
   open LifeOS.xcodeproj
   ```
3. 选择一个 iOS 模拟器或实体设备进行编译和运行。

## 许可证

本项目基于 MIT 许可证开源 - 详情请查看 LICENSE 文件。
