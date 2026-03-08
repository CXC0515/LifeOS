import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

// MARK: - 任务行组件 (LMS 风格 - 毛玻璃拟态 + 侧边分类条)
// 该组件用于在列表中展示单个任务项，支持点击交互、状态切换、子任务展开等功能
struct GlassTaskRow: View {
    // MARK: - 核心数据
    
    // 传入的任务模型数据
    let task: TaskItem
    
    // SwiftData 上下文，用于数据操作
    @Environment(\.modelContext) var context
    
    // 主题管理器，用于获取当前应用的主题颜色配置
    @ObservedObject var theme = ThemeManager.shared
    
    // MARK: - 交互状态
    
    // 是否展开子任务列表（仅针对节点型任务）
    @State private var isExpanded: Bool = false
    
    // 是否处于按下状态（用于缩放动画效果）
    @State private var isPressed: Bool = false
    
    // 是否显示数量录入弹窗（仅针对数量型任务）
    @State private var showQuantityInput: Bool = false
    
    // 数量录入的临时绑定值
    @State private var inputQuantityValue: Double = 0
    
    // MARK: - 布局常量
    
    // 左侧状态图标的大小
    private let iconSize: CGFloat = 22
    
    // 卡片的圆角半径
    private let cornerRadius: CGFloat = 24
    
    // MARK: - 视图主体
    var body: some View {
        VStack(spacing: 0) {
            // 1. 主任务卡片区域
            mainCardContent
                // 按下时的缩放效果
                .scaleEffect(isPressed ? 0.98 : 1.0)
                // 缩放动画配置
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                // 点击手势处理
                .onTapGesture {
                    handleCardTap()
                }
            
            // 2. 子任务列表 (缩进显示) - 仅节点型任务且有子任务时显示
            if isExpanded && task.type == .node, let subtasks = task.children, !subtasks.isEmpty {
                VStack(spacing: 8) {
                    // 连接主任务和子任务的视觉引导线
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .padding(.leading, 24)
                        Spacer()
                    }
                    .frame(height: 8)
                    
                    // 遍历显示子任务，按开始时间排序
                    ForEach(subtasks.sorted(by: { $0.startTime < $1.startTime })) { subtask in
                        GlassTaskRow(task: subtask)
                            .padding(.leading, 16) // 子任务缩进，体现层级关系
                            .scaleEffect(0.98) // 子任务稍微缩小，区分主次
                    }
                }
                .padding(.top, 4)
                // 展开/收起的过渡动画
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4) // 列表项之间的垂直间距
        // 数量录入弹窗 Sheet
        .sheet(isPresented: $showQuantityInput) {
            QuantityInputSheet(
                title: task.title,
                current: $inputQuantityValue,
                target: task.targetValue ?? 100,
                unit: task.valueUnit ?? "",
                onCommit: { newValue in
                    // 提交新进度
                    TaskService.shared.updateTaskProgress(task: task, newProgress: newValue, context: context)
                }
            )
        }
    }
    
