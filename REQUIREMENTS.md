# ASMR Player 需求文档

## 1. 项目概述

一款 iOS 端的本地 ASMR 音频播放器，按 DLsite 作品（RJ 编号）组织音频资源。核心特性：

- 本地音频文件管理，按 RJ 编号识别 DLsite 作品
- 自动抓取 DLsite 作品元数据（封面、声优、标签等）
- 完整的音频播放体验（后台播放、锁屏控制、倍速、A-B 循环、睡眠定时器）
- 字幕加载与基于 LLM API 的日译中
- 隐私保护（应用锁、模糊预览图）

## 2. 项目范围与约束

### 2.1 平台
- **目标平台**：iOS（iPhone 优先，iPad 兼容）
- **最低系统**：iOS 15+
- **分发方式**：淘宝签名（超级签 / 企业签）自用，不上架 App Store

### 2.2 技术栈
- **框架**：Flutter (3.x)
- **语言**：Dart
- **状态管理**：Riverpod
- **本地数据库**：Drift（原计划 Isar 3，因 Flutter 3.44 + Riverpod 3 依赖冲突替换为 Drift）
- **音频核心**：`just_audio` + `audio_service`
- **HTTP**：`dio` + `cookie_jar` + `dio_cookie_manager`
- **HTML 解析**：`html` 包
- **文件访问**：`file_picker` + `path_provider`
- **图片缓存**：`cached_network_image`（需自定义带 Referer 的 HTTP client）

### 2.3 明确不做的事情（避免范围蔓延）
- ❌ 不做 Android 版本（Flutter 代码保留可移植性即可）
- ❌ 不做 NAS / SMB / WebDAV 远程音频
- ❌ 不做账号系统、不做后端服务
- ❌ 不做云同步（iCloud 同步留作未来扩展点）
- ❌ 不做 Share Extension、Widget、Action Extension（淘宝签名兼容性考虑）
- ❌ 不做音频下载（音频通过文件 App 导入）

## 3. 核心功能模块

### 3.1 媒体库管理

**目标**：扫描用户导入的音频文件夹，识别 RJ 编号作品并建立索引。

**功能点**：
- 通过文件 App 或 `UIDocumentPickerViewController` 导入文件夹/单个作品
- 自动识别作品根目录的 RJ 编号（文件夹名包含 `RJ\d{6,8}` 即可，前后可有其他字符）
- 递归扫描所有子目录（不限深度），**不依赖目录命名约定**
- **基于文件类型分类**而非目录名：
  - 音频文件（`.wav` / `.mp3` / `.flac` / `.m4a` / `.ogg` / `.opus` 等）→ Track
  - 图片文件（`.jpg` / `.png` / `.webp` 等）→ 本地图片资源
  - 字幕文件（`.srt` / `.lrc` / `.vtt` / `.ass`）→ Subtitle
  - 文本文件（`.txt` / `.md`）→ 说明文档（可选展示）
  - 其他类型忽略
- **音频分组与去重策略**：
  - 同一目录下的音频文件视为一组
  - 若不同目录的音频**主文件名相同但扩展名不同**（如 `track01.wav` 与 `track01.mp3`），视为同一音频的不同音质版本，自动归并
  - 用户可手动调整分组（合并 / 拆分）
  - 同组多音质共存时按优先级播放（FLAC > WAV > MP3 > 其他，可在设置中调整）
- **音频用途的弱推断**（仅作建议性标签，不影响功能）：
  - 通过目录名 / 文件名中的关键词推断用途：含 `本編` / `本编` / `main` → 正篇；含 `フリートーク` / `free` / `talk` → 附加；其他 → 未分类
  - 推断结果作为标签展示，用户可手动改
- **封面图选择策略**：
  - 优先使用 DLsite 抓取的官方封面
  - 若抓取失败，从本地图片中按以下规则挑选默认封面：文件名含 `main` / `cover` / `jacket` / `表紙` 优先；否则取最大尺寸的图片；否则取第一张
  - 用户可手动设置任意本地图片为封面
