# Tonari 原生版排期

用 Swift / SwiftUI 重写 Tonari，替换 Flutter 版。2026-09-24 开工，已完成切换，原生正式版日常使用；Flutter 版归档在 `flutter` 分支（标签 `flutter-final`）。

## 1. 技术决策（2026-09-24）

| 决策 | 选择 | 理由 |
|---|---|---|
| 最低系统 | iOS 26 | 自用不上架；直接用 `tabViewBottomAccessory`、`tabBarMinimizeBehavior` 等 iOS 26 API，不写兼容代码 |
| UI | SwiftUI 为主，UIKit 补位；系统主题 + 底部 Tab | PiP、DocumentPicker、横屏视频需要 UIKit；不沿用 Kikoeru 配色与侧边抽屉 |
| 数据库 | GRDB，沿用 Drift schema | 能直接打开 Flutter 版的库；Flutter 备份恢复即数据迁移 |
| 工程 | Xcode 工程（同步文件夹）+ SPM 包 `TonariCore` | 纯逻辑放 SPM 包，`swift test` 快 |
| 依赖 | GRDB、SwiftSoup、mdk-sdk | 网络用 URLSession，Keychain 直接用 Security，WebDAV 自写 PROPFIND |

## 2. Bundle ID 与签名

| App | Bundle ID | 证书 |
|---|---|---|
| 原生调试版 | `com.leo.tonari.native` | 免费 Apple ID |
| 原生正式版 | `com.nuownqyyy990.ct12215` | 付费证书（explicit profile，2027-09-14 到期） |

Bundle ID 相同则覆盖安装（沙盒保留），不同则并存。免费证书每台设备最多同时装 3 个 App。

## 3. 阶段

| 阶段 | 内容 | 状态 |
|---|---|---|
| N0 技术验证 | 工程骨架、命令行构建与重签、视频引擎选型、GRDB 读旧库 | ✅ 2026-09-24 |
| N1 数据层 + 骨架 | 14 张表、偏好、Keychain、Tab 骨架、Flutter 备份恢复 | ✅ 2026-09-24 |
| N2 媒体库 | 三视图 / 筛选 / 排序 / 随机、详情页、文件树、收藏分组、本地导入、DLsite 补全 | ✅ 2026-09-24 |
| N3 播放器 + 字幕 | 播放引擎、锁屏、迷你播放栏、播放历史、收听统计、字幕与画中画字幕 | ✅ 2026-09-25 |
| N4a 115 | 扫码登录、浏览、导入、直链播放 | ✅ 2026-09-24 |
| N5 视频 | 视频播放页、视频库 | ✅ 2026-09-25 |
| N6 其余功能 | 设置、LLM 翻译、备份导出、消息盒子、后台模糊 | ✅ 2026-09-25 |
| N8 主页改版 | Tonari 主页、资料库合并媒体库与收藏、设置移入主页齿轮 | ✅ 2026-09-25 |
| N9 发现与愿望单 | DLsite 发现 / 搜索、在线详情与 chobit 试听、网页登录、愿望单、待入库 | ✅ 2026-09-25 |
| N7 切换 | Flutter 正式版导出备份 → 原生正式版恢复，日常使用 | ✅ |
| N4b WebDAV | WebDAV 服务器管理、浏览导入；播放失败时点名不可达来源 | 暂缓（用户基本不用） |
| N10 数据安全与稳定性 | 备份提醒、MetricKit 崩溃报告 | ✅ 2026-10-11 |
| N11 115 离线下载 | 按作品下载曲目目录，播放优先走本地 | ✅ 2026-10-11 |
| N12 隐私锁 | Face ID / 密码锁（备选图标不做） | 未开始 |
| N13 快捷指令与 Spotlight | App Intents、作品进系统搜索 | 未开始 |
| N14 DLsite 增强 | 愿望单特价、已购未入库、特价通知 | 未开始 |

### 后续排期（2026-10-11）

按「先保数据 → 日常收听价值最大 → 小而独立 → 需要先验证 → 新范围」排序，每段收尾停下验收。签名评估：以下都不需要额外 entitlement，`resign.sh` 不用改。

