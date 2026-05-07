import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主题模式状态提供者
/// 默认为跟随系统
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

/// 是否隐藏收入金额
final hideIncomeProvider = StateProvider<bool>((ref) {
  return false;
});

/// 是否隐藏统计页面
final hideStatisticsProvider = StateProvider<bool>((ref) {
  return false;
});
