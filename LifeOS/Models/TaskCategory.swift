//
//  TaskCategory.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import Foundation
import SwiftData

@Model
final class TaskCategory {
    var id: UUID
    var name: String
    
    // 颜色控制
    var useThemeColor: Bool = false // 新增：是否跟随系统主题色
    var colorHex: String // 存储颜色代码，比如 "#FF5733"
    
    var icon: String     // 存储 SF Symbol 名字，比如 "briefcase"
    
    // MARK: - 系统控制字段
    var isSystem: Bool   // 标识是否为系统预置 (但不再限制删除)
    var systemKey: String? // 系统内部标识符 (如 "routine")，用于逻辑绑定
    var sortOrder: Int   // 排序权重 (越小越靠前)
    
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.category)
    var tasks: [TaskItem]?
    
    init(name: String, colorHex: String = "#000000", useThemeColor: Bool = false, icon: String = "circle", isSystem: Bool = false, systemKey: String? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.useThemeColor = useThemeColor
        self.icon = icon
        self.isSystem = isSystem
        self.systemKey = systemKey
        self.sortOrder = sortOrder
    }
}

@Model
final class TaskTag {
    var id: UUID
    var name: String
    var colorHex: String
    var isSystem: Bool // 新增：系统预置标签

    @Relationship(deleteRule: .cascade)
    var attributeLinks: [TagAttributeLink] = []

    // 多对多关系：一个标签可以贴在多个任务上，一个任务可以有多个标签
    var tasks: [TaskItem]?
    
    init(name: String, colorHex: String = "#888888", isSystem: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.isSystem = isSystem
    }
}

@Model
final class TagAttributeLink {
    var id: UUID
    var attributeKey: String
    var tag: TaskTag
    var createdAt: Date

    init(attributeKey: String, tag: TaskTag) {
        self.id = UUID()
        self.attributeKey = attributeKey
        self.tag = tag
        self.createdAt = Date()
    }
}
