import SwiftUI
import SwiftData

private enum TimeMode: Hashable {
    case point   // 时间点
    case range   // 时间段
}

struct AddTaskView: View {
    let parentTask: TaskItem?
    let level: Int
    let maxLevel: Int
    let editingTask: TaskItem?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var theme = ThemeManager.shared
    
    // 表单状态
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var plannedScore: Double = 0
    @State private var weightValue: Double = 1
    @State private var selectedType: TaskType = .single
    @State private var selectedPriority: Priority = .p2
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var timeMode: TimeMode = .point
    @State private var includeTime: Bool = true  // 是否包含具体时刻
    
    // 数量型任务
    @State private var targetValueText: String = ""
    @State private var valueUnitText: String = ""
    
    // 周期任务
    @State private var recurrenceUnit: RecurrenceUnit = .day
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceWeekdays: Set<Int> = []
    @State private var recurrenceMonthDays: Set<Int> = []
    @State private var hasRepeatEndDate: Bool = false
    @State private var repeatEndDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var hasRepeatMaxCount: Bool = false
    @State private var repeatMaxCountText: String = ""
    
    // 分类与标签
    @Query(sort: \TaskCategory.sortOrder, order: .forward) var categories: [TaskCategory]
    @Query(sort: \TaskTag.name, order: .forward) var allTags: [TaskTag]
    @State private var selectedCategory: TaskCategory?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var customTagName: String = ""
    
    @State private var currentTask: TaskItem?
    @State private var showChildSheet: Bool = false
    @State private var childParentTask: TaskItem?
    @State private var nextChildLevel: Int = 2
    @State private var showEditSheet: Bool = false
    @State private var editingChildTask: TaskItem?
    @State private var editingChildLevel: Int = 2
    @State private var hasLoadedEditingTask: Bool = false
    
