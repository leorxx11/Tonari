# Tonari

iOS 端 ASMR 播放器，按 DLsite 作品（RJ 编号）组织音视频资源。支持本地导入与云端片库（WebDAV 直连、115 网盘扫码登录），音频与视频统一播放，自动抓取 DLsite 元数据。

仅供个人自用。

## 技术栈

- **框架 / 语言**：Flutter 3.x + Dart
- **状态管理**：Riverpod
- **本地数据库**：Drift（SQLite）
- **音频**：just_audio + just_audio_background + audio_session
- **视频**：video_player + fvp（FFmpeg 软解后端，支持 MKV / HEVC / 10-bit）
- **网络**：dio
- **云存储**：WebDAV（dio + xml PROPFIND）、115（cookie 登录，本地 HTTP 代理注入鉴权头给 fvp）
- **元数据**：DLsite HTML + AJAX 抓取（html 包解析）
- **密钥存储**：flutter_secure_storage（iOS Keychain）

## 环境要求

- Flutter SDK（Dart `^3.12.0`）
- Xcode + iOS 15.0 及以上的真机
- 签名证书（免费开发证书调试，或淘宝分发证书发布）

## 构建与运行

```bash
flutter pub get

# Drift 代码生成（生成物 lib/core/db/database.g.dart 已入库，
# 仅在改了表结构后才需要重新生成）
dart run build_runner build --delete-conflicting-outputs

# 静态检查 + 测试
flutter analyze
flutter test

# 真机 release 运行（设备 ID 见 AGENTS.md）
flutter run --release -d <device-id>
```

真机部署若 `flutter run` 报找不到 `.app`，改用纯构建 + devicectl 安装：

```bash
flutter build ios --release
xcrun devicectl device install app --device <coredevice-uuid> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <coredevice-uuid> com.leo.tonari
```

## 分发签名

源码层 Bundle ID 固定为 `com.leo.tonari`（免费证书调试用）。正式分发走最小 entitlements 重签：

```bash
tools/sign-ipa.sh   # 产物 build/ios/iphoneos/tonari-signed.ipa
```

调试版 `com.leo.tonari` 与正式版 `com.wangshaikang` 数据沙盒隔离、互不影响。证书材料（`p12` / `mobileprovision` / `证书_*`）不入版本库。

## 文档

- [REQUIREMENTS.md](REQUIREMENTS.md) — 需求与设计文档
- [AGENTS.md](AGENTS.md) — 协作约定、真机部署与签名细节