- 扫描结果缓存到 Isar，避免每次启动重扫
- 支持手动刷新、增量扫描、移除作品
- 媒体库视图支持按以下维度筛选：
  - 声优
  - 社团
  - 标签（DLsite genres + 用户自定义 tags）
  - 收藏 / 历史 / 未听
- 媒体库视图支持以下排序：
  - 导入时间
  - 发售日
  - 最近播放
  - 评分
  - 标题
- 支持搜索（标题、声优、社团、标签全文）

**输入**：用户通过文件 App 选择的文件夹。

**输出**：本地 `Work` 数据库记录 + 文件路径映射。

### 3.2 DLsite 元数据抓取

**目标**：根据 RJ 编号从 DLsite 获取作品完整元数据。

**功能点**：
- 入库时自动触发抓取，可手动重试
- 抓取两个数据源并合并：
  1. **HTML 页面**：`https://www.dlsite.com/maniax/work/=/product_id/{RJ_ID}.html`
     - 解析作品大表（`#work_outline`）获取基础信息
  2. **AJAX 接口**：`https://www.dlsite.com/maniax/product/info/ajax?product_id={RJ_ID}`
     - JSON 返回评分、销量、当前折扣价
- 请求时必须携带：
  - `Cookie: adultchecked=1; locale=ja-jp`（绕过年龄验证）
  - 浏览器 User-Agent
  - 单作品请求间随机延迟 1–2 秒（批量入库时）
- 字段解析容错：每个字段单独 try-catch，单字段失败不影响整体入库
- 封面图、样品图本地缓存到 App Documents 目录（避免下架后丢失）
- 图片下载请求需带 `Referer: https://www.dlsite.com/`

**封面图 URL 规律**：
```
主图：https://img.dlsite.jp/modpub/images2/work/doujin/{bucket}/{RJ_ID}_img_main.jpg
缩略：https://img.dlsite.jp/resize/images2/work/doujin/{bucket}/{RJ_ID}_img_main_240x240.jpg
样品：https://img.dlsite.jp/modpub/images2/work/doujin/{bucket}/{RJ_ID}_img_sam{n}.jpg
```
`bucket` = RJ 编号数字部分向上取整到下一个千位，例如 RJ01560714 → bucket = RJ01561000。

**抓取失败处理**：
- 显示占位封面 + RJ 号 + "元数据获取失败"提示
- 提供"手动重试"按钮
- 作品仍可正常播放（依赖本地文件即可）

### 3.3 播放器核心

**目标**：流畅、专注的 ASMR 播放体验。

**功能点**：
- **基础控制**：播放/暂停、上一曲/下一曲（同作品内章节）、停止
- **进度控制**：拖动进度条、±10s / ±30s 跳秒（跳秒幅度可设置）
- **倍速**：0.5x – 3.0x，0.05 步进；快捷预设按钮 0.75x / 1.0x / 1.25x / 1.5x / 2.0x
- **播放模式**：单曲、列表顺序、列表循环、随机
- **A-B 循环**：标记 A 点和 B 点后循环播放该段落
- **睡眠定时器**：
  - 预设：15 / 30 / 45 / 60 / 90 分钟
  - "本曲结束后停止"
  - 自定义时长
- **章节切换**：作品内多音频文件以章节列表展示
- **进度记忆**：每个作品独立记录上次播放章节 + 位置（精确到秒）
- **后台播放**：
  - `Info.plist` 配置 `UIBackgroundModes: audio`
  - `AVAudioSession` 类别为 `.playback`
- **锁屏 / 控制中心集成**：
  - 显示作品封面、标题、声优
  - 支持播放/暂停、上下章节、跳秒
- **AirPlay** 与蓝牙耳机/汽车音响兼容
- **音质保护**：不应用任何音效（均衡器、立体声增强等），ASMR 多为双耳录音不能破坏

