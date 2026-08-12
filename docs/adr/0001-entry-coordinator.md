---
status: Proposed
date: 2026-07-15
deciders: (grill-with-docs 流程用户)
---

# ADR-0001 · 集中 WorkEntry 变更语义

## Context

今天 `lib/providers/notes_provider.dart` 中两个 mutation provider（`saveNoteProvider`、`deleteNoteProvider`）各自手写 7 行 `ref.invalidate(...)`。AGENTS.md 已经把"任一派生 Provider 出现，必须 invalidate 到这两个 mutation"写成项目级别的**规则**——这本身就是接缝渗漏的信号：

- mutation 数量增长时，维护成本指数上升（archive / duplicate / merge 任一出现都让失效清单再复制一遍）
- "我们改了什么 → 应该失效什么" 的语义信息被埋在 6+ 个 `ref.invalidate` 调用里，调试时追帧栈吃力
- 自动备份 (`_tryAutoBackup`) 与 mutation 实现共存，难以独立审视 / 重放

架构评估（`improve-codebase-architecture`）2026-07-15 把"变更事件的失效级联"列为 **Strong** 候选。

## Decision

新增 `EntryCoordinator : Notifier<AsyncValue<void>>`：

1. **集中变更**：`save(WorkEntry)` / `delete(int id)` 是唯一写入入口。未来 archive / duplicate / merge 全部归 Coordinator 管。
2. **集中失效**：Coordinator 维护一份失效清单 `_afterEveryWrite`，外加单条精准清空 `_invalidateFor(note.date)`。代码骨架见 **ADR-0002**。
3. **内联自动备份**：`save()` / `delete()` 末尾直接 `await _tryAutoBackup(ref)`。Coordinator imports `BackupService` + 两个 settings providers，耦合是有意识的，非偶然。
4. **状态单发错误**：mutation 方法 catch 内部异常 → `state = AsyncError(e)` → 返回 `Future<void>` 不抛。错误信号统一从 `state` 流走；screens 改用 `ref.listen(entryCoordinatorProvider, ...)` 替代 try/catch。

## Consequences

### 正向

- 新增派生 Provider：只动 Coordinator 一个文件
- Mutation + 副作用 + 失效表达集中，便于审查
- 自动备份触发点固定，调试一目了然
- 错误信号唯一，与 Riverpod Notifier 形态保持一致（状态机模型）
- 8 张屏幕里的错误处理从 try/catch 迁移后，未来新增 screen 默认就走 Notifier 路径，无歧义

### 代价

- 8 张屏幕里的错误处理需迁移（try/catch → `ref.listen`），是项目里最大单点改动
- Coordinator 自身引入对 `BackupService` 和 `autoBackupProvider` / `webDavConfiguredProvider` 的依赖（γ 的代价）
- 新增派生 Provider 必须改 Coordinator（统一写入一侧的代价）

### 反向影响

- AGENTS.md 的"Provider 失效级联"规则将在迁移完成后被删除（详见 Follow-up #1）

## Alternatives considered

| 方案 | 为什么不取 |
| --- | --- |
| **B · 只集中失效图谱** | mutation 实体仍在两处；新增 mutation 仍要复制失效清单，未根治 |
| **C · ProviderObserver 自动失效** | 副作用触发点从 Coordinator 移走，调试时需追帧栈，且无法表达"哪些派生应该失效"的业务意图——"集中"被严重稀释 |
| **双 Notifier (Q3 β)** | 立即回到"两个 mutation 各自持有失效清单"的现状 |
| **family 化 Notifier (Q3 F)** | 仅一个 `EntryCoord`，引入 family 凭空加概念负担 |
| **异步 throw 错误 (Q4 E)** | 维持双通道（future 抛 + state 显示），违反单一信号原则 |
| **H2 · 反向自注册** | 派生 Provider 在 build 阶段 `attachToMutation` 触发全局副作用，可读性掉档，且打破 A 派"集中"立场 |
| **H3 · ProviderObserver 失效** | 同上 ProviderObserver 选项；"集中"严重稀释 |
| **A 派 vs B 派之争的 B 派** | 只把失效集集中，mutation 实体仍分裂——半截命题 |
| **Provider Scope 隔离** | 不可行——单 isolate、单 ProviderScope，全局共享 |

## Follow-ups

- [ ] **#1 · 删 AGENTS.md "Provider 失效级联" 规则**：Coordinator 落地 + 8 张屏幕迁移完成后，AGENTS.md 那段失效规则变成纯历史包袱。届时新写 **ADR-0003** 仅作"曾经记录过"的备忘，免去未来 explorer 重提同样建议。预计一句话总结："原 2026-07 之前 `notes_provider.dart` 的两处 mutation 各硬编码 7 行失效；现统一收敛到 `EntryCoordinator`，见 ADR-0001。"
- [ ] **#2 · Candidate #2（Strong）落地**：Coordinator 内的 `ref.read(databaseHelperProvider).updateNote(...)` 仍直走单例。下一步抽 `WorkEntryRepository` 接口 + InMemory 适配器，让 widget 测试不再启 sqflite_ffi。规模可控，预计一个 PR。
- [ ] **#3 · Candidate #3（Worth exploring）评估**：`WageCalculator` 模块抽象——纯函数化工资三件套推导。StatisticsScreen 可复用，screen 减重。
- [ ] **#4 · Candidate #4（Speculative）评估**：`AppConstants` 拆分（设计 token / Theme 工厂）。优先级最低。

## Status

Proposed。**ADR-0002** 已收口 H1 + P 两项子决策；Controller 落地 + 8 屏错误路径迁移完成后，本 ADR 与 ADR-0002 同步升 Accepted。