import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'day_entries_screen.dart';
import '../providers/settings_provider.dart';

/// 主页面 —— 精致的底部导航
/// 管理三个Tab：日历、统计、设置
/// 开启隐藏统计后自动隐藏统计 Tab
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _allPages;

  @override
  void initState() {
    super.initState();
    _allPages = [
      CalendarScreen(
        onDaySelected: (dateStr) {
          _navigateToDayEntries(dateStr);
        },
      ),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
  }

  void _navigateToDayEntries(String dateStr) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DayEntriesScreen(dateStr: dateStr),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hideStatistics = ref.watch(hideStatisticsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // 构建可见页面列表和导航项
    final visiblePages = <Widget>[];
    final navItems = <_NavItem>[];

    // 日历 — 始终显示
    visiblePages.add(_allPages[0]);
    navItems.add(_NavItem(icon: Icons.calendar_today_rounded, label: l10n.calendarTab));

    // 统计 — 根据隐藏设置决定
    if (!hideStatistics) {
      navItems.add(_NavItem(icon: Icons.show_chart_rounded, label: l10n.statisticsTab));
      visiblePages.add(_allPages[1]);
    }

    // 设置 — 始终显示
    visiblePages.add(_allPages.last);
    navItems.add(_NavItem(icon: Icons.tune_rounded, label: l10n.settingsTab));

    // 如果当前选中索引超出范围，回退到 0
    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: visiblePages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF3A3A44)
                  : const Color(0xFFEDE8E2),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (i) {
                return _buildNavItem(
                  index: i,
                  icon: navItems[i].icon,
                  activeIcon: navItems[i].icon,
                  label: navItems[i].label,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = isSelected
        ? theme.bottomNavigationBarTheme.selectedItemColor
        : theme.bottomNavigationBarTheme.unselectedItemColor;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color(0xFFC8895A).withValues(alpha: 0.12)
                  : const Color(0xFFC8895A).withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color!,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