**特别约束**：
- 应用切换到后台、锁屏、其他 App 占用音频会话时的行为符合 iOS 标准
- 来电中断后应能自动恢复（由 `audio_service` 处理）

### 3.4 字幕系统

**目标**：加载本地字幕并提供翻译能力。

**功能点**：
- **支持格式**：`.srt` / `.lrc` / `.vtt` / `.ass`（前两个为主）
- **自动加载**：同目录或子目录中文件名匹配音频的字幕自动加载
- **手动加载**：允许用户为某个音频文件手动指定字幕路径
- **显示控制**：
  - 字号、行距、颜色、阴影/描边自定义
  - 字幕在播放页中央滚动区显示，当前行高亮
  - 双语模式：原文上 + 译文下（可切换为仅原文 / 仅译文）
- **时间偏移**：±0.1s 步进调整（应对字幕和音频不同步），按作品记忆
- **翻译触发**：
  - 加载新字幕时提示用户是否翻译
  - 设置中可开启"自动翻译新字幕"
  - 可在播放页随时手动触发"翻译当前字幕"
- **翻译缓存**：以 `字幕文件 SHA256 + 模型名` 为 key，永久本地缓存

### 3.5 LLM 简介翻译服务

**目标**：用户自配 LLM API 翻译 DLsite 作品简介为中文。

**范围决定**：原计划做完整字幕翻译，已放弃 — 用户主要听的作品多有官方中文版；R18 对话字幕在主流 LLM 上拒答率高、需要大量 prompt 微调，投入产出不划算。仅做详情页简介（descriptionHtml）这一段翻译。

**功能点**：
- **配置接口**（OpenAI 兼容协议，覆盖主流国内外服务）：
  - Provider 名称（用户自定义标签，如 "DeepSeek 主力"）
  - Base URL（如 `https://api.deepseek.com/v1`）
  - API Key
  - Model 名称（如 `deepseek-chat`）
  - 可选自定义 System Prompt
  - 可选请求参数（temperature、max_tokens 等）
- **多 Provider 管理**：可保存多个配置，一键切换默认
- **连接测试**：保存前验证 Base URL + Key + Model 可用性
- **翻译入口**：详情页简介区域下方一个「翻译为中文」按钮
  - 整段 HTML 一次性翻译，无分批
  - 结果缓存到 Work 表新增的 `descriptionHtmlZh` 字段（持久化，下次直接显示）
  - 提供「显示原文 / 显示译文」切换
  - 允许手动重译（覆盖缓存）
- **错误处理**：
  - 翻译失败（网络 / 拒答 / 限流）直接显示原文 + toast 提示，不阻断浏览
  - 失败不写入缓存
- **API Key 存储**：使用 iOS Keychain，不进入数据库 / 不进备份

### 3.6 隐私与安全

**目标**：内容敏感性决定了隐私是核心功能而非可选项。

**功能点**：
- **应用锁**：
  - Face ID / Touch ID / 数字密码（任选其一启用）
  - 设置中可调超时（立即 / 1 分钟 / 5 分钟）
- **后台模糊**：
  - 应用切换到后台时，App Switcher 预览图替换为模糊封面或纯色封面
  - 通过监听 `WidgetsBindingObserver` 的生命周期实现
- **图标隐藏 / 备选图标**：
  - 提供普通图标 + 伪装图标（如计算器、记事本风格）
  - 使用 iOS `setAlternateIconName` 切换
- **数据保护**：
  - API Key 存 Keychain
  - 数据库与缓存文件设置 `NSFileProtectionComplete`
  - 不接入任何 Analytics / Crashlytics
- **媒体库可见性**：
  - 不调用 Photos 权限，封面图存 App 沙盒
  - 不出现在系统媒体库 / iTunes 文件共享列表中（可配置）

## 4. 数据模型

