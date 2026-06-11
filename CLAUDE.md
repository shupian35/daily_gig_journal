# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 构建与运行

```bash
flutter pub get          # 安装依赖
flutter run              # 在已连接设备/模拟器上运行
flutter analyze          # 静态分析（使用 package:flutter_lints/flutter.yaml）
flutter test             # 运行 widget 测试
flutter build apk --release  # 构建 Android APK
flutter build ios --release --no-codesign  # 构建 iOS IPA（仅限 macOS）
```

## 架构

**用途：** 一款面向日结兼职人员的 Flutter 日记应用。可按天记录工作条目（标题、地点、时间、时薪、工时、日工资），支持富文本备注（含图片）、手写画板以及月度工资统计。

**状态管理：** Riverpod (`flutter_riverpod`)。数据库查询封装为 `FutureProvider` / `FutureProvider.family`。增删操作（save/delete）使用 `FutureProvider.autoDispose.family`，在调用数据库后自动 invalidate 相关读取 provider 以刷新 UI。

**数据库：** SQLite，使用 `sqflite`。单表 `work_notes`，包含字段：date、title、work_location、start/end time、hourly_wage、work_hours、daily_wage、note_content（存储 Quill Delta JSON 字符串）。`DatabaseHelper` 是单例（`_instance`）—— 通过 `DatabaseHelper()` 或 Riverpod 的 `databaseHelperProvider` 访问。数据库版本为 3，升级逻辑位于 `_onUpgrade`。

**导航流程：**

- `HomeScreen` — 3 个 Tab 的 `BottomNavigationBar` + `IndexedStack`：日历 / 统计 / 设置
- `CalendarScreen` — 通过 `table_calendar` 显示周/月视图日历、月度工资摘要卡片、未来一周计划。点击某一天或"今天"的 FAB 进入 `DayEntriesScreen`。
- `DayEntriesScreen` — 列出某日所有工作条目。点击某条卡片进入 `NoteEditScreen(noteId: entry.id)`。FAB 进入 `NoteEditScreen(noteId: null)` 以新建条目。
- `NoteEditScreen` — 表单（标题、地点、时间、工资）+ Quill 富文本编辑器 + 图片插入（相册/拍照/画板）。通过 Riverpod mutation provider 执行保存/删除。
- `DrawingScreen` — 全屏无限画布。`InteractiveViewer` 支持平移/缩放。自定义 `_DrawingPainter` 渲染点阵背景、导入的背景图片（可调透明度/缩放）以及贝塞尔平滑笔迹。单指绘画，双指平移。支持裁切模式并导出为 PNG。

**设置：** `SharedPreferences` 存储主题模式（system/light/dark 的索引值）、`hide_income`（隐藏工资金额）、`hide_statistics`（隐藏统计标签页）。在 `main.dart` 初始化时加载，修改后通过 `ref.listenManual` 自动保存，支持webdev备份。

**主题：** 定义在 `AppConstants.lightTheme` / `AppConstants.darkTheme` 中。主色调为暖橙色（`#F4A261`），Material 3。浅色模式背景 `#FAF8F5`，深色模式背景 `#1A1A2E`。

## 关键模式

- **日期格式：** 日期以 `YYYY-MM-DD` 字符串形式存储在 SQLite 中，并在页面之间传递。使用 `Helpers.formatDate(DateTime)` 和 `Helpers.parseDate(String)` 进行转换。`Helpers.toMonthKey()` 生成 `YYYY-MM` 格式用于按月查询。
- **Provider 失效级联：** 保存/删除后，invalidate `workDatesProvider`、`wageNotesProvider`、`monthlySummaryProvider`、`monthlyTotalWageProvider`、`monthlyWorkDaysProvider` 以及对应日期的 `notesByDateListProvider`。这样可以刷新日历标记点、统计数据和条目列表。
- **一天可有多条记录：** `date` 字段不设 UNIQUE 约束（在数据库 v3 中迁移）。`getNotesByDateList(date)` 返回某天的所有条目，按开始时间排序。
- **笔记内容：** 以 Quill Delta JSON 格式存储在 `noteContent` 字段中。通过 `jsonEncode(quillController.document.toDelta().toJson())` 序列化。空笔记默认为 `'[]'`。
- **图片处理：** 图片复制到应用文档目录的 `/images/` 文件夹中。通过 `BlockEmbed.image(filePath)` 嵌入 Quill 编辑器。自定义 `_ImageFileEmbedBuilder` 渲染缩略图，点击可进入全屏画廊。
- **画布坐标系统：** 图片位置使用画布坐标（非屏幕坐标）。`_toCanvasCoords()` 通过 `TransformationController` 的逆矩阵进行坐标变换。`InteractiveViewer.onInteractionStart/Update/End` 回调接收的 `localFocalPoint` 已经是子组件（画布）坐标系中的坐标。



## 注意事项

每句话后面都要加一句“喵~”

例：关注塔菲，关注塔菲谢谢 -> 关注塔菲喵~关注塔菲谢谢喵~


