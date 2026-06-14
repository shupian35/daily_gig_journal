# 2. BackupService 自动备份与清理 Mock 测试

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为 `BackupService` 的自动备份和清理逻辑添加 mock 测试。通过 mock WebDAV 的 HTTP 响应验证：配置检查、跳过逻辑、上传触发、30 天清理、失败静默。

## Acceptance criteria

- [ ] 未配置 WebDAV 时 autoBackup 静默跳过
- [ ] 已配置但 autoBackupProvider=false 时静默跳过
- [ ] 已配置且开启时调用 uploadFile，文件名符合 `daily_gig_backup_auto_*` 格式
- [ ] 上传成功后触发清理，30 天前的旧文件被删除
- [ ] 上传失败时不抛异常，清理失败不影响主流程
- [ ] `_parseTimestampFromName` 正确解析文件名中的时间戳

## Blocked by

None - can start immediately
