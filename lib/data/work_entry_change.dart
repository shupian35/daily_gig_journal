/// WorkEntry 写操作的最小可观察信号。
///
/// 由 [WorkEntryRepository] 在 add / update / remove 完成后发出，
/// [EntryCoordinator] 监听以驱动派生缓存失效（见 ADR-0006）。
///
/// `date` 字段用于精准失效 [notesByDateListProvider] 的对应 family 项；
/// `id` 字段用于诊断 / 未来选择性失效。
sealed class WorkEntryChange {
  final int id;
  final String date;
  const WorkEntryChange(this.id, this.date);
}

/// 新增一条 WorkEntry。id 是新生成的 rowid。
class Added extends WorkEntryChange {
  const Added(super.id, super.date);
}

/// 更新已存在的 WorkEntry。
class Edited extends WorkEntryChange {
  const Edited(super.id, super.date);
}

/// 删除一条 WorkEntry。
class Removed extends WorkEntryChange {
  const Removed(super.id, super.date);
}