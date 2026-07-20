import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/providers/settings_provider.dart';
import 'package:daily_gig_journal/screens/appearance_screen.dart';

void main() {
  testWidgets('AppearanceScreen renders all 3 options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('外观设置'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
  });

  testWidgets('AppearanceScreen checkmark for selected theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) => ThemeMode.dark),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final darkTile = find.text('深色模式');
    expect(darkTile, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: darkTile, matching: find.byType(ListTile)),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });
}
