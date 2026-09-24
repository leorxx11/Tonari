# 功能对照清单

原生版与 Flutter 版对齐的验收清单，按阶段分组。每项括号内是 Flutter 版对应源码，移植时以它为准。完成一项勾一项（`[~]` 表示已实现但还没在真机验证），N6 结束时应全部打勾。

## N1 数据层 + 骨架

- [x] 14 张表 GRDB 模型，结构与 Drift schema v17 一致（`lib/core/db/`）
- [ ] 偏好设置读写（`lib/core/prefs/`、各 `*_prefs.dart`）
- [x] Keychain：WebDAV 密码、115 Cookie、LLM API Key
- [x] 底部 Tab：媒体库（音声 / 视频切换）、收藏、浏览、设置（替代 Flutter 版侧边抽屉 `lib/shared/widgets/app_drawer.dart`；抽屉里的分类、播放历史、消息、随机来一部的入口位置待定）
- [x] 主题跟随系统浅色 / 深色；播放页固定深色（参照 Apple Music）；Kikoeru 配色不做
- [x] 从 Flutter 备份恢复：数据库 + 图片目录 + prefs.json + secrets.json（`backup_service.dart`）

## N2 媒体库

- [x] 媒体库三种视图：大卡片 / 网格 / 列表（`library_view_prefs.dart`、`view_mode_button.dart`）
- [x] 排序（点当前字段切换升降序，记忆选择）（`sort_order.dart`、`sort_menu_button.dart`）
- [x] 搜索：RJ、标题、CV、社团、`#标签`（`library_page.dart`）
- [x] 来源筛选：全部 / 本地 / 远程（`library_page.dart`）
- [x] 作品卡片：收藏、加入 / 移出分组、销量、移除作品（`work_card.dart`）
- [x] 随机来一部（`app_drawer.dart`）
- [x] 作品详情：封面、演职员、标签、系列、价格 / 评分 / 售出 / 收藏数 / 排名、简介、图片画廊（`work_detail_page.dart`）
- [x] 详情页操作：刷新元数据、只刷新图片、更新统计数据、在 DLsite 中打开、从媒体库移除、重新扫描此作品（「下载图片」即刷新图片）
- [ ] 作品文件浏览：目录树、音频数 ✅；字幕状态、字幕预览（N3）（`work_files_page.dart`）
- [x] 作品文件入口位置：左下角 / 右下角（`file_entry_prefs.dart`）
- [x] 收藏与分组：全部收藏、新建 / 重命名 / 删除分组，作品和视频都可加入（`collections_page.dart`、`collection_detail_page.dart`、`collection_picker_sheet.dart`）
- [x] 分类页：社团 / 声优 / 标签，搜索，按作品数 / 名称排序（`stats_page.dart`）
- [~] 导入本地文件夹（已实现，待 115 接入后真机验证）：security-scoped bookmark、递归扫描、RJ 识别、音质归并（`folder_bookmark.dart`、`core/scanner/`、`import_service.dart`）
- [x] 导入结果汇总（115 真机验证）：新增 / 跳过 / 音轨数 / 失败作品（`import_entry.dart`）
- [~] 文件夹重扫默认跳过已导入（待验证）；单作品重扫 `reviveTombstoned`（`rescan_service.dart`、`work_reimport_provider.dart`）
- [~] 移除 = 清快照 + 墓碑（待验证）；已移除作品页：重新导入、彻底移除（`removed_works_page.dart`）
- [~] needsRescan 迁移重扫（待验证）：仅本地来源启动时自动跑
- [x] DLsite 抓取：HTML + AJAX、翻译版回退原作、图片带 Referer 下载到沙盒（`dlsite_fetcher.dart`、`metadata_enrichment.dart`、`work_image_cache.dart`）
- [x] 后台补全队列：串行、每作品最多重试 2 次、进度 + 「补全 N 个」、打开未补全作品自动拉取（`enrichment_queue.dart`、`library_task_status.dart`）
- [x] 全部作品统计数据批量更新（`settings_page.dart`）
- [~] 音轨时长探测：本地导入时探测（待验证）；远程音轨随 N3/N4（`track_duration_probe.dart`）

## N3 播放器 + 字幕

