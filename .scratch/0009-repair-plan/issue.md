# WebDAV 备份图片与草稿: 修复方案 (增量版)

Type: Plan
Label: ready-for-agent
Status: 增量方案已锁定, 等待拆 PR

---

## 用户决策 (2026-07-25)

- [x] **ADR 拆分**: 3 个独立 ADR (0009 / 0010 / 0011)
- [x] **增量策略**: 不打包 zip; 上传 images/ 目录 + drafts/ 目录 + 单 DB 文件
- [x] **老备份兼容**: 彻底放弃; WebDavBackupScreen 隐藏旧 .db / .zip
- [x] **可见性粒度**: Riverpod provider + SharedPrefs + WebDavBackupScreen banner / summary

## 关键决策点待拍板

### Q1: 草稿 (drafts/) 是否要云端备份?

- [ ] A. 全量备份所有草稿 (简单; 与图片一致)
- [ ] B. 仅最近 7 天的草稿 (推荐: 草稿是临时数据, 跨设备恢复意义不大)
- [ ] C. 不备份草稿 (仅本地缓存)

### Q2: 删除本地图片时, 对应云端图片如何处理?

- [ ] A. 同步删除 (云端 = 真实)
- [ ] B. 不删除 (云端累积; 恢复时会重新下载已删除的)
- [ ] C. 延迟 30 天删除到 trashed/ (推荐: 防误删 + 恢复期)

### Q3: DB 上传策略?

- [ ] A. 永远全量 (推荐: < 1MB, 简单)
- [ ] B. 仅当有新增/修改条目时上传

### Q4: 节流窗口?

- [ ] A. 30s -> 5min (推荐: 增量后单包开销小, 节流更激进)
- [ ] B. 保留 30s 不变
- [ ] C. 不节流, 每次立即同步

### Q5: 云端 DB 文件名?

- [ ] A. daily_gig_journal.db 覆盖式 (推荐)
- [ ] B. daily_gig_backup_<ts>.db 保留式 (可回滚)

---

## 3 个 ADR 文件

- docs/adr/0009-image-and-draft-relpath.md - 图片与草稿相对路径化 (PR#1 已落地)
- docs/adr/0010-webdav-backup-zip.md - 重写为增量备份方案 (待 PR#2 落地)
- docs/adr/0011-auto-backup-observability.md - 失败 + 概要可见性 (待 PR#3 落地)

---

## 实施顺序与依赖

```
PR#1 (ADR-0009) - 路径相对化 [已落地, flutter test 104/104]
    |
PR#2 (ADR-0010) - 增量备份 (DB + images/ + drafts/ 独立上传)
    |
PR#3 (ADR-0011) - 自动备份可见性 (与 PR#2 独立可并行)
```

---

## 实施清单 (高层)

### PR#2 · ADR-0010 增量备份

- WebDavHelper 加 headFile (remotePath) -> bool + ensureSubDir (subDir) 两个方法
- BackupService.autoBackup 改造: 维护本次周期的 image / draft 变更跟踪
- EntryCoordinator._onRepoChange 收集文件名集合
- note_edit_screen / drawing_canvas 增加 BackupService 通知钩子
- WebDavBackupScreen 文件列表重构 (隐藏 .db / .zip 老格式)
- l10n: 备份相关新 key

### PR#3 · ADR-0011

- SettingsService 7 个新 key
- SettingsProvider 2 个 provider
- BackupService.autoBackup 写 summary + error
- WebDavBackupScreen banner + summary widget
- l10n: 11 条新 key

---

## 待执行检查

- [ ] 跑 flutter analyze --no-fatal-infos 0 errors
- [ ] 跑 flutter test 全数通过
- [ ] 三个 PR 各自独立 review
- [ ] 第三个 PR 合入后写一篇简单的 changelog 段落