1. **N10 数据安全与稳定性**：上次备份超过 30 天时写一条消息（点开进备份页）；接入 MetricKit，崩溃 / 卡死的调用栈写进诊断日志和消息盒子。验收：改系统时间触发提醒；正式包故意崩溃一次，下次启动收到报告。收不到说明 Ad Hoc 包拿不到，MetricKit 撤掉不做。
2. **N11 115 离线下载**：详情页 ⋯ →「下载到本机」，下载当前曲目目录（音频 + 字幕），后台 `URLSession` 串行，沿用 115 请求节奏；播放、冷启动恢复优先本地文件；详情页显示下载状态，存储空间页加「离线下载」分区，可按作品删除。验收：飞行模式下冷启动续播、连播、字幕正常。
3. **N12 隐私锁**：设置 → 隐私 开关，回到前台时 Face ID（失败用设备密码），与后台模糊共用最上层窗口。验收：切后台再回来要解锁，全屏播放页也被盖住，锁屏时音频不中断。
4. **N13 快捷指令与 Spotlight**：先做最小的「继续收听」Intent，装正式包确认快捷指令 App 里能看到（重签改了 Bundle ID，这一步不通过则 N13 不做）；再加「随机一部」「睡眠定时」「播放某部作品」，作品做成 `AppEntity` + `IndexedEntity`，一份索引同时供 Intent 参数和 Spotlight 搜 RJ 号 / 标题。验收：Siri、操作按钮、Spotlight 都能触发并跳到对应作品。
5. **N14 DLsite 增强**：发现页加「愿望单里正在特价」；读 DLsite 已购列表，标出未入库作品（先确认接口与现有登录 Cookie 是否够用）；`BGAppRefreshTask` + 本地通知提醒愿望单特价（触发时间由系统决定，不保证准时）。验收：真实账号数据下列表正确，后台刷新至少触发一次通知。

## 4. 实现要点与踩过的坑

- **视频**：mdk-sdk 0.38，C API + 自写 Swift 封装 `MDKPlayer`（官方 swift-mdk 编不过）。用外部渲染上下文（MTKView 提供 drawable，主线程调 `renderVideo`）；让 mdk 自管视图会点 / 像素混用，自管图层会每帧改 frame 卡死 Core Animation 被看门狗强杀。截图数据是 RGBA。
- **115**：`P115Client` actor 串行、请求间隔 ≥1.2s、手动跟随重定向合并 Cookie；子文件夹不列内容摘要、预览文件点开才下载，避免触发风控。音频直链按曲解析，过期前 2 分钟重取，播放中失败或过期卡住重取一次。
- **播放**：单个 `AVPlayer` 逐首加载；Combine `.values` 会丢 KVO 变化导致加载卡死，改用缓冲的 `AsyncStream`。音视频互斥由 `NowPlaying` 协调。
- **画中画字幕**：逐句绘制成帧送入 `AVSampleBufferDisplayLayer`；AVKit 创建控制器时就查询播放状态，要先备好状态。
- **数据库**：GRDB 查询条件里的 Date 按文本绑定，与 Unix 秒列比较要传秒数。原生新增改动走 `Schema.migrations`（18 `wanted_works`、19 PDF 归为 `document`）。
- **备份**：与 Flutter 版同格式；prefs 只带字符串 / 数字 / 布尔 / 字符串列表，复杂值存 JSON 字符串。
- **SwiftSoup**：要自己做 HTML5 换行规范化；只改文本节点时仍输出原文，翻译简介要替换节点。
- **SwiftUI**：同一视图只认一个 `fileImporter`，统一导入入口按类型切换一个选择器。
- **DLsite 发现**：排行榜读 `/{floor}/ranking/{term}?category=voice` 的 HTML（全年龄区没有日榜）；其余列表读 `fsr/ajax`，统一带账号默认条件（男性向、同人、音声、语言 JPN/CHI/CHI_HANS/CHI_HANT/NM）；标题 / 主图 / 价格统一由 `product/info/ajax` 批量补全（列表缩略图是方形裁切、标题可能打码）。
- **DLsite 登录**：非持久 `WKWebView` 打开 `maniax/login/=/skip_register/1`，见到 `loginchecked` 即存 www.dlsite.com 的 Cookie 与登录页 UA；每次请求把续发的 Cookie 写回。愿望单读 `maniax/load/favorite/product`，写 `maniax/cart/ajax`（`mode=wishlist` / `wishlist_remove`，`result_code` -1 为失败）。
- **崩溃报告**：Ad Hoc 重签包能收到 MetricKit 诊断，前提是手机开着「分析与改进 → 与 App 开发者共享」，开关打开前的崩溃不会补发；下次启动时投递。报告里只有地址，用同一次构建的 `Tonari.app.dSYM`（`dwarfdump --uuid` 对上报告的 `binaryUUID`）执行 `atos -l 0x100000000`，地址取 `0x100000000 + offsetIntoBinaryTextSegment`。dSYM 每次构建都会被覆盖，要查旧报告得留着当时的 dSYM。
- **离线下载**：`offline_works` 只记「哪部作品、哪个目录要离线」，文件在 `Documents/offline/<RJ>/<相对路径>`，下完才移入，存在即完整，不进备份。后台 `URLSession`（`httpMaximumConnectionsPerHost = 1`，115 全走同一 CDN 域名，等于串行），队列按作品加入先后、作品内按曲目列表的自然顺序（115 的 `file_path` 是 pickcode，不能用来排序）。实测三条系统行为：**App 在后台时新建的任务被限速**（1.8 MB/s，前台建的 11.7 MB/s，锁屏后仍保持）；**后台只在 session 里任务全部结束时唤醒 App 一次**，不是每首一次；115 直链有效期 32 分钟到 7 小时不等（`resolved` 日志的 `expiresIn`）。所以用滑动窗口：前台把已提交未完成的补到 15 首且不超过 10 GB（满速约 15 分钟内），每下完一首就补，App 中途离开就停；窗口在后台跑空后，每次唤醒只交 1 首慢速的，下完再唤醒交下一首；回到前台不动这首慢速的，把窗口其余位置补满快速的。实测同一域名的任务并非严格串行（常有两首同时下完），所以慢速那首不挡快速的。不用 resume data：CDN 虽有 `Accept-Ranges: bytes` 与 ETag，但用后台 session 的 resume data 重建的任务轮到时报「无此文件」失败（2026-10-12 实测）。解析中的曲目单独记一份，补窗口和过期重试不会重复提交同一首。排队中过期（非 200）换新链接重试一次，再失败或解析失败就整体暂停并写消息；暂停状态跨启动保留。系统唤醒时等所有解析中的链接交给 session 后才调 completion。作品下完前台弹横幅、后台发本地通知（点开进作品页，失败暂停进消息页），通知权限在第一次下载时申请；后台的完成通知要等那一批结束被唤醒时才发。删作品 / 来源会连带删表行，`OfflineDownloads` 观察表变化清掉多余文件。入口：详情页 ⋯ / 作品长按菜单下载，详情页播放按钮下进度条，主页 / 资料库工具栏总进度环（半屏「下载」），资料库「已下载」与存储空间「离线下载」同一列表。长按预览卡片不继承环境，用到 `@Environment` 对象的视图要显式 `.environment(...)` 注入。
- **chobit 试听**：`chobit.cc/api/v1/dlsite/embed` → 嵌入页 `.track-list li[data-src]`，翻译版取原作。

