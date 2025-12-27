//
//  CertificateManager.swift
//  Webclip
//
//  Created by Guck on 2025/3/21.
//

import Foundation
import Security
import CoreFoundation

// 证书信息结构
struct CertificateInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let identity: SecIdentity
    let commonName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(commonName)
    }
    
    static func == (lhs: CertificateInfo, rhs: CertificateInfo) -> Bool {
        return lhs.name == rhs.name && lhs.commonName == rhs.commonName
    }
}

class CertificateManager: ObservableObject {
    @Published var availableCertificates: [CertificateInfo] = []
    
    init() {
        loadSystemCertificates()
    }
    
    // 加载系统钥匙串中的代码签名证书
    func loadSystemCertificates() {
        availableCertificates = getSystemDeveloperCertificates()
    }
    
    // 获取系统中的Apple开发者证书
    private func getSystemDeveloperCertificates() -> [CertificateInfo] {
        var certificates: [CertificateInfo] = []
        
        // 查询钥匙串中的身份标识（证书+私钥对）
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let identities = result as? [SecIdentity] else {
            return certificates
        }
        
        for identity in identities {
            if let certInfo = extractCertificateInfo(from: identity) {
                // 过滤出Apple开发者证书
                if isAppleDeveloperCertificate(certInfo.name) {
                    certificates.append(certInfo)
                }
            }
        }
        
        return certificates.sorted { $0.name < $1.name }
    }
    
    // 从SecIdentity中提取证书信息
    private func extractCertificateInfo(from identity: SecIdentity) -> CertificateInfo? {
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        
        guard status == errSecSuccess, let cert = certificate else {
            return nil
        }
        
        // 获取证书的通用名称
        guard let commonName = getCommonName(from: cert) else {
            return nil
        }
        
        // 获取证书的主题名称
        let subjectName = getSubjectName(from: cert) ?? commonName
        
        return CertificateInfo(
            name: subjectName,
            identity: identity,
            commonName: commonName
        )
    }
    
    // 获取证书的通用名称
    private func getCommonName(from certificate: SecCertificate) -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)
        
        guard status == errSecSuccess, let name = commonName else {
            return nil
        }
        
        return name as String
    }
    
    // 获取证书的主题名称
    private func getSubjectName(from certificate: SecCertificate) -> String? {
        // 为了简化实现，暂时返回nil，让调用方使用CommonName
        // 如果需要完整的主题名称，可以使用SecCertificateCopySubjectSummary等API
        return nil
    }
    
    // 判断是否为Apple开发者证书
    private func isAppleDeveloperCertificate(_ name: String) -> Bool {
        let appleDeveloperPatterns = [
            "Apple Development:",
            "Apple Distribution:",
            "Developer ID Application:",
            "Developer ID Installer:",
            "Mac Developer:",
            "iPhone Developer:",
            "iPhone Distribution:",
            "iOS Developer:",
            "iOS Distribution:"
        ]
        
        return appleDeveloperPatterns.contains { pattern in
            name.contains(pattern)
        }
    }
    
    // 检查证书是否可用于签名
    func validateCertificateForSigning(_ certificate: CertificateInfo) -> Bool {
        // 检查身份标识是否包含私钥
        var privateKey: SecKey?
        let status = SecIdentityCopyPrivateKey(certificate.identity, &privateKey)
        
        if status != errSecSuccess || privateKey == nil {
            print("证书 \(certificate.name) 没有关联的私钥，状态码: \(status)")
            return false
        }
        
        // 检查证书是否有效
        var cert: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(certificate.identity, &cert)
        
        if certStatus != errSecSuccess || cert == nil {
            print("证书 \(certificate.name) 无法获取证书信息")
            return false
        }
        
        print("证书 \(certificate.name) 验证通过，可以用于签名")
        return true
    }
    
    // 获取证书的详细信息
    func getCertificateDetails(_ certificate: CertificateInfo) -> [String: String] {
        var details: [String: String] = [:]
        
        // 获取证书
        var cert: SecCertificate?
        let status = SecIdentityCopyCertificate(certificate.identity, &cert)
        
        guard status == errSecSuccess, let _ = cert else {
            return details
        }
        
        // 基本信息
        details["通用名称"] = certificate.commonName
        details["证书类型"] = getCertificateType(certificate.name)
        
        // 可以添加更多详细信息，如有效期、颁发者等
        
        return details
    }
    
    // 获取证书类型
    private func getCertificateType(_ name: String) -> String {
        if name.contains("Apple Development") {
            return "Apple开发证书"
        } else if name.contains("Apple Distribution") {
            return "Apple分发证书"
        } else if name.contains("Developer ID Application") {
            return "Developer ID应用证书"
        } else if name.contains("Developer ID Installer") {
            return "Developer ID安装包证书"
        } else if name.contains("Mac Developer") {
            return "Mac开发证书"
        } else if name.contains("iPhone Developer") || name.contains("iOS Developer") {
            return "iOS开发证书"
        } else if name.contains("iPhone Distribution") || name.contains("iOS Distribution") {
            return "iOS分发证书"
        } else {
            return "Apple证书"
        }
    }
    
    // 使用系统证书进行签名
    func signWithSystemCertificate(_ data: Data, using certificate: CertificateInfo) throws -> Data {
        // 参数验证
        guard !data.isEmpty else {
            throw NSError(domain: "CertificateManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "签名数据不能为空"
            ])
        }
        
        // 验证证书是否可用于签名
        guard validateCertificateForSigning(certificate) else {
            throw NSError(domain: "CertificateManager", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "证书 \(certificate.name) 不可用于签名，请检查是否包含私钥"
            ])
        }
        
        print("开始使用系统证书签名: \(certificate.name)")
        
        // 使用CMSHelper的CMS API进行签名
        // 使用Swift重命名后的方法调用
        guard let signedData = CMSHelper.signData(withCMS: data, identity: certificate.identity) else {
            print("系统证书签名失败: CMS签名过程失败")
            throw NSError(domain: "CertificateManager", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "系统证书签名失败: CMS签名过程失败，请检查证书是否有效"
            ])
        }
        
        print("系统证书签名成功，签名数据大小: \(signedData.count) bytes")
        return signedData
    }
} 
