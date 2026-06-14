# 3. DayEntriesScreen Widget Test

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为条目列表页添加 widget test，覆盖空状态和含数据状态的渲染。

## Acceptance criteria

- [ ] 空状态测试：无数据时显示"当天还没有工作安排"文案
- [ ] 有数据测试：插入 2 条测试数据后，列表渲染 2 张条目卡片
- [ ] 卡片内容验证：标题、地点、时间范围、日工资正确显示
- [ ] FAB 存在且可点击
- [ ] 使用 `sqflite_common_ffi` + `setTestDbPath()` 注入测试数据
- [ ] 参考 `test/widget_test.dart` 的 ProviderScope 包裹模式

## Blocked by

None - can start immediately
