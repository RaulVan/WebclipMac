//
//  ContentView.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Security


struct ContentView: View {
    // 添加coordinator用于页面导航
    var coordinator: AppCoordinator
    
    @State private var appName: String = ""
    @State private var url: String = ""
    @State private var selectedImage: NSImage?
    @State private var isRemovable: Bool = true
    @State private var isFullScreen: Bool = true
    @State private var showAdvancedSettings: Bool = false
    
    // 表单验证状态
    @State private var nameError: String? = nil
    @State private var urlError: String? = nil
    @State private var imageError: String? = nil
    @State private var isDragging: Bool = false
    
    // 高级设置
    @State private var organizationName: String = ""
    @State private var profileDescription: String = ""
    @State private var consentText: String = ""
    
    var isFormValid: Bool {
        return appName.count > 0 && URL(string: url) != nil && selectedImage != nil && 
              nameError == nil && urlError == nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                Text("WebClip 生成器")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                
                Text("简单易用的 iOS Web Clip 创建工具，帮助您快速将网页添加到主屏幕。")
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
                
                // WebClip 配置区域
                GroupBox(label: Text("WebClip 配置").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        // 应用名称
                        VStack(alignment: .leading) {
                            HStack {
                                Text("应用名称")
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            TextField("输入应用名称", text: $appName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: appName) { newValue in
                                    validateAppName(newValue)
                                }
                            
                            if let error = nameError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // URL
                        VStack(alignment: .leading) {
                            HStack {
                                Text("URL")
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            TextField("输入网站URL", text: $url)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: url) { newValue in
                                    validateURL(newValue)
                                }
                            
                            if let error = urlError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // 应用图标
                        VStack(alignment: .leading) {
                            HStack {
                                Text("应用图标")
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            
                            ZStack(alignment: .leading) {
                                VStack(alignment: .leading) {
                                    HStack(alignment: .top) {
                                        if let image = selectedImage {
                                            Image(nsImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 80, height: 80)
                                                .cornerRadius(8)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("要求尺寸: 256x256 至 1024x1024 像素 (必须正方形)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("支持格式: PNG, JPG (将自动转换为无透明度的PNG)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("最大文件大小: 1MB (超过将自动压缩)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Button("选择图标") {
                                                openImagePicker()
                                            }
                                            .padding(.top, 4)
                                            
                                            if let error = imageError {
                                                Text(error)
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                    .padding(.top, 2)
                                            }
                                        }
                                        .padding(.leading, 10)
                                    }
                                }
                                
                                // 拖拽区域覆盖整个区域
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 100)
                                    .onDrop(of: [.fileURL, .image, .png, .jpeg], isTargeted: $isDragging) { providers in
                                        return handleDrop(providers: providers)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isDragging ? Color.blue : Color.clear, style: StrokeStyle(lineWidth: 2))
                                    )
                            }
                        }
                    }
                    .padding()
                }
                
                // 选项设置区域
                GroupBox(label: Text("选项设置").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        // 是否可移除
                        VStack(alignment: .leading) {
                            Text("是否可移除")
                                .fontWeight(.medium)
                            HStack {
                                RadioButtonField(
                                    id: "removable",
                                    label: "可移除",
                                    isMarked: isRemovable,
                                    callback: { isRemovable = true }
                                )
                                
                                RadioButtonField(
                                    id: "nonRemovable",
                                    label: "不可移除",
                                    isMarked: !isRemovable,
                                    callback: { isRemovable = false }
                                )
                            }
                        }
                        
                        // 全屏模式
                        Toggle(isOn: $isFullScreen) {
                            Text("全屏模式 (隐藏Safari工具栏)")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                }
                
                // 高级设置
                DisclosureGroup(
                    isExpanded: $showAdvancedSettings,
                    content: {
                        VStack(alignment: .leading, spacing: 15) {
                            // 组织名称
                            VStack(alignment: .leading, spacing: 5) {
                                Text("组织名称")
                                    .fontWeight(.medium)
                                TextField("Web Clip Generator", text: $organizationName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("显示在配置文件中的组织名称")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 描述
                            VStack(alignment: .leading, spacing: 5) {
                                Text("描述")
                                    .fontWeight(.medium)
                                TextField("Install this profile to add \(appName) to your Home screen", text: $profileDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("配置文件的描述信息")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 同意信息
                            VStack(alignment: .leading, spacing: 5) {
                                Text("同意信息")
                                    .fontWeight(.medium)
                                TextField("安装此配置文件即表示您同意...", text: $consentText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("用户安装配置文件时显示的同意信息")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    },
                    label: {
                        Text("高级设置 (可选)")
                            .font(.headline)
                    }
                )
                .padding(.vertical, 5)
                .padding(.horizontal)
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)
                
                // 生成按钮
                Button(action: {
                    generateWebClip()
                }) {
                    Text("生成 WebClip")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!isFormValid)
                .padding(.top, 10)
            }
            .padding()
            .frame(minWidth: 600)
        }
    }
    
    // 输入验证功能
    private func validateAppName(_ name: String) {
        if name.isEmpty {
            nameError = "应用名称不能为空"
        } else if name.count > 30 {
            nameError = "应用名称不能超过30个字符"
        } else {
            nameError = nil
        }
    }
    
    private func validateURL(_ urlString: String) {
        if urlString.isEmpty {
            urlError = "URL不能为空"
            return
        }
        
        if let url = URL(string: urlString) {
            if url.scheme == "http" || url.scheme == "https" {
                urlError = nil
            } else {
                urlError = "URL必须以http://或https://开头"
            }
        } else {
            urlError = "请输入有效的URL"
        }
    }
    
    // 图片验证和处理
    private func validateAndProcessImage(_ image: NSImage) -> NSImage? {
        return image
//        let originalSize = image.size
//        
//        // 检查尺寸
//        if originalSize.width < 256 || originalSize.height < 256 {
//            imageError = "图片尺寸过小，已自动放大至512x512像素"
//            // 放大图片至512x512
//            return resizeImage(image, to: NSSize(width: 512, height: 512))
//        }
//        
//        if originalSize.width > 1024 || originalSize.height > 1024 {
//            imageError = "图片尺寸过大，已自动缩小至512x512像素"
//            // 缩小图片至512x512
//            return resizeImage(image, to: NSSize(width: 512, height: 512))
//        }
//        
//        // 检查是否为正方形
//        if abs(originalSize.width - originalSize.height) > 1 { // 允许1像素的误差
//            imageError = "图片必须是正方形，已自动裁剪"
//            // 裁剪为正方形
//            return cropToSquare(image)
//        }
//        
//        // 检查文件大小
//        if let imageData = image.tiffRepresentation,
//           let bitmap = NSBitmapImageRep(data: imageData),
//           let pngData = bitmap.representation(using: .png, properties: [:]) {
//            
//            let sizeInMB = Double(pngData.count) / (1024 * 1024)
//            if sizeInMB > 1.0 {
//                imageError = "图片已自动压缩以减小文件大小"
//                return compressImage(image)
//            }
//        }
//        
//        imageError = nil
//        return image
    }
    
    // 图片处理功能
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    private func cropToSquare(_ image: NSImage) -> NSImage {
        let originalSize = image.size
        let minDimension = min(originalSize.width, originalSize.height)
        let newSize = NSSize(width: minDimension, height: minDimension)
        
        let offsetX = (originalSize.width - minDimension) / 2
        let offsetY = (originalSize.height - minDimension) / 2
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize), 
                   from: NSRect(origin: NSPoint(x: offsetX, y: offsetY), size: newSize), 
                   operation: .copy, 
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    private func compressImage(_ image: NSImage) -> NSImage {
        // 使用较低的质量设置压缩图片
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return image
        }
        
        var compression: CGFloat = 0.9
        var imageData = bitmap.representation(using: .png, properties: [.compressionFactor: compression])
        
        // 逐步降低质量直到图片小于800KB
        while let data = imageData, Double(data.count) > 800 * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = bitmap.representation(using: .png, properties: [.compressionFactor: compression])
        }
        
        if let data = imageData, let compressedImage = NSImage(data: data) {
            return compressedImage
        }
        
        return image
    }
    
    // 图片选择器
    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg]
        
        if panel.runModal() == .OK {
            if let url = panel.url, let image = NSImage(contentsOf: url) {
                if let processedImage = validateAndProcessImage(image) {
                    selectedImage = processedImage
                }
            }
        }
    }
    
    // 处理拖拽
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data = data, let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            if let processedImage = validateAndProcessImage(image) {
                                self.selectedImage = processedImage
                            }
                        }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            if let processedImage = validateAndProcessImage(image) {
                                self.selectedImage = processedImage
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    func generateWebClip() {
        // 验证所有必填信息
        guard isFormValid, let image = selectedImage else {
            return
        }
        
        // 创建 WebClip 配置
        let config = WebClipConfiguration(
            appName: appName,
            url: url,
            icon: image,
            isRemovable: isRemovable,
            isFullScreen: isFullScreen,
            organizationName: organizationName.isEmpty ? appName : organizationName,
            description: profileDescription.isEmpty ? "Install this profile to add \(appName) to your Home screen" : profileDescription,
            consentText: consentText
        )
        
        // 生成未签名的 mobileconfig 数据
        guard let configData = MobileConfigGenerator.generateMobileConfig(config: config) else {
            let alert = NSAlert()
            alert.messageText = "生成失败"
            alert.informativeText = "无法生成配置文件。请确保图标格式正确。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        // 保存面板
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(appName).mobileconfig"
        savePanel.allowedContentTypes = [.init(filenameExtension: "mobileconfig")!]
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    // 直接保存未签名的文件
                    try configData.write(to: url)
                    
                    // 显示成功信息
                    let alert = NSAlert()
                    alert.messageText = "WebClip 生成成功！"
                    alert.informativeText = "配置文件已保存到: \(url.path)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定并签名")
                    alert.addButton(withTitle: "在访达中显示")
                    alert.addButton(withTitle: "仅保存")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        // 导航到签名页面
                        coordinator.navigateToSignature(with: url)
                    } else if response == .alertSecondButtonReturn {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                } catch {
                    // 处理错误
                    let alert = NSAlert(error: error)
                    alert.messageText = "保存失败"
                    alert.informativeText = "无法保存配置文件：\(error.localizedDescription)"
                    alert.runModal()
                }
            }
        }
    }
}

// 自定义单选按钮组件
struct RadioButtonField: View {
    let id: String
    let label: String
    let isMarked: Bool
    let callback: () -> Void
    
    var body: some View {
        Button(action: {
            callback()
        }) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isMarked ? "circle.inset.filled" : "circle")
                    .foregroundColor(isMarked ? .blue : .primary)
                
                Text(label)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(coordinator: AppCoordinator())
    }
}
