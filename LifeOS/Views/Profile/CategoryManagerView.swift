import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appUIState: AppUIState
    @Query(sort: \TaskCategory.sortOrder) private var categories: [TaskCategory]
    @State private var showAddSheet = false
    @State private var categoryToEdit: TaskCategory?
    @State private var categoryToDelete: TaskCategory?
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.currentTheme.textColor)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                }
                
                Spacer()
                
                Text("分类管理")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.currentTheme.textColor)
                
                Spacer()
                
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.currentTheme.textColor)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                }
            }
            .padding()
            
            List {
            ForEach(categories) { category in
                HStack(spacing: 12) {
                    // Icon & Color
                    ZStack {
                        Circle()
                            .fill(ThemeManager.shared.color(for: category).opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: category.icon)
                            .foregroundStyle(ThemeManager.shared.color(for: category))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.body)
                        if category.useThemeColor {
                            Text("跟随主题色")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if category.isSystem {
                        Text("系统")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }
                }
                .contentShape(Rectangle()) // 增加点击区域
                .onTapGesture {
                    categoryToEdit = category
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !category.isSystem {
                        Button(role: .destructive) {
                            categoryToDelete = category
                            showDeleteAlert = true
                        } label: {
                            Text("删除") // Explicitly use Text instead of Label to control text? Actually standard is Button("删除")
                        }
                        .tint(.red)
                    }
                    
                    Button {
                        categoryToEdit = category
                    } label: {
                        Text("编辑")
                    }
                    .tint(.blue)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
        .background(ThemeManager.shared.currentTheme.pageBackground.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #else
        .toolbar(.hidden)
        #endif
        .onAppear {
            appUIState.isTabBarHidden = true
        }
        .onDisappear {
            appUIState.isTabBarHidden = false
        }
    .sheet(isPresented: $showAddSheet) {
            AddCategorySheet()
        }
        .sheet(item: $categoryToEdit) { category in
            AddCategorySheet(existingCategory: category)
        }
        .confirmationDialog(
            "确认删除分类？",
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let category = categoryToDelete {
                    modelContext.delete(category)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除分类后，该分类下的任务可能需要重新分类。")
        }
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var existingCategory: TaskCategory?
    
    @State private var name: String = ""
    @State private var icon: String = "circle"
    @State private var useThemeColor: Bool = false
    @State private var color: Color = .blue
    
    private let availableIcons = ["circle", "briefcase", "book", "cart", "gamecontroller", "tv", "music.note", "house", "person"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("分类名称", text: $name)
                }
                
                Section("图标") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableIcons, id: \.self) { iconName in
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundStyle(icon == iconName ? .blue : .secondary)
                                    .onTapGesture {
                                        icon = iconName
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("颜色") {
                    Toggle("跟随系统主题色", isOn: $useThemeColor)
                    
                    if !useThemeColor {
                        ColorPicker("自定义颜色", selection: $color)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeManager.shared.currentTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(existingCategory == nil ? "新建分类" : "编辑分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let existing = existingCategory {
                            // Update
                            existing.name = name
                            existing.icon = icon
                            existing.useThemeColor = useThemeColor
                            existing.colorHex = color.toHex()
                        } else {
                            // Create
                            let newCategory = TaskCategory(
                                name: name,
                                colorHex: color.toHex(),
                                useThemeColor: useThemeColor,
                                icon: icon
                            )
                            modelContext.insert(newCategory)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let existing = existingCategory {
                    name = existing.name
                    icon = existing.icon
                    useThemeColor = existing.useThemeColor
                    color = Color(hex: existing.colorHex)
                }
            }
        }
    }
}
