import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

/// 日程清单
/// 帮助日结兼职人员记录工作安排、笔记与工资统计
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web 平台：切换到 IndexedDB 数据库工厂（浏览器无原生 SQLite）
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // 初始化 intl 区域数据（table_calendar / flutter_quill 中文显示需要）
  await initializeDateFormatting('zh_CN', null);

  runApp(
    const ProviderScope(
      child: DailyGigApp(),
    ),
  );
}

/// 应用根组件
class DailyGigApp extends ConsumerStatefulWidget {
  const DailyGigApp({super.key});

  @override
  ConsumerState<DailyGigApp> createState() => _DailyGigAppState();
}

class _DailyGigAppState extends ConsumerState<DailyGigApp> {
  @override
  void initState() {
    super.initState();
    // 从本地加载持久化设置
    Future.microtask(() => loadSettings(ref));
    // 监听变化并自动保存
    ref.listenManual(themeModeProvider, (prev, next) {
      saveThemeMode(next);
    });
    ref.listenManual(hideIncomeProvider, (prev, next) {
      saveHideIncome(next);
    });
    ref.listenManual(hideStatisticsProvider, (prev, next) {
      saveHideStatistics(next);
    });
    ref.listenManual(webDavUrlProvider, (prev, next) {
      saveWebDavUrl(next);
    });
    ref.listenManual(webDavUsernameProvider, (prev, next) {
      saveWebDavUsername(next);
    });
    ref.listenManual(webDavPasswordProvider, (prev, next) {
      saveWebDavPassword(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: '日程清单',
      debugShowCheckedModeBanner: false,

      theme: AppConstants.lightTheme,
      darkTheme: AppConstants.darkTheme,
      themeMode: themeMode,

      locale: const Locale('zh'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],

      home: const HomeScreen(),
    );
  }
}
