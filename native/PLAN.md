# Tonari 原生版排期

用 Swift / SwiftUI 重写 Tonari，功能与 Flutter 版对齐后替换 Flutter 版日常使用。

- 起点：2026-09-28
- 预计切换：2026-12-11（缓冲一周，最晚 12/18）
- 估算依据：Flutter 版 2026-05～06 的开发节奏；Flutter 版现状约 2.6 万行手写 Dart、14 张表、约 30 个页面，`ios/Runner/AppDelegate.swift` 已有约 1080 行原生代码（bookmark、PiP、NowPlaying 等）可直接复用。

## 1. 技术决策（2026-09-24 已确认）

| # | 决策 | 推荐 | 理由 |
|---|---|---|---|
| 1 | 最低系统 | iOS 17 | 自用不上架；`@Observable`、成熟的 `NavigationStack` 从 17 起才可用，停在 15 要写大量兼容代码 |
| 2 | UI 框架 | SwiftUI 为主，UIKit 补位 | 播放器 PiP、DocumentPicker、横屏视频需要 UIKit |
| 3 | UI 风格 | 暂用系统白色主题 + 底部 Tab（2026-09-24 改定） | 用户决定不沿用 Kikoeru 配色与侧边抽屉 |
| 4 | 数据库 | GRDB | 能直接打开 Drift 生成的 SQLite，表结构原样沿用；SwiftData 需要重新建模且读不了旧库；SQLite.swift 维护活跃度不如 GRDB |
| 5 | 数据迁移 | 实现「从 Flutter 备份恢复」 | 备份/恢复本来就要移植，兼容现有备份格式一份代码两用；恢复后只需重选本地文件夹 |
| 6 | 仓库 | 同仓库 `native/` 目录 | Flutter 代码随时对照、`test/fixtures` 复用；切换后删除 Flutter 部分 |
| 7 | 工程组织 | Xcode 工程（同步文件夹）+ 本地 SPM 包 `TonariCore` | 纯逻辑（解析、扫描、字幕、DLsite）放 SPM 包，`swift test` 快；`.pbxproj` 基本不改 |
| 8 | M7 隐私 | 切换之后再做 | 应用锁、备选图标 Flutter 版没做，不拖慢对齐进度；后台模糊 Flutter 版已有，随 N6 移植 |

第三方依赖控制在 3 个：GRDB、SwiftSoup（HTML 解析）、视频播放器（N0 验证后确定）。网络用 URLSession async/await，Keychain 直接用 Security 框架，WebDAV 继续自写 PROPFIND。

开发期间 Flutter 版冻结：只修 bug，不加新功能。

## 2. Bundle ID 与签名

| App | Bundle ID | 证书 | 用途 |
|---|---|---|---|
| Flutter 调试版 | `com.leo.tonari` | 免费 Apple ID | 现有，保持不动 |
| 原生调试版 | `com.leo.tonari.native` | 免费 Apple ID | 开发期间真机调试 |
| 正式版 | `com.wangshaikang` | 付费证书（explicit profile，唯一） | 切换前是 Flutter 版，切换后是原生版 |

- iOS 用 Bundle ID 判断是不是同一个 App：相同 → 覆盖安装（沙盒数据保留），不同 → 并存。
- 免费证书可以自己新建 Bundle ID（每周最多 10 个），所以原生调试版用新 ID，与两个 Flutter 版并存，互不替换。
- 免费证书每台设备最多同时装 3 个 App；Flutter 调试版 + 原生调试版共 2 个，正式版走付费证书不计入。
- 付费证书只有 `com.wangshaikang` 一个，所以正式版只能在 N7 一次性替换。覆盖安装会保留沙盒，但仍先从 Flutter 版导出备份再装。

## 3. 排期

每个阶段结束停下验收，确认后再开始下一个。