### 4.1 Work（作品）
```
productId: String              // RJ01560714，主键
title: String
titleRomaji: String?
translatedTitle: String?       // LLM 翻译后的中文标题
circle: { id, name }
releaseDate: DateTime
voiceActors: List<String>
illustrators: List<String>
scenarioWriters: List<String>
musicians: List<String>
ageRating: String              // R18 / R15 / 全年齢
workType: String               // SOU / RPG / MNG ...
workTypeName: String
fileFormats: List<String>      // [WAV, MP3, FLAC]
genres: List<{id, name}>
fileSize: String               // 原样保留 "3.6GB"
seriesId: String?
seriesName: String?
descriptionHtml: String
mainImageUrl: String
sampleImageUrls: List<String>
mainImageLocalPath: String?
sampleImageLocalPaths: List<String>

// 销量与价格
officialPrice: int
currentPrice: int
discountRate: int
rating: double?                // 0-5
ratingCount: int?
dlCount: int?
reviewCount: int?

// 本地状态
scrapedAt: DateTime?
localImportedAt: DateTime
localFolderPath: String        // 沙盒相对路径
lastPlayedAt: DateTime?
lastPlayedTrackId: String?
isFavorite: bool
userRating: int?               // 1-5
userTags: List<String>
notes: String?                 // 用户笔记
```

### 4.2 Track（音频文件）
```
id: String                     // UUID
workId: String                 // 外键 Work.productId
filePath: String               // 沙盒相对路径
fileName: String
fileFormat: String             // WAV / MP3 / FLAC
fileSizeBytes: int
durationMs: int
sampleRate: int?
bitRate: int?
categoryHint: String?          // 弱推断的用途标签（正篇/附加/未分类），可被用户覆盖
userCategory: String?          // 用户手动设置的分类（覆盖 categoryHint）
parentDirName: String          // 所在子目录名（用于 UI 分组展示）
trackNumber: int?              // 章节顺序，根据文件名解析
title: String                  // 解析出的章节标题或文件名
alternateQualityPaths: Map<String, String>  // 同音频的其他音质 {格式: 文件路径}
lastPositionMs: int            // 上次播放位置
playCount: int
```

### 4.3 Subtitle（字幕）
```
id: String
trackId: String                // 外键 Track.id
filePath: String
fileFormat: String             // srt / lrc / vtt / ass
fileHash: String               // SHA256，用于翻译缓存 key
timeOffsetMs: int              // 用户调整的偏移
originalLines: List<{startMs, endMs, text}>
translatedLines: List<{startMs, endMs, text}>?
translatedAt: DateTime?
translatedByModel: String?     // 记录翻译用的模型
```

### 4.4 LlmProvider（LLM 配置）
```
id: String
name: String                   // 用户自定义标签
baseUrl: String
apiKeyRef: String              // 指向 Keychain 中的 key
model: String
systemPrompt: String?
temperature: double?
maxTokens: int?
isDefault: bool
createdAt: DateTime
```

### 4.5 PlayHistory（播放历史）
```
id: String
workId: String
trackId: String
startedAt: DateTime
endedAt: DateTime
durationMs: int                // 实际播放时长
```

## 5. UI 结构

### 5.1 整体导航
```
TabView (底部 Tab)
├── 媒体库 (Library)
├── 收藏 (Favorites)
├── 历史 (History)
└── 设置 (Settings)
```

### 5.2 关键页面

**媒体库页**
- 顶部：搜索框 + 筛选/排序入口
- 主体：封面瀑布流或网格（用户可切换视图密度）
- 右上：扫描/导入按钮
- 长按作品：快捷菜单（收藏、移除、查看详情、重新抓取元数据）

**作品详情页**
- 顶部大封面 + 标题
- 元数据区：声优、社团、发售日、评分、标签
- 简介（可展开）
- 样品图轮播
- 章节列表（本篇 / フリートーク 分组）
- 底部：开始播放按钮

