# WebClip Mobileconfig 生成器

一个简单易用的 macOS 原生应用程序，用于创建和签名 iOS/iPadOS 设备上的 WebClip 配置文件（.mobileconfig）。

## 功能特点

- 通过简单的表单界面创建 WebClip 配置文件
- 自定义应用名称、URL、图标和行为选项
- 支持图标拖拽导入和选择
- 智能图片处理：自动裁剪、缩放和压缩
- 一键生成并签名配置文件
- 使用系统钥匙串中的 Apple 开发者证书进行签名
- 高级设置根据应用名称自动生成中英文内容
- 简洁易用的 SwiftUI 原生界面
- 支持本地保存 mobileconfig 文件

## 什么是 WebClip？

WebClip 是一种将网页添加到 iOS/iPadOS 设备主屏幕的方式，使网页看起来和行为类似于原生应用程序。通过配置文件（.mobileconfig）可以实现一键安装 WebClip，提供比手动"添加到主屏幕"更丰富的选项。

## 使用方法

### 创建 WebClip

1. 打开应用，进入"创建 Web Clip"页面
2. 填写应用名称和目标网站 URL
3. 选择或拖拽一个图标文件（支持 PNG、JPG 格式，任意尺寸）
   - 图片会自动裁剪为正方形并缩放至 256x256
   - 自动移除透明度，压缩至 800KB 以内
4. 设置是否可移除和全屏模式选项
5. 配置证书签名（可选）：
   - 启用"证书签名"开关
   - 从系统钥匙串中选择 Apple 开发者证书
6. 可以展开高级设置，自定义组织名称、描述和同意信息
   - 留空将根据应用名称语言（中文/英文）自动生成
7. 点击"生成 WebClip"或"生成并签名 WebClip"按钮
8. 选择保存位置，完成文件创建

### 为现有配置文件签名

1. 切换到"签名"标签页
2. 选择要签名的 .mobileconfig 文件
3. 从系统钥匙串中选择 Apple 开发者证书
4. 点击"签名"按钮
5. 选择保存位置，完成签名文件创建

## 技术实现

- 使用 SwiftUI 构建现代化 macOS 应用界面
- 基于 MVVM 架构设计
- 原生支持图像处理：自动裁剪、缩放、移除透明度、压缩
- 使用 Apple 原生 Security 框架进行证书签名
- 使用 Apple 配置描述文件规范生成标准 mobileconfig 文件

## 系统要求

- macOS 12.0+ (Monterey 或更高版本)
- 支持 Apple Silicon 和 Intel 芯片

## 注意事项

- 签名需要在系统钥匙串中安装有效的 Apple 开发者证书
- 签名后的配置文件可以通过电子邮件、网站或 MDM 分发给用户
- 用户需要在 iOS/iPadOS 设备上手动安装并信任配置文件

## 隐私说明

本应用完全在本地运行，不会上传或存储您的数据。签名使用系统钥匙串中的证书，无需导入或存储证书文件。

---

# WebClip Mobileconfig Generator

A simple and easy-to-use macOS native application for creating and signing WebClip configuration files (.mobileconfig) for iOS/iPadOS devices.

## Features

- Create WebClip configuration files through a simple form interface
- Customize app name, URL, icon, and behavior options
- Support for icon drag-and-drop import and selection
- Smart image processing: automatic cropping, resizing, and compression
- One-click generation and signing of configuration files
- Sign using Apple developer certificates from system keychain
- Advanced settings auto-generate content based on app name language (Chinese/English)
- Clean and user-friendly native SwiftUI interface
- Support for local saving of mobileconfig files

## What is WebClip?

WebClip is a way to add web pages to the home screen of iOS/iPadOS devices, making websites look and behave similar to native applications. Configuration profiles (.mobileconfig) enable one-click installation of WebClips, offering more options than the manual "Add to Home Screen" method.

## Usage Instructions

### Creating a WebClip

1. Open the application and go to the "Create Web Clip" page
2. Enter the app name and target website URL
3. Select or drag and drop an icon file (PNG, JPG formats supported, any size)
   - Images are automatically cropped to square and resized to 256x256
   - Transparency is removed and compressed to under 800KB
4. Set removable and full-screen mode options
5. Configure certificate signing (optional):
   - Enable the "Certificate Signing" toggle
   - Select an Apple developer certificate from the system keychain
6. Expand advanced settings to customize organization name, description, and consent text
   - Leave blank to auto-generate based on app name language (Chinese/English)
7. Click "Generate WebClip" or "Generate and Sign WebClip" button
8. Choose a save location to complete file creation

### Signing Existing Configuration Files

1. Switch to the "Signature" tab
2. Select the .mobileconfig file to sign
3. Choose an Apple developer certificate from the system keychain
4. Click the "Sign" button
5. Choose a save location to complete the signed file creation

## Technical Implementation

- Built with SwiftUI for a modern macOS application interface
- Designed based on MVVM architecture
- Native image processing: automatic cropping, resizing, transparency removal, compression
- Uses Apple native Security framework for certificate signing
- Generates standard mobileconfig files according to Apple configuration profile specifications

## System Requirements

- macOS 12.0+ (Monterey or later)
- Supports both Apple Silicon and Intel chips

## Notes

- Signing requires a valid Apple developer certificate installed in the system keychain
- Signed configuration profiles can be distributed to users via email, websites, or MDM
- Users need to manually install and trust the configuration profile on their iOS/iPadOS devices

## Privacy Statement

This application runs entirely locally and does not upload or store your data. Signing uses certificates from the system keychain, eliminating the need to import or store certificate files.
