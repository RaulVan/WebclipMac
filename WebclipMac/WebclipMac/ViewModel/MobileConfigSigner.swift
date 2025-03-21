//
//  MobileConfigSigner.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import Foundation
import Security

public class MobileConfigSigner {
    public enum SigningError: Error, LocalizedError {
        case certificateLoadFailed
        case signingFailed(String)
        case invalidData
        case invalidPassword
        case tempFileCreationFailed
        case openSSLCommandFailed(Int32, String)
        case openSSLNotFound
        case directoryAccessDenied
        
        public var errorDescription: String? {
            switch self {
            case .certificateLoadFailed:
                return "无法加载证书文件"
            case .signingFailed(let reason):
                return "签名失败: \(reason)"
            case .invalidData:
                return "无效的数据"
            case .invalidPassword:
                return "证书密码不正确"
            case .tempFileCreationFailed:
                return "创建临时文件失败"
            case .openSSLCommandFailed(let code, let message):
                return "OpenSSL命令失败(代码: \(code)): \(message)"
            case .openSSLNotFound:
                return "未找到OpenSSL，请确保系统已安装"
            case .directoryAccessDenied:
                return "无法访问临时目录，权限被拒绝"
            }
        }
    }
    
    // 验证OpenSSL是否可用
    static private func verifyOpenSSLAvailability() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "which openssl"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                throw SigningError.openSSLNotFound
            }
        } catch {
            throw SigningError.openSSLNotFound
        }
    }
    
    // 使用 OpenSSL 签名 - 参考 TypeScript 的实现方式
    static public func sign(data: Data, certificatePath: String, password: String) throws -> Data {
        print("开始签名过程...")
        
        // 首先验证 OpenSSL 是否可用
        do {
            try verifyOpenSSLAvailability()
        } catch {
            print("OpenSSL 验证失败: \(error.localizedDescription)")
            throw error
        }
        
        // 使用系统临时目录，确保有正确的权限
        let fileManager = FileManager.default
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("webclip_temp_\(UUID().uuidString)")
        
        print("将使用系统临时目录: \(tempDirectory.path)")
        print("当前进程用户ID: \(getuid()), 有效用户ID: \(geteuid())")
        print("临时目录权限: \(try? fileManager.attributesOfItem(atPath: NSTemporaryDirectory()))")
        
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            print("临时目录创建成功: \(tempDirectory.path)")
            
            // 检查目录是否真的存在
            if !fileManager.fileExists(atPath: tempDirectory.path) {
                print("临时目录不存在，虽然创建操作没有报错")
                throw SigningError.tempFileCreationFailed
            }
            
            // 检查目录权限
            if !fileManager.isWritableFile(atPath: tempDirectory.path) {
                print("临时目录权限不足，无法写入")
                throw SigningError.directoryAccessDenied
            }
            
            print("临时目录权限检查通过，可以写入")
        } catch {
            print("创建临时目录失败: \(error.localizedDescription)")
            throw SigningError.tempFileCreationFailed
        }
        
        // 创建临时文件
        let unsignedPath = tempDirectory.appendingPathComponent("unsigned.mobileconfig")
        let signedPath = tempDirectory.appendingPathComponent("signed.mobileconfig")
        let certPath = tempDirectory.appendingPathComponent("cert.pem")
        let keyPath = tempDirectory.appendingPathComponent("key.pem")
        
        // 测试文件创建
        do {
            let testFile = tempDirectory.appendingPathComponent("test.txt")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            print("测试文件创建成功: \(testFile.path)")
            try fileManager.removeItem(at: testFile)
        } catch {
            print("测试文件创建失败: \(error.localizedDescription)")
            throw SigningError.directoryAccessDenied
        }
        
        // 写入未签名的数据
        do {
            try data.write(to: unsignedPath)
            print("写入未签名数据到: \(unsignedPath.path)")
        } catch {
            print("写入未签名数据失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("无法写入临时文件: \(error.localizedDescription)")
        }
        
        // 确认证书文件存在
        if !fileManager.fileExists(atPath: certificatePath) {
            print("证书文件不存在: \(certificatePath)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.certificateLoadFailed
        }
        
        // 步骤1: 从P12文件提取证书
        print("从P12文件提取证书...")
        let extractCertCommand = """
        /usr/bin/openssl pkcs12 -in "\(certificatePath)" -clcerts -nokeys -out "\(certPath.path)" -passin pass:"\(password.replacingOccurrences(of: "\"", with: "\\\""))"
        """
        
        print("执行提取证书命令...")
        
        do {
            let exitCode = try runCommand(extractCertCommand)
            if exitCode != 0 {
                print("提取证书失败，返回代码: \(exitCode)")
                throw SigningError.signingFailed("无法提取证书，返回代码: \(exitCode)")
            }
            
            // 检查证书文件是否成功创建
            if !fileManager.fileExists(atPath: certPath.path) {
                print("证书文件不存在: \(certPath.path)")
                throw SigningError.signingFailed("提取证书后文件不存在")
            }
            
            print("证书提取成功: \(certPath.path)")
        } catch let error as SigningError {
            try? fileManager.removeItem(at: tempDirectory)
            throw error
        } catch {
            print("提取证书命令失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("提取证书命令执行失败: \(error.localizedDescription)")
        }
        
        // 步骤2: 从P12文件提取私钥
        print("从P12文件提取私钥...")
        let extractKeyCommand = """
        /usr/bin/openssl pkcs12 -in "\(certificatePath)" -nocerts -nodes -out "\(keyPath.path)" -passin pass:"\(password.replacingOccurrences(of: "\"", with: "\\\""))"
        """
        
        print("执行提取私钥命令...")
        
        do {
            let exitCode = try runCommand(extractKeyCommand)
            if exitCode != 0 {
                print("提取私钥失败，返回代码: \(exitCode)")
                throw SigningError.signingFailed("无法提取私钥，返回代码: \(exitCode)")
            }
            
            // 检查私钥文件是否成功创建
            if !fileManager.fileExists(atPath: keyPath.path) {
                print("私钥文件不存在: \(keyPath.path)")
                throw SigningError.signingFailed("提取私钥后文件不存在")
            }
            
            print("私钥提取成功: \(keyPath.path)")
        } catch let error as SigningError {
            try? fileManager.removeItem(at: tempDirectory)
            throw error
        } catch {
            print("提取私钥命令失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("提取私钥命令执行失败: \(error.localizedDescription)")
        }
        
        // 步骤3: 使用提取的证书和私钥签名
        print("使用提取的证书和私钥进行签名...")
        let signCommand = """
        /usr/bin/openssl smime -sign -in "\(unsignedPath.path)" -out "\(signedPath.path)" \
        -signer "\(certPath.path)" -inkey "\(keyPath.path)" \
        -outform der -nodetach -binary
        -md sha256
        """
        
        print("执行签名命令: \(signCommand)")
        
        do {
            let exitCode = try runCommand(signCommand)
            if exitCode != 0 {
                print("签名失败，返回代码: \(exitCode)")
                throw SigningError.signingFailed("签名过程失败，返回代码: \(exitCode)")
            }
        } catch let error as SigningError {
            try? fileManager.removeItem(at: tempDirectory)
            throw error
        } catch {
            print("签名命令失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("签名命令执行失败: \(error.localizedDescription)")
        }
        
        // 读取签名后的文件
        if !fileManager.fileExists(atPath: signedPath.path) {
            print("签名失败: 输出文件不存在")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("输出文件不存在")
        }
        
        do {
            let signedData = try Data(contentsOf: signedPath)
            print("成功读取签名后的数据，大小: \(signedData.count) bytes")
            
            // 清理临时文件
            try? fileManager.removeItem(at: tempDirectory)
            
            return signedData
        } catch {
            print("读取签名后的数据失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempDirectory)
            throw SigningError.signingFailed("无法读取签名后的文件: \(error.localizedDescription)")
        }
    }
    
    // 辅助方法：运行命令并返回退出代码
    static private func runCommand(_ command: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        // 捕获输出和错误
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // 始终捕获并记录输出和错误
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            if !output.isEmpty {
                print("命令输出: \(output)")
            }
            
            if !errorOutput.isEmpty {
                print("命令错误: \(errorOutput)")
            }
            
            // 如果出现错误
            if process.terminationStatus != 0 {
                // 检查是否是密码错误
                if errorOutput.contains("bad decrypt") || 
                   errorOutput.contains("wrong password") || 
                   errorOutput.contains("Mac verify error") {
                    throw SigningError.invalidPassword
                }
                
                throw SigningError.openSSLCommandFailed(process.terminationStatus, errorOutput)
            }
            
            return process.terminationStatus
        } catch let error as SigningError {
            throw error
        } catch {
            print("执行命令过程中出错: \(error.localizedDescription)")
            throw SigningError.openSSLCommandFailed(-1, "执行命令过程中出错: \(error.localizedDescription)")
        }
    }
    
    // 检查签名是否有效
    static public func isSignatureValid(data: Data) -> Bool {
        // 使用系统临时目录
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("webclip_verify_\(UUID().uuidString).mobileconfig")
        
        do {
            // 写入数据
            try data.write(to: tempFile)
            
            // 运行 OpenSSL 验证
            let command = "/usr/bin/openssl cms -verify -in \"\(tempFile.path)\" -inform der -noverify"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            
            // 捕获输出
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            // 清理
            try? FileManager.default.removeItem(at: tempFile)
            
            // 检查结果
            return process.terminationStatus == 0
        } catch {
            print("验证签名时出错: \(error.localizedDescription)")
            // 尝试清理
            try? FileManager.default.removeItem(at: tempFile)
            return false
        }
    }
}