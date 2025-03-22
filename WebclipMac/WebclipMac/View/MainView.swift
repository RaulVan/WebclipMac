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
            // 顶部标签栏
            HStack(spacing: 0) {
                tabButton(title: "创建Web Clip", isSelected: coordinator.selectedTab == .create) {
                    coordinator.selectedTab = .create
                }
                
                tabButton(title: "签名", isSelected: coordinator.selectedTab == .signature) {
                    coordinator.selectedTab = .signature
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .background(Color(.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .bottom
            )
            
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
    
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 
