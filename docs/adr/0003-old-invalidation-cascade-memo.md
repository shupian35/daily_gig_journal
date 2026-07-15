---
status: Accepted
date: 2026-07-15
deciders: (grill-with-docs 流程用户)
---

# ADR-0003 · 历史备忘：Provider 失效级联

## Context

`AGENTS.md` 旧"关键模式"段曾要求每个写操作手写 7 行 `ref.invalidate(...)`。该规则曾是正确的（因为没有 Coordinator），但被 ADR-0001 + ADR-0002 取代之后变成历史包袱。

如果不留备忘：未来 explorer 在 AGENTS.md 看到旧规则（或在 git 历史 bisect 时翻到），可能误以为"失效级联"仍是有效模式，再次提议类似的"集中失效"方案、绕过 ADR-0001 的"集中变更"立场。

## Decision

仅作备忘存在。说明：

- **2026-07 之前**：两个 mutation provider（`saveNoteProvider`、`deleteNoteProvider`，原 `lib/providers/notes_provider.dart`）各自硬编码 7 行失效规则，AGENTS.md 强制要求新增派生 Provider 同步更新两端。
- **2026-07 起**：Coordinator 接管——`EntryCoordinator._invalidateCommon()` + `_invalidateFor(note)` / `_invalidateForDate(date)`。详见 ADR-0002。AGENTS.md "Provider 失效级联" 规则随之打上删除线并指向本 ADR。

## Alternatives considered

不适用——这是一份历史备忘，不是可讨论的设计。

## Status

Accepted（不升不降，仅作记录）。