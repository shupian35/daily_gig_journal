import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 统一可选列表项 — 精致杂志风
/// 选中态带主色边框 + 圆形图标背景加深 + 右侧 ✓；未选中态右侧 chevron。
/// 消除 language_screen 与 appearance_screen 两处 option() 重复喵~
class AppSelectableTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const AppSelectableTile({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: selected
              ? AppConstants.primaryColor.withValues(alpha: 0.45)
              : (isDark
                  ? const Color(0xFF3A3A44)
                  : const Color(0xFFEDE8E2)),
          width: selected ? 1.0 : 0.5,
        ),
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppConstants.primaryColor
                .withValues(alpha: selected ? 0.18 : 0.08),
          ),
          child: Icon(icon, color: AppConstants.primaryDark, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppConstants.primaryDark : null,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppConstants.textSecondary,
                ),
              ),
        trailing: selected
            ? const Icon(
                Icons.check_rounded,
                color: AppConstants.primaryColor,
                size: 22,
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppConstants.textSecondary,
                size: 20,
              ),
        onTap: onTap,
      ),
    );
  }
}