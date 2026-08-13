---
status: Accepted
date: 2026-07-21
deciders: (grill-with-docs 流程用户)
---

# ADR-0008 · 全局搜索 + 工作标签 / 分类：Repository 接缝扩宽

## Context

ADR-0006 落地后，`WorkEntryRepository` 接缝面有 13 个动词（9 read + 3 write + 1 infra），所有 SQL / 表名收拢在 `lib/data/sqlite_work_entry_repository.dart` 一处；写入统一走 `EntryCoordinator`；派生失效走 `WorkEntryRepository.watch()` 事件驱动。

但 2026-07-21 用户调研 `improve-codebase-architecture` 识别出两块**逃生口缺失**：

1. **数据量增长后找不到记录**：条目按月/按日查询足够，但"我那天写了什么"需要全文搜索；当前 `WorkEntryRepository` 没有 `search` 动词，UI 也没有搜索入口。
2. **无法按工种/对接人聚合**：`WorkEntry` 12 个字段全是结构化字段，**没有 tag/category**；用户无法区分"会展协助""餐饮传菜""搬货"等工种，统计页也没法按 tag 横切。

候选评估为 **Strong**；落地前 grill 三题：

- **Q1 · tag 存哪？** — 逗号分隔字符串列 vs 独立 `work_tags` 表 + 多对多关联 vs JSON 列。
- **Q2 · 搜索匹配范围** — 仅结构化字段 vs 含 `noteContent` 纯文本片段；LIKE 全表扫 vs SQLite FTS5 虚表。
- **Q3 · 标签管理 UI** — 列表项长按删除 vs 单独"管理标签"页（含重命名 / 删除 / 合并）。

ADR-0001 已经为"未来 archive / duplicate / merge 全部归 Coordinator 管"留出口。本次是首次**非 entry-level** 的写入（改的是已有 entry 的 tags 列、不增不删 entry），是否仍走 Coordinator 写路径需要明确。

ADR-0006 失效集当前 7 个 provider（`notesByDateListProvider` family + 6 个表级聚合），新功能需扩宽失效集。

## Decision

### 1. tags 字段：逗号分隔字符串列

`WorkEntry` 加 `final List<String> tags` 字段；`SqliteWorkEntryRepository` 加 `tags TEXT DEFAULT ''` 列（v5 迁移）；老数据 `tags=''` → 反序列化为 `const []`，**零侵入迁移**。

**token 边界**：`SqliteWorkEntryRepository.findByTag / renameTag / deleteTag / search` 中所有 `LIKE` 模式都用 `',tag,'` 包裹前后逗号（或 4 个分支：`= ? / LIKE 'tag,%' / LIKE '%,tag' / LIKE '%,tag,%'`），避免子串误匹配（`'会'` 命中 `'会展'`）。

不取多对多 `work_entry_tags` 表：
- 日结工典型 tag 数 < 30，单标签组合 < 5；
- 多对多表要 2 张表 + 2 次迁移 + N 个外键；
- 字符串列 SQL LIKE 性能在条目量级别（百-千）可接受。

### 2. Repository 接口扩宽（6 个新动词）

`WorkEntryRepository` 现有 13 动词 + 6 新动词 = 19 动词：

| 动词 | 类型 | 说明 |
|------|------|------|
| `allTags()` | Read | 去重升序返回所有 tag 字符串 |
| `findByTag(String tag)` | Read | 命中含独立 token 的 entry |
| `search({keyword, dateFrom, dateTo, tag})` | Read | 全文 + 日期 + tag 组合 AND；keyword 大小写不敏感，命中结构化字段 OR `note_content` 纯文本片段 |
| `renameTag({from, to})` | Write（不创建 entry） | 单事务替换 token + 去重；返回受影响行数 |
| `deleteTag(String tag)` | Write（不创建 entry） | 单事务从所有 row 移除 token |
| `mergeTag({from, to})` | Write | 显式 override = `renameTag(from, to)`，给 TagsScreen 用语义清晰别名 |

### 3. 关键词搜索实现细节（重要）

```dart
// SqliteWorkEntryRepository.search
where.add('(title LIKE ? OR work_location LIKE ? OR contact LIKE ? OR note_content LIKE ?)');
// LIKE 子串里 %, _, \ 三个特殊字符 escape，避免注入 / 误匹配
final like = '%${_escapeLike(kw)}%';
```

