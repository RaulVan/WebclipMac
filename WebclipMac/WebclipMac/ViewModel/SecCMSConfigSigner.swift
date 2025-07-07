//
//  SecCMSConfigSigner.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import Foundation

/// 使用 SecCMS API 对 mobileconfig 文件进行签名的类
public class SecCMSConfigSigner {
    
    /// 签名相关错误
    public enum SigningError: Error, LocalizedError {
        case identityLoadFailed(Int, String)
        case encoderCreationFailed
        case failedToAddSigner(Int)
        case failedToUpdateContent(Int)
        case failedToEncodeContent(Int)
        case certificateImportFailed(Int)
        case identityCreationFailed
        case p12FileNotFound
        case invalidPassword
        case invalidData
        case unknown(Error)
        
        public var errorDescription: String? {
            switch self {
            case .identityLoadFailed(let status, let message):
                return "无法加载证书身份: \(message) (代码: \(status))"
            case .encoderCreationFailed:
                return "无法创建CMS签名编码器"
            case .failedToAddSigner(let status):
                return "添加签名者失败 (代码: \(status))"
            case .failedToUpdateContent(let status):
                return "更新签名内容失败 (代码: \(status))"
            case .failedToEncodeContent(let status):
                return "编码签名内容失败 (代码: \(status))"
            case .certificateImportFailed(let status):
                return "导入证书失败 (代码: \(status))"
            case .identityCreationFailed:
                return "无法创建身份标识"
            case .p12FileNotFound:
                return "未找到p12/pfx证书文件"
            case .invalidPassword:
                return "证书密码不正确"
            case .invalidData:
                return "无效的数据"
            case .unknown(let error):
                return "未知错误: \(error.localizedDescription)"
            }
        }
    }
    
    /// 使用p12证书签名mobileconfig文件
    /// - Parameters:
    ///   - data: 要签名的mobileconfig数据
    ///   - certificatePath: p12/pfx证书文件路径
    ///   - password: 证书密码
    /// - Returns: 签名后的数据
    public static func sign(data: Data, certificatePath: String, password: String) throws -> Data {
        let fileManager = FileManager.default
        
        // 检查证书文件是否存在
        guard fileManager.fileExists(atPath: certificatePath) else {
            throw SigningError.p12FileNotFound
        }
        
        // 读取证书文件数据
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)) else {
            throw SigningError.invalidData
        }
        
        // 调用Objective-C桥接方法进行签名
        // 使用Swift简化的方法名，CMSHelper内部会处理详细错误
        guard let signedData = CMSHelper.sign(data, withP12Data: p12Data, password: password) else {
            // 简化错误处理，实际错误信息已在CMSHelper中打印到控制台
            throw SigningError.unknown(NSError(domain: "SecCMSConfigSigner", code: -1, userInfo: [NSLocalizedDescriptionKey: "CMS签名失败，请检查证书文件和密码"]))
        }
        
        return signedData
    }
    
    /// 检查签名是否可用
    /// - Returns: 签名是否可用
    public static func isSigningAvailable() -> Bool {
        return CMSHelper.isSigningAvailable()
    }
}
