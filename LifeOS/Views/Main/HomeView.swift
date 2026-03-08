import SwiftUI
import SwiftData

// 定义可折叠的分组枚举
enum TaskSection: String, Identifiable, CaseIterable {
    case overdue = "已过期"
    case active = "进行中"
    case completed = "已完成"
    var id: String { rawValue }
}

struct HomeView: View {
    @ObservedObject var theme = ThemeManager.shared
    
    // 1. 获取数据库上下文
    @Environment(\.modelContext) private var modelContext
    
    // 2. 获取所有根任务
    @Query(filter: #Predicate<TaskItem> { $0.parent == nil },
           sort: \TaskItem.startTime, order: .forward)
    var tasks: [TaskItem]
    
    // 3. 获取用户钱包
    @Query var userProfiles: [UserProfile]
    
    // 4. 获取所有分类
    @Query(sort: \TaskCategory.sortOrder) var categories: [TaskCategory]
    
    // 状态：当前选中的分类 (nil 表示全部)
    @State private var selectedCategory: TaskCategory?
    
    // 状态：当前正在编辑的任务
    @State private var editingTask: TaskItem?
    
    // 状态：视图模式 (列表 vs 宫格)
    @State private var viewMode: TaskViewMode = .list
    
    // 状态：折叠的分组 (默认全展开)
    @State private var expandedSections: Set<TaskSection> = Set(TaskSection.allCases)
    
    // 计算属性：安全获取当前分数
    var currentScore: Int {
        return Int(userProfiles.first?.totalScore ?? 0)
    }
    
    // 计算属性：当前昵称
    var currentNickname: String {
        return userProfiles.first?.nickname ?? "程同学"
    }
    
    // 计算属性：当前成就
    var currentAchievement: String {
        return userProfiles.first?.selectedAchievement ?? "才高八斗"
    }
    
    // 计算属性：当前等级
    var currentLevel: Int {
        return userProfiles.first?.level ?? 1
    }
    
    // 过滤后的任务列表 (基础过滤：分类 + 可见性)
    var filteredTasks: [TaskItem] {
        tasks.filter { task in
            // 1. 分类过滤
            if let selected = selectedCategory {
                if task.category?.id != selected.id {
                    return false
                }
            }
            // 2. 可见性过滤
            return isTaskVisible(task)
        }
    }
    
    // 分组数据源
    var overdueTasks: [TaskItem] {
        filteredTasks.filter { !$0.isCompleted && $0.isOverdue }
    }
    
    var activeTasks: [TaskItem] {
        filteredTasks.filter { !$0.isCompleted && !$0.isOverdue }
    }
    
