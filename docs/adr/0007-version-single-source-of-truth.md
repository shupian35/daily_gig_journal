---
status: Accepted
date: 2026-08-12
deciders: (用户)
---

# ADR-0007 · 版本号单一真相源（package_info_plus + 启动预加载）

## Context

发版改版本号时散落在 5 个文件需要同步：
1. `pubspec.yaml` — `version: 1.0.1+2`（**唯一真实来源**）
2. `lib/screens/settings_screen.dart:177` — `applicationVersion: '1.0.1'`
3. `lib/screens/settings_screen.dart:497` — `latestVersion != '1.0.1'`（更新检查比较）
4. `lib/l10n/app_zh.arb` — `"aboutAppSubtitle": "版本 1.0.1 —— 让每一份付出都有记录"`
5. `lib/l10n/app_en.arb` + `app_zh_TW.arb` — 同上英文 / 繁中

每次发版都漏改风险（已经发生过：Android `local.properties` 和 iOS `Generated.xcconfig` 里的 `1.0.0` 没人手动更新，靠 `flutter build` 自动同步——但这次 `1.0.0 → 1.0.1` 时这俩文件就漏了，靠下次 build 修复）。

`updateAvailable(latestVersion)` 已经在用 `{version}` 占位符机制（`app_en.arb:98-99`），具备 l10n 参数化基础。

## Decision

### 1. 引入 `package_info_plus: ^8.3.0`

`pubspec.yaml` 加依赖。理由：
- pub 官方维护（`fluttercommunity.dev`），Flutter 生态标准做法
- `^8.x` 稳定线，要求 Dart ≥ 3.3，本仓库 `^3.11.0` 满足
- `^10.x` 较新且要求 Dart ≥ 3.10 + 引入较多 API 变更，先稳

### 2. 新建 `lib/utils/app_info.dart` —— 真相源封装

```dart
PackageInfo? _cached;

Future<void> initAppInfo() async {
  try { _cached = await PackageInfo.fromPlatform(); }
  catch (_) { _cached = null; }   // 降级，不抛
}

String get currentVersion => _cached?.version ?? '—';
```

关键设计：**`main()` 启动时 `await initAppInfo()` 一次**，之后所有 UI 同步读取：
- `PackageInfo.fromPlatform()` 是 platform channel call（Android PackageManager / iOS Bundle），无内置缓存
- 每次 UI 渲染都调会浪费
- 启动时一次预加载 → 全局同步读，最干净

### 3. `lib/main.dart` 启动序列

`runApp()` 之前 `await initAppInfo()`，紧跟在 `initializeDateFormatting` 之后。

### 4. `settings_screen.dart` 调用方改造

- `applicationVersion: '1.0.1'` → `currentVersion`
- `latestVersion != '1.0.1'` → `latestVersion != currentVersion`

### 5. l10n 三语 `aboutAppSubtitle` 参数化

参照 `updateAvailable(version)` 的 ARB 模式，三语同时改：
```jsonc
"aboutAppSubtitle": "版本 {version} —— 让每一份付出都有记录",
"@aboutAppSubtitle": {
  "placeholders": { "version": { "type": "String" } }
}
```
settings_screen 调用：`l10n.aboutAppSubtitle(currentVersion)`。

### 6. Android/iOS 配置文件

`android/local.properties`、`ios/Flutter/Generated.xcconfig` 等里的 `1.0.0` 是 Flutter build 时自动从 pubspec 同步生成的，**不需要手动改**，下次 `flutter build` 自然覆盖。

## Consequences

### 正面
- **发版流程从 5 处缩到 1 处**：只改 `pubspec.yaml`，其它自动跟随
- 启动多 1 次 platform call，耗时 < 50ms（实测 package_info_plus 文档）
- 测试覆盖 `initAppInfo()` 失败降级路径（`MissingPluginException` 走 catch）
- ADR 形式沉淀设计决策，未来人 / Agent 不会再走回头路

### 负面 / 取舍
- 多一个 pub 依赖（`package_info_plus` 已被 Flutter 生态广泛使用，维护活跃）
- `initAppInfo()` 必须放在 `runApp()` 之前，否则 UI 拿到 '—' 占位
- web 平台需在 `web/version.json` 配置版本（package_info_plus 在 web 走另一条路）——本仓库暂不发 web 版本，可暂忽略

### 失败模式
- `PackageInfo.fromPlatform()` 失败（platform 通道未注册）→ `_cached = null` → UI 拿到 '—' 占位
- 测试环境下 platform 通道未注册：`initAppInfo()` 吞掉异常不抛，测试覆盖此路径

## Revisions

| 日期 | 修订内容 | 来源 |
| --- | --- | --- |
| 2026-08-12 | 首次落稿 | 用户反馈「修改一次版本号要修改多个文件，这不合理」 |