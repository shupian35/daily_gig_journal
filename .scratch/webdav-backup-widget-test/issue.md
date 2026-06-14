# 8. WebDavBackupScreen Widget Test

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为云备份页添加 widget test，验证配置表单和按钮状态。

## Acceptance criteria

- [ ] 服务器地址默认显示坚果云 URL
- [ ] 三个输入框存在：地址、账号、密码
- [ ] 密码框默认隐藏（obscure），可切换可见
- [ ] 未填写账号时测试连接按钮禁用
- [ ] 备份按钮和恢复按钮在未配置时禁用
- [ ] 自动备份开关存在，默认关闭
- [ ] 说明区域显示三条指引信息
- [ ] 使用 `ProviderScope` 包裹

## Blocked by

None - can start immediately
