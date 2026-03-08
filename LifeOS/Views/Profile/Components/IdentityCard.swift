import SwiftUI
import SwiftData
import PhotosUI

struct IdentityCard: View {
    @Bindable var user: UserProfile
    @State private var showEditSheet = false
    @State private var showAvatarPreview = false // 控制头像预览
    
    // UI Constants
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Glass Background
            glassBackground
            
            VStack(spacing: 24) {
                // Top Row: Avatar & Info
                HStack(spacing: 24) {
                    // Avatar (Click to Preview)
                    Button {
                        showAvatarPreview = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 88, height: 88)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            if let data = user.avatarData, let image = createImage(from: data) {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .frame(width: 88, height: 88)
                    }
                    .buttonStyle(.plain)
                    // Full Screen Preview
                    .sheet(isPresented: $showAvatarPreview) {
                        NavigationStack {
                            VStack {
                                Spacer()
                                if let data = user.avatarData, let image = createImage(from: data) {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(Circle())
                                        .padding()
                                        .shadow(radius: 10)
                                } else {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                            }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("关闭") { showAvatarPreview = false }
                                }
                            }
                        }
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(user.nickname)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            // Level Badge
                            Text("Lv.\(user.level)")
                                .font(.system(size: 12, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.yellow))
                                .foregroundStyle(.black)
                                .shadow(color: .yellow.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        // Achievement
                        if let achievement = user.selectedAchievement {
                            HStack(spacing: 6) {
                                Image(systemName: "medal.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(achievement)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.ultraThinMaterial))
                        }
                        
                        // Edit Button
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("编辑资料", systemImage: "pencil")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                }
                
                // Bottom Row: Exp Bar
                VStack(spacing: 8) {
                    HStack {
                        Text("当前经验")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(user.currentExp) / \(user.nextLevelExp)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: calculateProgressWidth(total: geometry.size.width))
                                .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(height: 10)
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(user: user)
        }
    }
    
    private func calculateProgressWidth(total: CGFloat) -> CGFloat {
        let progress = Double(user.currentExp) / Double(user.nextLevelExp)
        return total * CGFloat(min(max(progress, 0), 1))
    }
    
    // Reusing Glass Effect
    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            
            // 增加白色不透明度，使卡片更亮
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.45))
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Global Helper
func createImage(from data: Data) -> Image? {
    #if os(macOS)
    if let nsImage = NSImage(data: data) {
        return Image(nsImage: nsImage)
    }
    #else
    if let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
    }
    #endif
    return nil
}

// Edit Sheet with Avatar & Achievement
struct EditProfileSheet: View {
    @Bindable var user: UserProfile
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var newNickname: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedAchievement: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 头像修改
                Section("头像") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let data = user.avatarData, let image = createImage(from: data) {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.gray)
                            }
                            
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text("更换头像")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            user.avatarData = data
                        }
                    }
                }
                
                // 2. 个人信息
                Section("个人信息") {
                    TextField("昵称", text: $newNickname)
                }
                
                // 3. 成就佩戴
                Section("佩戴成就") {
                    Picker("选择成就", selection: $selectedAchievement) {
                        Text("无").tag("")
                        ForEach(user.unlockedAchievements, id: \.self) { achievement in
                            Text(achievement).tag(achievement)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #else
                    .pickerStyle(.menu)
                    #endif
                }
            }
            .navigationTitle("编辑资料")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 保存昵称
                        if !newNickname.isEmpty {
                            user.nickname = newNickname
                        }
                        // 保存成就 (允许为空)
                        user.selectedAchievement = selectedAchievement.isEmpty ? nil : selectedAchievement
                        
                        dismiss()
                    }
                }
            }
            .onAppear {
                newNickname = user.nickname
                selectedAchievement = user.selectedAchievement ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}