- **结构化字段** (`title / work_location / contact`)：直接 SQL LIKE。
- **`note_content`** (Quill Delta JSON)：SQL 层 `LIKE '%kw%'` + **实现层二次过滤**——把 Delta JSON 反序列化为纯文本后用 lowercase `contains` 校验，防止 JSON 操作符 / 嵌入图片的序列化片段误命中。
- **排序**：与 `findAllWithWage` 对齐——`date DESC, startTime ASC`。

条目量到 5k+ 时 LIKE 全表扫会出现性能边界（不在本次范围，见 Follow-ups）。

### 4. tag 写入路径：Repository 直发 `Edited` 事件，不经 Coordinator

`renameTag / deleteTag / mergeTag` 不是 entry-level mutation（不改 `id` / 不增删 row，仅改已有 row 的 `tags` 列）。但要触发**同一失效集**，所以：

- `SqliteWorkEntryRepository` 实现层：受影响 row 各发一条 `_changes.add(Edited(id, date))`，自然走到 `EntryCoordinator._onRepoChange` 失效链。
- `InMemoryWorkEntryRepository`：同上。
- **不经 Coordinator 的 `save()` 入口**：因为这些操作本质是"批量编辑"，不是单 entry 的 add/update；强迫走 `save()` 会让每次操作把整个 entry 拉出 → 改 → 写回，N 条 = N 次 UPDATE，丧失单事务原子性。

这是 ADR-0001 "Coordinator 集中 WorkEntry 变更语义" 边界的首次明确化：

> Coordinator 管 **entry-level mutation**（add / update / remove）。
> Repository 管 **bulk mutation over tags**（rename / delete / merge），但通过 `_changes.add(Edited(...))` 自动复用 watch 失效链。

### 5. 失效集扩宽

`EntryCoordinator._onRepoChange` 增加 3 行失效：

```dart
ref.invalidate(allTagsProvider);
ref.invalidate(entriesByTagProvider);
ref.invalidate(searchResultsProvider);
```

不破坏 ADR-0006 "新增派生 Provider 必须挂在 Coordinator 失效集" 的规则（AGENTS.md）。

### 6. Provider 设计

```dart
// 3 个 StateProvider 横向（搜索条件）
searchKeywordProvider        // String
searchDateRangeProvider      // ({DateTime? from, DateTime? to})
searchTagFilterProvider      // String?（null = 不限）

// 1 个 FutureProvider.autoDispose 监听三者重算
searchResultsProvider

// 2 个独立 provider（标签字典 + 单 tag 列表）
allTagsProvider              // FutureProvider<List<String>>
entriesByTagProvider         // FutureProvider.autoDispose.family<List<WorkEntry>, String>
```

不把 `searchResultsProvider` 做成 family — 三个 StateProvider 各自持有状态，已经够轻；family 化会引入"key 列表维护"负担。`searchKeywordProvider` 变更经 200ms debounce（SearchScreen 内部 `Timer`）写到 state，减少数据库抖动。

### 7. UI 落地

- **新 widget `TagsField`**：已选 chip + 输入框（Enter / `,` 提交）+ 建议 chip 行（来自 `allTagsProvider` 未选前 8 个）。
- **新 widget `TagChips`**（只读）：卡片 / 列表展示用，最多 N 个 + `+M` 兜底。
- **新页 `SearchScreen`**：搜索框（200ms debounce） + 横滑 chip（日期范围 / tag） + 按月分组结果 + 摘要头部（匹配 N / 总收入 / 工作天数）。
- **新页 `TagsScreen`**：列出 `allTagsProvider` + 每行 count（`entriesByTagProvider(tag).length`），三个 IconButton（重命名 / 合并 / 删除），操作期间遮罩防误触。
- **5 个已有屏集成**：
  - `NoteEditScreen` — 新 tags 卡片在表单下方
  - `DayEntriesScreen` — 卡片标题下 chip 行
  - `CalendarScreen` — AppBar 搜索 IconButton；未来一周 plan item 加 chip 行
  - `StatisticsScreen` — `ConsumerWidget → ConsumerStatefulWidget`，横滑 chip 切 `_selectedTag`
  - `SettingsScreen` — 数据组首项"管理标签"入口
- **导出**：`ExportHelper` CSV 表头加"标签"列（`|` 分隔转义），JSON 加 `tags: List<String>`。

### 8. l10n

