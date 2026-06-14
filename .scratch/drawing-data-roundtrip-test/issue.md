# 1. Drawing 数据序列化往返测试

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为画板数据模型添加 JSON 序列化的往返测试。验证 `ImageLayer`、`StrokeData`、`CanvasDraft` 三个数据结构的 `toJson() → fromJson()` 往返一致性。

## Acceptance criteria

- [ ] `ImageLayer` 往返测试：创建带 Base64 图片数据的图层，序列化→反序列化，验证所有字段一致
- [ ] `StrokeData` 往返测试：创建含多点坐标的笔迹，序列化→反序列化，验证颜色和坐标
- [ ] `CanvasDraft` 完整草稿往返测试：含笔迹+图层+transform，序列化→反序列化，验证完整恢复
- [ ] `CanvasDraft.saveToFile/loadFromFile` 文件读写测试：写入临时文件→读回，验证一致
- [ ] Base64 图片恢复测试：删除原始图片文件后 fromJson 能从 Base64 恢复文件
- [ ] 沿用现有测试风格（group + test + 中文描述）

## Blocked by

None - can start immediately
