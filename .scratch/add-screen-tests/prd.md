# PRD: 增加页面级 Widget 测试与集成测试覆盖

**Label**: `ready-for-agent`

## Problem Statement

当前 33 个测试全部覆盖数据层（WorkEntry 模型、Helpers 工具函数、DatabaseHelper CRUD），但七个屏幕页面零测试。用户修改 UI 或业务逻辑时没有安全网，回归问题只能在手动测试中发现。

## Solution

为核心页面添加 widget test，优先覆盖关键用户路径：创建条目 → 保存 → 列表展示 → 编辑 → 删除。针对自动备份和云备份流程添加集成级测试。

## User Stories

1. 作为开发者，我希望日历页有 widget test，验证日期选择导航和月度摘要渲染
2. 作为开发者，我希望条目列表页有空状态和含数据两种状态的测试
3. 作为开发者，我希望编辑页能测试表单保存和自动计算工资的联动
4. 作为开发者，我希望设置页能验证主题切换和隐私开关生效
5. 作为开发者，我希望统计页能验证图表在有数据和无数据时的渲染
6. 作为开发者，我希望云备份页能验证配置表单和按钮状态逻辑
7. 作为开发者，我希望画板的草稿保存/加载有单元级的 JSON 序列化往返测试
8. 作为开发者，我希望 BackupService 的 autoBackup 和清理逻辑有 mock 测试
9. 作为开发者，我希望导航栏在开启/关闭隐藏统计时正确增减 Tab

## Implementation Decisions

- Widget test 使用 `pumpWidget` + `ProviderScope` 包裹，已有 `widget_test.dart` 作为参考
- 数据库相关测试使用 `sqflite_common_ffi` + `setTestDbPath()` 注入，已有 `database_helper_test.dart` 作为参考
- BackupService 测试需要使用 mock WebDAV 或 fake HTTP client
- 画板草稿测试直接测试 `ImageLayer.toJson/fromJson` 和 `CanvasDraft.saveToFile/loadFromFile` 的往返一致性
- 统计图表测试仅验证 widget 存在（不验证像素级渲染）
- 保持现有测试风格：group + test，中文描述

## Testing Decisions

- 好测试的标准：验证外部行为（用户看到什么、操作后发生了什么），不验证内部实现
- 优先覆盖：用户最常走的路径（创建→保存→返回列表→看到新条目）
- 每个页面至少覆盖：空状态 + 正常数据状态
- 表单页额外覆盖：输入联动（改时间→自动算工时→自动算日工资）

## Out of Scope

- E2E 测试（需要真实设备）
- 画板的触摸手势模拟测试
- 性能测试
- WebDAV 真实网络连接的集成测试

## Further Notes

- 测试依赖 `sqflite_common_ffi` 已在 dev_dependencies 中
- DB 测试路径注入 `DatabaseHelper.setTestDbPath()` 已实现
- Provider 测试无需额外 mock，Riverpod 的 `ProviderScope` 支持 override