`app_zh.arb` / `app_en.arb` / `app_zh_TW.arb` 同步加 25 条 key（`search` / `searchHint` / `searchEmpty` / `searchEmptyHint` / `searchResultsCount` / `searchFilterTag` / `searchFilterAllTags` / `searchFilterDateRange` / `searchDateRangeAll` / `searchClearFilters` / `searchTotalIncome` / `searchWorkDays` / `searchAllTimeFilter` / `tags` / `tagsHint` / `tagsEmpty` / `tagsAddTag` / `tagsManage` / `tagsManageSubtitle` / `tagsRename` / `tagsDelete` / `tagsDeleteConfirm` / `tagsCount` / `tagsSuggestedTags` / `tagsStatisticsByTag` / `tagsNoCount` / `tagsRenameDialogTitle` / `tagsRenameLabel` / `tagsMerge` / `tagsMergeTargetHint` / `tagsMergeConfirm` / `tagsMoreCount`），`flutter pub get` 触发 `gen-l10n` 自动生成。

## Consequences

### 正向

- 接缝面 13 → 19 动词；保留 ADR-0006 "两个 adapter 才算真接缝" 原则。
- 双 adapter 完全对称：22 个新增测试全在 `InMemoryWorkEntryRepository`，SQLite 走 `sqlite_work_entry_repository_test.dart` 的同等覆盖。
- tag 操作走单事务，失败回滚（参 `BackupService.safeOverwrite` 模式）。
- 派生失效统一在 `_onRepoChange`，新增 Provider 不破坏 AGENTS.md 规则。
- UI 增量对老用户零侵入（tags 列 DEFAULT ''，老数据视为无 tag）。
- `mergeTag` 接口签名让 TagsScreen 调用语义清晰（"把 from 归并到 to"）；底层委托 `renameTag`，无重复实现。

### 代价

- **写入边界扩张**：ADR-0001 集中写入的"集中"被首次削弱——`renameTag / deleteTag / mergeTag` 不经 Coordinator.save。需要清楚文档化（见 Decision §4）并接受。
- **`searchResultsProvider` 不能用 family**：因为三个 StateProvider 持有状态，URL / bookmarkable link 等场景下不可序列化；当前不需要，可接受。
- **LIKE 全表扫**：条目数 > 5k 时性能下降。本次不优化。
- **3 处 UI 集成点**：DayEntriesScreen / CalendarScreen / StatisticsScreen 都加 chip 行 / 切 tag，~120 行 UI 改动。
- **`MergeTag` interface method 必须两个 adapter 显式 override**：Dart `abstract class` 默认实现不满足接口实现要求（即便有 body），这是 Dart 语言约束不是设计缺陷。
- **iOS native UI Surface 不动**（CONTEXT.md §iOS Native UI Surface）：本次纯 Flutter 树内变更，Info.plist `CFBundleLocalizations` 不需改。

### 反向影响

- **AGENTS.md "Provider 失效级联" 规则**：仍成立——本次新增 3 个失效行就是这条规则的应用；无修改。
- **ADR-0001（EntryCoordinator 集中写入）**：Decision §4 首次明确 Coordinator 的边界——entry-level 走 Coordinator，bulk-mutation-over-tags 走 Repository（仍触发失效）。**不需要 Superseded**，需要补一句"Coordinator 管 entry-level"。
- **ADR-0006（Repository 接缝）**：失效集扩宽从 7 → 10 provider（`notesByDateListProvider` family 算 1 个 + 6 表级聚合 + 3 新增）；仍走 watch 事件驱动，不破坏 watch 路径。
- **CONTEXT.md 词条**：`WorkTag` / `WorkEntry.tags` / `Backup Cycle` 节 不受影响；`EntryCoordinator` 节可补"边界"一段。
- **导出 CSV schema**：从 13 列扩到 14 列（加"标签"）。下游消费 CSV 的脚本需更新；本项目无外部消费方，可接受。
- **WorkEntry.toString**：debug 日志多一字段 `tags: [...]`。

## Alternatives considered

