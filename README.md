# Tonari

iOS 端 ASMR 播放器，按 DLsite 作品（RJ 编号）组织音视频资源。支持本地导入与 115 网盘（扫码登录），音频与视频统一播放，自动抓取 DLsite 元数据，可用 LLM 翻译标题、简介与曲目名。

仅供个人自用。原先的 Flutter 版已归档到 `flutter` 分支（标签 `flutter-final`）。

## 技术栈

- **语言 / 界面**：Swift 6 + SwiftUI（UIKit 补位），iOS 26+
- **数据库**：GRDB（沿用 Flutter 版 Drift schema，备份双向互通）
- **音频**：AVPlayer（锁屏、画中画字幕）
- **视频**：mdk-sdk（外部 Metal 渲染，支持 MKV / HEVC / 10-bit）
- **元数据**：DLsite HTML + AJAX 抓取（SwiftSoup 解析）
- **密钥存储**：Keychain

## 目录

- `native/Tonari.xcodeproj`、`native/Tonari/`：App
- `native/TonariCore/`：纯逻辑 Swift 包（数据库、导入、115、DLsite、字幕、翻译、备份）
- `native/Packages/MDK/`：mdk 二进制与 Swift 封装
- `native/PLAN.md`、`native/PARITY.md`、`native/design/`：排期、功能对照清单、界面示意

## 构建与测试

```bash
cd native/TonariCore && swift test
```

```bash
cd native && xcodebuild -project Tonari.xcodeproj -scheme Tonari -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -allowProvisioningUpdates -quiet build
```

## 分发签名

源码层 Bundle ID 为 `com.leo.tonari.native`（免费证书调试用）。正式包用最小 entitlements 重签 Release 产物，Bundle ID 由描述文件决定。证书材料（`p12` / `mobileprovision` / `证书_*`）不入版本库。

## 文档

- [REQUIREMENTS.md](REQUIREMENTS.md)：需求与设计
- [AGENTS.md](AGENTS.md)：协作约定、构建、装机与签名
