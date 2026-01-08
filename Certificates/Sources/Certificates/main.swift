import Foundation
import Security

// MARK: - Keychain Query Helper
/// 从钥匙串中获取所有 "iPhone Distribution" 类型的证书
func fetchiPhoneDistributionCertificates() -> [SecCertificate] {
    let query: [String: Any] = [
        kSecClass as String: kSecClassCertificate,
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnRef as String: true
    ]
    
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess, let certificates = result as? [SecCertificate] else {
        print("❌ 无法从钥匙串读取证书: \(status)")
        return []
    }
    
    // 仅筛选 iPhone Distribution 类型证书
    return certificates.filter { cert in
        if let summary = SecCertificateCopySubjectSummary(cert) as String? {
            return summary.contains("iPhone Distribution")
        }
        return false
    }
}

// MARK: - Date Formatting Helper
/// 将日期格式化为字符串
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}

// MARK: - Parse Certificate Info
/// 打印证书的详细信息，包括颁发机构、签发日期和到期日期
func printCertificateDetails(_ cert: SecCertificate) {
    let summary = SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown Certificate"
    print("\n===============================")
    print("📜 证书名称: \(summary)")
    
    // 获取证书所有值
    let keys = [
        kSecOIDX509V1IssuerName,
        kSecOIDX509V1ValidityNotBefore,
        kSecOIDX509V1ValidityNotAfter
    ] as CFArray
    
    guard let values = SecCertificateCopyValues(cert, keys, nil) as? [String: Any] else {
        print("❌ 无法解析证书详细信息。")
        return
    }
    
    // 1. 获取颁发机构 (Issuer)
    if let issuerDict = values[kSecOIDX509V1IssuerName as String] as? [String: Any],
       let issuerSequence = issuerDict[kSecPropertyKeyValue as String] as? [[String: Any]] {
        let commonName = issuerSequence.first { ($0[kSecPropertyKeyLabel as String] as? String) == "2.5.4.3" }
        let issuerLabel = (commonName?[kSecPropertyKeyValue as String] as? String) ?? (issuerSequence.first?[kSecPropertyKeyValue as String] as? String) ?? "Unknown Issuer"
        print("🏢 颁发机构: \(issuerLabel)")
    }
    
    // 2. 获取日期信息 (处理可能的 Double 或 Date 类型)
    func extractDate(from key: CFString) -> Date? {
        guard let dict = values[key as String] as? [String: Any],
              let value = dict[kSecPropertyKeyValue as String] else {
            return nil
        }
        
        if let date = value as? Date {
            return date
        } else if let timeInterval = value as? Double {
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        } else if let timeInterval = value as? NSNumber {
            return Date(timeIntervalSinceReferenceDate: timeInterval.doubleValue)
        }
        return nil
    }
    
    if let notBeforeDate = extractDate(from: kSecOIDX509V1ValidityNotBefore) {
        print("🕓 签发日期: \(formatDate(notBeforeDate))")
    }
    
    if let notAfterDate = extractDate(from: kSecOIDX509V1ValidityNotAfter) {
        print("⏰ 到期日期: \(formatDate(notAfterDate))")
        
        let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: notAfterDate).day ?? 0
        print("📅 剩余有效期: \(remainingDays) 天")
        
        if remainingDays < 30 {
            print("⚠️ 证书即将过期！请尽快更新。")
        }
    } else {
        print("❌ 无法读取有效期信息。")
    }
    
    print("===============================\n")
}

// MARK: - Main Execution
let certificates = fetchiPhoneDistributionCertificates()

if certificates.isEmpty {
    print("未找到任何 'iPhone Distribution' 类型证书。")
} else {
    print("🔍 找到 \(certificates.count) 个 iPhone Distribution 证书：")
    certificates.forEach { printCertificateDetails($0) }
}
