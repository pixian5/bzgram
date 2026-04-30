# BZGram

第三方 Telegram iOS 客户端，支持无限多账号和内置自动翻译。

## 功能特性

- 🔐 **无限多账号**：支持无限数量的 Telegram 账号同时登录和一键切换
- 🌐 **自动翻译**：全局翻译设置 + 单聊覆盖，内置翻译缓存
- 💬 **完整聊天**：消息收发、编辑、撤回、回复、搜索
- 📱 **联系人管理**：在线状态、按首字母分组
- 🎨 **暗黑模式**：支持系统/浅色/深色三种外观模式
- 🔒 **安全存储**：账号数据 Keychain 加密存储
- ♿ **无障碍**：完整 VoiceOver 支持

## 系统要求

- macOS + Xcode 15 或更高版本
- iOS 16.0+
- Swift 5.9+
- `xcodegen`（可选，用于从 `project.yml` 生成 Xcode 项目）

## 项目结构

```text
BZGram/
  Sources/
    App/           应用入口（BZGramApp.swift）
    Core/
      Models/      数据模型（Account, Chat, Message, Contact, ...）
      Services/    业务逻辑（AccountManager, ChatService, TranslationService, ...）
      ViewModels/  UI 绑定（ChatListVM, ChatVM, AccountListVM, ContactListVM）
    Views/
      Accounts/    账号管理 UI
      Auth/        登录认证 UI
      Chats/       聊天列表和对话 UI
      Contacts/    联系人列表 UI
      Settings/    设置页面（含隐私政策、用户协议）
  Tests/           单元测试
fastlane/          自动化打包配置
.github/workflows/ CI/CD 配置
```

## 快速开始

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/pixian5/bzgram.git
cd bzgram

# 生成 Xcode 项目
brew install xcodegen
xcodegen generate
open BZGram.xcodeproj
```

### 运行测试

```bash
swift test --parallel
```

### 配置 Telegram API

应用支持两种启动模式：

- **Mock 模式**：不配置 API 参数时自动使用演示后端（验证码 `12345`）
- **真实模式**：在 Xcode 的 `BZGram` target 中配置以下 Info.plist 键：
  - `BZGRAM_TELEGRAM_API_ID`
  - `BZGRAM_TELEGRAM_API_HASH`
  - `BZGRAM_TELEGRAM_USE_TEST_DC`（可选）

从 [https://my.telegram.org](https://my.telegram.org) 获取 API 参数。

### 使用 CI 构建产物

1. 从 GitHub Actions 或 Releases 下载 `BZGram-iOS-project-v*.zip`
2. 解压后用 Xcode 打开 `BZGram.xcodeproj`
3. 配置签名后 Archive 导出 IPA

### Fastlane 自动化

```bash
# 安装 Fastlane
gem install fastlane

# 运行测试
bundle exec fastlane ios test

# Debug 构建
bundle exec fastlane ios build_debug

# Release 构建
bundle exec fastlane ios build
```

## 架构

- **MVVM** 架构，Core 层纯 Swift（无 SwiftUI 依赖）
- **多 TDLib 实例**：每个账号拥有独立的 TDLib 数据目录
- **Keychain 安全存储**：敏感数据使用 iOS Keychain 加密
- **翻译缓存**：UserDefaults 持久化，最大 5000 条缓存

## 常规运行方式

如果 Xcode 项目文件缺失，运行 `xcodegen generate` 生成。CI 构建使用模拟器（无需签名证书）。

## 许可

MIT
