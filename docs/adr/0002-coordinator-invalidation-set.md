---
status: Superseded by ADR-0006
date: 2026-07-15
superseded-date: 2026-07-20
deciders: (grill-with-docs 流程用户)
parent: ADR-0001
---

# ADR-0002 · EntryCoordinator 失效集的具体形态

## Context

ADR-0001 决议：EntryCoordinator 拥有失效图谱（Decision 2）。本 ADR 收口两项子决策：
- **Q5 → H1**：失效集写在 Coordinator 文件内（hardcoded 列表）
- **Q6 → P**：family 化派生按单条精准清空（per-date），其它仍整族清空

## Decision

Coordinator 的实现骨架：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/work_entry.dart';
import '../providers/notes_provider.dart';        // workDates / wageNotes / monthly* / notesByDate*
import '../services/backup_service.dart';
import '../providers/settings_provider.dart';     // autoBackupProvider / webDavConfiguredProvider

class EntryCoordinator extends Notifier<AsyncValue<void>> {
  /// 每次写入必清的派生缓存。Review 时一眼可读。
  static const _afterEveryWrite = <ProviderListenable>{
    workDatesProvider,
    wageNotesProvider,
    monthlySummaryProvider,
    monthlyTotalWageProvider,
    monthlyWorkDaysProvider,
    notesByDateRangeProvider,    // range 不可枚举，保留整族
    notesByDateListProvider,    // 整族作为兜底
  };

  /// save 用：note 已知日期
  void _invalidateFor(WorkEntry note) {
    for (final p in _afterEveryWrite) ref.invalidate(p);
    ref.invalidate(notesByDateListProvider(note.date));
  }

  /// delete 用：params.date 已知
  void _invalidateForDate(String date) {
    for (final p in _afterEveryWrite) ref.invalidate(p);
    ref.invalidate(notesByDateListProvider(date));
  }

  Future<void> _tryAutoBackup() async {
    try {
      await BackupService.autoBackup(ref);
    } catch (_) {
      // 自动备份失败不打断 mutation 主流程（与现状一致）
    }
  }

  Future<void> save(WorkEntry note) async {
    state = const AsyncLoading<void>().copyWithPrevious(state);
    try {
      final db = ref.read(databaseHelperProvider);
      if (note.id != null) {
        await db.updateNote(note);
      } else {
        await db.insertNote(note);
      }
      _invalidateFor(note);
      await _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> delete({required int id, required String date}) async {
    state = const AsyncLoading<void>().copyWithPrevious(state);
    try {
      final db = ref.read(databaseHelperProvider);
      await db.deleteNote(id);
      _invalidateForDate(date);
      await _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

final entryCoordinatorProvider =
    NotifierProvider<EntryCoordinator, AsyncValue<void>>(EntryCoordinator.new);
```

### 失效清单规则

- `_afterEveryWrite` 是**写完后立刻清的派生缓存**——每个名字对应一个语义聚合（例：`workDatesProvider` 是"有工作安排的日期集合"）
- 静态清单与精准清空**并用**：静态清单负责"所有派生同步"，精准清空负责"单条窄域命中"
- range 保留整族清空：未来若引入多 range 视图（年历 / 月历），range 列表仍可保持单元素
- `notesByDateListProvider` 留在静态清单仅作**兜底**——正常路径由 `_invalidateFor` 末尾的 per-date 精准清空覆盖

### 待解决（不在本 ADR）

- 数据库调用直走 `databaseHelperProvider`——属 Candidate #2（Repository 接缝），落地时把那一块改成 `workEntryRepositoryProvider` 即可，本 ADR 不受影响

## Alternatives considered

| 方案 | 为什么不取 |
| --- | --- |
| **H2 · 反向自注册** | 派生 Provider 在 build 阶段 `attachToMutation(self)` 触发全局副作用，可读性↓，反向耦合让 Coordinator 不再是 A 派"中心" |
| **H3 · ProviderObserver** | 失效触发点从 Coordinator 移走；A 派"集中"严重稀释 |
| **Q6 → L · 全懒惰** | 当前屏幕只读单 family 变体时，L ≈ P；但若未来"全月汇总屏"一次订阅 365 个日期，差异显现 |
| **Q6 → A · 现状不对称** | 保留 range 整族 + dates 精准但混着用，Coordinator 内部"两种粒度并存"会让未来 explorer 必问"为什么 range 是整族"——选 P 后此问题彻底消失 |

## Consequences

### 正向

- A 派"集中"最纯正：失效清单单一文件名 `_afterEveryWrite`，review 时一眼可读
- 命中数据局部性：单条写入只清对应日期的 `notesByDateListProvider(date)`，跨日缓存不重建
- 备份触发点固定（`save` / `delete` 末尾），调试一目了然
- 静态清单与精准清空**职责分离**：前者管"每个 mutation 都影响什么"，后者管"这条 mutation 影响哪一格"

### 代价

- 新增派生 Provider 必须改 Coordinator 一个文件——A 派"集中"换来的限制
- `_invalidateFor` / `_invalidateForDate` 重复了一遍循环+精确清空的两行——可后续抽内部 `_invalidateAt(date)` 公共方法
- ~~数据库直走 `databaseHelperProvider`~~ → 属 Candidate #2，不在本 ADR

## Status

Proposed（与 ADR-0001 同步推进）。Implementation 落地后两条 ADR 同步升 Accepted。

## 相关 ADR

- **ADR-0001**（父）：集中 WorkEntry 变更语义——高层 4 条决策（A / N / γ / S）
- **ADR-0003**（待起）：仅作"AGENTS.md 旧规则曾存在"的备忘；落地于 Coordinator + 8 屏迁移完成后

## Superseded notice (2026-07-20)

本 ADR 的"静态失效清单"主张被 **ADR-0006** 的 watch 事件驱动路径替代：
- ADR-0002 的 `_invalidateFor` / `_invalidateForDate` 整体下沉到 `WorkEntryRepository.watch()` 事件监听
- "什么变了" 由 repository 在 add/update/remove 后通过 `Stream<WorkEntryChange>` 发出
- "谁要失效" 仍由 EntryCoordinator 决策，但触发点从写入同步路径改为 watch 异步路径

历史 ADR 保留以记录此前的设计取舍与备选方案。后续探索者请直接阅读 ADR-0006。