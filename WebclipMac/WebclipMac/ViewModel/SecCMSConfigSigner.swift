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
        
        do {
            // 调用Objective-C桥接方法进行签名 - 使用Swift throws语法
            
            let signedData = try CMSHelper.sign(data, withP12Data: p12Data, password: password)
            return signedData
        } catch let error as NSError {
            // 转换Objective-C错误到我们的自定义错误类型
            switch error.code {
            case 1000: // CMSHelperErrorCodeIdentityLoadFailed
                throw SigningError.identityLoadFailed(error.code, error.localizedDescription)
            case 1001: // CMSHelperErrorCodeEncoderCreationFailed
                throw SigningError.encoderCreationFailed
            case 1002: // CMSHelperErrorCodeFailedToAddSigner
                throw SigningError.failedToAddSigner(error.code)
            case 1003: // CMSHelperErrorCodeFailedToUpdateContent
                throw SigningError.failedToUpdateContent(error.code)
            case 1004: // CMSHelperErrorCodeFailedToEncodeContent
                throw SigningError.failedToEncodeContent(error.code)
            case 1005: // CMSHelperErrorCodeCertificateImportFailed
                throw SigningError.certificateImportFailed(error.code)
            case 1006: // CMSHelperErrorCodeIdentityCreationFailed
                throw SigningError.identityCreationFailed
            case 1007: // CMSHelperErrorCodeInvalidPassword
                throw SigningError.invalidPassword
            case 1008: // CMSHelperErrorCodeInvalidData
                throw SigningError.invalidData
            default:
                throw SigningError.unknown(error)
            }
        }
    }
    
    /// 检查签名是否可用
    /// - Returns: 签名是否可用
    public static func isSigningAvailable() -> Bool {
        return CMSHelper.isSigningAvailable()
    }
}
