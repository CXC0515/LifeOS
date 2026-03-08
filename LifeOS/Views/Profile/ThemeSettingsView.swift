import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appUIState: AppUIState
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showAddSheet = false
    @State private var themeToEdit: AppTheme? // 用于控制编辑弹窗
    @State private var themeToDelete: AppTheme? // 用于控制删除弹窗
    @State private var showDeleteAlert = false
    
    // Grid Layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(themeManager.currentTheme.textColor)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                }
                
                Spacer()
                
                Text("主题工坊")
                    .font(.headline)
                    .foregroundStyle(themeManager.currentTheme.textColor)
                
                Spacer()
                
                // Placeholder for balance
                Color.clear.frame(width: 40, height: 40)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                // Built-in Themes
                VStack(alignment: .leading, spacing: 12) {
                    Text("官方主题")
                        .font(.headline)
                        .foregroundStyle(themeManager.currentTheme.textColor)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(ThemeManager.builtInThemes) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: themeManager.currentThemeId == theme.id
                            )
                            .onTapGesture {
                                withAnimation {
                                    themeManager.currentThemeId = theme.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Custom Themes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("我的主题")
                            .font(.headline)
                            .foregroundStyle(themeManager.currentTheme.textColor)
                        Spacer()
                        Button(action: { showAddSheet = true }) {
                            Label("新建", systemImage: "plus")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.currentTheme.textColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    if themeManager.customThemes.isEmpty {
                        ContentUnavailableView("暂无自定义主题", systemImage: "paintpalette", description: Text("点击右上角创建属于你的主题"))
                            .foregroundStyle(themeManager.currentTheme.textColor)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(themeManager.customThemes) { theme in
                                ThemePreviewCard(
                                    theme: theme,
                                    isSelected: themeManager.currentThemeId == theme.id
                                )
                                .onTapGesture {
                                    withAnimation {
                                        themeManager.currentThemeId = theme.id
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        themeToEdit = theme
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        themeToDelete = theme
                                        showDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        }
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
            AddThemeSheet()
                .frame(maxWidth: 600) // 限制宽度，防止在 iPad/Mac 上过宽
                .presentationDetents([.large])
        }
        .sheet(item: $themeToEdit) { theme in
            AddThemeSheet(existingTheme: theme)
                .frame(maxWidth: 600) // 限制宽度，防止在 iPad/Mac 上过宽
                .presentationDetents([.large])
        }
        .confirmationDialog(
            "确认删除主题？",
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let theme = themeToDelete {
                    themeManager.deleteCustomTheme(theme)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除主题后，将无法恢复。")
        }
        .background(themeManager.currentTheme.pageBackground.ignoresSafeArea())
    }
}

struct AddThemeSheet: View {
    @Environment(\.dismiss) var dismiss
    
    // 如果传入 existingTheme，则是编辑模式
    var existingTheme: AppTheme?
    
    @State private var name: String = ""
    @State private var baseColor: Color = .white
    @State private var p0: Color = .red
    @State private var p1: Color = .orange
    @State private var p2: Color = .blue
    @State private var p3: Color = .green
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("主题名称", text: $name)
                    ColorPicker("背景基调", selection: $baseColor)
                }
                
                Section("优先级颜色") {
                    ColorPicker("重要且紧急 (P0)", selection: $p0)
                    ColorPicker("重要不紧急 (P1)", selection: $p1)
                    ColorPicker("紧急不重要 (P2)", selection: $p2)
                    ColorPicker("不重要不紧急 (P3)", selection: $p3)
                }
                
                Section {
                    HStack {
                        Spacer()
                        ThemePreviewCard(
                            theme: AppTheme(
                                id: "preview",
                                name: name.isEmpty ? "预览" : name,
                                baseColor: baseColor,
                                p0: p0,
                                p1: p1,
                                p2: p2,
                                p3: p3
                            ),
                            isSelected: true
                        )
                        .frame(width: 200)
                        Spacer()
                    }
                } header: {
                    Text("预览")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeManager.shared.currentTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(existingTheme == nil ? "创建新主题" : "编辑主题")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let existing = existingTheme {
                            // 更新逻辑
                            var updated = existing
                            updated.name = name
                            updated.baseColorHex = baseColor.toHex()
                            updated.p0Hex = p0.toHex()
                            updated.p1Hex = p1.toHex()
                            updated.p2Hex = p2.toHex()
                            updated.p3Hex = p3.toHex()
                            
                            ThemeManager.shared.updateCustomTheme(updated)
                        } else {
                            // 创建逻辑
                            ThemeManager.shared.createNewTheme(
                                name: name.isEmpty ? "未命名主题" : name,
                                base: baseColor,
                                p0: p0,
                                p1: p1,
                                p2: p2,
                                p3: p3
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let existing = existingTheme {
                    name = existing.name
                    baseColor = existing.baseColor
                    p0 = existing.p0
                    p1 = existing.p1
                    p2 = existing.p2
                    p3 = existing.p3
                }
            }
        }
    }
}
