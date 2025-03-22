# WebClip Mobileconfig 生成器

一个简单易用的 macOS 原生应用程序，用于创建和签名 iOS/iPadOS 设备上的 WebClip 配置文件（.mobileconfig）。

## 功能特点

- 通过简单的表单界面创建 WebClip 配置文件
- 自定义应用名称、URL、图标和行为选项
- 支持图标拖拽导入和选择
- 支持配置文件证书签名
- 简洁易用的 SwiftUI 原生界面
- 支持本地保存 mobileconfig 文件

## 什么是 WebClip？

WebClip 是一种将网页添加到 iOS/iPadOS 设备主屏幕的方式，使网页看起来和行为类似于原生应用程序。通过配置文件（.mobileconfig）可以实现一键安装 WebClip，提供比手动"添加到主屏幕"更丰富的选项。

## 使用方法

### 创建 WebClip

1. 打开应用，默认显示"创建 Web Clip"标签页
2. 填写应用名称和目标网站 URL
3. 选择或拖拽一个图标文件（支持 PNG、JPG 格式）
4. 设置是否可移除和全屏模式选项
5. 可以展开高级设置，添加组织名称、配置文件描述和同意文本
6. 点击"生成 WebClip"按钮
7. 选择保存位置，完成文件创建

### 为配置文件签名

1. 切换到"签名"标签页
2. 选择要签名的 .mobileconfig 文件
3. 选择 .p12 或 .pfx 格式的证书文件
4. 输入证书密码
5. 点击"签名"按钮
6. 选择保存位置，完成签名文件创建

## 技术实现

- 使用 SwiftUI 构建现代化 macOS 应用界面
- 基于 MVVM 架构设计
- 原生支持图像处理和证书签名
- 使用 Apple 配置描述文件规范生成标准 mobileconfig 文件

## 系统要求

- macOS 12.0+ (Monterey 或更高版本)
- 支持 Apple Silicon 和 Intel 芯片

## 注意事项

- 签名需要有效的开发者证书或 MDM 证书
- 签名后的配置文件可以通过电子邮件、网站或 MDM 分发给用户
- 用户需要在 iOS/iPadOS 设备上手动安装并信任配置文件

## 隐私说明

本应用完全在本地运行，不会上传或存储您的数据和证书信息。证书密码仅临时用于签名过程，不会永久存储。

---

# WebClip Mobileconfig Generator

A simple and easy-to-use macOS native application for creating and signing WebClip configuration files (.mobileconfig) for iOS/iPadOS devices.

## Features

- Create WebClip configuration files through a simple form interface
- Customize app name, URL, icon, and behavior options
- Support for icon drag-and-drop import and selection
- Support for configuration file certificate signing
- Clean and user-friendly native SwiftUI interface
- Support for local saving of mobileconfig files

## What is WebClip?

WebClip is a way to add web pages to the home screen of iOS/iPadOS devices, making websites look and behave similar to native applications. Configuration profiles (.mobileconfig) enable one-click installation of WebClips, offering more options than the manual "Add to Home Screen" method.

## Usage Instructions

### Creating a WebClip

1. Open the application, defaulting to the "Create Web Clip" tab
2. Enter the app name and target website URL
3. Select or drag and drop an icon file (PNG, JPG formats supported)
4. Set removable and full-screen mode options
5. Expand advanced settings to add organization name, profile description, and consent text
6. Click the "Generate WebClip" button
7. Choose a save location to complete file creation

### Signing Configuration Files

1. Switch to the "Signature" tab
2. Select the .mobileconfig file to sign
3. Choose a certificate file in .p12 or .pfx format
4. Enter the certificate password
5. Click the "Sign" button
6. Choose a save location to complete the signed file creation

## Technical Implementation

- Built with SwiftUI for a modern macOS application interface
- Designed based on MVVM architecture
- Native support for image processing and certificate signing
- Generates standard mobileconfig files according to Apple configuration profile specifications

## System Requirements

- macOS 12.0+ (Monterey or later)
- Supports both Apple Silicon and Intel chips

## Notes

- Signing requires a valid developer or MDM certificate
- Signed configuration profiles can be distributed to users via email, websites, or MDM
- Users need to manually install and trust the configuration profile on their iOS/iPadOS devices

## Privacy Statement

This application runs entirely locally and does not upload or store your data or certificate information. Certificate passwords are only temporarily used for the signing process and are not permanently stored. 