    // MARK: - 主卡片内容
    // 包含背景、状态、文本信息、积分和侧边分类条
    private var mainCardContent: some View {
        ZStack {
            // A. 背景层 (毛玻璃质感)
            glassBackground
            
            // B. 内容容器 (水平布局)
            HStack(spacing: 0) {
                // --- 左侧：主内容区域 (包含状态图标、文本、积分) ---
                HStack(alignment: .top, spacing: 14) {
                    // 1. 状态指示器 (左侧圆圈)
                    statusIndicator
                        .padding(.top, 2) // 微调垂直对齐
                    
                    // 2. 中间文本信息区 (含积分与优先级)
                    VStack(alignment: .leading, spacing: 6) {
                        // 2.1 标题行 + 积分
                        HStack(alignment: .top, spacing: 4) {
                            // 任务标题
                            Text(task.title)
                                .font(.system(size: 15, weight: .semibold))
                                // 如果任务逾期且未完成，显示红色，否则显示深色
                                .foregroundStyle(task.isOverdue && !task.isCompleted ? Color.red : Color(hex: "06141B"))
                                // 已完成任务降低不透明度
                                .opacity(task.isCompleted ? 0.6 : 1.0)
                                // 已完成任务添加删除线
                                .strikethrough(task.isCompleted, color: Color(hex: "4A5C6A"))
                                .lineLimit(1) // 限制单行显示
                            
                            // 检查是否有子任务
                            let hasChildren = task.type == .node && !(task.children?.isEmpty ?? true)
                            // 如果有子任务，显示展开/收起箭头
                            if hasChildren {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: "4A5C6A").opacity(0.8))
                            }
                            
                            Spacer(minLength: 4)
                            
                            // 积分显示胶囊
                            if !task.isCompleted {
                                // 未完成：显示计算后的预估积分
                                Text("+\(Int(displayScore))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(categoryColor) // 根据分类显示颜色
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor.opacity(0.1)) // 背景色跟随分类
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                // 已完成：显示实际获得的积分
                                Text("+\(task.earnedScore)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        
                        // 2.2 标签 (Tags) 显示区域
                        if let tags = task.tags, !tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(tags) { tag in
                                    Text(tag.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.7)) // 标签文字颜色
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: tag.colorHex).opacity(0.2)) // 标签背景色 (带透明度)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        } else {
                            // 为了保持卡片高度一致，如果没有标签，显示一个不可见的占位符
                            Text("Placeholder")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.vertical, 2)
                                .opacity(0)
                        }
                        
                        // 2.3 底部元数据 (Metadata) + 优先级
                        HStack(alignment: .bottom, spacing: 4) {
                            metadataRow
                            
                            Spacer()
                            
                            // 优先级显示 (P0-P3)
                            Text("P\(task.priority.rawValue)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(priorityColor.opacity(0.8))
                        }
                    }
                    // 为 VStack 设置最小高度以保证一致性 (特别是有父任务时)
                    .frame(minHeight: task.parent != nil ? 44 : nil, alignment: .leading)
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.vertical, 16)
                
                // --- 右侧：侧边分类条 ---
                // 显示分类名称的首字，通过颜色区分分类
                CategorySideBar(task: task)
            }
        }
        // 卡片整体圆角
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // 卡片阴影效果
        .shadow(color: Color(hex: "253745").opacity(0.08), radius: 16, x: 0, y: 4)
        // 完成状态下整体降低不透明度
        .opacity(task.isCompleted ? 0.8 : 1.0)
    }
    
    // MARK: - 辅助视图组件
    
    // 毛玻璃背景视图
    private var glassBackground: some View {
        ZStack {
            // 底层：超薄材质 (系统提供的毛玻璃效果)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            
            // 中层：白色半透明遮罩，增加亮度
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.4))
            
            // 顶层：边框描边，增加立体感
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
    }
    
    // 元数据行 (显示周期、进度、截止时间等)
    private var metadataRow: some View {
        HStack(spacing: 10) {
            // 1. 周期性任务描述
            if task.type == .periodic {
                let text = task.recurrenceFullDescription
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "06141B"))
                }
            }
            // 2. 数量型任务进度 (当前/目标 单位)
            else if task.type == .quantity, let target = task.targetValue, let current = task.currentValue {
                Text("\(Int(current))/\(Int(target)) \(task.valueUnit ?? "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }
            // 3. 节点型任务进度 (百分比)
            else if task.type == .node {
                let progress = TaskService.shared.calculateProgress(task)
                Text("进度 \(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }
            
            // 4. 截止时间显示
            if let deadline = task.endTime {
                Text("\(deadline.chineseDateShort) \(deadline.formattedTime)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "4A5C6A"))
            }
        }
    }
    
    // 状态指示器 (左侧圆圈按钮)
    @ViewBuilder
    private var statusIndicator: some View {
        Button(action: handleStatusTap) {
            ZStack {
                // 1. 基础圆环
                Circle()
                    .stroke(Color(hex: "4A5C6A").opacity(0.2), lineWidth: 2)
                    .frame(width: iconSize, height: iconSize)
                
                // 2. 进度环 (仅针对节点型或数量型任务)
                if task.type == .node || task.type == .quantity {
                    let progress = TaskService.shared.calculateProgress(task)
                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress) // 根据进度截取圆环
                            .stroke(theme.currentTheme.p1, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: iconSize, height: iconSize)
                            .rotationEffect(.degrees(-90)) // 从顶部开始
                            .animation(.spring, value: progress)
                    }
                }
                
                // 3. 完成状态 (实心圆 + 对勾)
                if task.isCompleted {
                    Circle()
                        .fill(Color(hex: "06141B"))
                        .frame(width: 16, height: 16)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain) // 禁用默认按钮样式
    }
    
    // MARK: - 侧边分类条组件
    struct CategorySideBar: View {
        let task: TaskItem
        
        // 计算当前任务所属的有效分类 (递归查找父级分类)
        private var effectiveCategory: TaskCategory? {
            var current: TaskItem? = task
            while let item = current {
                if let category = item.category {
                    return category
                }
                current = item.parent
            }
            return nil
        }
        
        var body: some View {
            VStack(spacing: 2) {
                if let category = effectiveCategory {
                    // 如果有分类，显示分类名称的前两个字符
                    ForEach(Array(category.name.prefix(2).enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                } else {
                    // 如果无分类，显示"未分"
                    Text("未")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("分")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 32)
            .frame(maxHeight: .infinity) // 撑满高度
            .background(categoryBackgroundColor) // 背景色
            // 只在右侧切圆角，防止覆盖主卡片的圆角
            // 但因为父容器已经 clipShape 了，这里直接填满即可
        }
        
        // 计算分类背景色
        private var categoryBackgroundColor: Color {
            if let hex = effectiveCategory?.colorHex {
                return Color(hex: hex).opacity(0.5)
            }
            return ThemeManager.shared.currentTheme.baseColor.opacity(0.5)
        }
    }
    
    // MARK: - 逻辑处理
    
    // 获取任务优先级对应的颜色
    private var priorityColor: Color {
        theme.currentTheme.color(for: task.priority)
    }
    
    // 获取显示用的积分 (转换为 Double)
    private var displayScore: Double {
        let score = TaskService.shared.plannedScore(for: task)
        return Double(score)
    }
    
    // 获取分类颜色 (用于积分显示)
    private var categoryColor: Color {
        if let category = task.category {
            return Color(hex: category.colorHex)
        }
        return priorityColor // 无分类时回退到优先级颜色
    }
    
    // 处理卡片整体点击事件
    private func handleCardTap() {
        if task.type == .node {
            // 节点任务：展开/收起子任务列表
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
            triggerHaptic()
        } else {
            // 普通任务：目前仅触发震动，未来可扩展为进入详情页
            // TODO: 弹出编辑页面的逻辑 (可以后续添加)
            // 目前先做简单的震动反馈
            triggerHaptic()
        }
    }
    
    // 处理状态指示器点击事件
    private func handleStatusTap() {
        if task.type == .node {
            // 节点任务点击圆圈也可以展开/收起，或者提示必须完成子任务
             withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } else if task.type == .quantity {
            // 数量型任务：始终弹出进度录入
            // 无论是未完成还是已完成，点击都允许修改进度（例如从 50 改回 20）
            inputQuantityValue = task.currentValue ?? 0
            showQuantityInput = true
        } else {
            // 普通任务：切换完成状态
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                TaskService.shared.toggleTaskCompletion(task, context: context)
            }
            if !task.isCompleted { triggerHaptic() }
        }
    }
    
    // 触发触觉反馈 (震动)
    private func triggerHaptic() {
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif
    }
}
