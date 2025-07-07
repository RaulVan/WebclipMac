//
//  MainView.swift
//  WebclipMac
//
//  Created by Guck on 2025/3/21.
//

import SwiftUI

struct MainView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部分段控件
            VStack(spacing: 0) {
                HStack {
                    Picker("", selection: $coordinator.selectedTab) {
                        Text("创建Web Clip").tag(AppCoordinator.Tab.create)
                        Text("签名").tag(AppCoordinator.Tab.signature)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden() // 隐藏标签
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.controlBackgroundColor))
                
                // 分隔线
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
            }
            
            // 内容区域
            ZStack {
                if coordinator.selectedTab == .create {
                    ContentView(coordinator: coordinator)
                        .transition(.opacity)
                } else {
                    SignatureView(coordinator: coordinator)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: coordinator.selectedTab)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 
