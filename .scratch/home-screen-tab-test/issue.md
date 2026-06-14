# 9. HomeScreen Tab 动态增减 Widget Test

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为 HomeScreen 添加 widget test，验证开启/关闭隐藏统计时底部导航 Tab 的动态增减。

## Acceptance criteria

- [ ] 默认状态：导航栏显示"日历"和"设置"两个胶囊按钮（hideStatistics=false 时还有"统计"）
- [ ] 开启 hideStatistics：统计 Tab 从导航栏移除
- [ ] 关闭 hideStatistics：统计 Tab 恢复显示
- [ ] Tab 切换后 IndexedStack 正确显示对应页面
- [ ] 使用 `ProviderScope` + hideStatisticsProvider override

## Blocked by

None - can start immediately
