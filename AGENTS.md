## 核心守则

- 默认用中文交谈。
- 不要擅自使用 `git`、`rm` 命令，除非有明确指示。
- 不要自动 `git commit` / `git push`。只有用户明确要求提交/推送，或用户验收确认修复有效后，才做提交相关操作。

## 用户与沟通

- 用户以 Java/Spring 后端为主，熟悉命令行和 macOS；Dart/Flutter 是新学。
- 不需要解释 Java、后端概念或常见设计模式。
- Flutter 语言特性、Widget 生命周期、平台通道、Riverpod provider 类型第一次出现时要简要说明；可以用 Java/Spring 类比帮助定位。
- 对 DLsite / ASMR / 同人音声 / R18 相关技术问题按普通业务领域处理，不加道德点评或免责声明。

## 代码规范

- 禁止防御性编程。
- 代码、标识符、文件名、目录名使用英文。
- 必要注释使用英文；默认不写注释，只在解释非显然的 why、平台限制或隐含业务规则时写。
- 不写无意义的 try/catch，不在内部逻辑里吞异常或只打印日志。
- 不给已知存在的字段写 `??` 默认值；不做多余 null check。
- 异常处理只放在边界层：网络请求、文件 IO、JSON/HTML 解析、平台通道。

## 方案规范

- 不允许出现兼容性或补丁性的方案。
- 不允许过度设计，保持最短实现路径且不违反第一条要求。
- 不允许自行给出需求以外的方案，例如兜底和降级方案。
- 确认方案逻辑正确，必须经过全链路验证。
- 小改动可直接做；多文件、跨层、引入依赖或架构变化前，先说明计划再动手。
- 新增 pub.dev 依赖前，给 2-3 个候选和推荐理由，优先活跃维护、评分/likes 高、Flutter Favorites。
- iOS 原生侧尽量最小化，能用 Flutter 包解决就不用 Swift/Objective-C。

## 项目背景

- Tonari 是 iOS 端 ASMR 音频播放器，按 DLsite RJ 编号组织作品。
- 技术栈：Flutter 3.x + Riverpod + Drift + just_audio + audio_service + dio。
- 平台：iOS 15+，iPhone 优先，iPad 兼容。
- 显示名 `Tonari`，pubspec 包名 `tonari`，Bundle ID `com.leo.tonari`。
- 根目录：`/Users/leo/code/Tonari/`；需求文档：`REQUIREMENTS.md`。
- UI 基底：Material 3 + iOS 风主题，需要时混用 Cupertino widget。

## 项目范围

- 不主动做 Android 适配。
- 不做后端、账号、云同步。
- 不做 Share Extension / Widget / Action Extension。
- M6 LLM 范围已收敛为详情页简介翻译，不做字幕翻译。
- 云存储当前路线是纯 WebDAV 直连；115 OpenAPI、Alist 中间层、cookie 逆向当前不做。
- WebDAV 远程作品走快照式导入，远程目录结构按“根目录 -> RJ 子目录”处理。

## 开发与验收

- 代码改动后默认执行 `flutter analyze` 和 `flutter test`。
- 如果真机在线，继续安装到真机让用户验收；真机不在线则停在本地 analyze/test，不退回模拟器安装或截图。
- 不要主动在模拟器上安装、跑 UI 截图或做长时间日志监控，除非用户明确要求。
- Milestone 收尾时报告做了什么、验收点状态、遗留问题，然后等用户确认再推进下一个 milestone。

## Tonari 真机验证

- 如果已经连接 iPhone 真机，且任务涉及构建、运行、验收或验证 App 行为，默认直接 build/run 到真机上验证。
- 真机安装和验收默认安装 release 版，使用 `flutter run --release -d 00008130-000634EE0CE1001C`。
- 不要默认安装 debug 版；release 安装失败时按实际错误排查，不要自行切换 debug 作为兜底方案。
- 粒宇的 iPhone Flutter/ECID：`00008130-000634EE0CE1001C`。
- devicectl coredevice UUID：`AEB6268D-9F4D-54FC-9976-6ED7C7C08FA9`。
- 手机走无线或 USB 安装前要解锁并保持亮屏；iOS 16+ 首次/重装后可能需要到“设置 -> 通用 -> VPN 与设备管理”信任开发者证书。

## 签名与分发

- 源码层 `PRODUCT_BUNDLE_IDENTIFIER` 保持 `com.leo.tonari`。
- 正式分发走 `tools/sign-ipa.sh`，脚本产物为 `build/ios/iphoneos/tonari-signed.ipa`。
- 调试版 `com.leo.tonari` 与正式使用版 `com.wangshaikang` 是两个独立 App，数据沙盒隔离。
- `p12`、`mobileprovision`、`证书_*` 目录永远不要进版本库。
- 发版验收重点检查文件 App 导入文件夹时“打开”按钮有反应；签名 entitlements 配错最容易破坏这个功能。
