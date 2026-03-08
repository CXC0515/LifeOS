//
//  UserProfile.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/21.
//

import SwiftData
import Foundation

@Model
final class UserProfile {
    // MARK: - 基础信息
    var nickname: String        // 昵称 (可修改)
    var avatarData: Data?       // 头像数据
    
    // MARK: - 经济系统
    var totalScore: Int         // 当前积分 (余额)
    var totalEarned: Int        // 历史总积分 (用于统计)
    
    // MARK: - 统计数据 (用于概览)
    var completedTaskCount: Int // 累计完成任务数
    var daysActive: Int         // 活跃天数
    
    // MARK: - 六维属性 (RPG)
    var attrIntellect: Int      // 智力
    var attrStrength: Int       // 体力
    var attrCharm: Int          // 魅力
    var attrExecution: Int      // 执行
    var attrCreativity: Int     // 创造
    var attrWillpower: Int      // 毅力
    
    // MARK: - 历史记录 (用于图表)
    // 存储每日的积分净值快照
    var scoreHistory: [ScoreHistoryItem]
    
    // 兼容旧数据的初始化
    init() {
        self.nickname = "程同学"
        self.avatarData = nil
        
        self.totalScore = 0
        self.totalEarned = 0
        
        self.completedTaskCount = 0
        self.daysActive = 1
        
        // 初始属性值
        self.attrIntellect = 0
        self.attrStrength = 0
        self.attrCharm = 0
        self.attrExecution = 0
        self.attrCreativity = 0
        self.attrWillpower = 0
        
        self.scoreHistory = []
    }
}

// 历史记录模型 (Codable 以便存入 SwiftData)
struct ScoreHistoryItem: Codable {
    var date: Date
    var score: Int // 当日结束时的总积分 (净值)
}
