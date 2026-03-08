//
//  DefaultMetadata.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/1/21.
//

import Foundation
import SwiftUI

/// 提供系统预置的元数据配置 (分类、标签等)
struct DefaultMetadata {
    
    // MARK: - 配置模型
    
    struct CategoryConfig {
        let key: String        // 系统唯一标识 (用于逻辑绑定)
        let name: String       // 默认显示名称
        let icon: String       // SF Symbol
        let themeLevel: Priority // 关联的主题等级 (决定默认颜色)
        let isSystem: Bool     // 是否为系统预置
    }
    
    struct TagConfig {
        let key: String
        let name: String
        let colorHex: String
        let isSystem: Bool
    }
    
    // MARK: - 预置数据定义
    
    /// 系统预置分类列表
    static let categories: [CategoryConfig] = [
        .init(key: "routine", name: "每日例行", icon: "repeat", themeLevel: .p2, isSystem: true),   // 蓝色 (常态)
        .init(key: "goal",    name: "长期目标", icon: "flag.fill", themeLevel: .p0, isSystem: true), // 红色 (重点)
        .init(key: "skill",   name: "技能提升", icon: "book.fill", themeLevel: .p1, isSystem: true), // 黄色 (次重)
        .init(key: "life",    name: "生活琐事", icon: "cart.fill", themeLevel: .p3, isSystem: true), // 绿色 (休闲)
        .init(key: "inbox",   name: "灵感收集", icon: "lightbulb.fill", themeLevel: .p3, isSystem: true) // 绿色 (备忘)
    ]
    
    /// 系统预置标签列表
    static let tags: [TagConfig] = [
        .init(key: "sport", name: "运动", colorHex: "#48CFAD", isSystem: true), // 绿色
        .init(key: "read",  name: "阅读", colorHex: "#5D9CEC", isSystem: true), // 蓝色
        .init(key: "dev",   name: "开发", colorHex: "#AC92EC", isSystem: true), // 紫色
        .init(key: "shop",  name: "购物", colorHex: "#FFCE54", isSystem: true), // 黄色
        .init(key: "fun",   name: "娱乐", colorHex: "#EC87C0", isSystem: true)  // 粉色
    ]
}
