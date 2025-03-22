//
//  AppCoordinator.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/22.
//

import Foundation
import SwiftUI

class AppCoordinator: ObservableObject {
    // 定义标签页枚举
    enum Tab {
        case create
        case signature
    }
    
    // 发布的属性，用于在视图之间共享状态
    @Published var selectedTab: Tab = .create
    @Published var lastGeneratedFile: URL? = nil
    
    // 导航到签名页，并可选择传递文件URL
    func navigateToSignature(with fileURL: URL? = nil) {
        selectedTab = .signature
        lastGeneratedFile = fileURL
    }
}

//
//// 创建一个可观察对象，用于页面间通信
//class AppCoordinator: ObservableObject {
//    @Published var selectedTab: MainView.Tab = .createWebClip
//    @Published var lastGeneratedFile: URL? = nil
//    
//    func navigateToSignature(with fileURL: URL) {
//        lastGeneratedFile = fileURL
//        selectedTab = .signature
//    }
//}
