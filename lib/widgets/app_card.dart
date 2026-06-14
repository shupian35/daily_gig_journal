import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 统一卡片容器 — 精致杂志风
/// 封装项目标准的卡片装饰，消除 20+ 处重复的 BoxDecoration
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262630) : Colors.white,
        borderRadius: BorderRadius.circular(radius ?? AppConstants.radiusXl),
        border: showBorder
            ? Border.all(
                color: isDark ? const Color(0xFF3A3A44) : const Color(0xFFEDE8E2),
                width: 0.5,
              )
            : null,
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
