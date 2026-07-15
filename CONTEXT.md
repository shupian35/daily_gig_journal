# CONTEXT.md · 日记清单 (daily_gig_journal)

领域词汇表 (domain glossary)。单 context 仓库；更细的格式约定见 `docs/agents/domain.md`。

> 最后修订：2026-07-15 · 由 `grill-with-docs` 流程结晶产生；当日跟进 iOS 系统组件本地化 bug fix

## 核心术语

| 术语 | 含义 | 对应代码 |
| --- | --- | --- |
| **WorkEntry** | 一条工作日记（标题、地点、对接人、工时、工资三件套、正文） | `lib/models/work_entry.dart`，库表 `work_notes` |
| **Wage Spec** | 工资三件套：`hourlyWage × workHours = dailyWage`，双向推导 | `lib/utils/helpers.dart::calculateWorkHours`；未来归 `WageCalculator` 模块 |
| **Note Body** | 富文本正文，Quill Delta JSON 格式；嵌图走 `BlockEmbed.image` | `noteContent` 字段；`jsonEncode(quill.Document.toDelta().toJson())` |
| **Calendar View** | 月/周日历视图；标点来自 `workDatesProvider` | `lib/screens/calendar_screen.dart` |
| **Backup Cycle** | 一次"本地 → 云端（WebDAV）"备份回合；保留 30 天 | `lib/services/backup_service.dart` |
| **Settings Surface** | 主题/隐私/云端/语言设置，持久化到 `SharedPreferences` | `lib/services/settings_service.dart` |
| **EntryCoordinator** | 集中所有 WorkEntry 写入与未来 archive/duplicate/merge 的 Notifier；同地点触发失效图谱与自动备份 | `lib/providers/entry_coordinator.dart`（待新建，见 ADR-0001） |
| **Worker Hours** | `startTime - endTime` 的小时数（小数保留 1 位） | `Helpers.calculateWorkHours(start, end)` |
| **Work Week Plan** | 今天起未来一周的条目预览，按日期聚组 | `CalendarScreen._buildUpcomingWeekPlan` |
| **iOS Native UI Surface** | iOS 系统渲染的 UI 组件（不在 Flutter 树里）。iOS 用 Info.plist `CFBundleLocalizations` 决定走哪国语言 | 长按输入框的 UIEditMenuInteraction、`image_picker` 的 UIImagePickerController、系统分享面板 |

## 概念上的提法

- "**变更语义**" 一律经过 `EntryCoordinator`，**禁止**屏幕直接调 `DatabaseHelper.update/insert/delete`。理由见 ADR-0001。
- "**派生缓存失效**" 由 `EntryCoordinator` 集中调度，新加派生 Provider 必须挂在 Coordinator 的失效集下。
- **一天可多条**：库 `date` 字段无 UNIQUE 约束（v3 迁移引入）。
- **Note Body 永远序列化为字符串**（Quill Delta JSON）——不要直接保存 `Document` 对象。
- "**iOS 原生 UI 的语言**" 由 Info.plist 的 `CFBundleLocalizations` 决定，**不归 Flutter 管**——和 `MaterialApp.locale` 是两套机制。改动 Info.plist 时注意保留原有 `CFBundleDisplayName` 等硬编码值。

## 与外部依赖的边界

- **本地路径**：`Helpers.getImagesDirectory()` 给图片／`DatabaseHelper.getDatabasePath()` 给 sqlite 文件；测试路径通过 `DatabaseHelper.setTestDbPath()` 注入。
- **云端**：仅 WebDAV（坚果云默认 URL 已硬编码在 `defaultWebDavUrl`）。不走 GitHub / Firebase / iCloud。
- **设置面板**：SharedPreferences 单例；新设置项 = `lib/services/settings_service.dart` 加 const key + provider 暴露。

## Revisions

| 日期       | 修订内容                                  | 来源                    |
| --------- | --------------------------------------- | ---------------------- |
| 2026-07-15 | 首次落稿；新增 EntryCoordinator 词条    | grill-with-docs Q1-Q4  |
| 2026-07-15 | 新增 iOS Native UI Surface 词条 + CFBundleLocalizations 概念 | grill-with-docs (iOS bug fix 跟进) |