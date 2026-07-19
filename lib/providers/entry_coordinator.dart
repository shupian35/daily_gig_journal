import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_entry.dart';
import '../providers/notes_provider.dart';
import '../services/backup_service.dart';

/// WorkEntry 写入与失效协调 Notifier。
///
/// 集中所有 save / delete 调用，同地点触发派生缓存失效与自动备份。
/// 设计见 ADR-0001（高层 A/N/γ/S 四决策）与 ADR-0002（H1 清单 + P 粒度）。
class EntryCoordinator extends Notifier<AsyncValue<void>> {
  /// 自动备份 leading-edge 节流窗口。
  ///
  /// 窗口从**上一次备份完成**算起——备份本身耗时再加 30s 缓冲。Leading
  /// edge 让单次保存不等窗口立刻备份；trailing edge 会让单次保存延迟
  /// 30s，UX 反而退步。
  static const _backupThrottleWindow = Duration(seconds: 30);

  bool _isBackupRunning = false;
  DateTime? _lastBackupCompletedAt;

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

  /// 自动备份 —— 后台异步触发，不阻塞 save / delete 关键路径。
  ///
  /// 之前 `await _tryAutoBackup()` 把云端 WebDAV 上传 + 列目录 + 清旧档
  /// 串在 mutation 关键路径里，用户体感"保存时间 = WebDAV 往返耗时"。
  /// 现改为 `unawaited()` —— save / delete 立刻返回，备份在事件循环里
  /// 自己跑完。
  ///
  /// 节流（leading edge）：1) 有备份在跑 → 跳过；2) 最近 30s 内刚跑完
  /// → 跳过；3) 否则发起新一次。备份失败被 `BackupService.autoBackup`
  /// 内部 try/catch 吞掉，对外无副作用。
  void _tryAutoBackup() {
    if (_isBackupRunning) return;
    final last = _lastBackupCompletedAt;
    if (last != null &&
        DateTime.now().difference(last) < _backupThrottleWindow) {
      return;
    }
    _isBackupRunning = true;
    unawaited(_runBackup());
  }

  Future<void> _runBackup() async {
    try {
      await BackupService.autoBackup(ref);
    } finally {
      _isBackupRunning = false;
      _lastBackupCompletedAt = DateTime.now();
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
      _tryAutoBackup();
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
      _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

/// Coordinator 的唯一入口。任何写操作都必须经过这里。
final entryCoordinatorProvider =
    NotifierProvider<EntryCoordinator, AsyncValue<void>>(EntryCoordinator.new);