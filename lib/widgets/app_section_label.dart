import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 统一分区标题 — 精致杂志风
/// 带图标的 section header，消除 settings/webdav/form 三处的重复
class AppSectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;

  const AppSectionLabel({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppConstants.primaryDark),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryDark,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
