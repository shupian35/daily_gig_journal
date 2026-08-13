# CONTEXT.md · 日记清单 (daily_gig_journal)

领域词汇表 (domain glossary)。单 context 仓库；更细的格式约定见 `docs/agents/domain.md`。

> 最后修订：2026-07-19 · 当日跟进 `EntryCoordinator` 自动备份从 await 改为 `unawaited()` + leading-edge 30s 节流（保存时长优化 + 多保存去重）

## 核心术语

| 术语 | 含义 | 对应代码 |
| --- | --- | --- |
| **WorkEntry** | 一条工作日记（标题、地点、对接人、工时、工资三件套、正文） | `lib/models/work_entry.dart`，库表 `work_notes` |
| **Wage Spec** | 工资三件套：`hourlyWage × workHours = dailyWage`，双向推导 | `lib/utils/helpers.dart::calculateWorkHours`；未来归 `WageCalculator` 模块 |
| **Note Body** | 富文本正文，Quill Delta JSON 格式；嵌图走 `BlockEmbed.image` | `noteContent` 字段；`jsonEncode(quill.Document.toDelta().toJson())` |
| **Calendar View** | 月/周日历视图；标点来自 `workDatesProvider` | `lib/screens/calendar_screen.dart` |
| **Backup Cycle** | 一次"本地 → 云端（WebDAV）"备份回合；保留 30 天。**Fire-and-forget** + **leading-edge 节流 30s**：save / delete 不等待；备份在后台事件循环里跑；窗口从上次备份**完成**算起，30s 内的后续 save 被合并 | `lib/services/backup_service.dart` + `entry_coordinator.dart::_tryAutoBackup` |
| **Settings Surface** | 主题/隐私/云端/语言设置，持久化到 `SharedPreferences` | `lib/services/settings_service.dart` |
| **WorkEntryRepository** | WorkEntry 持久化的接缝：13 个 find/save/remove/filePath/watch 动词；显式 add/update 不变式（`entry.id == null` → add；非空 → update）；2 个 adapter：SQLite（生产）+ InMemory（测试） | `lib/data/work_entry_repository.dart`（待新建，见 ADR-0006） |
| **WorkEntryChange** | sealed class {Added, Edited, Removed}，repository 写操作的最小可观察信号，date 字段用于精准失效 | `lib/data/work_entry_change.dart`（待新建，见 ADR-0006） |
| **EntryCoordinator** | 集中所有 WorkEntry 写入与未来 archive/duplicate/merge 的 Notifier；`build()` 单一挂 `WorkEntryRepository.watch()` 订阅做派生缓存失效、同步触发自动备份。**边界**：只管 *entry-level mutation*（`save(WorkEntry)` / `delete(int id)`）；*bulk-mutation-over-tags*（`renameTag / deleteTag / mergeTag`）不走 Coordinator，由 Repository 单事务后直发 `Edited` 事件，仍触发本表失效链。详见 ADR-0001 + ADR-0008 §Decision 4 | `lib/providers/entry_coordinator.dart`；watch 监听见 ADR-0006；Coordinator 边界切分见 ADR-0008 |
| **Worker Hours** | `startTime - endTime` 的小时数（小数保留 1 位） | `Helpers.calculateWorkHours(start, end)` |
| **Work Week Plan** | 今天起未来一周的条目预览，按日期聚组 | `CalendarScreen._buildUpcomingWeekPlan` |
| **Preview Build** | dev 分支每次推送产出的预发布 artifact；tag 命名空间 `preview/vX.Y.Z+N-sha`，GitHub Release 标 `prerelease: true` | `.github/workflows/cd.yaml` 的 release-preview job |
| **iOS Native UI Surface** | iOS 系统渲染的 UI 组件（不在 Flutter 树里）。iOS 用 Info.plist `CFBundleLocalizations` 决定走哪国语言 | 长按输入框的 UIEditMenuInteraction、`image_picker` 的 UIImagePickerController、系统分享面板 |

## 概念上的提法

- "**变更语义**" 一律经过 `EntryCoordinator`，**禁止**屏幕直接调 `DatabaseHelper.update/insert/delete`。理由见 ADR-0001。
- "**派生缓存失效**" 由 `EntryCoordinator` 集中调度，新加派生 Provider 必须挂在 Coordinator 的失效集下。2026-07-20 起失效集下沉到 `WorkEntryRepository.watch()` 事件驱动（见 ADR-0006）；新增 Provider 只需在 `WorkEntryChange` listener 里挂一行失效即可，ADR-0002 静态清单已 Superseded。
- **一天可多条**：库 `date` 字段无 UNIQUE 约束（v3 迁移引入）。
- **Note Body 永远序列化为字符串**（Quill Delta JSON）——不要直接保存 `Document` 对象。
- "**iOS 原生 UI 的语言**" 由 Info.plist 的 `CFBundleLocalizations` 决定，**不归 Flutter 管**——和 `MaterialApp.locale` 是两套机制。改动 Info.plist 时注意保留原有 `CFBundleDisplayName` 等硬编码值。
- "**CI/CD 按分支分两套**"：main 上 CI + CD（pubspec 变才 release，tag `v...`）；dev 上 CI + 每次 push 都 release preview artifact（tag `preview/v...-sha`，Release 标 `prerelease: true`）。详见 ADR-0004。
- "**自动备份是后台异步**"——`EntryCoordinator` 的 save / delete 不等待 WebDAV 上传；备份失败仅 `debugPrint` 日志（未来若要可见再加状态指示）。见 ADR-0005（如有）
- "**自动备份 leading-edge 节流 30s**"——从**上次备份完成**算起；窗口内有 save 调用被吞掉。设这个而不是 trailing 是因为单次保存不该被延迟 30s。

## 与外部依赖的边界

- **本地路径**：`Helpers.getImagesDirectory()` 给图片／`DatabaseHelper.getDatabasePath()` 给 sqlite 文件；测试路径通过 `DatabaseHelper.setTestDbPath()` 注入。
- **云端**：仅 WebDAV（坚果云默认 URL 已硬编码在 `defaultWebDavUrl`）。不走 GitHub / Firebase / iCloud。
- **设置面板**：SharedPreferences 单例；新设置项 = `lib/services/settings_service.dart` 加 const key + provider 暴露。

## Revisions

| 日期       | 修订内容                                  | 来源                    |
| --------- | --------------------------------------- | ---------------------- |
| 2026-07-15 | 首次落稿；新增 EntryCoordinator 词条    | grill-with-docs Q1-Q4  |
| 2026-07-15 | 新增 iOS Native UI Surface 词条 + CFBundleLocalizations 概念 | grill-with-docs (iOS bug fix 跟进) |
| 2026-07-15 | 新增 Preview Build 词条 + CI/CD 按分支概念 | grill-with-docs (CI/CD 配置改 Q1-Q5) |
| 2026-07-19 | Backup Cycle 加注 fire-and-forget；新增"自动备份是后台异步"概念 | （性能反馈："保存日程，保存时间长"） |
| 2026-07-19 | Backup Cycle 加注 leading-edge 30s 节流；新增"自动备份 leading-edge 节流 30s"概念 | （接 grill Q1+L、Q2+30） |
| 2026-07-20 | 新增 WorkEntryRepository / WorkEntryChange 词条；EntryCoordinator / 派生缓存失效更新为 watch 事件驱动；ADR-0002 Superseded by ADR-0006 | grill-with-docs（架构评审 #1 Repository 接缝设计） |