    init(parentTask: TaskItem? = nil, level: Int = 1, maxLevel: Int = 3, editingTask: TaskItem? = nil) {
        self.parentTask = parentTask
        self.level = level
        self.maxLevel = maxLevel
        self.editingTask = editingTask
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.currentTheme.pageBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        titleSection
                        attributeSection
                        scoreSection
                        if parentTask != nil || editingTask?.parent != nil {
                            weightSection
                        }
                        categorySection
                        tagSection
                        timeSection
                        typeSpecificSection
                        parentSection
                        Spacer(minLength: 40)
                    }
                    .padding()
            }
        }
            .navigationTitle(navigationTitleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveTask()
                    }) {
                        Text("保存")
                            .font(.body)
                            .foregroundStyle(theme.currentTheme.p2)
                    }
                    .disabled(title.isEmpty)
                }
                if canShowSubtaskButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            handleSaveAndAddSubtask()
                        }) {
                            Text("添加子任务")
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.currentTheme.p2)
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .sheet(isPresented: $showChildSheet) {
            AddTaskView(parentTask: childParentTask, level: nextChildLevel, maxLevel: maxLevel)
        }
        .sheet(isPresented: $showEditSheet) {
            if let task = editingChildTask {
                AddTaskView(parentTask: task.parent, level: editingChildLevel, maxLevel: maxLevel, editingTask: task)
            }
        }
        .onAppear {
            loadEditingTaskIfNeeded()
        }
    }
    
    private var navigationTitleText: String {
        if editingTask != nil {
            return "任务详情"
        }
        if level == 1 {
            return "新任务"
        } else if level == 2 {
            return "二级任务"
        } else {
            return "三级任务"
        }
    }
    
    // MARK: - 1. 标题部分
    private var titleSection: some View {
        VStack(spacing: 0) {
            TextField("任务标题", text: $title)
                .font(.system(size: 22, weight: .semibold))
                .padding()
            Divider().opacity(0.3).padding(.horizontal)
            TextField("备注...", text: $note, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .frame(minHeight: 80, alignment: .top)
        }
        .glassCardStyle()
    }
    
    // MARK: - 2. 属性部分
    private var attributeSection: some View {
        HStack(spacing: 16) {
            // 类型
            VStack(alignment: .leading, spacing: 10) {
                Label("类型", systemImage: "square.grid.2x2")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Menu {
                    Button {
                        selectedType = .single
                    } label: {
                        Label("单次", systemImage: selectedType == .single ? "checkmark" : "")
                    }
                    Button {
                        selectedType = .periodic
                    } label: {
                        Label("周期", systemImage: selectedType == .periodic ? "checkmark" : "")
                    }
                    Button {
                        selectedType = .quantity
                    } label: {
                        Label("数量", systemImage: selectedType == .quantity ? "checkmark" : "")
                    }
                    if level < maxLevel {
                        Button {
                            selectedType = .node
                        } label: {
                            Label("节点", systemImage: selectedType == .node ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack {
                        Text(typeName(selectedType))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .padding()
                    .background(.white.opacity(0.2))
                    .cornerRadius(10)
                }
                .tint(.primary)
            }
            .padding()
            .glassCardStyle()
            
            // 优先级
            VStack(alignment: .leading, spacing: 10) {
                Label("优先级", systemImage: "flag.fill")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Menu {
                    Button {
                        selectedPriority = .p0
                    } label: {
                        Label("P0 - 重要且紧急", systemImage: selectedPriority == .p0 ? "checkmark" : "")
                    }
                    Button {
                        selectedPriority = .p1
                    } label: {
                        Label("P1 - 重要不紧急", systemImage: selectedPriority == .p1 ? "checkmark" : "")
                    }
                    Button {
                        selectedPriority = .p2
                    } label: {
                        Label("P2 - 紧急不重要", systemImage: selectedPriority == .p2 ? "checkmark" : "")
                    }
                    Button {
                        selectedPriority = .p3
                    } label: {
                        Label("P3 - 不重要不紧急", systemImage: selectedPriority == .p3 ? "checkmark" : "")
                    }
                } label: {
                    HStack {
                        Circle().fill(theme.currentTheme.color(for: selectedPriority)).frame(width: 8, height: 8)
                        Text("P\(selectedPriority.rawValue)")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .padding()
                    .background(.white.opacity(0.2))
                    .cornerRadius(10)
                }
                .tint(.primary)
            }
            .padding()
            .glassCardStyle()
        }
    }
    
    // MARK: - 3. 总积分
    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("总积分", systemImage: "star.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            HStack {
                Text("0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $plannedScore, in: 0...100, step: 1)
                    .tint(theme.currentTheme.p2)
                Text("100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(parentTask == nil ? 1.0 : 0.4)
            .allowsHitTesting(parentTask == nil)
            
            HStack {
                Text("当前：\(Int(plannedScore)) 分")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding()
        .glassCardStyle()
    }
    
    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("权重", systemImage: "scalemass")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            HStack {
                Text("1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $weightValue, in: 1...10, step: 1)
                    .tint(theme.currentTheme.p2)
                Text("10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("当前：\(Int(weightValue))")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding()
        .glassCardStyle()
    }
    
    // MARK: - 4. 分类
    private var categorySection: some View {
        Group {
            if parentTask == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label("分类", systemImage: "square.grid.3x3.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    let currentCategory = selectedCategory
                    let availableCategories = categories.filter { category in
                        guard let current = currentCategory else { return true }
                        return category.id != current.id
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已选分类")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        if let selected = currentCategory {
                            HStack(spacing: 6) {
                                Image(systemName: selected.icon)
                                    .font(.system(size: 12))
                                Text(selected.name)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: selected.colorHex).opacity(0.9))
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                        } else {
                            Text("请选择一个分类")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分类池")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        if availableCategories.isEmpty {
                            Text("暂无可用分类")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableCategories) { category in
                                        Button {
                                            selectedCategory = category
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: category.icon)
                                                    .font(.system(size: 12))
                                                Text(category.name)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(hex: category.colorHex).opacity(0.2))
                                            .foregroundStyle(Color.primary)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        if selectedCategory == nil {
                            selectedCategory = categories.first
                        }
                    }
                }
                .padding()
                .glassCardStyle()
            }
        }
    }
    
    // MARK: - 5. 标签
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("标签", systemImage: "tag.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            let selectedTags = allTags.filter { selectedTagIDs.contains($0.id) }
            let availableTags = allTags.filter { !selectedTagIDs.contains($0.id) }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("已选标签")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                if selectedTags.isEmpty {
                    Text("从下方标签池中选择，或自定义添加，最多 5 个")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedTags) { tag in
                                HStack(spacing: 4) {
                                    Text(tag.name)
                                        .font(.system(size: 11, weight: .medium))
                                    Button {
                                        selectedTagIDs.remove(tag.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: tag.colorHex).opacity(0.9))
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("标签池")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("已选 \(selectedTagIDs.count)/5")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                if availableTags.isEmpty {
                    Text("暂无可用标签")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableTags) { tag in
                                Button {
                                    if selectedTagIDs.count < 5 {
                                        selectedTagIDs.insert(tag.id)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "number")
                                            .font(.system(size: 10))
                                        Text(tag.name)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: tag.colorHex).opacity(0.2))
                                    .foregroundStyle(Color.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                TextField("自定义标签", text: $customTagName)
                    .font(.footnote)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let trimmed = customTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    guard selectedTagIDs.count < 5 else { return }
                    
                    if let existing = allTags.first(where: { $0.name == trimmed }) {
                        selectedTagIDs.insert(existing.id)
                        customTagName = ""
                        return
                    }
                    
                    let newTag = TaskTag(name: trimmed)
                    context.insert(newTag)
                    selectedTagIDs.insert(newTag.id)
                    customTagName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.currentTheme.p2)
            }
        }
        .padding()
        .glassCardStyle()
    }
    
    // MARK: - 6. 时间部分
    private var timeSection: some View {
        VStack(spacing: 16) {
            // 第一行：点/段选择器 + 时刻开关
            HStack(spacing: 12) {
                Image(systemName: "clock")
                Text("时间")
                Spacer()
                
                // 点/段选择器
                Picker("", selection: $timeMode) {
                    Text("点").tag(TimeMode.point)
                    Text("段").tag(TimeMode.range)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                
                // 时刻开关按钮
                Button {
                    includeTime.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: includeTime ? "clock.fill" : "clock")
                            .font(.system(size: 12))
                        Text("时刻")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(includeTime ? theme.currentTheme.p2 : Color.gray.opacity(0.2))
                    .foregroundStyle(includeTime ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // 日期/时间选择器
            if timeMode == .point {
                // 点任务
                HStack {
                    Text(includeTime ? "时间" : "日期")
                    Spacer()
                    DatePicker(
                        "",
                        selection: $endTime,
                        displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                }
                
                if !includeTime {
                    Text("全天任务将显示在日视图的顶部区域")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 段任务
                VStack(spacing: 12) {
                    HStack {
                        Text(includeTime ? "开始时间" : "开始日期")
                        Spacer()
                        DatePicker(
                            "",
                            selection: $startTime,
                            displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                        )
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text(includeTime ? "结束时间" : "结束日期")
                        Spacer()
                        DatePicker(
                            "",
                            selection: $endTime,
                            displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                        )
                        .labelsHidden()
                    }
                    
                    // 显示时长或天数
                    if endTime > startTime {
                        if includeTime {
                            let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
                            let hours = minutes / 60
                            let remainMinutes = minutes % 60
                            Text("总耗时约 \(hours) 小时 \(remainMinutes) 分钟")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            let days = Calendar.current.dateComponents([.day], from: startTime, to: endTime).day ?? 0
                            Text("跨越 \(days + 1) 天")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .glassCardStyle()
    }
    
    // MARK: - 7. 类型特定配置
    @ViewBuilder
    private var typeSpecificSection: some View {
        switch selectedType {
        case .quantity:
            quantitySection
        case .periodic:
            periodicSection
        default:
            EmptyView()
        }
    }
    
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数量任务", systemImage: "number.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            HStack {
                Text("目标数量")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("例如 100", text: $targetValueText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .padding(8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("单位")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("如 次 / 页 / 题", text: $valueUnitText)
                    .disabled(targetValueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(targetValueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 160)
                    .padding(8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Text("不填写目标数量时，进度按 0–100% 计算。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassCardStyle()
    }
    
    private var periodicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("周期任务", systemImage: "repeat.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("执行条件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("开始时间")
                                .font(.subheadline)
                            Text("从此时间开始执行")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        DatePicker("", selection: $startTime, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    
                    Divider().padding(.leading)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("结束时间")
                                .font(.subheadline)
                            Text("可选具体结束时间")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if hasRepeatEndDate {
                            HStack(spacing: 8) {
                                DatePicker("", selection: $repeatEndDate, displayedComponents: .date)
                                    .labelsHidden()
                                Button {
                                    hasRepeatEndDate = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Button {
                                hasRepeatEndDate = true
                                if repeatEndDate < startTime {
                                    repeatEndDate = startTime
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("永不结束")
                                        .foregroundStyle(theme.currentTheme.p2)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    
                    Divider().padding(.leading)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("执行次数")
                                .font(.subheadline)
                            Text("该周期剩余执行的次数")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if hasRepeatMaxCount {
                            HStack(spacing: 8) {
                                TextField("次数", text: $repeatMaxCountText)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .padding(6)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                                Button {
                                    hasRepeatMaxCount = false
                                    repeatMaxCountText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Button {
                                hasRepeatMaxCount = true
                                if repeatMaxCountText.isEmpty {
                                    repeatMaxCountText = "1"
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("不限制")
                                        .foregroundStyle(theme.currentTheme.p2)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                }
                .cornerRadius(16)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("重复")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            recurrenceUnit = .day
                        } label: {
                            HStack {
                                Image(systemName: recurrenceUnit == .day ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(recurrenceUnit == .day ? theme.currentTheme.p2 : .secondary)
                                Text("每")
                                if recurrenceUnit == .day {
                                    TextField("", text: Binding(
                                        get: { String(recurrenceInterval) },
                                        set: { newValue in
                                            let digits = newValue.filter { $0.isNumber }
                                            if let value = Int(digits), value > 0 {
                                                recurrenceInterval = min(value, 30)
                                            } else {
                                                recurrenceInterval = 1
                                            }
                                        }
                                    ))
                                    .multilineTextAlignment(.center)
                                    .frame(width: 40)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(6)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                                } else {
                                    Text("\(recurrenceInterval)")
                                        .frame(width: 40)
                                        .foregroundStyle(.secondary)
                                }
                                Text("天")
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    
                    Divider().padding(.leading)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                recurrenceUnit = .week
                            } label: {
                                HStack {
                                    Image(systemName: recurrenceUnit == .week ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(recurrenceUnit == .week ? theme.currentTheme.p2 : .secondary)
                                    Text("每")
                                    if recurrenceUnit == .week {
                                        TextField("", text: Binding(
                                            get: { String(recurrenceInterval) },
                                            set: { newValue in
                                                let digits = newValue.filter { $0.isNumber }
                                                if let value = Int(digits), value > 0 {
                                                    recurrenceInterval = min(value, 30)
                                                } else {
                                                    recurrenceInterval = 1
                                                }
                                            }
                                        ))
                                        .multilineTextAlignment(.center)
                                        .frame(width: 40)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(6)
                                        #if os(iOS)
                                        .keyboardType(.numberPad)
                                        #endif
                                    } else {
                                        Text("\(recurrenceInterval)")
                                            .frame(width: 40)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("周")
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        
                        if recurrenceUnit == .week {
                            HStack(spacing: 12) {
                                let labels = ["日", "一", "二", "三", "四", "五", "六"]
                                ForEach(0..<7, id: \.self) { index in
                                    let code = index == 0 ? 7 : index
                                    let isSelected = recurrenceWeekdays.contains(code)
                                    Button {
                                        if isSelected {
                                            recurrenceWeekdays.remove(code)
                                        } else {
                                            recurrenceWeekdays.insert(code)
                                        }
                                    } label: {
                                        Text(labels[index])
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(width: 30, height: 30)
                                            .background(isSelected ? theme.currentTheme.p2 : Color.clear)
                                            .foregroundStyle(isSelected ? Color.white : .secondary)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                    }
                    .background(Color.white.opacity(0.15))
                    
                    Divider().padding(.leading)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                recurrenceUnit = .month
                            } label: {
                                HStack {
                                    Image(systemName: recurrenceUnit == .month ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(recurrenceUnit == .month ? theme.currentTheme.p2 : .secondary)
                                    Text("每")
                                    if recurrenceUnit == .month {
                                        TextField("", text: Binding(
                                            get: { String(recurrenceInterval) },
                                            set: { newValue in
                                                let digits = newValue.filter { $0.isNumber }
                                                if let value = Int(digits), value > 0 {
                                                    recurrenceInterval = min(value, 30)
                                                } else {
                                                    recurrenceInterval = 1
                                                }
                                            }
                                        ))
                                        .multilineTextAlignment(.center)
                                        .frame(width: 40)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(6)
                                        #if os(iOS)
                                        .keyboardType(.numberPad)
                                        #endif
                                    } else {
                                        Text("\(recurrenceInterval)")
                                            .frame(width: 40)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("月")
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        
                        if recurrenceUnit == .month {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(1...31, id: \.self) { day in
                                    let isSelected = recurrenceMonthDays.contains(day)
                                    Button {
                                        if isSelected {
                                            recurrenceMonthDays.remove(day)
                                        } else {
                                            recurrenceMonthDays.insert(day)
                                        }
                                    } label: {
                                        Text("\(day)")
                                            .font(.system(size: 12))
                                            .frame(width: 28, height: 28)
                                            .background(isSelected ? theme.currentTheme.p2 : Color.clear)
                                            .foregroundStyle(isSelected ? Color.white : .secondary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button {
                                    let code = 0
                                    if recurrenceMonthDays.contains(code) {
                                        recurrenceMonthDays.remove(code)
                                    } else {
                                        recurrenceMonthDays.insert(code)
                                    }
                                } label: {
                                    let isSelected = recurrenceMonthDays.contains(0)
                                    Text("最后")
                                        .font(.system(size: 11))
                                        .frame(width: 28, height: 28)
                                        .background(isSelected ? theme.currentTheme.p2 : Color.clear)
                                        .foregroundStyle(isSelected ? Color.white : .secondary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                    }
                    .background(Color.white.opacity(0.15))
                }
                .cornerRadius(16)
            }
        }
        .padding()
        .glassCardStyle()
    }
    
    // MARK: - 8. 嵌套部分
    private var parentSection: some View {
        Group {
            if let task = currentTask,
               let children = task.children,
               !children.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("子任务", systemImage: "arrow.turn.down.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(children) { child in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.title)
                                        .font(.system(size: 13, weight: .medium))
                                    HStack(spacing: 6) {
                                        Text("权重 \(Int(child.weight))")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Text(typeName(child.type))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    TaskService.deleteTask(child, context: context)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingChildTask = child
                                editingChildLevel = min(level + 1, maxLevel)
                                showEditSheet = true
                            }
                        }
                    }
                }
                .padding()
                .glassCardStyle()
            }
        }
    }
    
    // MARK: - 辅助逻辑
    private func typeName(_ type: TaskType) -> String {
        switch type {
        case .single: return "单次"
        case .periodic: return "周期"
        case .quantity: return "数量"
        case .node: return "节点"
        }
    }
    
    private var canShowSubtaskButton: Bool {
        selectedType == .node && level < maxLevel
    }
    
    private func loadEditingTaskIfNeeded() {
        guard !hasLoadedEditingTask, let task = editingTask else { return }
        hasLoadedEditingTask = true
        
        title = task.title
        note = task.note
        selectedType = task.type
        selectedPriority = task.priority
        weightValue = min(max(task.weight, 1), 10)
        
        if let end = task.endTime, end != task.startTime {
            timeMode = .range
            startTime = task.startTime
            endTime = end
        } else {
            timeMode = .point
            endTime = task.startTime
        }
        
        // 加载全天任务状态
        includeTime = !task.isAllDay
        
        if parentTask == nil {
            plannedScore = Double(task.plannedScore)
            selectedCategory = task.category
        }
        
        if task.type == .quantity, let target = task.targetValue {
            targetValueText = target > 0 ? String(Int(target)) : ""
            valueUnitText = task.valueUnit ?? ""
        }
        
        if task.type == .periodic {
            if let unit = task.recurrenceUnit {
                recurrenceUnit = unit
            }
            if let interval = task.recurrenceInterval, interval > 0 {
                recurrenceInterval = interval
            }
            if let weekdays = task.recurrenceWeekdays {
                recurrenceWeekdays = Set(weekdays)
            }
            if let monthDays = task.recurrenceMonthDays, !monthDays.isEmpty {
                recurrenceMonthDays = Set(monthDays)
            }
            if let stopDate = task.repeatStopDate {
                hasRepeatEndDate = true
                repeatEndDate = stopDate
            } else {
                hasRepeatEndDate = false
            }
            if let maxCount = task.repeatMaxCount, maxCount > 0 {
                hasRepeatMaxCount = true
                repeatMaxCountText = String(maxCount)
            } else {
                hasRepeatMaxCount = false
                repeatMaxCountText = ""
            }
        }
        
        if let tags = task.tags {
            selectedTagIDs = Set(tags.map { $0.id })
        }
        
        currentTask = task
    }
    
    private func handleSaveAndAddSubtask() {
        guard let task = createTask() else { return }
        childParentTask = task
        nextChildLevel = min(level + 1, maxLevel)
        showChildSheet = true
    }
    
    private func createTask() -> TaskItem? {
        // 根据时间模式确定开始时间
        let start: Date
        if !includeTime {
            // 全天任务：只保留日期，时间设为当天0点
            start = Calendar.current.startOfDay(for: timeMode == .range ? startTime : endTime)
        } else if timeMode == .range {
            start = startTime
        } else {
            start = endTime
        }
        
        if let task = editingTask ?? currentTask {
            task.title = title
            task.note = note
            task.type = selectedType
            task.startTime = start
            task.priority = selectedPriority
            task.isAllDay = !includeTime  // 未选择时刻 = 全天任务
            
            if task.parent != nil {
                let clamped = min(max(weightValue, 1), 10)
                task.weight = clamped
            }
            
            // 根据时间模式和是否包含时刻设置 startTime 和 endTime
            if !includeTime {
                // 全天任务：只保留日期
                if timeMode == .range {
                    task.startTime = Calendar.current.startOfDay(for: startTime)
                    task.endTime = Calendar.current.startOfDay(for: endTime)
                } else {
                    let dayStart = Calendar.current.startOfDay(for: endTime)
                    task.startTime = dayStart
                    task.endTime = dayStart
                }
            } else if timeMode == .range {
                task.startTime = startTime
                task.endTime = endTime
            } else {
                task.startTime = endTime
                task.endTime = endTime
            }
            
            if parentTask == nil {
                task.plannedScore = Int(plannedScore)
                task.category = selectedCategory ?? categories.first
            } else if let parent = task.parent {
                task.category = parent.category
            }
            
            if selectedType == .quantity {
                let trimmed = targetValueText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Double(trimmed), value > 0 {
                    task.targetValue = value
                    let unitTrimmed = valueUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
                    task.valueUnit = unitTrimmed.isEmpty ? nil : unitTrimmed
                } else {
                    task.targetValue = nil
                    task.valueUnit = nil
                }
            } else {
                task.targetValue = nil
                task.currentValue = nil
                task.valueUnit = nil
            }
            
            if selectedType == .periodic {
                task.recurrenceUnit = recurrenceUnit
                task.recurrenceInterval = recurrenceInterval
                if recurrenceUnit == .week {
                    let weekdays = Array(recurrenceWeekdays).sorted()
                    task.recurrenceWeekdays = weekdays.isEmpty ? nil : weekdays
                    task.recurrenceMonthDays = nil
                } else if recurrenceUnit == .month {
                    let days = Array(recurrenceMonthDays).sorted()
                    task.recurrenceMonthDays = days.isEmpty ? nil : days
                    task.recurrenceWeekdays = nil
                } else {
                    task.recurrenceWeekdays = nil
                    task.recurrenceMonthDays = nil
                }
                task.repeatStopDate = hasRepeatEndDate ? repeatEndDate : nil
                if hasRepeatMaxCount,
                   let value = Int(repeatMaxCountText.trimmingCharacters(in: .whitespacesAndNewlines)),
                   value > 0 {
                    task.repeatMaxCount = value
                } else {
                    task.repeatMaxCount = nil
                }
            } else {
                task.recurrenceUnit = nil
                task.recurrenceInterval = nil
                task.recurrenceWeekdays = nil
                task.recurrenceMonthDays = nil
                task.repeatStopDate = nil
                task.repeatMaxCount = nil
            }
            
            if !selectedTagIDs.isEmpty {
                let picked = allTags.filter { selectedTagIDs.contains($0.id) }
                task.tags = picked.isEmpty ? [] : picked
            } else {
                task.tags = []
            }
            
            currentTask = task
            return task
        } else {
            let newTask = TaskItem(
                title: title,
                type: selectedType,
                startTime: start,
                priority: selectedPriority
            )
            newTask.note = note
            
            if parentTask == nil {
                newTask.plannedScore = Int(plannedScore)
            }
            
            if selectedType == .quantity {
                let trimmed = targetValueText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Double(trimmed), value > 0 {
                    newTask.targetValue = value
                    let unitTrimmed = valueUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !unitTrimmed.isEmpty {
                        newTask.valueUnit = unitTrimmed
                    }
                }
            }
            
            if selectedType == .periodic {
                newTask.recurrenceUnit = recurrenceUnit
                newTask.recurrenceInterval = recurrenceInterval
                if recurrenceUnit == .week {
                    let weekdays = Array(recurrenceWeekdays).sorted()
                    newTask.recurrenceWeekdays = weekdays.isEmpty ? nil : weekdays
                } else if recurrenceUnit == .month {
                    let days = Array(recurrenceMonthDays).sorted()
                    newTask.recurrenceMonthDays = days.isEmpty ? nil : days
                }
                newTask.repeatStopDate = hasRepeatEndDate ? repeatEndDate : nil
                if hasRepeatMaxCount,
                   let value = Int(repeatMaxCountText.trimmingCharacters(in: .whitespacesAndNewlines)),
                   value > 0 {
                    newTask.repeatMaxCount = value
                }
                newTask.currentRepeatCount = 0
            }
            
            // 设置全天任务状态
            newTask.isAllDay = !includeTime
            
            // 根据时间模式和是否包含时刻设置 startTime 和 endTime
            if !includeTime {
                // 全天任务：只保留日期
                if timeMode == .range {
                    newTask.startTime = Calendar.current.startOfDay(for: startTime)
                    newTask.endTime = Calendar.current.startOfDay(for: endTime)
                } else {
                    let dayStart = Calendar.current.startOfDay(for: endTime)
                    newTask.startTime = dayStart
                    newTask.endTime = dayStart
                }
            } else if timeMode == .range {
                newTask.startTime = startTime
                newTask.endTime = endTime
            } else {
                newTask.endTime = endTime
            }
            
            if parentTask == nil {
                newTask.category = selectedCategory ?? categories.first
            }
            
            if !selectedTagIDs.isEmpty {
                let picked = allTags.filter { selectedTagIDs.contains($0.id) }
                if !picked.isEmpty {
                    newTask.tags = picked
                }
            }
            
            if let parent = parentTask {
                newTask.parent = parent
                let clamped = min(max(weightValue, 1), 10)
                newTask.weight = clamped
                newTask.category = parent.category
            }
            
            context.insert(newTask)
            currentTask = newTask
            
            // 编辑或新建后，立即评估是否达标
            TaskService.shared.reassessTaskCompletion(newTask, context: context)
            
            return newTask
        }
    }
    
    private func saveTask() {
        guard let task = createTask() else { return }
        
        // 再次确保评估 (虽然 createTask 里已经调了，但双重保险)
        TaskService.shared.reassessTaskCompletion(task, context: context)
        
        dismiss()
    }
}
