//
//  WebclipApp.swift
//  Webclip
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI
import AppKit

@main
struct WebclipApp: App {
    
    init() {
        // 应用启动时清理过期的临时文件
        MobileConfigSigner.cleanupTempFiles()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
//                .frame(width: 800, height: 600)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(width: 400, height: 1000)
        .windowResizability(.contentSize)
    }
}
