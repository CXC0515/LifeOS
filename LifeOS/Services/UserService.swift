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
    
    // MARK: - 3. 统计更新
    func incrementCompletedTasks(context: ModelContext) {
        let user = getCurrentUser(context: context)
        user.completedTaskCount += 1
    }
    
    func checkDailyLogin(context: ModelContext) {
        // 可以在 App 启动时调用，检查最后登录日期来增加 activeDays
        // 这里暂时留空，后续实现
    }
}
