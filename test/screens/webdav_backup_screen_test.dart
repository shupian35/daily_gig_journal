import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/screens/webdav_backup_screen.dart';
import 'package:daily_gig_journal/services/backup_service.dart';

void main() {
  testWidgets('config form renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const WebDavBackupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // AppBar
    expect(find.text('\u4e91\u5907\u4efd'), findsOneWidget);

    // first-screen form (in viewport)
    expect(find.text('\u670d\u52a1\u5668\u5730\u5740'), findsOneWidget);
    expect(find.text('\u6d4b\u8bd5\u8fde\u63a5'), findsOneWidget);
  });

  testWidgets('error banner renders on consecutive failures', (tester) async {
    final container = ProviderContainer();
    container.read(lastAutoBackupErrorProvider.notifier).state =
        AutoBackupError(
      occurredAt: DateTime(2026, 7, 25, 10, 30),
      reason: 'test failure reason',
      consecutiveCount: 3,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const WebDavBackupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('\u8fde\u7eed 3 \u6b21'), findsOneWidget);
    expect(find.textContaining('test failure reason'), findsOneWidget);
    expect(find.text('\u7acb\u5373\u91cd\u8bd5'), findsOneWidget);
  });

  testWidgets('summary banner renders on successful backup', (tester) async {
    final container = ProviderContainer();
    container.read(lastAutoBackupSummaryProvider.notifier).state =
        AutoBackupSummary(
      completedAt: DateTime(2026, 7, 25, 10, 30),
      uploadedImages: 5,
      skippedImages: 12,
      uploadedDrafts: 0,
      uploadedBytes: 1024000,
      dbUploaded: true,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const WebDavBackupScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // summary text contains 'uploaded 5 images'
    expect(find.textContaining('5'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
  });
}
