---
status: Accepted
date: 2026-07-20
deciders: (grill-with-docs 流程用户)
---

# ADR-0006 · WorkEntryRepository 接缝 + watch 事件驱动的失效

## Context

2026-07-20 `improve-codebase-architecture` 评审识别出：
- `lib/providers/notes_provider.dart` 的 7 个 read FutureProvider 全是 3 行 pass-through（删减测试下整个文件可折叠成 1 行）
- `lib/utils/export_helper.dart` 直接 `DatabaseHelper()` 绕过 Riverpod
- `lib/screens/note_edit_screen.dart` 与 `lib/providers/entry_coordinator.dart` 都 `ref.read(databaseHelperProvider)` 直接调方法
- 9 个调用点全部摸到同一个具体类，SQL 与表名散落

评估为 **Strong** 候选；落地前 grill 三题：Q1 接口显式拆 add/update；Q2 watch 现在启用；Q3 filePath() 留 repo。

ADR-0002 当时接受 `_invalidateFor` / `_invalidateForDate` 静态清单为 EntryCoordinator 内置职责。本次深化决定把"什么变了"从写入方挪到 Repository 接缝，Coordinator 只挂监听。

## Decision

### 1. 新增 `WorkEntryRepository` 抽象接口

位置：`lib/data/work_entry_repository.dart`。

接缝面 = 13 动词：
- **Read**（9 个 find-verb）：`findByDate` / `findByRange` / `findByMonth` / `findAllWithWage` / `findById` / `workDates` / `monthlyTotal` / `monthlyDays` / `recentSummary`
- **Write**（3 个动词，**显式 add/update 不变式**）：
  - `Future<int> add(WorkEntry entry)` — `entry.id == null`；违反则 throw
  - `Future<void> update(WorkEntry entry)` — `entry.id != null`；违反则 throw
  - `Future<void> remove(int id)` — 实现内部 `findById(id)` 取 date 用于事件
- **Infra**：`Future<String> filePath()` + `Stream<WorkEntryChange> watch()`

### 2. 新增 `WorkEntryChange` sealed class

`Added(id, date)` / `Edited(id, date)` / `Removed(id, date)`，`date` 字段用于精准失效。

### 3. 两个 adapter

- **`SqliteWorkEntryRepository`**（现 `DatabaseHelper` 改造）：所有 SQL + 表名收拢此处，`StreamController<WorkEntryChange>.broadcast()` 在 add/update/remove 完成后 `add` 事件
- **`InMemoryWorkEntryRepository`**（测试 fake）：纯 `Map<int, WorkEntry>`，零 sqflite_ffi 仪式

### 4. EntryCoordinator 监听 watch

`build()` 里 `ref.read(repoProvider).watch().listen(_onRepoChange)` + `ref.onDispose(sub.cancel)`：

```dart
void _onRepoChange(WorkEntryChange change) {
  // 精准：按 change.date 失效该日 list
  ref.invalidate(notesByDateListProvider(change.date));
  // 表级：6 个聚合 provider
  ref.invalidate(workDatesProvider);
  ref.invalidate(wageNotesProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(monthlyTotalWageProvider);
  ref.invalidate(monthlyWorkDaysProvider);
  ref.invalidate(notesByDateRangeProvider);
}
```

ADR-0002 的 `_invalidateFor` / `_invalidateForDate` 整体下沉。

### 5. Coordinator.save 显式 add/update

```dart
if (note.id == null) await repo.add(note);
else await repo.update(note);
```

### 6. Coordinator.delete 瘦参

`delete({required int id})` — 不再要 `date:` 参数，实现查出来给事件用。

### 7. 调用方跟随改造

- `DayEntriesScreen._confirmDelete`：`delete(id: entry.id!, date: entry.date)` → `delete(id: entry.id!)`
- `NoteEditScreen._deleteNote`：同样去掉 `date:`

## Consequences

### 正向

