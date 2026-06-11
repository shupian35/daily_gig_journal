import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'day_entries_screen.dart';

/// 主页面 —— 精致的底部导航
/// 管理三个Tab：日历、统计、设置
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
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
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.calendar_today_rounded,
                  activeIcon: Icons.calendar_today_rounded,
                  label: '日历',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.show_chart_rounded,
                  activeIcon: Icons.show_chart_rounded,
                  label: '统计',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.tune_rounded,
                  activeIcon: Icons.tune_rounded,
                  label: '设置',
                ),
              ],
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
