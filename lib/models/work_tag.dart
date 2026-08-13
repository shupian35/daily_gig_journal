/// 工作标签的值对象，供 [TagsScreen] 管理页与统计页 chip 使用。
///
/// 标签本身只是字符串（持久化于 `work_notes.tags` 逗号分隔字段），
/// 这个类把"标签名 + 该标签命中的条目数"绑在一起，避免各处重复 `length` 计算。
class WorkTag {
  final String name;

  /// 当前数据库中含此标签的 WorkEntry 条数。
  final int count;

  const WorkTag({
    required this.name,
    required this.count,
  });

  @override
  String toString() => 'WorkTag($name, $count)';

  @override
  bool operator ==(Object other) =>
      other is WorkTag && other.name == name && other.count == count;

  @override
  int get hashCode => Object.hash(name, count);
}