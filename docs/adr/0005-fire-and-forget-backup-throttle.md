---
status: Accepted
date: 2026-07-19
deciders: (grill-with-docs 流程用户)
---

# ADR-0005 · EntryCoordinator 自动备份：fire-and-forget + leading-edge 30s 节流

## Context

用户反馈（2026-07-19）：
> "保存日程，保存时间长"

追溯保存路径：`EntryCoordinator.save()` 末尾 `await _tryAutoBackup()` 把云端
WebDAV 上传 + 列目录 + 清旧档串在 mutation 关键路径里。每次保存体感时长
= DB 写入 + invalidate + WebDAV 往返 + 30 天旧档清理。

之前状态（在 commit `54485fd` 之前）：
```dart
Future<void> _tryAutoBackup() async {
  try {
    await BackupService.autoBackup(ref);
  } catch (_) {}
}
// save() / delete() 末尾：
await _tryAutoBackup();
```

`_tryAutoBackup` 已经是 best-effort（异常 swallow），但**网络耗时**稳定塞
在 `await` 里——即使 WebDAV 失败或超时，"保存"也要走完握手流程才能返回。

## Decision

两件事一起落地。

### 1. Fire-and-forget

```dart
void _tryAutoBackup() {
  unawaited(BackupService.autoBackup(ref));
}
```

save / delete 不再 `await _tryAutoBackup()`，备份在事件循环里跑完。
Coordinator 状态机（`AsyncLoading → AsyncData`）不受备份影响。

### 2. Leading-edge 节流 30 秒

```dart
static const _backupThrottleWindow = Duration(seconds: 30);
bool _isBackupRunning = false;
DateTime? _lastBackupCompletedAt;

void _tryAutoBackup() {
  if (_isBackupRunning) return;  // 已有备份在跑 → 跳过
  final last = _lastBackupCompletedAt;
  if (last != null &&
      DateTime.now().difference(last) < _backupThrottleWindow) {
    return;                       // 30s 窗口内 → 跳过
  }
  _isBackupRunning = true;
  unawaited(_runBackup());
}

Future<void> _runBackup() async {
  try {
    await BackupService.autoBackup(ref);
  } finally {
    _isBackupRunning = false;
    _lastBackupCompletedAt = DateTime.now();
  }
}
```

## 关键设计选择

### 为什么 leading edge 不是 trailing edge

Trailing edge debounce 在"用户保存 + 30s 内无新保存"才触发。问题：
- **单次保存也会被延迟 30s** —— UX 反而退步
- 本 app 的保存是 deliberate action（按保存按钮），不像打字机式连续输入

Leading edge：第一次保存立刻触发，后续 30s 内的 save 被合并。
- 单次保存：不延迟，立刻备份
- 连续多次保存：合并为一次

### 为什么窗口从"完成"算起，不是"启动"

| 基准 | 锁定窗口总长 | t=0 save + 5s 备份 + 30s 后 save |
|--|--|--|
| 从"启动"算 | 备份耗时 + 30s = 35s | t=35s 后窗口外 |
| 从"完成"算 | 同 35s | t=35s 后窗口外 |

"启动"算和"完成"算的**实际锁定时长相同**（都 = 备份耗时 + 30s），
但"完成"算的实现更简单：只在 backup finally 块里更新一次时间戳，无需在
"启动"时记 timestamp 算差。两种实现等价，本 ADR 选"完成"算。

### 为什么 30s 不是 5s / 60s / 可配置

| N | 优点 | 缺点 |
|--|--|--|
| 5s | 短延迟 | 6s 间隔保存就漏（典型"保存-改-保存"循环触发 2 次） |
| **30s（推荐）** | 覆盖典型 burst（修改-验证-修正 5-20s）；不延迟单次保存 | 用户保存后 30s 内杀 app，备份可能丢 |
| 60s | 更保守 | 用户保存后 60s 内大概率已离开 app，备份挂起时间过长 |
| 配置项 | 灵活 | Settings 多一个噪声项；30s 已经是足够合理的默认 |

**30s 漏一次**的成本 ≤ 用户手动重保存一次；用户感知"丢档"概率极低。

### 为什么 no UI observability

