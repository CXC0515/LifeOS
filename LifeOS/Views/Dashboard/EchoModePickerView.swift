//
//  EchoModePickerView.swift
//  LifeOS
//
//  Created by LifeOS AI on 2026/01/27.
//

import SwiftUI

/// Echo 模式子视图切换器（单日/多日/月）- 下拉菜单版
struct EchoModePickerView: View {
    @Binding var selectedMode: EchoMode
    @ObservedObject var theme = ThemeManager.shared
    
    var body: some View {
        Menu {
            ForEach(EchoMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                }) {
                    HStack {
                        Text(mode.rawValue)
                        if selectedMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedMode.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.currentTheme.p2.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.currentTheme.p2.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    @Previewable @State var mode: EchoMode = .day
    return EchoModePickerView(selectedMode: $mode)
}