**播放页**
- 顶部：封面（可点击旋转切换为字幕全屏模式）
- 中部：字幕滚动区（当前行高亮，可点击跳转）
- 进度条：当前时间 / 总时长，可拖动
- 主控制：上一曲 / 后退 / 播放暂停 / 前进 / 下一曲
- 二级控制：倍速、A-B 循环、睡眠定时器、章节列表
- 底部抽屉：字幕设置、翻译触发、音频信息

**设置页**
- 媒体库设置：根目录、音质优先级、自动扫描
- 播放设置：默认倍速、跳秒幅度、退出时是否继续后台播放
- 字幕设置：默认字号、自动翻译开关、显示模式
- 翻译服务：LLM Provider 配置列表、添加/编辑/测试
- 隐私：应用锁、备选图标、后台模糊
- DLsite 设置：抓取间隔、是否抓取销量
- 关于：版本、清理缓存、导出/导入数据库（JSON 备份）

## 6. 开发路线图

| 阶段 | 目标 | 验收标准 |
|---|---|---|
| **M1: 项目骨架** | 工程搭建、依赖配置、基础架构 | 空 App 可在真机运行，4 个 Tab 切换正常 |
| **M2: 媒体库 MVP** | 文件夹导入、扫描、列表展示 | 能导入并展示真实 RJ 作品目录 |
| **M3: 播放器核心** | 完整播放控制 + 后台 + 锁屏 | 锁屏控制、AirPlay 全部正常 |
| **M4: DLsite 抓取** | HTML + AJAX 双源解析 + 图片缓存 | 任意 RJ 编号能获取完整元数据 |
| **M5: 字幕系统** | 加载、显示、时间偏移 | srt/lrc 字幕跟随播放正常显示 |
| **M6: LLM 简介翻译** | Provider 配置 + 简介翻译 + 缓存 | 详情页一键把日文简介翻译为中文，结果持久化 |
| **M7: 隐私功能** | 应用锁、模糊、备选图标 | 三项功能均可在设置中开关 |
| **M8: 打磨** | 体验优化、错误处理、性能 | 媒体库 500+ 作品流畅滚动 |

每个阶段产出可独立运行的版本，避免长期不可运行状态。

## 7. 关键技术决策（已确认）

| 项 | 决策 |
|---|---|
| 跨平台框架 | Flutter |
| 状态管理 | Riverpod |
| 本地数据库 | Drift（SQLite，原 Isar 因依赖冲突替换） |
| 音频库 | just_audio + audio_service |
| 是否后端 | 无后端，纯客户端 |
| 是否云同步 | 暂不做（不排除未来用 iCloud） |
| LLM 协议 | OpenAI 兼容（覆盖 DeepSeek、Moonshot、智谱、OpenRouter、Ollama 等） |
| 签名方式 | 淘宝签名（关闭应用内自动更新） |
| 文件导入方式 | 文件 App / DocumentPicker，不做 Share Extension |

## 8. 验收与质量要求

- **构建**：iOS Release 包能在 iPhone 真机运行，启动 < 2 秒
- **性能**：500 部作品的媒体库滚动 60fps
- **音频**：后台播放、锁屏控制、AirPlay 在 iPhone + AirPods + 蓝牙音响三种场景下全部正常
- **稳定性**：连续后台播放 8 小时无崩溃、无内存泄漏
- **错误处理**：所有网络请求、文件 IO、JSON 解析有兜底，不出现白屏 / 闪退
- **隐私**：所有 API Key、敏感数据存 Keychain，数据库文件 `NSFileProtectionComplete`

## 9. 未来扩展点（不在本期范围）

- iCloud Drive 同步元数据与翻译缓存
- macOS / iPad 优化布局
- 音频波形可视化
- AI 自动生成作品摘要、章节标签
- 多设备进度同步（基于 iCloud KV 或 CloudKit）
- 自动从 `asmr.one` 等社区站补全缺失元数据
