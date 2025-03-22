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
    private let kLastCertificatePasswordKey = "lastCertificatePassword"
    
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
    
    @AppStorage("lastCertificatePath") private var lastCertificatePath: String = ""
    
    enum FileChooserType {
        case mobileConfigFile
        case certificateFile
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
        return mobileConfigFile != nil && certificateFile != nil && !certificatePassword.isEmpty && !isSigning
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
                        // 证书文件
                        VStack(alignment: .leading, spacing: 5) {
                            Text("证书文件")
                                .fontWeight(.medium)
                            
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
                            Text("证书密码")
                                .fontWeight(.medium)
                            SecureField("输入证书密码", text: $certificatePassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: certificatePassword) { newValue in
                                    // 保存密码到 UserDefaults
                                    UserDefaults.standard.set(newValue, forKey: kLastCertificatePasswordKey)
                                }
                            Text("如果签名失败，请检查密码是否正确，或尝试不使用特殊字符的密码")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    // onAppear修改以处理从coordinator获取的文件
    private func checkLastGeneratedFile() {
        if let fileURL = coordinator.lastGeneratedFile {
            mobileConfigFile = fileURL
            status = "文件已加载: \(fileURL.lastPathComponent)"
            isStatusError = false
            coordinator.lastGeneratedFile = nil  // 清除，避免重复加载
        }
        
        // 检查上次使用的证书是否存在
        if !lastCertificatePath.isEmpty {
            let fileURL = URL(fileURLWithPath: lastCertificatePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                certificateFile = fileURL
            } else {
                // 证书文件不存在，清除保存的路径
                lastCertificatePath = ""
            }
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
    
    private func selectCertificateFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "p12") ?? .data, UTType(filenameExtension: "pfx") ?? .data]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                certificateFile = url
                status = ""
                isStatusError = false
                
                // 保存证书路径到 UserDefaults
                UserDefaults.standard.set(url.path, forKey: kLastCertificatePathKey)
                lastCertificatePath = url.path
            }
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
        
        // 检查证书文件是否存在
        if certificateFile == nil && UserDefaults.standard.string(forKey: kLastCertificatePathKey) != nil {
            // 尝试重新加载保存的证书路径
            checkLastGeneratedFile()
        }
        
        guard let certURL = certificateFile, !certificatePassword.isEmpty else { return }
        
        // 最后一次检查文件是否存在
        guard FileManager.default.fileExists(atPath: certURL.path) else {
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
                            certificatePath: certURL.path,
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
                    guard let tempCertURL = copyFileToTempDirectory(from: certURL) else {
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
                
                // 创建新的文件名（添加sign_前缀）
                let originalFileName = mobileConfigURL.lastPathComponent
                let signedFileName = "sign_" + originalFileName
                let signedFileURL = mobileConfigURL.deletingLastPathComponent().appendingPathComponent(signedFileName)
                
                // 保存签名后的文件
                try signedData.write(to: signedFileURL)
                
                // 更新 UI
                DispatchQueue.main.async {
                    isSigning = false
                    status = "签名成功！文件已保存为: \(signedFileName)"
                    isStatusError = false
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
