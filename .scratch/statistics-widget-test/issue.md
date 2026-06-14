# 7. StatisticsScreen Widget Test

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为统计页添加 widget test，覆盖空状态、隐藏状态和正常数据状态的渲染。

## Acceptance criteria

- [ ] 无数据时显示"还没有工资记录"空状态
- [ ] 开启 hideStatistics 时显示盾牌隐私保护状态
- [ ] 有数据时渲染柱状图和月度详情卡片
- [ ] hideIncome 开启时工资金额显示为 ***
- [ ] "近6个月收入趋势"标题可见
- [ ] 使用 `ProviderScope` + 可 override 的 providers

## Blocked by

None - can start immediately
