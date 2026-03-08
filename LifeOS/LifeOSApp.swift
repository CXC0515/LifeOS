//
//  LifeOSApp.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
//

import SwiftUI
import SwiftData

@main
struct LifeOSApp: App {
    @StateObject private var appUIState = AppUIState()
    // 这一段是 SwiftData 的标准容器代码，保持不变
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            TaskCategory.self, // 如果你有用到这个
            TaskTag.self,      // 如果你有用到这个
            UserProfile.self,
            StoreProduct.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        StoreService.shared.bootstrapIfNeeded(context: sharedModelContainer.mainContext)
        // 确保系统分类颜色与当前主题同步
        TaskService.shared.ensureSystemCategoryColors(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            // 👇 这里一定要改成 MainTabView()
            MainTabView()
                .environmentObject(appUIState)
                .modelContainer(sharedModelContainer)
        }
    }
}
