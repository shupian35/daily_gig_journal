# 4. NoteEditScreen Widget Test

**Type**: AFK
**Blocked by**: None - can start immediately
**Label**: `ready-for-agent`

## What to build

为编辑页添加 widget test，验证新建模式下的表单渲染和自动计算联动。

## Acceptance criteria

- [ ] 新建模式：dateStr 传入，noteId 为 null，显示空表单
- [ ] 表单字段渲染：标题、地点、时间、时薪、工时、日工资输入框可见
- [ ] 默认值验证：开始时间 09:00、结束时间 18:00
- [ ] 富文本编辑器渲染（QuillEditor 存在）
- [ ] 插入按钮组存在：相册图片、拍照、画板
- [ ] 自动计算：修改结束时间后工作时长自动更新
- [ ] 保存按钮在加载完成后可用
- [ ] 使用 `ProviderScope` + 测试 DB 注入

## Blocked by

None - can start immediately
