//
//  FileManagerView.swift
//  LifeOS
//
//  文件管理占位视图
//

import SwiftUI

struct FileManagerView: View {
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        VStack {
            ContentUnavailableView(
                "文件管理",
                systemImage: "folder.badge.gearshape",
                description: Text("此功能正在开发中，敬请期待")
            )
        }
        .background(theme.currentTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("文件管理")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        FileManagerView()
    }
}
