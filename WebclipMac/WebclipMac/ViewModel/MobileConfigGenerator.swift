//
//  MobileConfigGenerator.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import Foundation
import AppKit

public class MobileConfigGenerator {
    static public func generateMobileConfig(config: WebClipConfiguration) -> Data? {
        guard let iconBase64 = config.iconToBase64() else {
            return nil
        }
        
        // 生成唯一 UUID
        let webClipUUID = WebClipConfiguration.generateUUID()
        let payloadUUID = WebClipConfiguration.generateUUID()
        
        // 创建标识符 (参考 ts 版本)
        let bundleId = "com.webclip.\(config.appName.lowercased().replacingOccurrences(of: " ", with: ""))"
        
        // 创建 XML 格式的 MobileConfig 文件内容
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>FullScreen</key>
                    <\(config.isFullScreen ? "true" : "false")/>
                    <key>IgnoreManifestScope</key>
                    <true/>
                    <key>Icon</key>
                    <data>\(iconBase64)</data>
                    <key>IsRemovable</key>
                    <\(config.isRemovable ? "true" : "false")/>
                    <key>Label</key>
                    <string>\(config.appName)</string>
                    <key>PayloadDescription</key>
                    <string>Configures Web Clip</string>
                    <key>PayloadDisplayName</key>
                    <string>Web Clip (\(config.appName))</string>
                    <key>PayloadIdentifier</key>
                    <string>\(bundleId).webclip</string>
                    <key>PayloadType</key>
                    <string>com.apple.webClip.managed</string>
                    <key>PayloadUUID</key>
                    <string>\(webClipUUID)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>Precomposed</key>
                    <true/>
                    <key>URL</key>
                    <string>\(config.url)</string>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>\(config.description.isEmpty ? "Install this profile to add \(config.appName) to your Home screen" : config.description)</string>
            <key>PayloadDisplayName</key>
            <string>\(config.appName)</string>
            <key>PayloadIdentifier</key>
            <string>\(bundleId)</string>
            <key>PayloadOrganization</key>
            <string>\(config.organizationName)</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(payloadUUID)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>\(config.consentText.isEmpty ? "" : """

            <key>ConsentText</key>
            <dict>
                <key>default</key>
                <string>\(config.consentText)</string>
            </dict>
            """)
        </dict>
        </plist>
        """
        
        return xmlString.data(using: String.Encoding.utf8)
    }
}
