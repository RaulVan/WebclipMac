//
//  WebclipMacApp.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI

@main
struct WebclipMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 650, minHeight: 700)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}