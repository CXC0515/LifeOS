import SwiftUI

struct QuantityInputSheet: View {
    let title: String
    @Binding var current: Double
    let target: Double
    let unit: String
    let onCommit: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    private var primaryColor: Color {
        ThemeManager.shared.currentTheme.p2
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 16)
            
            Text("更新进度")
                .font(.headline)
                .padding(.top, 4)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text("\(Int(current))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(primaryColor)
                
                Text("/ \(Int(target)) \(unit)")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
            .padding(.vertical, 8)
            
            Slider(value: $current, in: 0...target, step: 1)
                .tint(primaryColor)
                .padding(.horizontal)
            
            HStack {
                Button {
                    if current > 0 { current -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button {
                    if current < target { current += 1 }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.headline)
                        .foregroundStyle(primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button {
                    onCommit(current)
                    dismiss()
                } label: {
                    Text("确定")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ThemeManager.shared.currentTheme.p2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.height(360)])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.visible)
    }
}
