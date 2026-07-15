import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_entry.dart';
import '../providers/notes_provider.dart';
import '../services/backup_service.dart';

/// WorkEntry 写入与失效协调 Notifier。
///
/// 集中所有 save / delete 调用，同地点触发派生缓存失效与自动备份。
/// 设计见 ADR-0001（高层 A/N/γ/S 四决策）与 ADR-0002（H1 清单 + P 粒度）。
class EntryCoordinator extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData<void>(null);
  }

  /// 清空所有"每次写都受影响"的派生缓存。
  /// 注：保留为方法而非 const List 是因为 family provider 的静态类型与
  /// `ProviderListenable<T>` 列表无法对齐，硬编码调用可读性反而更佳。
  /// 见 ADR-0002 H1 决议。
  void _invalidateCommon() {
    ref.invalidate(workDatesProvider);
    ref.invalidate(wageNotesProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(monthlyTotalWageProvider);
    ref.invalidate(monthlyWorkDaysProvider);
    ref.invalidate(notesByDateRangeProvider);
    ref.invalidate(notesByDateListProvider);
  }

  /// save 用：note 已知日期 → 公共清单 + 单日期精准清空。
  void _invalidateFor(WorkEntry note) {
    _invalidateCommon();
    ref.invalidate(notesByDateListProvider(note.date));
  }

  /// delete 用：date 已知 → 公共清单 + 单日期精准清空。
  void _invalidateForDate(String date) {
    _invalidateCommon();
    ref.invalidate(notesByDateListProvider(date));
  }

  /// 自动备份。失败不阻断 mutation 主流程——与现状 BackupService 一致。
  Future<void> _tryAutoBackup() async {
    try {
      await BackupService.autoBackup(ref);
    } catch (_) {
      // 自动备份失败不打断 mutation 主流程（与现状一致）
    }
  }

  /// 保存或插入一个 WorkEntry。错误统一从 `AsyncError` 流走，不抛。
  Future<void> save(WorkEntry note) async {
    state = AsyncLoading<void>().copyWithPrevious(state);
    try {
      final db = ref.read(databaseHelperProvider);
      if (note.id != null) {
        await db.updateNote(note);
      } else {
        await db.insertNote(note);
      }
      _invalidateFor(note);
      await _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  /// 删除一个 WorkEntry。错误统一从 `AsyncError` 流走，不抛。
  Future<void> delete({required int id, required String date}) async {
    state = AsyncLoading<void>().copyWithPrevious(state);
    try {
      final db = ref.read(databaseHelperProvider);
      await db.deleteNote(id);
      _invalidateForDate(date);
      await _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

/// Coordinator 的唯一入口。任何写操作都必须经过这里。
final entryCoordinatorProvider =
    NotifierProvider<EntryCoordinator, AsyncValue<void>>(EntryCoordinator.new);