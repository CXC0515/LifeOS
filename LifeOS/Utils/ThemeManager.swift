//
//  ThemeManager.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import SwiftUI
import Combine

// MARK: - 1. Color 扩展 (支持 Hex 初始化)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // 辅助方法：转换为 Hex 字符串
    func toHex() -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
    
    func darken(by ratio: Double) -> Color {
        let clamped = max(0, min(1, ratio))
        guard let components = cgColor?.components, components.count >= 3 else {
            return self
        }
        
        let r = Double(components[0])
        let g = Double(components[1])
        let b = Double(components[2])
        let a = components.count >= 4 ? Double(components[3]) : 1.0
        
        let factor = 1 - clamped
        
        return Color(
            .sRGB,
            red: r * factor,
            green: g * factor,
            blue: b * factor,
            opacity: a
        )
    }
}

// MARK: - 2. 主题结构体
struct AppTheme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    
    // 颜色配置 (存储 Hex 字符串以便 Codable，运行时转 Color)
    var baseColorHex: String    // 基础背景色
    var p0Hex: String           // 紧急重要 (红色系)
    var p1Hex: String           // 重要不紧急 (橙色系)
    var p2Hex: String           // 紧急不重要 (蓝色系)
    var p3Hex: String           // 不紧急不重要 (绿色系)
    
    // 辅助方法：返回 SwiftUI Color 对象
    var baseColor: Color { Color(hex: baseColorHex) }
    var p0: Color { Color(hex: p0Hex) }
    var p1: Color { Color(hex: p1Hex) }
    var p2: Color { Color(hex: p2Hex) }
    var p3: Color { Color(hex: p3Hex) }
    
    // 文本颜色：根据背景深浅自动判断
    // 简单算法：计算 baseColor 的亮度，如果暗则返回白色，否则返回黑色
    var textColor: Color {
        // 这里只是一个简单的估算，实际可以使用更复杂的 Luminance 算法
        // 这里为了简化，我们假设 baseColor 通常是比较深的（如森林、敦煌）或者比较浅的
        // 如果我们没有 complex luminance，可以使用 SwiftUI 的 colorScheme 适配
        // 但为了强制适配自定义背景，我们还是返回 .primary 或者根据 Hex 简单判断
        
        // 简单亮度判断 (R*0.299 + G*0.587 + B*0.114)
        let hex = baseColorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((int >> 16) & 0xFF)
            g = Double((int >> 8) & 0xFF)
            b = Double(int & 0xFF)
        } else {
            return .primary
        }
        
        let luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
        return luminance > 0.5 ? .black : .white
    }
    
    // 辅助方法：根据 Priority 枚举获取颜色
    func color(for priority: Priority) -> Color {
        switch priority {
        case .p0: return p0
        case .p1: return p1
        case .p2: return p2
        case .p3: return p3
        }
    }
    
    // 初始化方法
    init(id: String, name: String, baseColor: Color, p0: Color, p1: Color, p2: Color, p3: Color) {
        self.id = id
        self.name = name
        self.baseColorHex = baseColor.toHex()
        self.p0Hex = p0.toHex()
        self.p1Hex = p1.toHex()
        self.p2Hex = p2.toHex()
        self.p3Hex = p3.toHex()
    }
}

extension AppTheme {
    var pageBackground: Color {
        baseColor.opacity(0.1)
    }
    
    // 卡片背景色
    var cardBackground: Color {
        Color.white
    }
    
    // 主要强调色 (别名)
    var primaryColor: Color {
        p1
    }
    
    var surfacePrimary: Color {
        p1
    }
    
    var surfaceOnPrimary: Color {
        p3
    }
}