## 5. 界面方案

示意图在 `design/`，浏览器直接打开：[主页](design/home.html) · [发现](design/discover.html) · [媒体库](design/library-layouts.html) · [作品详情](design/work-detail.html) · [曲目翻页](design/track-pager.html) · [资源页](design/work-files.html) · [浏览](design/browse.html) · [收藏](design/favorites.html) · [设置](design/settings.html)（[整改](design/settings-cleanup.html)） · [迷你播放栏](design/mini-player.html) · [搜索](design/search.html) · [视频](design/video.html) · [离线下载进度](design/offline-progress.html)（采用全局 B、作品页 A）。

整体对标 Apple Music / iOS 26 原生组件：去卡片底色与阴影，封面直接放背景上（DLsite 原图 4:3），长按用系统 `contextMenu`。示意图之外的规则：

- **Tab**：Tonari（主页）· 发现 · 资料库 · 浏览 · 搜索；设置是主页右上角齿轮打开的 sheet，未读消息数显示在齿轮角标。
- **不展示总时长**：115 作品导入时拿不到时长，只在播放时逐首回写，批量探测会触发风控。
- **继续播放**按作品记（`works.last_played_track_id`），与曲目目录选择无关；曲目目录默认 `WorkTree.autoPath`，手动选择按作品记住。
- **原文 / 译文**：详情页整页一个开关（默认译文），同时作用于标题、曲目名、简介。
- **设置**：不用页脚说明，后果类说明放确认弹窗；不放调试信息；功能没做时不放占位入口。存储空间为 iPhone 储存空间式，简介图片缺失时原位提示「未下载」，不做在线兜底。
- **视频**：始终全屏黑底，不做竖屏内嵌与视频画中画；看到最后 10 秒内的从头开始，不弹「从头播放」提示；后台暂停超过 10 分钟释放播放器。
- **明确不做**：App 内悬浮字幕、右边缘左滑前进、购买、Widget / Share Extension / Live Activity。
