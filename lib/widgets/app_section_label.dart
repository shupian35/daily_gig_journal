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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 分区标题作为视觉锚点：图标加暖色圆形底 + 标题加大字距形成节奏
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor
                  .withValues(alpha: isDark ? 0.16 : 0.12),
            ),
            child: Icon(icon, size: 13, color: AppConstants.primaryDark),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppConstants.primaryDark,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 细延伸线：延续 note_form_fields 的杂志风分隔符语言
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppConstants.primaryColor.withValues(alpha: 0.22),
                    AppConstants.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
