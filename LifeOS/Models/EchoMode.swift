//
//  EchoMode.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/28.
//

import Foundation

/// Echo 子视图模式枚举
/// 用于 Dashboard 中 Echo 模块的时间轴视图切换
enum EchoMode: String, CaseIterable {
    /// 单日时间轴
    case day = "单日"
    
    /// 多日时间轴（双日视图）
    case multiDay = "多日"
    
    /// 月历视图
    case month = "月"
}
