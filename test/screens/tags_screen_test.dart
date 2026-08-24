import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/data/in_memory_work_entry_repository.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/models/work_entry.dart';
import 'package:daily_gig_journal/providers/entry_coordinator.dart';
import 'package:daily_gig_journal/providers/notes_provider.dart';
import 'package:daily_gig_journal/screens/tags_screen.dart';

/// TagsScreen 写入走 EntryCoordinator 的编排验证：
/// rename / merge / delete 经 UI 触发后必须改写 repo 数据并触发自动备份。
void main() {
  late InMemoryWorkEntryRepository repo;
  late int backupCalls;

  setUp(() {
    backupCalls = 0;
    EntryCoordinator.backupHook = (_) async => backupCalls++;
  });

  tearDown(() {
    EntryCoordinator.backupHook = null;
  });

  Future<void> seedRepo() async {
    await repo.add(WorkEntry.empty('2025-06-14')
        .copyWith(title: '会展协助', tags: ['会展', 'A馆']));
    await repo.add(WorkEntry.empty('2025-06-15')
        .copyWith(title: '家教', tags: ['家教']));
    await repo.add(WorkEntry.empty('2025-06-16')
        .copyWith(title: '发传单', tags: ['会展']));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workEntryRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const TagsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// 标签字典按 Unicode 升序：A馆 < 会展 < 家教。
  Future<void> tapRowAction(WidgetTester tester, IconData icon, int row) async {
    await tester.tap(find.byIcon(icon).at(row));
    await tester.pump();
    await tester.pump();
  }

  /// 点击当前弹窗里的确认按钮（actions 的最后一个 TextButton）。
  Future<void> tapDialogConfirm(WidgetTester tester) async {
    await tester.tap(find.byType(TextButton).last);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('rename via UI: repo renamed + auto backup triggered',
      (tester) async {
    repo = InMemoryWorkEntryRepository();
    await seedRepo();
    await pumpScreen(tester);

    // 重命名「家教」（第 3 行）
    await tapRowAction(tester, Icons.edit_outlined, 2);
    await tester.enterText(find.byType(TextField), '补习');
    await tapDialogConfirm(tester);

    // 等 coordinator 异步完成
    await tester.pump();
    await tester.pump();

    expect(await repo.findByTag('补习'), hasLength(1));
    expect(await repo.findByTag('家教'), isEmpty);
    expect(backupCalls, 1);
  });

  testWidgets('merge via UI: merged into target + auto backup triggered',
      (tester) async {
    repo = InMemoryWorkEntryRepository();
    await seedRepo();
    await pumpScreen(tester);

    // 合并「家教」（第 3 行）→「会展」
    await tapRowAction(tester, Icons.merge_outlined, 2);
    await tester.enterText(find.byType(TextField), '会展');
    await tapDialogConfirm(tester); // 第一个对话框：填目标
    await tapDialogConfirm(tester); // 确认对话框

    await tester.pump();
    await tester.pump();

    expect((await repo.findByTag('会展')).length, 3);
    expect(await repo.findByTag('家教'), isEmpty);
    expect(backupCalls, 1);
  });

  testWidgets('delete via UI: tag removed + auto backup triggered',
      (tester) async {
    repo = InMemoryWorkEntryRepository();
    await seedRepo();
    await pumpScreen(tester);

    // 删除「A馆」（第 1 行，只挂在一条记录上）
    await tapRowAction(tester, Icons.delete_outline_rounded, 0);
    await tapDialogConfirm(tester);

    await tester.pump();
    await tester.pump();

    expect(await repo.findByTag('A馆'), isEmpty);
    final day1 =
        (await repo.findAllWithWage()).firstWhere((e) => e.date == '2025-06-14');
    expect(day1.tags, ['会展']);
    expect(backupCalls, 1);
  });
}
