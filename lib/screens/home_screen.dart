import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'day_entries_screen.dart';

/// 主页面 —— 包含底部导航栏
/// 管理三个Tab：日历、统计、设置
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 当前选中的Tab索引
  int _currentIndex = 0;

  /// 页面列表（使用 IndexedStack 保持页面状态）
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      // 日历页：处理日期选中导航 → 进入当天条目列表
      CalendarScreen(
        onDaySelected: (dateStr) {
          _navigateToDayEntries(dateStr);
        },
      ),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
  }

  /// 导航到当天工作条目列表页
  void _navigateToDayEntries(String dateStr) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DayEntriesScreen(dateStr: dateStr),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