| 阶段 | 时间 | 内容 | 验收 |
|---|---|---|---|
| N0 技术验证 ✅ | 9/24 提前完成 | 工程骨架、`xcodebuild` 命令行构建、签名脚本对接原生 .app；视频播放器选型验证（先验 mdk-sdk，即 fvp 底层；不通过再验 KSPlayer / MPVKit：MKV、HEVC 10-bit、带请求头的直链、115 并发限制、后台播放与锁屏）。Flutter 版视频没有画中画和字幕叠层，不在验证范围；GRDB 打开 Flutter 版数据库；功能对照清单；更新 AGENTS.md 开发规范 | 视频选型确定、旧库可读。不通过则不继续 |
| N1 数据层 + 骨架 ✅ | 9/24 提前完成 | 14 张表的 GRDB 模型（与 Drift 一致）、偏好设置、Keychain、底部 Tab 骨架（媒体库 / 收藏 / 浏览 / 设置）、从 Flutter 备份恢复（只接受 schema 17） | 恢复备份后能显示真实作品列表 |
| N2 媒体库 | 10/12 – 10/23（2 周） | 列表/网格、筛选、排序、搜索、随机；详情页、文件树、画廊；收藏、合集；security-scoped bookmark 导入、`FolderScanner`、`applyScanResult`、重扫、移除/回收站；DLsite 抓取、`EnrichmentQueue`、图片缓存 | 能导入本地文件夹并补全元数据，500 部作品滚动流畅 |
| N3 播放器 + 字幕 | 10/26 – 11/6（2 周） | AVQueuePlayer 播放引擎：播放模式、倍速、睡眠定时、按作品记忆进度、冷启动恢复、中断处理、锁屏/控制中心、MiniPlayer、收听记录；字幕解析与显示、时间偏移、字幕 PiP | 本地作品可日常听，开始自用 |
| N4 云端片库 | 11/9 – 11/18（1.5 周） | WebDAV 客户端；115 扫码登录、浏览、直链（带 Cookie 头）；远程扫描（跳过已导入）、远程字幕、直链过期刷新、不可达提示、媒体来源页 | 115 / WebDAV 作品后台播放、锁屏控制、连播正常 |
| N5 视频 | 11/19 – 11/25（1 周） | 视频库、播放页、横屏、滑动调进度、按文件记忆进度、截图设封面、后台继续播放 | MKV / HEVC 本地与 115 均可播放、拖进度 |
| N6 其余功能 | 11/26 – 12/4（1.5 周） | 设置各页、LLM 简介与音轨名翻译、备份导出、收听统计、消息盒子（app_events）、诊断日志 | 功能对照清单全部打勾 |
| N7 切换 | 12/7 – 12/11（1 周） | 8 小时后台稳定性、AirPods / 蓝牙 / AirPlay；正式签名包；Flutter 正式版导出备份 → 原生正式版覆盖安装 → 恢复；检查文件 App 导入「打开」按钮 | 原生版替换 Flutter 版日常使用 |
| 缓冲 | 12/14 – 12/18 | | |
| M7 隐私 | 切换之后 | Face ID / 密码锁、备选图标 | |

## 4. 阶段记录

- **N0（2026-09-24）**：视频选定 mdk-sdk 0.38（C API + 自写 Swift 封装 `MDKPlayer`；官方 swift-mdk 含编辑器占位符编不过）。真机验证 HEVC 10-bit / H.264 10-bit MKV、H.264 MP4 均走 VT 硬解，拖动约 200ms，带 Cookie / Referer / UA 直链与 2 连接上限正常，后台与锁屏控制正常，缺请求头被拒时正确报失败。GRDB 只读打开 Flutter 备份库（schema 16，219 部作品）全部解码。诊断日志提前移植。签名：`ios-resign` 可签原生 .app（含 mdk.framework）。
- **N1（2026-09-24）**：14 张表 GRDB Record（`DriftRecord` 统一 Drift 编码约定）、沿用 `user_version`、关闭外键（与 Drift 一致）、Keychain、备份恢复（只接受 schema 17，下次启动应用，跳过 `diagnostic.*`）。真机从 v17 备份恢复：219 部作品、3 个凭据。UI 改为白色主题 + 底部 Tab。

## 5. 风险与时间点

- 正式签名证书 2026-10-30 到期（落在 N3 期间），需提前续费或换证书；换证书时优先要通配 profile。
- 视频是最大风险，放在 N0 先验证；其余模块在 Flutter 版里都有对应的 iOS 原生实现路径。
- Widget、Share Extension、Live Activity 仍不做，签名方式的限制不变。
