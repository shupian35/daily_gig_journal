import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_gig_journal/l10n/app_localizations.dart';
import 'package:daily_gig_journal/providers/settings_provider.dart';
import 'package:daily_gig_journal/screens/language_screen.dart';

void main() {
  testWidgets('LanguageScreen renders all 4 options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const LanguageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语言设置'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
  });

  testWidgets('LanguageScreen checkmark for selected locale', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => const Locale('zh')),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const LanguageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chineseTile = find.text('中文');
    expect(chineseTile, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: chineseTile, matching: find.byType(ListTile)),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });
}
