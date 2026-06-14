# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 构建与运行

```bash
flutter pub get          # 安装依赖
flutter run              # 在已连接设备/模拟器上运行
flutter analyze          # 静态分析（使用 package:flutter_lints/flutter.yaml）
flutter test             # 运行测试（33 tests，覆盖 model/helper/db/widget）
flutter build apk --release  # 构建 Android APK
flutter build ios --release --no-codesign  # 构建 iOS IPA（仅限 macOS）
```

## 架构

**用途：** 一款面向日结兼职人员的 Flutter 日记应用。可按天记录工作条目（标题、地点、时间、时薪、工时、日工资），支持富文本备注（含图片）、手写画板以及月度工资统计。

**状态管理：** Riverpod (`flutter_riverpod`)。数据库查询封装为 `FutureProvider` / `FutureProvider.family`。增删操作（save/delete）使用 `FutureProvider.autoDispose.family`，在调用数据库后自动 invalidate 相关读取 provider 以刷新 UI。画板 (`DrawingScreen`) 使用纯 `setState`，因为其状态不需要跨页面共享。

**数据模型：** `WorkEntry` — 工作条目，对应数据库 `work_notes` 表。11 个字段：id、date、title、workLocation、startTime、endTime、hourlyWage、workHours、dailyWage、noteContent（Quill Delta JSON）、createdAt、updatedAt。

**数据库：** SQLite，使用 `sqflite`。`DatabaseHelper` 是单例（`_instance`）—— 通过 `DatabaseHelper()` 或 Riverpod 的 `databaseHelperProvider` 访问。数据库版本为 3，升级逻辑使用显式列名迁移。支持 `setTestDbPath()` 注入测试路径。

**服务层：** `BackupService` 统一封装本地备份、云备份（WebDAV）、自动备份逻辑。`safeOverwrite()` / `safeWriteBytes()` 在覆盖前自动创建 `.bak` 备份。自动备份每次保存/删除后触发，30 天自动清理。

**导航流程：**

- `HomeScreen` (ConsumerStatefulWidget) — `IndexedStack` + 自定义底部导航栏。开启隐藏统计后统计 Tab 从导航中移除（2 Tab：日历 / 设置）。
- `CalendarScreen` — 通过 `table_calendar` 显示周/月视图日历、月度工资摘要卡片、未来一周计划。点击某一天或 FAB 进入 `DayEntriesScreen`。
- `DayEntriesScreen` — 列出某日所有工作条目。点击某条卡片进入 `NoteEditScreen(noteId: entry.id)`。FAB 进入 `NoteEditScreen(noteId: null)` 以新建条目。
- `NoteEditScreen` — 表单（标题、地点、时间、工资）+ Quill 富文本编辑器 + 图片插入（相册/系统相机/画板）。通过 Riverpod mutation provider 执行保存/删除。保存/删除后自动触发 WebDAV 云备份（如果已配置并开启）。
- `DrawingScreen` — 全屏无限画布。`InteractiveViewer` 支持平移/缩放。`_DrawingPainter` 渲染点阵背景、图片图层（含 Base64 嵌入）、贝塞尔平滑笔迹。单指绘画，双指平移。裁切导出 PNG。草稿保存/加载嵌入图片 Base64 数据。
- `CameraScreen` — （已移除，目前使用系统相机 API）
- `WebDavBackupScreen` — WebDAV 云备份配置与手动操作。默认坚果云地址。

**设置：** `SharedPreferences` 存储主题模式、`hide_income`、`hide_statistics`、WebDAV 配置（url/username/password）、`auto_backup`。在 `main.dart` 初始化时加载，修改后通过 `ref.listenManual` 自动保存。

**云备份：** 支持 WebDAV（坚果云默认）。`WebDavHelper` 封装 PROPFIND/PUT/GET/DELETE/MKCOL。备份存储在 `daily_gig_journal/` 子目录下。自动备份在保存/删除条目后静默执行，失败不打扰用户。保留策略：30 天。

**主题：** 定义在 `AppConstants.lightTheme` / `AppConstants.darkTheme` 中。主色调温润琥珀 `#C8895A`，Material 3。浅色模式背景 `#FBFAF7`（暖纸色），深色模式背景 `#1B1B22`。

## 关键模式

- **日期格式：** 日期以 `YYYY-MM-DD` 字符串形式存储在 SQLite 中，并在页面之间传递。使用 `Helpers.formatDate(DateTime)` 和 `Helpers.parseDate(String)` 进行转换。`Helpers.toMonthKey()` 生成 `YYYY-MM` 格式用于按月查询。
- **Provider 失效级联：** 保存/删除后，invalidate `workDatesProvider`、`wageNotesProvider`、`monthlySummaryProvider`、`monthlyTotalWageProvider`、`monthlyWorkDaysProvider` 以及对应日期的 `notesByDateListProvider`。
- **一天可有多条记录：** `date` 字段不设 UNIQUE 约束（在数据库 v3 中迁移）。`getNotesByDateList(date)` 返回某天的所有条目，按开始时间排序。
- **笔记内容：** 以 Quill Delta JSON 格式存储在 `noteContent` 字段中。通过 `jsonEncode(quillController.document.toDelta().toJson())` 序列化。空笔记默认为 `'[]'`。导出 CSV 时自动转为纯文本。
- **图片处理：** 图片复制到应用文档目录的 `/images/` 文件夹中。通过 `BlockEmbed.image(filePath)` 嵌入 Quill 编辑器。`_ImageFileEmbedBuilder` 渲染缩略图，点击可进入全屏画廊。
- **画布坐标系统：** 图片位置使用画布坐标（非屏幕坐标）。`_toCanvasCoords()` 通过 `TransformationController` 的逆矩阵进行坐标变换。草稿 JSON 嵌入图片 Base64，恢复时不依赖原始文件。
- **数据库恢复安全：** 恢复前自动创建 `.bak` 备份，写入失败时回滚。
- **术语：** 代码中用 `WorkEntry`（工作条目），数据库表名保持 `work_notes` 不变。

## 注意事项

每句话后面都要加一句"喵~"
例：关注塔菲，关注塔菲谢谢 -> 关注塔菲喵~关注塔菲谢谢喵~

在修改代码之后，不要自动推送代码到github中。在有明确指令的情况下才推送代码。

## Agent skills

### Issue tracker

GitHub Issues — 使用 `gh` CLI 操作。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认标签名：`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`。详见 `docs/agents/triage-labels.md`。

### Domain docs

Single-context 布局：根目录 `CONTEXT.md` + `docs/adr/`。详见 `docs/agents/domain.md`。
