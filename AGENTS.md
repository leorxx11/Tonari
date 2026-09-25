## 核心守则

- 默认用中文交谈。
- 不要擅自使用 `git`、`rm` 命令，除非有明确指示。
- 不要自动 `git commit` / `git push`。只有用户明确要求提交/推送，或用户验收确认修复有效后，才做提交相关操作。

## 用户与沟通

- 用户以 Java/Spring 后端为主，熟悉命令行和 macOS；Swift / SwiftUI 是新学。
- 不需要解释 Java、后端概念或常见设计模式。
- Swift 并发（actor、`@MainActor`、`Sendable`）、属性包装器、`@Observable`、View 生命周期第一次出现时简要说明；可以用 Java/Spring 类比帮助定位。
- 对 DLsite / ASMR / 同人音声 / R18 相关技术问题按普通业务领域处理，不加道德点评或免责声明。

## 代码规范

- 禁止防御性编程。
- 代码、标识符、文件名、目录名使用英文。
- 必要注释使用英文；默认不写注释，只在解释非显然的 why、平台限制或隐含业务规则时写。
- 不写无意义的 do/catch，不在内部逻辑里吞异常或只打印日志。
- 不给已知存在的字段写 `??` 默认值；不做多余 nil 检查。
- 异常处理只放在边界层：网络请求、文件 IO、JSON/HTML 解析、系统框架回调。

## 方案规范

- 不允许出现兼容性或补丁性的方案。
- 不允许过度设计，保持最短实现路径且不违反第一条要求。
- 不允许自行给出需求以外的方案，例如兜底和降级方案。
- 确认方案逻辑正确，必须经过全链路验证。
- 小改动可直接做；多文件、跨层、引入依赖或架构变化前，先说明计划再动手。
- 新增 SPM 依赖前，给 2-3 个候选和推荐理由，优先活跃维护、stars 高的。

## 项目背景

- Tonari 是 iOS 端 ASMR 播放器，按 DLsite RJ 编号组织作品，支持本地导入与云端片库（115 网盘；WebDAV 待移植）。
- 技术栈：Swift 6 + SwiftUI（UIKit 补位）、GRDB、SwiftSoup、mdk-sdk（视频），iOS 26+，iPhone 优先。
- 显示名 `Tonari`。需求文档 `REQUIREMENTS.md`；原生版排期 `native/PLAN.md`，功能对照清单 `native/PARITY.md`（完成一项勾一项），界面示意 `native/design/`。
- UI 对标 Apple Music / iOS 26 原生组件。
- Flutter 版已归档：分支 `flutter`、标签 `flutter-final`。切换（`native/PLAN.md` 的 N7）完成前 Flutter 正式版仍在日常使用，只在 `flutter` 分支修 bug，不加新功能。

## 项目范围

- 不做 Android。
- 不做后端、账号、云同步。
- 不做 Share Extension / Widget / Action Extension。
- LLM 用途：作品标题、简介、曲目名翻译；不做字幕翻译，新用途先问。
- 云存储：WebDAV 直连 + 115 网盘 cookie 扫码登录；115 OpenAPI、Alist 中间层已弃。
- 远程作品走快照式导入，远程目录结构按“根目录 -> RJ 子目录”处理。

## 工程结构

- `native/Tonari.xcodeproj`：App target，`Tonari/` 为同步文件夹，加文件不改 `.pbxproj`；图标是 `Tonari/AppIcon.icon`（Icon Composer）。
- `native/TonariCore/`：纯逻辑 SPM 包，可在 macOS 上 `swift test`。
- `native/Packages/MDK/`：mdk 二进制 + Swift 封装。
- 数据库沿用 Flutter 版 Drift schema：snake_case 列名、日期存 Unix 秒、字符串列表存 JSON 文本；备份格式与 Flutter 版互通。
- App target 默认 `@MainActor` 隔离（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）。

## 开发与验收

- 代码改动后默认执行：
  - `cd native/TonariCore && swift test`
  - `cd native && xcodebuild -project Tonari.xcodeproj -scheme Tonari -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -allowProvisioningUpdates -quiet build`
- 构建通过后用新证书重签，真机在线就直接装正式包：`xcrun devicectl device install app --device <coredevice-uuid> native/build/DerivedData/Build/Products/Release-iphoneos/Tonari-signed.ipa`，再 `xcrun devicectl device process launch --device <coredevice-uuid> <正式版 Bundle ID>`。真机不在线则停在本地测试与构建。
- 默认不装调试版；只有遇到需要调试数据的验证阻塞问题时才装调试版（`native/build/DerivedData/Build/Products/Release-iphoneos/Tonari.app`，Bundle ID `com.leo.tonari.native`）。
- 不要主动在模拟器上安装、跑 UI 截图或做长时间日志监控，除非用户明确要求。
- 设备标识（devicectl coredevice UUID、设备 UDID）属隐私信息，不写入版本库；实际值保存在本地配置 / 记忆中。
- 手机安装前要解锁并保持亮屏。
- Milestone 收尾时报告做了什么、验收点状态、遗留问题，然后等用户确认再推进下一个 milestone。

## 签名与分发

- 源码层 `PRODUCT_BUNDLE_IDENTIFIER` 保持 `com.leo.tonari.native`（免费证书调试用）。
- 正式包用 `ios-resign` skill 重签 Release 产物的 .app：新证书（Team `Q7866CL7FU`，2027-09-14 到期）的 profile 锁定 Bundle ID `com.nuownqyyy990.ct12215`，产物为同目录 `Tonari-signed.ipa`。
- 原生正式版与 Flutter 正式版 `com.wangshaikang`（旧证书 2026-10-30 到期）是不同 App，并存、互不覆盖；切换方式是在 Flutter 正式版导出备份、原生正式版里恢复。
- `p12`、`mobileprovision`、`证书_*` 目录永远不要进版本库。
- 发版验收重点检查文件 App 导入文件夹时“打开”按钮有反应；签名 entitlements 配错最容易破坏这个功能。