- [x] 播放队列、上一首 / 下一首、队列列表（`playback_controller.dart`、`player_page.dart`）
- [x] 播放模式：顺序 / 循环 / 单曲 / 随机
- [x] 倍速
- [x] 快进 / 快退步长可设置（`playback_settings_page.dart`）
- [x] 睡眠定时：按时间 / 按曲数 / 播完本曲 / 自定义（`sleep_timer.dart`、`sleep_timer_sheet.dart`）
- [x] 按作品记忆进度、冷启动恢复
- [x] 中断处理（来电、其他 App 占用音频）、拔耳机暂停（Flutter 版由 just_audio 默认的 `handleInterruptions` 处理，原生要自己监听 `AVAudioSession` 通知）
- [x] 锁屏 / 控制中心：封面、标题、上下首、拖进度（`now_playing_bridge.dart`）
- [x] MiniPlayer（`tabViewBottomAccessory`，进度改为播放键外圈进度环）
- [x] 播放历史：音频 / 视频分组、看到百分比、删除单条、清空（`play_history_page.dart`）
- [x] 收听时长记录与收听统计：本周 / 本月 / 累计、每日、常听作品 / 声优 / 社团（原生版为可左右滑动的前 5 排行榜）（`listen_logs`、`listen_stats_page.dart`）
- [x] 字幕解析：srt / vtt / lrc（`core/subtitle/`）
- [x] 播放页字幕（原生新增，参照 Apple Music 歌词）：跟随播放滚动、手动滚动后 3 秒恢复跟随、点句跳转、偏移 ±0.1s / 重置
- [x] 字幕模式：原生版只保留画中画开关（播放页「⋯」菜单），App 内悬浮字幕按用户决定不做（`subtitle_overlay_prefs.dart`）
- [-] 悬浮字幕：不做（2026-09-25 用户决定）；偏移 ±0.1s / 重置已在播放页字幕实现（`subtitle_overlay.dart`）
- [x] 画中画字幕窗口（`ios/Runner/AppDelegate.swift` 的 `PipSubtitleController`）

## N4 云端片库

- [ ] WebDAV 服务器管理：增删改、测试连接、删除时提示受影响作品数（`webdav_settings_page.dart`、`webdav_server_edit_page.dart`）
- [ ] WebDAV 浏览、导入目录到媒体库（`webdav_browser_page.dart`）
- [x] 115 扫码登录、退出登录（`p115_login_page.dart`、`p115_settings_page.dart`）
- [x] 115 浏览（每级文件夹一页，记住上次位置）、导入、风控检测与中断（`p115_browser_page.dart`）
- [~] 浏览页：WebDAV / 115 入口与登录状态（115 ✅，WebDAV 待 N4b）（`browse_page.dart`、`remote_browser_page.dart`）
- [~] 远程扫描阶段跳过已导入作品；导入在后台进行（115 已实现）
- [~] 远程字幕下载解析（115 已实现，N3 显示字幕时验证）
- [x] 115 直链带请求头直连播放；音频过期前 2 分钟内重新获取；播放中出错或链接过期后卡住时重取一次（原生版不用 8 秒定时器）
- [ ] 播放失败时探测一次来源并点名不可达的来源，记入消息
- [~] 媒体来源页：查看、删除来源（级联硬删，显示作品数）（N2b 已实现，待验证）（`media_sources_page.dart`）

## N5 视频

- [ ] 视频库：从文件 App 导入、修改标题、删除、收藏、分组（`video_library_page.dart`、`local_video_import.dart`）
- [ ] 远程视频加入 / 移出视频库
- [ ] 播放页：竖屏内嵌、横屏全屏、控制条自动隐藏、倍速、睡眠定时（`video_player_page.dart`）
- [ ] 横向滑动微调进度，拖动时预览时间、抬手才 seek
- [ ] 按文件记忆进度、继续播放（`video_resume_store.dart`）
- [ ] 截取画面设为封面、视频默认封面（`playback_settings_page.dart`）
- [ ] 后台继续播放音轨、MiniPlayer、锁屏控制；暂停在后台超过 10 分钟释放播放器（`video_controller.dart`）

## N6 其余功能

- [ ] 设置首页与各子页（`settings_page.dart`）
- [ ] LLM Provider 管理：快速模板、测试连接、设为默认、删除（`translation_settings_page.dart`、`provider_edit_page.dart`）
- [ ] 简介翻译：翻译为中文、显示原文、失败重试（`work_detail_page.dart`、`features/translation/`）
- [ ] 音轨名翻译、显示 / 隐藏译名（`work_files_page.dart`）
- [ ] 备份导出：后台进行、字节进度、完成后写入消息（`backup_page.dart`、`backup_controller.dart`）
- [ ] 消息盒子：未读数、重新扫描 / 补全资料 / 重新登录等快捷操作、清空（`app_events_sheet.dart`）
- [x] 诊断日志：会话、停止 / 继续采集、复制、导出 txt（N0 提前移植）（`diagnostic_log_page.dart`）
- [ ] 后台模糊（`appearance_settings_page.dart`、`privacy_prefs.dart`）
- [ ] 右边缘左滑前进（`ForwardNavigationPlugin`）
- [ ] 简介文本可选中复制（`IosSelectableTextView`）