// MARK: - 3. 主题管理器 (单例)
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // 使用 AppStorage 持久化存储用户的主题选择
    @AppStorage("selectedThemeId") var currentThemeId: String = "dunhuang" {
        didSet {
            updateTheme()
        }
    }
    
    @Published var currentTheme: AppTheme = ThemeManager.themes[0]
    
    private init() {
        // 1. 先初始化 customThemes 为空，避免属性未初始化错误
        self.customThemes = []
        
        // 2. 然后加载已保存的主题
        loadCustomThemes()
        
        // 3. 最后更新当前主题
        updateTheme()
    }
    
    // MARK: - 4. 智能配色
    /// 根据分类配置返回合适的颜色
    /// - 如果 category.useThemeColor 为 true，则返回当前主题的颜色
    /// - 否则返回 category.colorHex 定义的颜色
    func color(for category: TaskCategory) -> Color {
        if category.useThemeColor {
            // 智能选择逻辑：默认使用 P1 (强调色)，也可以根据分类的 sortOrder 轮询
            return currentTheme.p1
        } else {
            return Color(hex: category.colorHex)
        }
    }
    
    // MARK: - 5. 自定义主题管理
    
    // 载入自定义主题 (从 UserDefaults 或其他持久化存储)
    // 这里为了简化，我们先使用内存存储，实际项目中建议存入 FileSystem 或 UserDefaults
    @Published var customThemes: [AppTheme] = [] {
        didSet {
            saveCustomThemes()
        }
    }
    
    private let customThemesKey = "custom_themes_data"
    
    // 初始化时加载
    private func loadCustomThemes() {
        if let data = UserDefaults.standard.data(forKey: customThemesKey),
           let decoded = try? JSONDecoder().decode([AppTheme].self, from: data) {
            self.customThemes = decoded
        }
    }
    
    private func saveCustomThemes() {
        if let encoded = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(encoded, forKey: customThemesKey)
        }
    }
    
    // 创建新主题
    func createNewTheme(name: String, base: Color, p0: Color, p1: Color, p2: Color, p3: Color) {
        let newTheme = AppTheme(
            id: UUID().uuidString,
            name: name,
            baseColor: base,
            p0: p0,
            p1: p1,
            p2: p2,
            p3: p3
        )
        customThemes.append(newTheme)
        // 自动切换到新主题
        currentThemeId = newTheme.id
    }
    
    // 更新自定义主题
    func updateCustomTheme(_ theme: AppTheme) {
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
        }
    }
    
    // 删除自定义主题
    func deleteCustomTheme(_ theme: AppTheme) {
        guard let index = customThemes.firstIndex(of: theme) else { return }
        customThemes.remove(at: index)
        
        // 如果删除的是当前正在用的，回退到默认主题
        if currentThemeId == theme.id {
            currentThemeId = ThemeManager.builtInThemes.first?.id ?? "dunhuang"
        }
    }
    
    // 获取所有可用主题 (内置 + 自定义)
    var availableThemes: [AppTheme] {
        return ThemeManager.builtInThemes + customThemes
    }
    
    // 重写 updateTheme 以支持自定义主题查找
    private func updateTheme() {
        // 先找内置
        if let theme = ThemeManager.builtInThemes.first(where: { $0.id == currentThemeId }) {
            self.currentTheme = theme
            return
        }
        // 再找自定义
        if let theme = customThemes.first(where: { $0.id == currentThemeId }) {
            self.currentTheme = theme
            return
        }
        // 找不到（可能被删了），回退到第一个
        if let first = ThemeManager.builtInThemes.first {
            self.currentTheme = first
            currentThemeId = first.id
        }
    }
    
    // MARK: - 预设主题库
    static let builtInThemes: [AppTheme] = [
        // 1. 敦煌飞天 (Dunhuang) - 沉稳、岩彩风格
        AppTheme(
            id: "dunhuang",
            name: "敦煌飞天",
            baseColor: Color(hex: "#F2E6D8"), // 暖沙色
            p0: Color(hex: "#E65A4C"),        // 朱砂红
            p1: Color(hex: "#F0C239"),        // 藤黄
            p2: Color(hex: "#39859D"),        // 石青
            p3: Color(hex: "#2A5D58")         // 孔雀绿
        ),
        
        // 2. 森林絮语 (Forest) - 清新、自然风格
        AppTheme(
            id: "forest",
            name: "森林絮语",
            baseColor: Color(hex: "#F6E093"), // 120, 183, 201
            p0: Color(hex: "#E58B7B"),        // 229, 139, 123
            p1: Color(hex: "#97B319"),        // 246, 224, 147
            p2: Color(hex: "#78B7C9"),        // 151, 179, 025
            p3: Color(hex: "#46788E")         // 070, 120, 142
        ),
        
        // 4. 丹霞风景 (Dracula)
        AppTheme(
            id: "dracula",
            name: "丹霞风景",
            baseColor: Color(hex: "#FFD19D"), // 橙色
            p0: Color(hex: "#ED8687"),        // 红色
            p1: Color(hex: "#FEB29B"),        // 橙色
            p2: Color(hex: "#BED2C6"),        // 绿色
            p3: Color(hex: "#163645")         // 蓝色   
        )
    ]
    
    // 兼容旧代码的别名，指向 builtInThemes
    static var themes: [AppTheme] {
        return builtInThemes
    }
}
