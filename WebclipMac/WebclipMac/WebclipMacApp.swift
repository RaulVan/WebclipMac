//
//  WebclipMacApp.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI
import AppKit

@main
struct WebclipMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(width: 800, height: 600)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
    }
}