| 方案 | 不取 |
| --- | --- |
| **独立 `work_tags` 表 + `work_entry_tags` 多对多** | 2 张表 + 2 次迁移 + N 个外键；典型 tag 数 < 30 时反而是负担；CQRS 模式收益 > 本项目规模 |
| **tag 字段为 JSON 列** | Dart 端处理 JSON 增加序列化复杂度；SQLite 没有原生 JSON 操作符；要靠 `json_each` 等扩展（`sqflite_common_ffi` 不一定支持） |
| **SQLite FTS5 全文虚表** | 性能边界未到（条目量级别千-万），引入虚表 + 触发器同步 = 复杂度溢价；tokenization 中文 / 英文差异要分词器；本期 not worth |
| **只匹配结构化字段（不动 noteContent）** | 用户高频搜索意图是"我那天写了什么"——纯结构化漏掉 Quill 富文本里大量内容 |
| **`searchResultsProvider` 用 family 包 4 元组 key** | 三个 StateProvider 已经够轻；family 化要维护 key 拼接/解析；查询条件本身需要 UI 维持，不是 URL 状态 |
| **搜索页走 Navigator route 替代 IndexedStack tab** | 已选；保持 2-3 Tab 简洁（CLAUDE.md / AGENTS.md "精致杂志风" 隐含约定） |
| **`renameTag` / `deleteTag` 走 `EntryCoordinator.save()`** | 每次操作要 fetch 整个 entry → 改 → save；N 条 = N 次事务，丧失原子性 |
| **`tags` UI 在 `NoteFormFields` 内部加字段** | `NoteFormFields` 是纯结构化字段组件（已封装 8 个 controller）；tags 是列表型态，破坏单一职责 |
| **`TagsScreen` 用 `FutureProvider.family<TagInfo, String>`** | count 在 build 时拉（`entriesByTagProvider(tag).length`），并发请求 30 个 provider 对典型规模 < 30 tag 集合可接受；family 化反而引一个"tag → TagInfo 派生" 不必要的中间层 |
| **重命名 / 合并走 SQL `UPDATE ... SET tags = REPLACE(...)`** | 子串替换会误改 `'会展'` → `'展览'` 中间字符；必须用 token 边界 + 显式 Python-style split；本次走 Dart 层 split/join 显式更安全 |

## Follow-ups

- [x] `WorkEntry` 加 `tags` 字段
- [x] `SqliteWorkEntryRepository` v5 迁移加 `tags` 列
- [x] `WorkEntryRepository` 接口 + 两个 adapter 加 6 个新动词
- [x] `notes_provider.dart` 加 5 个新 Provider（3 StateProvider + 1 FutureProvider + 1 family）
- [x] `EntryCoordinator._onRepoChange` 失效集加 3 行
- [x] 三语 arb + gen-l10n 25 条新 key
- [x] `TagsField` + `TagChips` widget
- [x] `SearchScreen` / `TagsScreen` 新页面
- [x] `NoteEditScreen` / `DayEntriesScreen` / `CalendarScreen` / `StatisticsScreen` / `SettingsScreen` 集成
- [x] `ExportHelper` CSV/JSON 加 tags 字段
- [x] `test/data/repository_search_test.dart` 22 个新测试
- [x] `flutter analyze --no-fatal-infos` 0 errors；`flutter test` 89/89 通过
- [x] **ADR-0006 Follow-up**：失效清单同步为 10 provider（7 + 3），在 ADR-0006 加 "后续扩宽（ADR-0008）" 小节落地
- [x] **CONTEXT.md Follow-up**：`EntryCoordinator` 词条扩展"边界"段，明确 bulk-mutation-over-tags 不经 save；同步 ADR-0008/ADR-0006 引用
- [ ] **未来 · tag emoji 选色器**：本期只用 chip 显示；下一 sprint 给 `TagsField` 加可选 emoji 字段
- [ ] **未来 · search 性能监控**：条目数 > 5k 时升级 SQLite FTS5；监控点可放在 `SqliteWorkEntryRepository.search` 入口
- [ ] **未来 · 标签导入 / 导出**：当前 CSV/JSON 仅导出 tags 字符串，无对导入的"标签字典修复"工具；可加 `ImportHelper.normalizeTags()`

## Status

Accepted。落地 commit `3735b62` 已 push 到 `origin/dev`；CI 走 preview release（ADR-0004 §分支策略）。

## 相关 ADR

- **ADR-0001**（前置 · EntryCoordinator 集中写入）：本次扩宽 Coordinator 边界——entry-level 走 Coordinator，bulk-mutation-over-tags 走 Repository（仍触发 watch 失效链）
- **ADR-0006**（前置 · Repository 接缝）：接缝面 13 → 19 动词；失效集 7 → 10 provider；watch 路径不破坏
- **ADR-0002**（**Superseded** by ADR-0006）：无变化
- **ADR-0003**（历史背景）：无变化
- **ADR-0004**（独立 · CI/CD 分支策略）：落地 commit push 到 dev 触发 `release-preview` job
- **ADR-0005**（独立 · 自动备份 fire-and-forget）：无冲突（tags 操作触发 watch 失效，备份路径独立）
- **ADR-0007**（独立 · 版本号真相源）：无冲突