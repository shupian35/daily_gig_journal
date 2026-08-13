import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/work_entry_change.dart';
import '../models/work_entry.dart';
import '../providers/notes_provider.dart';
import '../services/backup_service.dart';

/// WorkEntry 写入协调与派生缓存失效驱动器。
///
/// 设计动机与决策见 ADR-0001（集中写入）、ADR-0006（watch 事件驱动失效）。
/// 当前职责：
///   * 集中所有 save / delete mutation 入口
///   * build() 单一挂 `WorkEntryRepository.watch()` 订阅做派生缓存失效
///   * 同步触发自动备份（fire-and-forget，leading-edge 30s 节流；见 ADR-0005）
class EntryCoordinator extends Notifier<AsyncValue<void>> {
  /// 自动备份 leading-edge 节流窗口。窗口从上次备份**完成**算起。
  static const _backupThrottleWindow = Duration(seconds: 30);

  bool _isBackupRunning = false;
  DateTime? _lastBackupCompletedAt;
  StreamSubscription<WorkEntryChange>? _watchSub;

  @override
  AsyncValue<void> build() {
    // 单一 watch 订阅点：派生缓存失效清单整体下沉到事件 listener。
    // ADR-0002 的静态 _invalidateFor/_invalidateForDate 已删除。
    _watchSub =
        ref.read(workEntryRepositoryProvider).watch().listen(_onRepoChange);
    ref.onDispose(() {
      _watchSub?.cancel();
      _watchSub = null;
    });
    return const AsyncData<void>(null);
  }

  /// write event → invalidate 影响到的派生 provider。
  void _onRepoChange(WorkEntryChange change) {
    // 精准：按 change.date 失效该日 list 的 family 项。
    ref.invalidate(notesByDateListProvider(change.date));
    // 表级：所有写都影响的聚合 provider。
    ref.invalidate(workDatesProvider);
    ref.invalidate(wageNotesProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(monthlyTotalWageProvider);
    ref.invalidate(monthlyWorkDaysProvider);
    ref.invalidate(notesByDateRangeProvider);
    // tags / search：写入会让标签字典和搜索结果集失真，强制重算。
    ref.invalidate(allTagsProvider);
    ref.invalidate(entriesByTagProvider);
    ref.invalidate(searchResultsProvider);
  }

  /// 自动备份：后台异步触发，不阻塞 save/delete 关键路径。
  ///
  /// 节流（leading-edge）：
  ///   1) 有备份在跑 → 跳过；
  ///   2) 最近 30s 内刚跑完 → 跳过；
  ///   3) 否则发起新一次。失败被 [BackupService.autoBackup] 内部 try/catch 吞掉。
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

  /// 保存或插入一个 WorkEntry。显式 add/update 不变式由接口保证。
  /// 错误统一以 `AsyncError` 流转，不抛出。
  Future<void> save(WorkEntry note) async {
    state = AsyncLoading<void>().copyWithPrevious(state);
    try {
      final repo = ref.read(workEntryRepositoryProvider);
      if (note.id == null) {
        await repo.add(note);
      } else {
        await repo.update(note);
      }
      _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  /// 按 id 删除一个 WorkEntry。date 不再需要——repo 内部查出来发事件用。
  /// 错误统一以 `AsyncError` 流转，不抛出。
  Future<void> delete({required int id}) async {
    state = AsyncLoading<void>().copyWithPrevious(state);
    try {
      final repo = ref.read(workEntryRepositoryProvider);
      await repo.remove(id);
      _tryAutoBackup();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

/// Coordinator 的唯一入口。任何写操作必须经过这里。
final entryCoordinatorProvider =
    NotifierProvider<EntryCoordinator, AsyncValue<void>>(EntryCoordinator.new);