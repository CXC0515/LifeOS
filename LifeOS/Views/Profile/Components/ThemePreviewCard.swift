import SwiftUI

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.baseColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
            
            VStack(spacing: 12) {
                // Theme Name
                Text(theme.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                // Color Palette
                HStack(spacing: 8) {
                    Circle().fill(theme.p0).frame(width: 20, height: 20)
                    Circle().fill(theme.p1).frame(width: 20, height: 20)
                    Circle().fill(theme.p2).frame(width: 20, height: 20)
                    Circle().fill(theme.p3).frame(width: 20, height: 20)
                }
            }
            .padding()
            
            // Selection Checkmark
            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .background(Circle().fill(.white))
                            .font(.title3)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 100)
    }
}
