//
//  IdentityCard.swift
//  LifeOS
//
//  身份卡片：头像、昵称、编辑按钮、活跃天数进度条
//

import SwiftUI
import SwiftData
import PhotosUI

struct IdentityCard: View {
    @Bindable var user: UserProfile
    @State private var showEditSheet = false
    @State private var showAvatarPreview = false // 控制头像预览
    
    // UI Constants
    private let cornerRadius: CGFloat = 24
    
    /// 活跃天数目标（可以后续做成动态的）
    private let activeDaysGoal: Int = 365
    
    var body: some View {
        ZStack {
            // Glass Background
            glassBackground
            
            VStack(spacing: 20) {
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
                        Text(user.nickname)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
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
                
                // Bottom: 活跃天数进度条（紧凑美观）
                activeDaysBar
            }
            .padding(28)
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(user: user)
        }
    }
    
    // MARK: - 活跃天数进度条
    
    private var activeDaysBar: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("活跃天数")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(user.daysActive) 天")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.6), Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: calculateActiveDaysWidth(total: geometry.size.width))
                }
            }
            .frame(height: 6)
        }
    }
    
    private func calculateActiveDaysWidth(total: CGFloat) -> CGFloat {
        let progress = Double(user.daysActive) / Double(activeDaysGoal)
        return total * CGFloat(min(max(progress, 0.02), 1)) // min 2% so bar is always visible
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

// Edit Sheet with Avatar (Achievement section removed)
struct EditProfileSheet: View {
    @Bindable var user: UserProfile
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var newNickname: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    
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
                        dismiss()
                    }
                }
            }
            .onAppear {
                newNickname = user.nickname
            }
        }
        .presentationDetents([.medium, .large])
    }
}
