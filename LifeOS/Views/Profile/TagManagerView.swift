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
    
    // 能力绑定：当前选中的标签
    @State private var selectedTag: TaskTag?
    
    let tagColumns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - 标签池
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("标签池 (Tag Pool)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("点击标签可编辑能力绑定")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: tagColumns, spacing: 12) {
                        ForEach(tags) { tag in
                            TagGridCell(
                                tag: tag,
                                isSelected: selectedTag?.id == tag.id,
                                tagToEdit: $tagToEdit,
                                tagToDelete: $tagToDelete,
                                showDeleteAlert: $showDeleteAlert,
                                hasAttributes: !TaskService.shared.attributeTypes(for: tag).isEmpty,
                                onSelect: { selectedTag = tag },
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
                
                // MARK: - 能力绑定区域（左右双列）
                VStack(alignment: .leading, spacing: 12) {
                    Text("标签 — 能力绑定")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    HStack(alignment: .top, spacing: 0) {
                        // 左列：标签选择列表
                        tagSelectionList
                        
                        Divider()
                        
                        // 右列：能力勾选列表
                        abilityCheckList
                    }
                    .frame(minHeight: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
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
                    if selectedTag?.id == tag.id {
                        selectedTag = nil
                    }
                    modelContext.delete(tag)
                    tagToDelete = nil
                }
            }
        } message: {
            Text("确定要删除这个标签吗？此操作无法撤销。")
        }
    }
    
    // MARK: - 左列：标签选择列表
    
    private var tagSelectionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("选择标签")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(tags) { tag in
                        let isSelected = selectedTag?.id == tag.id
                        let boundAttributes = TaskService.shared.attributeTypes(for: tag)
                        
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTag = tag
                            }
                            triggerFeedback()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 8, height: 8)
                                
                                Text(tag.name)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 4)
                                
                                // 显示已绑定能力数量
                                if !boundAttributes.isEmpty {
                                    Text("\(boundAttributes.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(ThemeManager.shared.currentTheme.p2))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected
                                          ? ThemeManager.shared.currentTheme.p2.opacity(0.15)
                                          : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected
                                            ? ThemeManager.shared.currentTheme.p2.opacity(0.4)
                                            : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 140, idealWidth: 160)
    }
    
    // MARK: - 右列：能力勾选列表
    
    private var abilityCheckList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let tag = selectedTag {
                // 标题：当前标签名
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 10, height: 10)
                    Text("「\(tag.name)」的能力绑定")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
                
                let currentAttributes = TaskService.shared.attributeTypes(for: tag)
                
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(AttributeType.allCases, id: \.self) { attr in
                            let isBound = currentAttributes.contains(attr)
                            
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    if isBound {
                                        TaskService.shared.unlinkTag(tag, from: attr, context: modelContext)
                                    } else {
                                        TaskService.shared.linkTag(tag, to: attr, context: modelContext)
                                    }
                                }
                                triggerFeedback()
                            } label: {
                                HStack(spacing: 10) {
                                    // 能力图标
                                    ZStack {
                                        Circle()
                                            .fill(attr.color.opacity(isBound ? 0.2 : 0.08))
                                            .frame(width: 36, height: 36)
                                        
                                        Image(systemName: attr.icon)
                                            .font(.system(size: 15))
                                            .foregroundStyle(attr.color)
                                    }
                                    
                                    // 能力名称
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attr.displayName)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        
                                        Text(attr.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    
                                    Spacer()
                                    
                                    // 勾选状态
                                    Image(systemName: isBound ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isBound ? attr.color : Color.gray.opacity(0.3))
                                        .symbolEffect(.bounce, value: isBound)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isBound ? attr.color.opacity(0.06) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            } else {
                // 未选中标签时的占位
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("选择左侧标签\n编辑能力绑定")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Logic 
    
    private func unlinkAllAttributes(for tag: TaskTag) {
        withAnimation {
            TaskService.shared.unlinkAllAttributes(for: tag, context: modelContext)
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
    let isSelected: Bool
    @Binding var tagToEdit: TaskTag?
    @Binding var tagToDelete: TaskTag?
    @Binding var showDeleteAlert: Bool
    let hasAttributes: Bool
    let onSelect: () -> Void
    let onUnlinkAll: () -> Void
    
    var body: some View {
        TagChipView(tag: tag, isSelected: isSelected, hasAttributes: hasAttributes)
            .onTapGesture {
                onSelect()
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
                    Button("解绑全部能力", role: .destructive) {
                        onUnlinkAll()
                    }
                }
            }
    }
}

/// 标签胶囊视图
struct TagChipView: View {
    let tag: TaskTag
    let isSelected: Bool
    let hasAttributes: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: hasAttributes ? "link.circle.fill" : "number")
                .font(.caption2)
                .foregroundStyle(hasAttributes ? ThemeManager.shared.currentTheme.p2 : Color(hex: tag.colorHex))
            
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected
                      ? ThemeManager.shared.currentTheme.p2.opacity(0.15)
                      : ThemeManager.shared.currentTheme.pageBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(isSelected
                        ? ThemeManager.shared.currentTheme.p2.opacity(0.5)
                        : Color(hex: tag.colorHex).opacity(0.3), lineWidth: 1)
        )
    }
}
