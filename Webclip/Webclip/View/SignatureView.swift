//
//  SignatureView.swift
//  Webclip
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct SignatureView: View {
    // 添加coordinator
    @ObservedObject var coordinator: AppCoordinator
    
    @State private var mobileConfigFile: URL?
    @State private var status: String = "选择要签名的文件"
    @State private var isStatusError: Bool = false
    @State private var isSigning: Bool = false
    
    // 系统证书相关
    @StateObject private var certificateManager = CertificateManager()
    @State private var selectedSystemCertificate: CertificateInfo?
    
    var isFormValid: Bool {
        guard mobileConfigFile != nil && !isSigning else { return false }
        return selectedSystemCertificate != nil
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
                                                Text(cert.name)
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
                        
                        // 签名方法说明
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("使用原生签名 API")
                                    .fontWeight(.medium)
                            }
                            Text("使用 Apple 原生 API 进行签名，更加稳定和可靠")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    private func signMobileConfigFile() {
        guard let mobileConfigURL = mobileConfigFile,
              let systemCert = selectedSystemCertificate else { return }
        
        signWithSystemCertificate(mobileConfigURL, certificate: systemCert)
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
}

struct SignatureView_Previews: PreviewProvider {
    static var previews: some View {
        SignatureView(coordinator: AppCoordinator())
    }
} 
