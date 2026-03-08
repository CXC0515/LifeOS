//
//  TagManagerView.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct TagManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appUIState: AppUIState
    // 按名称排序查询标签
    @Query(sort: \TaskTag.name) private var tags: [TaskTag]
    
    // 状态控制
    @State private var showAddSheet = false
    @State private var tagToEdit: TaskTag?
    @State private var tagToDelete: TaskTag?
    @State private var showDeleteAlert = false
    
    // 拖拽高亮状态
    @State private var activeDropTarget: AttributeType?
    
    let tagColumns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("标签池 (Tag Pool)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("长按拖拽标签到下方能力列完成绑定")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: tagColumns, spacing: 12) {
                        ForEach(tags) { tag in
                            TagGridCell(
                                tag: tag,
                                tagToEdit: $tagToEdit,
                                tagToDelete: $tagToDelete,
                                showDeleteAlert: $showDeleteAlert,
                                hasAttributes: !TaskService.shared.attributeTypes(for: tag).isEmpty,
                                onUnlinkAll: { unlinkAllAttributes(for: tag) }
                            )
                        }
                        
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("新建")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(ThemeManager.shared.currentTheme.p1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(ThemeManager.shared.currentTheme.p1, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("能力方向绑定 (Ability Columns)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(AttributeType.allCases, id: \.self) { attr in
                                AttributeColumnView(
                                    attribute: attr,
                                    tags: tagsForAttribute(attr),
                                    isActive: activeDropTarget == attr,
                                    onUnlink: { tag in
                                        unlink(tag, from: attr)
                                    }
                                )
                                .dropDestination(for: String.self) { items, _ in
                                    handleDrop(items: items, to: attr)
                                } isTargeted: { isTargeted in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        activeDropTarget = isTargeted ? attr : nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .padding(.vertical)
            .background(ThemeManager.shared.currentTheme.pageBackground.ignoresSafeArea())
        }
        .navigationTitle("标签工坊")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            appUIState.isTabBarHidden = true
        }
        .onDisappear {
            appUIState.isTabBarHidden = false
        }
        .sheet(isPresented: $showAddSheet) {
            TagEditSheet(tag: nil)
        }
        .sheet(item: $tagToEdit) { tag in
            TagEditSheet(tag: tag)
        }
        .alert("删除标签", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let tag = tagToDelete {
                    modelContext.delete(tag)
                    tagToDelete = nil
                }
            }
        } message: {
            Text("确定要删除这个标签吗？此操作无法撤销。")
        }
    }
    
    // MARK: - Logic
    
    private func tagsForAttribute(_ attribute: AttributeType) -> [TaskTag] {
        tags.filter { tag in
            TaskService.shared.attributeTypes(for: tag).contains(attribute)
        }
    }
    
    private func handleDrop(items: [String], to attribute: AttributeType) -> Bool {
        guard let idString = items.first,
              let uuid = UUID(uuidString: idString),
              let tag = tags.first(where: { $0.id == uuid }) else {
            return false
        }
        
        withAnimation(.spring) {
            TaskService.shared.linkTag(tag, to: attribute, context: modelContext)
        }
        
        triggerFeedback()
        
        return true
    }
    
    private func unlinkAllAttributes(for tag: TaskTag) {
        withAnimation {
            TaskService.shared.unlinkAllAttributes(for: tag, context: modelContext)
        }
        triggerFeedback()
    }
    
    private func unlink(_ tag: TaskTag, from attribute: AttributeType) {
        withAnimation {
            TaskService.shared.unlinkTag(tag, from: attribute, context: modelContext)
        }
        triggerFeedback()
    }
    
    // MARK: - Helper
    private func triggerFeedback() {
        #if os(iOS)
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        #endif
    }
}


// MARK: - Components

struct AttributeColumnView: View {
    let attribute: AttributeType
    let tags: [TaskTag]
    let isActive: Bool
    let onUnlink: (TaskTag) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(attribute.color.opacity(isActive ? 0.3 : 0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(attribute.color, lineWidth: isActive ? 2 : 0)
                        )
                    
                    Image(systemName: attribute.icon)
                        .font(.title3)
                        .foregroundStyle(attribute.color)
                        .symbolEffect(.bounce, value: isActive)
                }
                
                Text(attribute.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if tags.isEmpty {
                    Text("暂无绑定")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(tags) { tag in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 6, height: 6)
                            
                            Text(tag.name)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Button {
                                onUnlink(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 160, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(attribute.color.opacity(isActive ? 0.7 : 0.25), lineWidth: isActive ? 2 : 1)
        )
        .scaleEffect(isActive ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

struct DraggableTagItem: View {
    let tag: TaskTag
    
    var primaryAttribute: AttributeType? {
        for link in tag.attributeLinks {
            if let attr = AttributeType(rawValue: link.attributeKey) {
                return attr
            }
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 如果已绑定，显示属性图标
            if let attr = primaryAttribute {
                Image(systemName: attr.icon)
                    .font(.caption2)
                    .foregroundStyle(attr.color)
            } else {
                Image(systemName: "number")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: tag.colorHex))
            }
            
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    var backgroundColor: Color {
        if let attr = primaryAttribute {
            return attr.color.opacity(0.15)
        }
        return ThemeManager.shared.currentTheme.pageBackground
    }
    
    var borderColor: Color {
        if let attr = primaryAttribute {
            return attr.color.opacity(0.5)
        }
        return Color(hex: tag.colorHex).opacity(0.3)
    }
    
    var shadowColor: Color {
        if let attr = primaryAttribute {
            return attr.color.opacity(0.2)
        }
        return .black.opacity(0.05)
    }
}

// 简单的编辑 Sheet (复用或新建)
struct TagEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    var tag: TaskTag?
    
    @State private var name: String = ""
    @State private var colorHex: String = "#888888"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标签名称", text: $name)
                    ColorPicker("标签颜色", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() }
                    ))
                }
            }
            .navigationTitle(tag == nil ? "新建标签" : "编辑标签")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let tag = tag {
                    name = tag.name
                    colorHex = tag.colorHex
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func save() {
        if let tag = tag {
            tag.name = name
            tag.colorHex = colorHex
        } else {
            let newTag = TaskTag(name: name, colorHex: colorHex)
            modelContext.insert(newTag)
        }
    }
}

struct TagGridCell: View {
    let tag: TaskTag
    @Binding var tagToEdit: TaskTag?
    @Binding var tagToDelete: TaskTag?
    @Binding var showDeleteAlert: Bool
    let hasAttributes: Bool
    let onUnlinkAll: () -> Void
    
    var body: some View {
        DraggableTagItem(tag: tag)
            .draggable(tag.id.uuidString) {
                // 拖拽时的预览视图
                Text(tag.name)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: tag.colorHex)))
                    .foregroundStyle(.white)
            }
            .contextMenu {
                Button("编辑") { tagToEdit = tag }
                if !tag.isSystem {
                    Button("删除", role: .destructive) {
                        tagToDelete = tag
                        showDeleteAlert = true
                    }
                }
                // 解绑选项
                if hasAttributes {
                    Button("解绑属性", role: .destructive) {
                        onUnlinkAll()
                    }
                }
            }
    }
}
