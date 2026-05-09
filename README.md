# 日程清单

帮助日结兼职人员轻松记录工作安排、笔记与工资统计。

## 功能

- **日历视图** — 周/月视图切换，标记有工作安排的日期，快速跳转
- **工作记录** — 添加每日工作条目：标题、地点、时间、时薪、时长、日工资
- **富文本笔记** — 图文混排备注，支持粗斜体、列表、引用、颜色
- **手写画板** — 全屏无限画布，贝塞尔平滑笔触，点阵背景
- **图片批注** — 导入图片、调整透明度、手写标注，双指缩放/平移
- **工资统计** — 月度柱状图，按月份汇总收入与工作天数
- **隐私保护** — 一键隐藏收入金额 / 统计页面
- **深色模式** — 跟随系统 / 浅色 / 深色 三种主题
- **数据管理** — 导出 CSV/JSON，数据库备份与恢复

## 技术栈

- **框架：** Flutter 3.41
- **状态管理：** Riverpod
- **数据库：** SQLite (sqflite)
- **富文本：** flutter_quill
- **图表：** fl_chart
- **日历：** table_calendar

## 快速开始

```bash
git clone https://github.com/shupian35/daily_gig_journal.git
cd daily_gig_journal
flutter pub get
flutter run
```

## 构建

```bash
# Android APK
flutter build apk --release

# iOS IPA（需要 macOS + Xcode）
flutter build ios --release --no-codesign
```

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   └── work_note.dart           # 工作笔记数据模型
├── database/
│   └── database_helper.dart     # SQLite 数据库操作
├── providers/
│   ├── notes_provider.dart      # 笔记数据提供者
│   └── settings_provider.dart   # 主题/隐私设置持久化
├── screens/
│   ├── home_screen.dart         # 底部 Tab 导航
│   ├── calendar_screen.dart     # 日历首页 + 月度工资 + 周计划
│   ├── day_entries_screen.dart  # 当天工作条目列表
│   ├── note_edit_screen.dart    # 笔记编辑（表单 + 富文本 + 图片）
│   ├── statistics_screen.dart   # 工资统计图表
│   ├── settings_screen.dart     # 设置（主题/隐私/导出/备份）
│   └── privacy_screen.dart      # 隐私开关
├── widgets/
│   ├── drawing_canvas.dart      # 手写画板（无限画布/笔触/裁切）
│   ├── note_form_fields.dart    # 结构化表单组件
│   ├── wage_summary_card.dart   # 月度收入摘要卡片
│   └── calendar_widget.dart     # 日历组件封装
└── utils/
    ├── constants.dart           # 主题/颜色常量
    ├── helpers.dart              # 日期/金额/文件工具函数
    └── export_helper.dart       # CSV/JSON 数据导出
```

## CI/CD

推送 `main` 分支自动触发 GitHub Actions 构建三平台产物并发布 Release：
- Android APK
- iOS IPA（无签名）
- ~~Web~~（已移除）
