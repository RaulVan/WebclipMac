//
//  WebClipModel.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import Foundation
import AppKit

public class WebClipConfiguration {
    var appName: String
    var url: String
    var icon: NSImage?
    var isRemovable: Bool
    var isFullScreen: Bool
    
    // 组织信息
    var organizationName: String
    var description: String
    var consentText: String
    
    // 初始化方法
    public init(appName: String, url: String, icon: NSImage?, isRemovable: Bool, isFullScreen: Bool, 
         organizationName: String = "WebClip Generator", description: String = "", consentText: String = "") {
        self.appName = appName
        self.url = url
        self.icon = icon
        self.isRemovable = isRemovable
        self.isFullScreen = isFullScreen
        self.organizationName = organizationName
        self.description = description
        self.consentText = consentText
    }
    
    // 生成唯一标识符
    static func generateUUID() -> String {
        return UUID().uuidString
    }
    
    // 转换图像为Base64字符串
    func iconToBase64() -> String? {
        guard let icon = icon else { return nil }
        
        // 转换 NSImage 为 Data
        guard let tiffData = icon.tiffRepresentation else { return nil }
        let bitmap = NSBitmapImageRep(data: tiffData)
        guard let pngData = bitmap?.representation(using: .png, properties: [:]) else { return nil }
        
        return pngData.base64EncodedString()
    }
    
    // 生成 mobileconfig 数据
    func generateMobileConfigData() -> Data? {
        // 这里将实现实际的 mobileconfig 文件生成逻辑
        // 暂时返回空数据
        return Data()
    }
}
