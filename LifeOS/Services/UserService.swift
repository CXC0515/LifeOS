//
//  UserService.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/26.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class UserService {
    static let shared = UserService()
    
    private init() {}
    
    // MARK: - 1. 获取当前用户
    func getCurrentUser(context: ModelContext) -> UserProfile {
        if let user = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return user
        } else {
            // 如果不存在，创建一个新的
            let newUser = UserProfile()
            context.insert(newUser)
            return newUser
        }
    }
    
    // MARK: - 2. 基础信息更新
    func updateAvatar(data: Data?, context: ModelContext) {
        let user = getCurrentUser(context: context)
        user.avatarData = data
    }
    
    func updateNickname(_ name: String, context: ModelContext) {
        let user = getCurrentUser(context: context)
        user.nickname = name
    }
    
    // MARK: - 3. 经验与等级系统
    /// 增加经验值并检查升级
    /// - Returns: 如果升级了，返回 true
    func addExp(_ amount: Int, context: ModelContext) -> Bool {
        guard amount > 0 else { return false }
        
        let user = getCurrentUser(context: context)
        user.currentExp += amount
        user.totalEarned += amount // 总积分也同步增加作为历史记录
        
        // 检查升级逻辑
        var didLevelUp = false
        while user.currentExp >= user.nextLevelExp {
            user.currentExp -= user.nextLevelExp
            user.level += 1
            
            // 升级后，下一级所需经验增加 (简单的成长曲线：每级增加 20%)
            user.nextLevelExp = Int(Double(user.nextLevelExp) * 1.2)
            
            didLevelUp = true
        }
        
        return didLevelUp
    }
    
    // MARK: - 4. 成就系统
    func unlockAchievement(_ name: String, context: ModelContext) {
        let user = getCurrentUser(context: context)
        if !user.unlockedAchievements.contains(name) {
            user.unlockedAchievements.append(name)
        }
    }
    
    func equipAchievement(_ name: String, context: ModelContext) {
        let user = getCurrentUser(context: context)
        if user.unlockedAchievements.contains(name) {
            user.selectedAchievement = name
        }
    }
    
    // MARK: - 5. 统计更新
    func incrementCompletedTasks(context: ModelContext) {
        let user = getCurrentUser(context: context)
        user.completedTaskCount += 1
    }
    
    func checkDailyLogin(context: ModelContext) {
        // 可以在 App 启动时调用，检查最后登录日期来增加 activeDays
        // 这里暂时留空，后续实现
    }
}
