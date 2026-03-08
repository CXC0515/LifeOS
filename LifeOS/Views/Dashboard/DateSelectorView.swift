import SwiftUI

/// 简洁的日期选择器：左箭头 + 日期（可点击选择） + 右箭头
struct DateSelectorView: View {
    @Binding var selectedDate: Date
    @ObservedObject var theme = ThemeManager.shared
    
    @State private var showDatePicker = false
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 20) {
            // 左箭头：昨天
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.currentTheme.p1)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.currentTheme.pageBackground)
                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                    )
            }
            
            // 中间：日期显示（可点击）
            Button(action: { showDatePicker.toggle() }) {
                VStack(spacing: 2) {
                    Text(formattedDate)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text(formattedWeekday)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 120)
            }
            .popover(isPresented: $showDatePicker) {
                VStack(spacing: 16) {
                    Text("选择日期")
                        .font(.headline)
                        .padding(.top)
                    
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(width: 320) // 增加宽度
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .presentationCompactAdaptation(.popover)
            }
            
            // 右箭头：明天
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.currentTheme.p1)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.currentTheme.pageBackground)
                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                    )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 格式化日期
    
    /// 格式化日期显示（如：2026年1月27日）
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: selectedDate)
    }
    
    /// 格式化星期显示（如：星期一）
    private var formattedWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - 操作
    
    /// 切换到前一天
    private func previousDay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
    
    /// 切换到下一天
    private func nextDay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
}

#Preview {
    @Previewable @State var date = Date()
    return DateSelectorView(selectedDate: $date)
}