把 `_isBackupRunning` 暴露成 provider 让屏幕显示"同步中…"小图标：
- 状态机复杂度翻倍（screen listener + UI 适配）
- 需要 save / delete / snackbar 三处 UI 协调
- 用户当前反馈"保存慢"——已修。还没人反馈"不知道有没有同步"

现状：备份失败 silent。用户后续若问"备份到底跑了没"，再加 UI 状态层。

## Alternatives considered

| 方案 | 不取 |
|--|--|
| 维持 `await _tryAutoBackup()` | 用户感知"保存时间 = WebDAV 往返耗时"，违反对 save 应瞬时的预期 |
| `await` + UI spinner 显示"同步中…" | 屏幕层要做 listener / snackBar 一堆协调工作；save / delete 都要适配；复杂度高 |
| 仅 fire-and-forget，不加节流 | 多次连点保存触发 N 个 WebDAV PUT，浪费网络 / 配额 |
| Trailing edge 节流 | 单次保存延迟 30s，UX 反而退步 |
| 节流窗口做配置项 | Settings 多一个噪声；v1 不需要 |
| Throttle 从"启动"算 | 等价但实现复杂 |
| 把 `_isBackupRunning` 暴露成 provider | UI 复杂度翻倍；用户当前没反馈"不知道有没有同步" |
| 抽 `BackupService` 成接口以方便 mock 测试 | 超出本次改动 scope；当前 in-class state machine 4 个分支，code review 已能验证 |

## Consequences

### 正向

- 用户体感"保存时间" = DB 写入 + invalidate，毫秒级
- 多次连点保存只触发 1 次备份，省网络 / 配额
- 单次保存不等节流窗口，立刻备份
- 即使 WebDAV 慢 / 离线 / 失败，UI 也不被拖死
- Coordinator 状态机只反映 DB 写入成功与否，与备份解耦——更纯粹的语义

### 代价

- 用户保存后立即杀 app，那次备份可能未完成 → 30 天保留的坚果云历史可能漏一档记录
  - 影响极小：日常 app 后台存活几秒足够 30s 节流窗口外的备份跑完
  - 即便漏一档，下一次保存窗口外会重新触发
- 备份状态对 UI 不可见（"同步中…"小图标未做）；当前所有备份失败都是 silent
- 节流逻辑是 in-class state machine（`_isBackupRunning` + `_lastBackupCompletedAt`），没有专门的单元测试覆盖
  - 测试代价：需要 mock `BackupService.autoBackup` 或拆出接口，超出本次改动 scope
  - 状态机足够简单（4 个分支），code review 已能验证

### 反向影响

- 若以后 Coordinator 加新 mutation（archive / duplicate），调用 `_tryAutoBackup()`
  同样适用，节流逻辑不变
- 若以后引入多源 mutation（iCloud Drive 同步、Dropbox），节流逻辑得提到更高的
  协调层——本 ADR 假设单一 mutation 来源
- 本 ADR 在落地 commit `54485fd` **之后**才起稿——这是疏忽。未来 reviewer 看到节流
  逻辑却没有 ADR 时间窗口很短，已在 commit message 里补了概要

## 验证

- `flutter analyze`: `No issues found`
- `flutter test`: `+64: All tests passed`（节流没影响现有 save/delete 测试——它们
  都是单次调用，节流不影响最终 state）
- 用户后续若反馈"备份怎么没跑 / 漏档"，第一时间检查：
  1. `_lastBackupCompletedAt` 是否刚刚更新（应距 save 不到 30s + 备份耗时）
  2. `_isBackupRunning` 是否在 save 期间为 true（理论只有第一次触发为 true，后续 skip）
  3. `webDavConfiguredProvider` 配置是否还有效
  4. `_runBackup` 是否真的调用

## Status

Accepted。已落地于：
- `lib/providers/entry_coordinator.dart::_tryAutoBackup` + `_runBackup`
- `CONTEXT.md` Backup Cycle 词条 + 概念段 + Revisions 表

## 相关 ADR

- ADR-0001 · 集中 WorkEntry 变更语义（`EntryCoordinator` 的设计根源）
- ADR-0002 · EntryCoordinator 失效集的具体形态（`_invalidateFor` + `_invalidateForDate` 在同一文件里被 throttle 包住）
- ADR-0003 · 历史备忘：Provider 失效级联
- ADR-0004 · CI/CD 按分支分两套（dev preview 构建）