    var completedTasks: [TaskItem] {
        filteredTasks.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                theme.currentTheme.pageBackground.ignoresSafeArea()
                
                // 主滚动容器
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. 顶部 Header
                        headerSection
                        
                        // 2. HUD (含视图切换)
                        StatsCard(currentScore: currentScore, viewMode: $viewMode)
                        
                        // 3. 分类过滤器 (在宫格模式下依然保留，作为全局筛选)
                        categoryFilter
                        
                        // 4. 核心内容区域
                        if tasks.isEmpty {
                            emptyState
                        } else {
                            if viewMode == .list {
                                // 列表视图
                                listViewContent
                            } else {
                                // 宫格视图
                                matrixViewContent
                            }
                        }
                        
                        // 底部留白
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top)
                }
                .scrollIndicators(.hidden)
            }
            // 移除 navigationTitle
            .toolbar {
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
        }
        // 自动检测并生成数据
        .onAppear {
            DataLoader.loadSampleDataIfNeeded(context: modelContext)
        }
    }
    
    // MARK: - 列表视图内容
    var listViewContent: some View {
        VStack(spacing: 20) {
            // 1. 已过期
            if !overdueTasks.isEmpty {
                TaskSectionView(
                    section: .overdue,
                    tasks: overdueTasks,
                    isExpanded: expandedSections.contains(.overdue),
                    theme: theme,
                    onToggle: toggleSection,
                    onDelete: deleteTask,
                    onEdit: { editingTask = $0 }
                )
            }
            
            // 2. 进行中
            if !activeTasks.isEmpty {
                TaskSectionView(
                    section: .active,
                    tasks: activeTasks,
                    isExpanded: expandedSections.contains(.active),
                    theme: theme,
                    onToggle: toggleSection,
                    onDelete: deleteTask,
                    onEdit: { editingTask = $0 }
                )
            }
            
            // 3. 已完成
            if !completedTasks.isEmpty {
                TaskSectionView(
                    section: .completed,
                    tasks: completedTasks,
                    isExpanded: expandedSections.contains(.completed),
                    theme: theme,
                    onToggle: toggleSection,
                    onDelete: deleteTask,
                    onEdit: { editingTask = $0 }
                )
            }
            
            // 空状态兜底 (有任务但被过滤掉了)
            if overdueTasks.isEmpty && activeTasks.isEmpty && completedTasks.isEmpty {
                Text("当前分类下暂无任务")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            }
        }
    }
    
    // MARK: - 宫格视图内容 (Eisenhower Matrix)
    var matrixViewContent: some View {
        VStack(spacing: 12) {
            // 第一行：P0 & P1
            HStack(spacing: 12) {
                QuadrantView(
                    title: "重要且紧急 (P0)",
                    tasks: filteredTasks.filter { !$0.isCompleted && $0.priority == .p0 },
                    color: theme.currentTheme.p0
                )
                QuadrantView(
                    title: "重要不紧急 (P1)",
                    tasks: filteredTasks.filter { !$0.isCompleted && $0.priority == .p1 },
                    color: theme.currentTheme.p1
                )
            }
            .frame(height: 220) // 固定高度，或者根据屏幕计算
            
            // 第二行：P2 & P3
            HStack(spacing: 12) {
                QuadrantView(
                    title: "紧急不重要 (P2)",
                    tasks: filteredTasks.filter { !$0.isCompleted && $0.priority == .p2 },
                    color: theme.currentTheme.p2
                )
                QuadrantView(
                    title: "不重要不紧急 (P3)",
                    tasks: filteredTasks.filter { !$0.isCompleted && $0.priority == .p3 },
                    color: theme.currentTheme.p3
                )
            }
            .frame(height: 220)
        }
        .padding(.horizontal)
    }
    
    // MARK: - 交互动作
    
    func toggleSection(_ section: TaskSection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    func deleteTask(_ task: TaskItem) {
        withAnimation {
            TaskService.deleteTask(task, context: modelContext)
        }
    }
    
    // MARK: - 顶部栏
    var headerSection: some View {
        HStack(spacing: 16) {
            // 1. 左侧头像 (简洁风格)
            Circle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 56, height: 56)
            .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
            
            // 2. 中间：早安 + 昵称
            VStack(alignment: .leading, spacing: 4) {
                Text("早安,")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(currentNickname)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // 3. 右侧：等级 + 称号
            VStack(alignment: .trailing, spacing: 4) {
                // 等级
                Text("Lv.\(currentLevel)")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.yellow))
                    .foregroundStyle(.black)
                    .shadow(color: .yellow.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // 称号
                HStack(spacing: 6) {
                    Image(systemName: "medal.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(currentAchievement)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 分类过滤器
    var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                CategoryPill(
                    title: "全部",
                    color: .gray, // 使用灰色统一视觉
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // 各分类按钮
                ForEach(categories) { category in
                    CategoryPill(
                        title: category.name,
                        color: Color(hex: category.colorHex),
                        isSelected: selectedCategory?.id == category.id,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 辅助组件：分类胶囊
    struct CategoryPill: View {
        let title: String
        let color: Color
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    // 选中文字白色，未选中文字为分类色
                    .foregroundStyle(isSelected ? .white : color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            // 选中背景深色(80%)，未选中背景浅色(15%)
                            .fill(isSelected ? color.opacity(0.8) : color.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            // 描边逻辑微调
                            .strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
    
    // MARK: - 辅助逻辑
    
    // 判断任务是否可见 (过滤掉未来的周期任务)
    private func isTaskVisible(_ task: TaskItem) -> Bool {
        // 如果任务是周期性的，且开始时间在未来(明天及以后)，则隐藏
        if task.type == .periodic {
            return task.startTime <= Date()
        }
        return true
    }
    
    // MARK: - 空状态
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(theme.currentTheme.p2.opacity(0.2)) // 修改为 P2 色
            
            VStack(spacing: 4) {
                Text("暂无任务")
                    .font(.headline)
                    .foregroundStyle(theme.currentTheme.p2) // 修改为 P2 色
                Text("正在初始化测试数据...")
                    .font(.caption)
                    .foregroundStyle(theme.currentTheme.p2.opacity(0.8)) // 修改为 P2 色
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - 子视图组件

struct TaskSectionView: View {
    let section: TaskSection
    let tasks: [TaskItem]
    let isExpanded: Bool
    let theme: ThemeManager
    let onToggle: (TaskSection) -> Void
    let onDelete: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button {
                onToggle(section)
            } label: {
                HStack {
                    Text(section.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(section == .overdue ? Color.red : Color.primary)
                    
                    Text("(\(tasks.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.01)) // 扩大点击区域
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                ForEach(tasks) { task in
                    GlassTaskRow(task: task)
                        .padding(.horizontal)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(task)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                onEdit(task)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        // 依然支持左滑删除
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDelete(task)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                onEdit(task)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
    }
}

struct QuadrantView: View {
    let title: String
    let tasks: [TaskItem]
    let color: Color
    
    @Environment(\.modelContext) private var context
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        let indicatorColor = indicatorColor(for: task)
                        QuadrantTaskRow(task: task, indicatorColor: indicatorColor)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func indicatorColor(for task: TaskItem) -> Color {
        if let hex = task.category?.colorHex {
            return Color(hex: hex)
        }
        return color
    }
    
    struct QuadrantTaskRow: View {
        let task: TaskItem
        let indicatorColor: Color
        
        @Environment(\.modelContext) private var context
        @ObservedObject var theme = ThemeManager.shared
        
        @State private var showQuantityInput: Bool = false
        @State private var inputQuantityValue: Double = 0
        @State private var isExpanded: Bool = false
        
        private var isTimeRange: Bool {
            if let end = task.endTime {
                return end > task.startTime
            }
            return false
        }
        
        private var hasChildren: Bool {
            if let children = task.children {
                return !children.isEmpty
            }
            return false
        }
        
        var body: some View {
            VStack(spacing: 4) {
                // 主任务行
                Button {
                    handleTap()
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        // 左侧指示器 - 垂直居中对齐
                        indicator
                        
                        // 任务标题 - 增大字体提高可读性
                        Text(task.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.8))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                        
                        // 如果是节点型任务且有子任务，显示展开/折叠图标
                        if task.type == .node && hasChildren {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                
                // 子任务列表（展开时显示）
                if isExpanded && task.type == .node, let children = task.children, !children.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(children) { child in
                            SubTaskRow(task: child, parentColor: indicatorColor)
                        }
                    }
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .sheet(isPresented: $showQuantityInput) {
                QuantityInputSheet(
                    title: task.title,
                    current: $inputQuantityValue,
                    target: task.targetValue ?? 100,
                    unit: task.valueUnit ?? "",
                    onCommit: { newValue in
                        TaskService.shared.updateTaskProgress(task: task, newProgress: newValue, context: context)
                    }
                )
            }
        }
        
        @ViewBuilder
        private var indicator: some View {
            if isTimeRange {
                // 时间段任务：竖条指示器
                RoundedRectangle(cornerRadius: 2)
                    .fill(indicatorColor)
                    .frame(width: 4, height: 20)
            } else {
                // 时间点任务：圆环指示器
                Circle()
                    .stroke(indicatorColor, lineWidth: 2.5)
                    .frame(width: 16, height: 16)
            }
        }
        
        private func handleTap() {
            // 如果是节点型任务且有子任务，切换展开状态
            if task.type == .node && hasChildren {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            // 如果是数量型任务，打开输入框
            else if task.type == .quantity {
                inputQuantityValue = task.currentValue ?? 0
                showQuantityInput = true
            }
            // 其他类型任务，切换完成状态
            else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    TaskService.shared.toggleTaskCompletion(task, context: context)
                }
            }
        }
        
        // 子任务行组件
        struct SubTaskRow: View {
            let task: TaskItem
            let parentColor: Color
            
            @Environment(\.modelContext) private var context
            @ObservedObject var theme = ThemeManager.shared
            
            @State private var showQuantityInput: Bool = false
            @State private var inputQuantityValue: Double = 0
            
            private var isTimeRange: Bool {
                if let end = task.endTime {
                    return end > task.startTime
                }
                return false
            }
            
            private var indicatorColor: Color {
                if let hex = task.category?.colorHex {
                    return Color(hex: hex)
                }
                return parentColor
            }
            
            var body: some View {
                Button {
                    handleTap()
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        // 左侧指示器 - 垂直居中对齐
                        indicator
                        
                        // 子任务标题 - 增大字体提高可读性
                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showQuantityInput) {
                    QuantityInputSheet(
                        title: task.title,
                        current: $inputQuantityValue,
                        target: task.targetValue ?? 100,
                        unit: task.valueUnit ?? "",
                        onCommit: { newValue in
                            TaskService.shared.updateTaskProgress(task: task, newProgress: newValue, context: context)
                        }
                    )
                }
            }
            
            @ViewBuilder
            private var indicator: some View {
                if isTimeRange {
                    // 子任务时间段：竖条指示器
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(indicatorColor)
                        .frame(width: 3, height: 16)
                } else {
                    // 子任务时间点：圆环指示器
                    Circle()
                        .stroke(indicatorColor, lineWidth: 2)
                        .frame(width: 13, height: 13)
                }
            }
            
            private func handleTap() {
                if task.type == .quantity {
                    inputQuantityValue = task.currentValue ?? 0
                    showQuantityInput = true
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        TaskService.shared.toggleTaskCompletion(task, context: context)
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskItem.self, TaskCategory.self, TaskTag.self, UserProfile.self, configurations: config)
    DataLoader.loadSampleDataIfNeeded(context: container.mainContext)
    return HomeView()
        .modelContainer(container)
}
