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
    
    // 签名相关
    @State private var enableSigning: Bool = true
    @StateObject private var certificateManager = CertificateManager()
    @State private var selectedSystemCertificate: CertificateInfo?
    @State private var isSigning: Bool = false
    @State private var statusMessage: String = ""
    @State private var isStatusError: Bool = false
    
    var isFormValid: Bool {
        return appName.count > 0 && URL(string: url) != nil && selectedImage != nil && 
              nameError == nil && urlError == nil
    }
    
    // 检测应用名称是否为中文
    private var isChineseAppName: Bool {
        for scalar in appName.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value) || // 基本汉字
               (0x3400...0x4DBF).contains(scalar.value) || // 扩展A
               (0x20000...0x2A6DF).contains(scalar.value) { // 扩展B
                return true
            }
        }
        return false
    }
    
    // 根据应用名称语言生成默认组织名称
    private var defaultOrganizationName: String {
        if isChineseAppName {
            return appName.isEmpty ? "WebClip 生成器" : appName
        } else {
            return appName.isEmpty ? "WebClip Generator" : appName
        }
    }
    
    // 根据应用名称语言生成默认描述
    private var defaultProfileDescription: String {
        if isChineseAppName {
            return "安装此配置文件以将 \(appName) 添加到您的主屏幕"
        } else {
            return "Install this profile to add \(appName) to your Home screen"
        }
    }
    
    // 根据应用名称语言生成默认同意信息
    private var defaultConsentText: String {
        if isChineseAppName {
            return "安装此配置文件即表示您同意将 \(appName) 添加到您的设备主屏幕。"
        } else {
            return "By installing this profile, you agree to add \(appName) to your device's Home screen."
        }
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
                                            Text("支持任意尺寸图片 (将自动裁剪为正方形并缩放至256x256)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("支持格式: PNG, JPG (将自动转换为无透明度格式)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("最大文件大小: 800KB (超过将自动压缩)")
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
                
                // 证书签名设置
                GroupBox(label: Text("证书签名").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        // 启用签名开关
                        Toggle(isOn: $enableSigning) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("启用证书签名")
                                    .fontWeight(.medium)
                                Text("使用系统证书对配置文件进行签名，提高安全性")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if enableSigning {
                            // 系统证书选择
                            VStack(alignment: .leading, spacing: 5) {
                                Text("选择系统证书")
                                    .fontWeight(.medium)
                                
                                Menu {
                                    Button("无") {
                                        selectedSystemCertificate = nil
                                    }
                                    
                                    Divider()
                                    
                                    ForEach(certificateManager.availableCertificates) { cert in
                                        Button(action: {
                                            selectedSystemCertificate = cert
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("\(cert.name)----\(Text(cert.expirationInfo))")
                                                    HStack(spacing: 4) {
                                                        Text(cert.certificateType)
                                                        if !cert.expirationInfo.isEmpty {
                                                            Text("·")
                                                            Text(cert.expirationInfo)
                                                        }
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                if cert.isExpired {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                } else if let days = cert.daysUntilExpiration, days <= 30 {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(.orange)
                                                } else {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }
                                        .disabled(cert.isExpired)
                                    }
                                } label: {
                                    HStack {
                                        if let cert = selectedSystemCertificate {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cert.name)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                HStack(spacing: 4) {
                                                    Text(cert.certificateType)
                                                    if !cert.expirationInfo.isEmpty {
                                                        Text("·")
                                                        Text(cert.expirationInfo)
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text("选择证书")
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(6)
                                }
                                
                                if certificateManager.availableCertificates.isEmpty {
                                    Text("未找到可用的Apple开发者证书")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if selectedSystemCertificate == nil {
                                    Text("请选择证书，否则无法生成签名的配置文件")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if let cert = selectedSystemCertificate {
                                    if cert.isExpired {
                                        Text("所选证书已过期，请选择其他证书")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else if let days = cert.daysUntilExpiration, days <= 30 {
                                        Text("所选证书将在 \(days) 天后过期，请注意更新")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("从钥匙串中选择Apple开发者证书")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack {
                                    Button("刷新证书列表") {
                                        certificateManager.loadSystemCertificates()
                                    }
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
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
                                TextField(defaultOrganizationName, text: $organizationName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("显示在配置文件中的组织名称（留空将使用应用名称）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 描述
                            VStack(alignment: .leading, spacing: 5) {
                                Text("描述")
                                    .fontWeight(.medium)
                                TextField(defaultProfileDescription, text: $profileDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("配置文件的描述信息（留空将根据应用名称自动生成）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 同意信息
                            VStack(alignment: .leading, spacing: 5) {
                                Text("同意信息")
                                    .fontWeight(.medium)
                                TextField(defaultConsentText, text: $consentText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("用户安装配置文件时显示的同意信息（留空将根据应用名称自动生成）")
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
                
                // 状态信息
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(isStatusError ? .red : .green)
                        .padding(.vertical, 6)
                }
                
                // 生成按钮
                Button(action: {
                    generateWebClip()
                }) {
                    HStack {
                        if isSigning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 5)
                        }
                        
                        Text(isSigning ? "正在生成..." : (enableSigning && selectedSystemCertificate != nil ? "生成并签名 WebClip" : "生成 WebClip"))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid && !isSigning ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!isFormValid || isSigning)
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
    
    // 图片验证和处理 - 统一处理流程
    private func validateAndProcessImage(_ image: NSImage) -> NSImage? {
        let originalSize = image.size
        
        // 检查图片是否有效
        guard originalSize.width > 0 && originalSize.height > 0 else {
            imageError = "图片无效，请选择有效的图片文件"
            return nil
        }
        
        // 检查是否能正常获取图片表示
        guard image.tiffRepresentation != nil else {
            imageError = "图片格式不支持，请使用PNG、JPEG等常见格式"
            return nil
        }
        
        print("开始处理图片，原始尺寸: \(originalSize.width) x \(originalSize.height)")
        
        var processedImage = image
        var processingSteps: [String] = []
        
        // 第1步：裁剪为正方形（按最短边）
        if abs(originalSize.width - originalSize.height) > 1 {
            processedImage = cropToSquare(processedImage)
            processingSteps.append("裁剪为正方形")
            print("已裁剪为正方形: \(processedImage.size.width) x \(processedImage.size.height)")
        }
        
        // 第2步：统一缩放为256x256
        let targetSize = NSSize(width: 256, height: 256)
        if processedImage.size.width != 256 || processedImage.size.height != 256 {
            processedImage = resizeImage(processedImage, to: targetSize)
            processingSteps.append("缩放至256x256")
            print("已缩放为256x256")
        }
        
        // 第3步：移除透明度
        processedImage = removeTransparency(from: processedImage)
        
        // 第4步：压缩图片，确保不超过800KB
        processedImage = compressImageTo800KB(processedImage)
        
        // 设置提示信息
        if !processingSteps.isEmpty {
            imageError = "图片已自动处理: \(processingSteps.joined(separator: "、"))"
        } else {
            imageError = nil
        }
        
        return processedImage
    }
    
    // 裁剪为正方形（按最短边居中裁剪）
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
    
    // 缩放图片到指定尺寸
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    // 压缩图片到800KB以内
    private func compressImageTo800KB(_ image: NSImage) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return image
        }
        
        let maxSizeKB: Double = 800
        
        // 首先尝试PNG格式
        if let pngData = bitmap.representation(using: .png, properties: [:]) {
            let sizeKB = Double(pngData.count) / 1024
            print("PNG格式大小: \(String(format: "%.2f", sizeKB)) KB")
            
            if sizeKB <= maxSizeKB {
                // PNG格式已经足够小，直接返回
                if let pngImage = NSImage(data: pngData) {
                    return pngImage
                }
            }
        }
        
        // PNG太大，使用JPEG压缩
        var compression: CGFloat = 0.9
        var imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
        
        // 逐步降低质量直到图片小于800KB
        while let data = imageData, Double(data.count) / 1024 > maxSizeKB && compression > 0.1 {
            compression -= 0.1
            imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
            print("JPEG压缩质量: \(String(format: "%.1f", compression)), 大小: \(String(format: "%.2f", Double(data.count) / 1024)) KB")
        }
        
        if let data = imageData {
            print("最终图片大小: \(String(format: "%.2f", Double(data.count) / 1024)) KB")
            if let compressedImage = NSImage(data: data) {
                return compressedImage
            }
        }
        
        return image
    }
    
    // 移除图片透明度，转换为无透明度的图片
    private func removeTransparency(from image: NSImage) -> NSImage {
        let size = image.size
        
        // 如果图片尺寸无效，返回原图
        guard size.width > 0 && size.height > 0 else {
            print("图片尺寸无效")
            return image
        }
        
        // 创建无透明度的位图
        let pixelsWide = Int(size.width)
        let pixelsHigh = Int(size.height)
        
        guard let noAlphaBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 3, // RGB，不包含Alpha
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 24
        ) else {
            print("无法创建无Alpha位图，使用备用方法")
            return removeTransparencyFallback(from: image)
        }
        
        // 绘制到无Alpha位图上
        NSGraphicsContext.saveGraphicsState()
        
        guard let context = NSGraphicsContext(bitmapImageRep: noAlphaBitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            print("无法创建绘制上下文，使用备用方法")
            return removeTransparencyFallback(from: image)
        }
        
        NSGraphicsContext.current = context
        
        // 白色背景
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // 绘制原图
        image.draw(in: NSRect(origin: .zero, size: size))
        
        NSGraphicsContext.restoreGraphicsState()
        
        // 创建最终图片
        let finalImage = NSImage(size: size)
        finalImage.addRepresentation(noAlphaBitmap)
        
        print("成功创建无Alpha通道图片")
        return finalImage
    }
    
    // 移除透明度的备用方法
    private func removeTransparencyFallback(from image: NSImage) -> NSImage {
        let size = image.size
        let newImage = NSImage(size: size)
        
        newImage.lockFocus()
        
        // 设置白色背景
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // 绘制原图片
        image.draw(in: NSRect(origin: .zero, size: size))
        
        newImage.unlockFocus()
        
        return newImage
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
        
        // 检查：如果启用了签名但没有选择证书，提示用户
        if enableSigning && selectedSystemCertificate == nil {
            let alert = NSAlert()
            alert.messageText = "请选择签名证书"
            alert.informativeText = "您已启用证书签名，但尚未选择证书。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        isSigning = true
        statusMessage = ""
        isStatusError = false
        
        // 获取最终使用的值（如果用户没有填写，使用默认值）
        let finalOrganizationName = organizationName.isEmpty ? defaultOrganizationName : organizationName
        let finalDescription = profileDescription.isEmpty ? defaultProfileDescription : profileDescription
        let finalConsentText = consentText.isEmpty ? defaultConsentText : consentText
        
        // 创建 WebClip 配置
        let config = WebClipConfiguration(
            appName: appName,
            url: url,
            icon: image,
            isRemovable: isRemovable,
            isFullScreen: isFullScreen,
            organizationName: finalOrganizationName,
            description: finalDescription,
            consentText: finalConsentText
        )
        
        // 生成未签名的 mobileconfig 数据
        guard let configData = MobileConfigGenerator.generateMobileConfig(config: config) else {
            isSigning = false
            let alert = NSAlert()
            alert.messageText = "生成失败"
            alert.informativeText = "无法生成配置文件。请确保图标格式正确。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        // 判断是否需要签名
        if enableSigning, let certificate = selectedSystemCertificate {
            // 使用系统证书签名
            signAndSaveConfig(configData: configData, certificate: certificate)
        } else {
            // 不签名，直接保存
            saveConfig(configData: configData, isSigned: false)
        }
    }
    
    // 使用系统证书签名并保存
    private func signAndSaveConfig(configData: Data, certificate: CertificateInfo) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 使用系统证书签名
                let signedData = try certificateManager.signWithSystemCertificate(configData, using: certificate)
                
                DispatchQueue.main.async {
                    saveConfig(configData: signedData, isSigned: true)
                }
            } catch {
                DispatchQueue.main.async {
                    isSigning = false
                    statusMessage = "签名失败：\(error.localizedDescription)"
                    isStatusError = true
                }
            }
        }
    }
    
    // 保存配置文件
    private func saveConfig(configData: Data, isSigned: Bool) {
        // 保存面板
        let savePanel = NSSavePanel()
        let fileName = isSigned ? "signed_\(appName).mobileconfig" : "\(appName).mobileconfig"
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedContentTypes = [.init(filenameExtension: "mobileconfig")!]
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    // 保存文件
                    try configData.write(to: url)
                    
                    isSigning = false
                    
                    // 显示成功信息
                    let signedText = isSigned ? "（已签名）" : "（未签名）"
                    statusMessage = "WebClip 生成成功！\(signedText)"
                    isStatusError = false
                    
                    let alert = NSAlert()
                    alert.messageText = "WebClip 生成成功！"
                    alert.informativeText = "配置文件\(signedText)已保存到: \(url.path)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "在访达中显示")
                    alert.addButton(withTitle: "确定")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                } catch {
                    isSigning = false
                    // 处理错误
                    statusMessage = "保存失败：\(error.localizedDescription)"
                    isStatusError = true
                    
                    let alert = NSAlert(error: error)
                    alert.messageText = "保存失败"
                    alert.informativeText = "无法保存配置文件：\(error.localizedDescription)"
                    alert.runModal()
                }
            } else {
                isSigning = false
            }
        } else {
            isSigning = false
            statusMessage = "操作已取消"
            isStatusError = false
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
