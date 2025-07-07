//
//  SignatureView.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct SignatureView: View {
    // UserDefaults 键名
    private let kLastCertificatePathKey = "lastCertificatePath"
    private let kCertificatePasswordsKey = "certificatePasswords"
    private let kLastUsedCertificateKey = "lastUsedCertificate"
    
    // 添加coordinator
    @ObservedObject var coordinator: AppCoordinator
    
    @State private var mobileConfigFile: URL?
    @State private var certificateFile: URL?
    @State private var certificatePassword: String = ""
    @State private var status: String = "选择要签名的文件"
    @State private var isStatusError: Bool = false
    @State private var isSigning: Bool = false
    @State private var showFileChooser: Bool = false
    @State private var fileChooserType: FileChooserType = .mobileConfigFile
    @State private var useNativeSigningMethod: Bool = true // 默认使用原生签名
    
    @AppStorage("lastUsedCertificate") private var lastUsedCertificate: String = ""
    @State private var certificatePasswords: [String: String] = [:] // 证书ID -> 密码的映射
    
    // 系统证书相关
    @StateObject private var certificateManager = CertificateManager()
    @State private var selectedSystemCertificate: CertificateInfo?
    @State private var useSystemCertificate: Bool = true
    
    enum FileChooserType {
        case mobileConfigFile
        case certificateFile
    }
    
    // 获取应用的证书存储目录
    private var certificatesDirectory: URL? {
        do {
            // 在Application Support目录中创建证书存储目录
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, 
                                                       in: .userDomainMask, 
                                                       appropriateFor: nil, 
                                                       create: true)
            let bundleID = Bundle.main.bundleIdentifier ?? "com.webclip.mac"
            let certDir = appSupport.appendingPathComponent(bundleID).appendingPathComponent("Certificates")
            
            // 确保目录存在
            if !FileManager.default.fileExists(atPath: certDir.path) {
                try FileManager.default.createDirectory(at: certDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            return certDir
        } catch {
            print("创建证书存储目录失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 证书ID的生成方式（使用文件名和创建日期作为唯一标识）
    private func certificateID(for url: URL) -> String {
        let fileName = url.lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: Date())
        return "\(fileName)_\(dateString)"
    }
    
    // 从ID获取证书在沙盒中的URL
    private func certificateURL(for id: String) -> URL? {
        return certificatesDirectory?.appendingPathComponent(id)
    }
    
    // 内部使用的签名错误类型
    enum SignViewError: Error, LocalizedError {
        case fileNotFound
        case fileAccessError
        case signingFailed(String)
        case invalidPassword
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "无法加载证书文件"
            case .fileAccessError:
                return "无法访问证书文件"
            case .signingFailed(let reason):
                return "签名失败: \(reason)"
            case .invalidPassword:
                return "证书密码不正确"
            }
        }
    }
    
    var isFormValid: Bool {
        guard mobileConfigFile != nil && !isSigning else { return false }
        
        if useSystemCertificate {
            return selectedSystemCertificate != nil
        } else {
            return certificateFile != nil && !certificatePassword.isEmpty
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                Text("证书签名")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                
                Text("为现有的 mobileconfig 文件添加证书签名")
                    .foregroundColor(.secondary)
                
                // 主表单
                GroupBox(label: Text("文件选择").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        // mobileconfig 文件选择
                        VStack(alignment: .leading, spacing: 5) {
                            Text("选择 mobileconfig 文件")
                                .fontWeight(.medium)
                            
                            HStack {
                                if let url = mobileConfigFile {
                                    Text(url.lastPathComponent)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                } else {
                                    Text("未选择文件")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("选择文件") {
                                    selectMobileConfigFile()
                                }
                            }
                            .padding(10)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                }
                
                // 证书设置
                GroupBox(label: Text("证书设置").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        // 证书类型选择
                        VStack(alignment: .leading, spacing: 10) {
                            Text("证书来源")
                                .fontWeight(.medium)
                            
                            Picker("证书来源", selection: $useSystemCertificate) {
                                Text("证书文件").tag(false)
                                Text("系统证书").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: useSystemCertificate) { _ in
                                // 切换证书类型时清空相关状态
                                if useSystemCertificate {
                                    certificateFile = nil
                                    certificatePassword = ""
                                } else {
                                    selectedSystemCertificate = nil
                                }
                            }
                        }
                        
                        if useSystemCertificate {
                            // 系统证书选择
                            VStack(alignment: .leading, spacing: 5) {
                                Text("选择系统证书")
                                    .fontWeight(.medium)
                                
                                Menu {
                                    Button("无") {
                                        selectedSystemCertificate = nil
                                    }
                                    
                                    ForEach(certificateManager.availableCertificates) { cert in
                                        Button(cert.name) {
                                            selectedSystemCertificate = cert
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedSystemCertificate?.name ?? "选择证书")
                                            .foregroundColor(selectedSystemCertificate != nil ? .primary : .secondary)
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
                                } else {
                                    Text("从钥匙串中选择Apple开发者证书")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Button("刷新证书列表") {
                                        certificateManager.loadSystemCertificates()
                                    }
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
                        } else {
                            // 证书文件选择
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("证书文件")
                                        .fontWeight(.medium)
                                    Text("(可选)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    if let url = certificateFile {
                                        Text(url.lastPathComponent)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    } else {
                                        Text("未选择证书")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("选择证书") {
                                        selectCertificateFile()
                                    }
                                }
                                .padding(10)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                                
                                Text("支持 .p12 或 .pfx 格式的证书文件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 证书密码
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("证书密码")
                                        .fontWeight(.medium)
                                    Text("(可选)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                SecureField("输入证书密码", text: $certificatePassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: certificatePassword) { newValue in
                                        handlePasswordChange(newValue)
                                    }
                                Text("如果签名失败，请检查密码是否正确，或尝试不使用特殊字符的密码")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 签名方法选择
                        Toggle(isOn: $useNativeSigningMethod) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("使用原生签名 API")
                                    .fontWeight(.medium)
                                Text("使用 Apple 原生 API 进行签名，更加稳定和可靠")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .padding()
                }
                
                // 状态信息
                if !status.isEmpty {
                    Text(status)
                        .foregroundColor(isStatusError ? .red : .primary)
                        .padding(.vertical, 6)
                }
                
                // 签名按钮
                Button(action: {
                    signMobileConfigFile()
                }) {
                    HStack {
                        if isSigning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 5)
                        }
                        
                        Text(isSigning ? "正在签名..." : "签名")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.blue.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!isFormValid)
                .padding(.top, 10)
            }
            .padding()
            .frame(minWidth: 600)
            .onAppear {
                checkLastGeneratedFile()
            }
        }
    }
    
    // onAppear修改以处理从coordinator获取的文件和加载保存的证书密码
    private func checkLastGeneratedFile() {
        // 从UserDefaults加载证书密码字典
        loadCertificatePasswords()
        
        if let fileURL = coordinator.lastGeneratedFile {
            mobileConfigFile = fileURL
            status = "文件已加载: \(fileURL.lastPathComponent)"
            isStatusError = false
            coordinator.lastGeneratedFile = nil  // 清除，避免重复加载
        }
        
        // 检查上次使用的证书是否存在
        if !lastUsedCertificate.isEmpty, let certURL = certificateURL(for: lastUsedCertificate) {
            if FileManager.default.fileExists(atPath: certURL.path) {
                certificateFile = certURL
                // 恢复保存的密码
                certificatePassword = certificatePasswords[lastUsedCertificate] ?? ""
            } else {
                // 证书文件不存在，清除保存的最后使用证书路径
                lastUsedCertificate = ""
                // 但不清除证书密码映射，因为其他证书可能还存在
            }
        }
    }
    
    // 加载保存的证书密码映射
    private func loadCertificatePasswords() {
        if let data = UserDefaults.standard.data(forKey: kCertificatePasswordsKey),
           let passwords = try? JSONDecoder().decode([String: String].self, from: data) {
            certificatePasswords = passwords
        }
    }
    
    // 保存证书密码映射
    private func saveCertificatePasswords() {
        if let data = try? JSONEncoder().encode(certificatePasswords) {
            UserDefaults.standard.set(data, forKey: kCertificatePasswordsKey)
        }
    }
    
    private func selectMobileConfigFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "mobileconfig") ?? .data]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                mobileConfigFile = url
                status = ""
                isStatusError = false
            }
        }
    }
    
    // 将外部证书复制到应用沙盒中
    private func importCertificateToSandbox(from externalURL: URL) -> (id: String, url: URL)? {
        guard let certsDir = certificatesDirectory else { return nil }
        
        do {
            // 生成唯一的证书ID
            let certID = certificateID(for: externalURL)
            let destinationURL = certsDir.appendingPathComponent(certID)
            
            // 复制证书文件到沙盒目录
            try FileManager.default.copyItem(at: externalURL, to: destinationURL)
            
            return (certID, destinationURL)
        } catch {
            print("复制证书到沙盒失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func selectCertificateFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "p12") ?? .data, UTType(filenameExtension: "pfx") ?? .data]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                // 将证书复制到沙盒目录
                if let (certID, sandboxURL) = importCertificateToSandbox(from: url) {
                    certificateFile = sandboxURL
                    status = "证书已导入: \(url.lastPathComponent)"
                    isStatusError = false
                    
                    // 保存当前使用的证书ID
                    lastUsedCertificate = certID
                    
                    // 检查是否有保存的密码
                    if let savedPassword = certificatePasswords[certID], !savedPassword.isEmpty {
                        certificatePassword = savedPassword
                    } else {
                        // 新证书，清空密码输入框
                        certificatePassword = ""
                    }
                } else {
                    status = "证书导入失败"
                    isStatusError = true
                }
            }
        }
    }
    
    // 处理密码变化
    private func handlePasswordChange(_ newValue: String) {
        certificatePassword = newValue
        
        // 保存密码到证书密码映射
        if lastUsedCertificate.isEmpty == false {
            certificatePasswords[lastUsedCertificate] = newValue
            saveCertificatePasswords()
        }
    }
    
    // 将文件复制到临时目录
    private func copyFileToTempDirectory(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("webclip_temp_\(UUID().uuidString)")
        
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            let destinationURL = tempDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("复制文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func signMobileConfigFile() {
        guard let mobileConfigURL = mobileConfigFile else { return }
        
        if useSystemCertificate {
            // 使用系统证书签名
            guard let systemCert = selectedSystemCertificate else { return }
            signWithSystemCertificate(mobileConfigURL, certificate: systemCert)
        } else {
            // 使用证书文件签名
            // 检查证书文件是否存在
            if certificateFile == nil && !lastUsedCertificate.isEmpty, 
               let certURL = certificateURL(for: lastUsedCertificate) {
                if FileManager.default.fileExists(atPath: certURL.path) {
                    certificateFile = certURL
                    certificatePassword = certificatePasswords[lastUsedCertificate] ?? ""
                } else {
                    lastUsedCertificate = ""
                }
            }
            
            guard let certURL = certificateFile, !certificatePassword.isEmpty else { return }
            signWithCertificateFile(mobileConfigURL, certificateURL: certURL)
        }
    }
    
    // 使用系统证书签名
    private func signWithSystemCertificate(_ mobileConfigURL: URL, certificate: CertificateInfo) {
        isSigning = true
        status = "正在使用系统证书签名..."
        isStatusError = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 读取 mobileconfig 文件数据
                let configData = try Data(contentsOf: mobileConfigURL)
                
                // 使用系统证书签名
                let signedData = try certificateManager.signWithSystemCertificate(configData, using: certificate)
                
                // 创建新的文件名（添加signed_前缀）
                let originalFileName = mobileConfigURL.lastPathComponent
                let signedFileName = "signed_" + originalFileName
                
                // 弹出保存对话框
                DispatchQueue.main.async {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [UTType(filenameExtension: "mobileconfig") ?? .data]
                    savePanel.nameFieldStringValue = signedFileName
                    savePanel.title = "保存已签名的配置文件"
                    
                    if savePanel.runModal() == .OK {
                        if let saveURL = savePanel.url {
                            do {
                                try signedData.write(to: saveURL)
                                isSigning = false
                                status = "签名成功！文件已保存为: \(saveURL.lastPathComponent)"
                                isStatusError = false
                            } catch {
                                isSigning = false
                                status = "保存文件失败：\(error.localizedDescription)"
                                isStatusError = true
                            }
                        } else {
                            isSigning = false
                            status = "操作已取消"
                            isStatusError = false
                        }
                    } else {
                        isSigning = false
                        status = "操作已取消"
                        isStatusError = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isSigning = false
                    status = "系统证书签名失败：\(error.localizedDescription)"
                    isStatusError = true
                }
            }
        }
    }
    
    // 使用证书文件签名
    private func signWithCertificateFile(_ mobileConfigURL: URL, certificateURL: URL) {
        // 最后一次检查文件是否存在
        guard FileManager.default.fileExists(atPath: certificateURL.path) else {
            status = "证书文件不存在或已被移动"
            isStatusError = true
            certificateFile = nil
            return
        }
        
        isSigning = true
        status = "正在签名文件..."
        isStatusError = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 读取 mobileconfig 文件数据
                let configData = try Data(contentsOf: mobileConfigURL)
                
                // 根据选择的签名方法进行签名
                let signedData: Data
                
                if useNativeSigningMethod {
                    // 使用 SecCMSConfigSigner (原生 API) 进行签名
                    do {
                        signedData = try SecCMSConfigSigner.sign(
                            data: configData,
                            certificatePath: certificateURL.path,
                            password: certificatePassword
                        )
                    } catch let error as SecCMSConfigSigner.SigningError {
                        // 转换 SecCMSConfigSigner 错误为 SignatureView 错误
                        switch error {
                        case .invalidPassword:
                            throw SignViewError.invalidPassword
                        case .p12FileNotFound:
                            throw SignViewError.fileNotFound
                        case .invalidData:
                            throw SignViewError.fileAccessError
                        default:
                            throw SignViewError.signingFailed(error.localizedDescription)
                        }
                    }
                } else {
                    // 使用 OpenSSL 命令行进行签名
                    // 复制证书文件到临时目录（避免中文路径和权限问题）
                    guard let tempCertURL = copyFileToTempDirectory(from: certificateURL) else {
                        throw SignViewError.fileAccessError
                    }
                    
                    // 签名数据
                    do {
                        signedData = try MobileConfigSigner.sign(
                            data: configData,
                            certificatePath: tempCertURL.path,
                            password: certificatePassword
                        )
                    } catch let error as MobileConfigSigner.SigningError {
                        // 转换 MobileConfigSigner 错误为 SignatureView 错误
                        switch error {
                        case .invalidPassword:
                            throw SignViewError.invalidPassword
                        case .certificateLoadFailed:
                            throw SignViewError.fileNotFound
                        case .invalidData:
                            throw SignViewError.fileAccessError
                        default:
                            throw SignViewError.signingFailed(error.localizedDescription)
                        }
                    }
                    
                    // 复制完成后清理临时文件
                    try? FileManager.default.removeItem(at: tempCertURL.deletingLastPathComponent())
                }
                
                // 创建新的文件名（添加signed_前缀）
                let originalFileName = mobileConfigURL.lastPathComponent
                let signedFileName = "signed_" + originalFileName
                
                // 弹出保存对话框
                DispatchQueue.main.async {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [UTType(filenameExtension: "mobileconfig") ?? .data]
                    savePanel.nameFieldStringValue = signedFileName
                    savePanel.title = "保存已签名的配置文件"
                    
                    if savePanel.runModal() == .OK {
                        if let saveURL = savePanel.url {
                            do {
                                try signedData.write(to: saveURL)
                                isSigning = false
                                status = "签名成功！文件已保存为: \(saveURL.lastPathComponent)"
                                isStatusError = false
                            } catch {
                                isSigning = false
                                status = "保存文件失败：\(error.localizedDescription)"
                                isStatusError = true
                            }
                        } else {
                            isSigning = false
                            status = "操作已取消"
                            isStatusError = false
                        }
                    } else {
                        isSigning = false
                        status = "操作已取消"
                        isStatusError = false
                    }
                }
            } catch let error as SignViewError {
                DispatchQueue.main.async {
                    isSigning = false
                    status = error.localizedDescription
                    isStatusError = true
                }
            } catch {
                DispatchQueue.main.async {
                    isSigning = false
                    status = "签名失败：\(error.localizedDescription)"
                    isStatusError = true
                }
            }
        }
    }
}

struct SignatureView_Previews: PreviewProvider {
    static var previews: some View {
        SignatureView(coordinator: AppCoordinator())
    }
} 
