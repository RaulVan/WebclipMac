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
    let expirationDate: Date?
    let notBeforeDate: Date?
    let issuerName: String?
    let certificateType: String
    let isExpired: Bool
    let daysUntilExpiration: Int?
    
    // 格式化的到期时间字符串
    var expirationDateString: String {
        guard let date = expirationDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // 简短的到期时间字符串（用于下拉列表）
    var shortExpirationString: String {
        guard let date = expirationDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // 签发时间字符串
    var notBeforeDateString: String {
        guard let date = notBeforeDate else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // 到期信息描述
    var expirationInfo: String {
        if let date = expirationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            formatter.timeZone = TimeZone.current
            if isExpired {
                return "已于 \(formatter.string(from: date)) 过期"
            } else if let days = daysUntilExpiration {
                if days <= 30 {
                    return "\(days)天后过期"
                }
                return "到期: \(formatter.string(from: date))"
            }
            return "到期: \(formatter.string(from: date))"
        }
        return ""
    }
    
    // 到期状态描述
    var expirationStatus: String {
        if isExpired {
            return "已过期"
        }
        guard let days = daysUntilExpiration else { return "" }
        if days <= 30 {
            return "即将过期(\(days)天)"
        }
        return ""
    }
    
    // 显示名称（包含到期日期）
    var displayName: String {
        if isExpired {
            return "\(name) [已过期:\(shortExpirationString)]"
        }
        // 显示证书名称 + 到期日期
        return "\(name) [\(shortExpirationString)]"
    }
    
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
    
    // UserDefaults key，用于保存上次使用的证书名称
    private static let lastUsedCertificateKey = "lastUsedCertificateName"
    
    init() {
        loadSystemCertificates()
    }
    
    // 加载系统钥匙串中的代码签名证书
    func loadSystemCertificates() {
        availableCertificates = getSystemDeveloperCertificates()
    }
    
    // MARK: - 证书记忆功能
    
    // 保存上次使用的证书名称
    func saveLastUsedCertificate(_ certificate: CertificateInfo) {
        UserDefaults.standard.set(certificate.name, forKey: Self.lastUsedCertificateKey)
        print("已保存上次使用的证书: \(certificate.name)")
    }
    
    // 获取上次使用的证书（如果仍然存在）
    func getLastUsedCertificate() -> CertificateInfo? {
        guard let savedName = UserDefaults.standard.string(forKey: Self.lastUsedCertificateKey) else {
            print("没有保存的上次使用证书记录")
            return nil
        }
        
        // 在当前可用证书列表中查找
        if let certificate = availableCertificates.first(where: { $0.name == savedName }) {
            print("找到上次使用的证书: \(savedName)")
            return certificate
        }
        
        print("上次使用的证书已不存在: \(savedName)")
        return nil
    }
    
    // 清除上次使用的证书记录
    func clearLastUsedCertificate() {
        UserDefaults.standard.removeObject(forKey: Self.lastUsedCertificateKey)
        print("已清除上次使用的证书记录")
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
        
        // 按到期时间排序，未过期的在前，过期的在后
        return certificates.sorted { cert1, cert2 in
            // 未过期的排在前面
            if cert1.isExpired != cert2.isExpired {
                return !cert1.isExpired
            }
            // 同样状态的按到期时间排序
            if let date1 = cert1.expirationDate, let date2 = cert2.expirationDate {
                return date1 < date2
            }
            return cert1.name < cert2.name
        }
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
        
        // 获取证书的主题名称（使用 SecCertificateCopySubjectSummary）
        let subjectName = SecCertificateCopySubjectSummary(cert) as String? ?? commonName
        
        // 获取证书到期时间
        let expirationDate = getExpirationDate(from: cert)
        
        // 获取证书签发时间
        let notBeforeDate = getNotBeforeDate(from: cert)
        
        // 获取颁发机构
        let issuerName = getIssuerName(from: cert)
        
        // 调试输出
        print("=== 证书信息 ===")
        print("📜 名称: \(subjectName)")
        if let issuer = issuerName {
            print("🏢 颁发机构: \(issuer)")
        }
        if let notBefore = notBeforeDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.current
            print("🕓 签发日期: \(formatter.string(from: notBefore))")
        }
        if let expDate = expirationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.current
            print("⏰ 到期日期: \(formatter.string(from: expDate))")
        } else {
            print("⏰ 到期日期: 未能获取")
        }
        
        // 计算是否过期和剩余天数
        let isExpired: Bool
        let daysUntilExpiration: Int?
        
        if let expDate = expirationDate {
            let now = Date()
            isExpired = expDate < now
            if !isExpired {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: now, to: expDate)
                daysUntilExpiration = components.day
                print("📅 剩余有效期: \(daysUntilExpiration ?? 0) 天")
                if let days = daysUntilExpiration, days < 30 {
                    print("⚠️ 证书即将过期！请尽快更新。")
                }
            } else {
                daysUntilExpiration = nil
                print("❌ 状态: 已过期")
            }
        } else {
            isExpired = false
            daysUntilExpiration = nil
        }
        print("===============================")
        
        // 获取证书类型
        let certType = getCertificateType(subjectName)
        
        return CertificateInfo(
            name: subjectName,
            identity: identity,
            commonName: commonName,
            expirationDate: expirationDate,
            notBeforeDate: notBeforeDate,
            issuerName: issuerName,
            certificateType: certType,
            isExpired: isExpired,
            daysUntilExpiration: daysUntilExpiration
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
    
    
    // 从证书属性字典中提取日期值（处理 Date、Double、NSNumber 多种类型）
    private func extractDate(from values: [String: Any], key: CFString) -> Date? {
        guard let dict = values[key as String] as? [String: Any],
              let value = dict[kSecPropertyKeyValue as String] else {
            return nil
        }
        
        // 处理多种可能的日期类型
        if let date = value as? Date {
            return date
        } else if let timeInterval = value as? Double {
            // macOS 有时返回自 2001-01-01 起的秒数
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        } else if let timeInterval = value as? NSNumber {
            return Date(timeIntervalSinceReferenceDate: timeInterval.doubleValue)
        }
        return nil
    }
    
    // 获取证书的到期时间
    private func getExpirationDate(from certificate: SecCertificate) -> Date? {
        // 获取指定的证书属性
        let keys = [
            kSecOIDX509V1ValidityNotAfter
        ] as CFArray
        
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any] else {
            print("无法获取证书属性")
            return nil
        }
        
        return extractDate(from: values, key: kSecOIDX509V1ValidityNotAfter)
    }
    
    // 获取证书的签发时间
    private func getNotBeforeDate(from certificate: SecCertificate) -> Date? {
        let keys = [
            kSecOIDX509V1ValidityNotBefore
        ] as CFArray
        
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any] else {
            return nil
        }
        
        return extractDate(from: values, key: kSecOIDX509V1ValidityNotBefore)
    }
    
    // 获取证书的颁发机构
    private func getIssuerName(from certificate: SecCertificate) -> String? {
        let keys = [kSecOIDX509V1IssuerName] as CFArray
        
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any] else {
            return nil
        }
        
        if let issuerDict = values[kSecOIDX509V1IssuerName as String] as? [String: Any],
           let issuerValue = issuerDict[kSecPropertyKeyValue as String] {
            // 颁发机构可能是数组或字符串
            if let issuerArray = issuerValue as? [[String: Any]] {
                // 优先查找 Common Name (OID 2.5.4.3)
                let commonName = issuerArray.first { ($0[kSecPropertyKeyLabel as String] as? String) == "2.5.4.3" }
                if let value = commonName?[kSecPropertyKeyValue as String] as? String {
                    return value
                }
                // 备用：查找包含 "Common Name" 或 "Organization" 的项
                for item in issuerArray {
                    if let label = item[kSecPropertyKeyLabel as String] as? String,
                       let value = item[kSecPropertyKeyValue as String] as? String {
                        if label.contains("Common Name") || label.contains("Organization") || label == "2.5.4.10" {
                            return value
                        }
                    }
                }
                // 如果都没找到，返回第一个值
                if let firstItem = issuerArray.first,
                   let value = firstItem[kSecPropertyKeyValue as String] as? String {
                    return value
                }
            } else if let issuerStr = issuerValue as? String {
                return issuerStr
            }
        }
        
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
        // 检查证书是否已过期
        if certificate.isExpired {
            print("证书 \(certificate.name) 已过期")
            return false
        }
        
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
        details["证书类型"] = certificate.certificateType
        details["到期时间"] = certificate.expirationDateString
        
        if certificate.isExpired {
            details["状态"] = "已过期"
        } else if let days = certificate.daysUntilExpiration {
            details["状态"] = "有效（剩余\(days)天）"
        } else {
            details["状态"] = "有效"
        }
        
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
        
        // 检查证书是否过期
        if certificate.isExpired {
            throw NSError(domain: "CertificateManager", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "证书 \(certificate.name) 已过期，无法用于签名"
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