- 接缝面 11 → 13 动词（多 2 个 write 换不变式检查 + 1 个 watch 抽象）
- SQL 收拢到 1 个适配器；9 个调用点跨同一接缝
- 失效清单**自动维护**：未来 archive / duplicate / merge（ADR-0001 路线图）每个新 mutation 自动复用 watch
- 测试用 InMemoryAdapter 替代 sqflite_ffi，AGENTS.md 测试模板可瘦身
- 删除 `_invalidateFor` / `_invalidateForDate` 共 ~14 行

### 代价

- EntryCoordinator.build() 加 subscription lifecycle（dispose 时取消）
- ADR-0002 静态清单被 watch 替代 → **ADR-0002 Superseded by ADR-0006**
- AGENTS.md "Provider 失效级联" 规则行需改写

### 风险与未来

- watch 是 broadcast stream，事件 dropped if no subscriber；当前 Coordinator 唯一订阅者，无 replay 需求
- 未来若多订阅者出现，需升级为 BehaviorSubject-like 缓冲
- `remove(int id)` 实现需 `findById(id)` 先查 date 用于事件；PK 查找成本忽略
- WebDAV backup 仍 `await ref.read(repoProvider).filePath()`，未触发 watch（备份是 IO，不是派生缓存）

## Alternatives considered

| 方案 | 不取 |
| --- | --- |
| **CQRS `query<T>(WorkEntryQuery<T>)`** | spec 类数量 ≈ 方法数量；Dart sealed 优势发挥不到接缝面；调用方每次 `query(ByDate(...))` 加 boilerplate |
| **11 方法 1:1 平移** | 接口宽度 = 实现宽度；删减测试下整个抽象被折叠；DEEPENING.md "两个 adapter 才算真接缝" 满足但深度为零 |
| **只留 watch() 接口、不实现（Q2 b）** | 现评审推翻；不接会让 archive / duplicate 落地时返工 |
| **拆 `WorkEntryStorage` 持有 filePath** | 拆出第二组接缝（Storage 接口 + 两个 adapter），违反"两个 adapter 才算真接缝"；filePath 无副作用、6 行不值得 |

## Follow-ups

- [ ] `lib/database/database_helper.dart` → `lib/data/sqlite_work_entry_repository.dart`，表名/列名常量迁入
- [ ] `lib/data/work_entry_change.dart` 新建 sealed class
- [ ] `lib/data/in_memory_work_entry_repository.dart` 新建（测试 fake）
- [ ] `lib/providers/notes_provider.dart` 7 个 read provider 退化为 1 行 `ref.watch(repoProvider).findByX(...)`
- [ ] `lib/utils/export_helper.dart` 改 `ref.read(repoProvider).findAllWithWage()`
- [ ] `lib/providers/entry_coordinator.dart` 删除 `_invalidateFor` / `_invalidateForDate`，`build()` 加 watch 订阅
- [ ] `lib/screens/day_entries_screen.dart` 与 `lib/screens/note_edit_screen.dart` 调用 `delete` 去掉 `date:`
- [ ] `test/database/database_helper_test.dart` → `test/data/sqlite_work_entry_repository_test.dart`
- [ ] 新增 `test/data/in_memory_work_entry_repository_test.dart`
- [ ] `test/providers/entry_coordinator_test.dart` 新增 3 个 watch 监听测试：(a) add 触发 notesByDateListProvider 失效 (b) remove 触发 workDatesProvider 失效 (c) build() 订阅在 dispose 时取消
- [ ] AGENTS.md "Provider 失效级联" 规则行改写
- [ ] CONTEXT.md 增加 **WorkEntryRepository** 与 **WorkEntryChange** 词条
- [ ] ADR-0002 status 改 "Superseded by ADR-0006"

## Status

Accepted。落地 commit 后续追加。

## 相关 ADR

- **ADR-0001**（前置）：EntryCoordinator 集中 WorkEntry 写入；本次保留并扩展
- **ADR-0002**（**Superseded**）：Coordinator 静态失效清单被 watch 路径替代
- **ADR-0003**（历史背景）：Provider 失效级联旧规则
- **ADR-0005**（独立）：自动备份 fire-and-forget + leading-edge 30s 节流；与本次无冲突