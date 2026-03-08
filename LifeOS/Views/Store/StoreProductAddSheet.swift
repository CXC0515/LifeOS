import SwiftUI
import SwiftData
import PhotosUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct StoreProductAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var theme = ThemeManager.shared
    
    // 表单字段状态
    @State private var name: String = ""
    @State private var desc: String = ""
    @State private var pointsCost: Int = 100
    
    // 图片相关状态
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    // 回调，通知外部数据已更新
    var onSave: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：使用主题背景色
                theme.currentTheme.pageBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. 图片选择区域（置顶且放大）
                        VStack(spacing: 16) {
                            if let selectedImageData, let image = createImage(from: selectedImageData) {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 140, height: 140)
                                
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .foregroundStyle(.secondary.opacity(0.3))
                            )
                        }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text(selectedImageData == nil ? "上传商品图片" : "更换图片")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(theme.currentTheme.p1)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(theme.currentTheme.p1.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 20)
                        
                        // 2. 基本信息卡片
                        VStack(spacing: 20) {
                            inputField(title: "商品名称", text: $name, icon: "tag.fill")
                            
                            // 描述输入框
                            VStack(alignment: .leading, spacing: 8) {
                                Label("商品描述", systemImage: "text.alignleft")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                
                                TextField("请输入简短描述", text: $desc)
                                    .padding()
                                    .background(Color.white.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // 积分价格
                            VStack(alignment: .leading, spacing: 8) {
                                Label("兑换积分", systemImage: "bitcoinsign.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                
                                HStack {
                                    TextField("100", value: $pointsCost, format: .number)
                                        #if os(iOS)
                                        .keyboardType(.numberPad)
                                        #endif
                                        .font(.title2.bold())
                                        .foregroundStyle(theme.currentTheme.p1)
                                    Text("pts")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(24)
                        .glassCardStyle(cornerRadius: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("添加商品")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        saveProduct()
                    }) {
                        Text("保存")
                            .font(.body)
                            .foregroundStyle(theme.currentTheme.p2)
                    }
                    .disabled(name.isEmpty)
                }
            }
            // 监听图片选择
            .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        withAnimation {
                            selectedImageData = data
                        }
                    }
                }
            }
        }
    }
    
    // 辅助视图：输入框组件
    private func inputField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            TextField("请输入...", text: text)
                .padding()
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // 保存逻辑
    private func saveProduct() {
        var imageRef = "gift.fill" // 默认图标
        var imageKind: ProductImageKind = .symbol
        
        // 如果有图片，保存到磁盘
        if let data = selectedImageData {
            if let fileName = saveImageToDisk(data: data) {
                imageRef = fileName
                imageKind = .file
            }
        }
        
        let newProduct = StoreProduct(
            name: name,
            desc: desc,
            pointsCost: pointsCost,
            imageKind: imageKind,
            imageRef: imageRef
        )
        context.insert(newProduct)
        
        // 调用回调刷新列表
        onSave?()
        
        dismiss()
    }
    
    // 保存图片到 Documents 目录
    private func saveImageToDisk(data: Data) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                return fileName
            } catch {
                print("Error saving image: \(error)")
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Helper
    private func createImage(from data: Data) -> Image? {
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
}
