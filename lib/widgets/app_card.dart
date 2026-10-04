import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 统一卡片容器 — 精致杂志风
/// 封装项目标准的卡片装饰，消除 20+ 处重复的 BoxDecoration
///
/// 视觉层次：底色 → 边框 → 顶部高光渐变（去塑料感）→ 三层柔和投影。
/// 传入 [onTap] 时启用按压缩放 + 水波纹，给静态卡片一点"可触碰"的暗示。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final bool showBorder;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius ?? AppConstants.radiusXl);

    // 高光层：盖在底色之上、内容之下，不参与 hit test
    final content = Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppConstants.cardSheen(isDark),
                borderRadius: shape,
              ),
            ),
          ),
        ),
        Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ],
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.cardDark : Colors.white,
        borderRadius: shape,
        border: showBorder
            ? Border.all(
                color: isDark
                    ? const Color(0xFF3A3A44)
                    : const Color(0xFFEDE8E2),
                width: 0.5,
              )
            : null,
        boxShadow: AppConstants.cardShadow(isDark),
      ),
      child: onTap == null
          ? content
          : _PressableCard(
              onTap: onTap!,
              borderRadius: shape,
              child: content,
            ),
    );

    return margin == null ? decorated : Padding(padding: margin!, child: decorated);
  }
}

/// 按压时轻微缩小（1 → 0.98）并加深投影，给出物理按压反馈。
class _PressableCard extends StatefulWidget {
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  const _PressableCard({
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v || !mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _pressed
              ? AppConstants.elevatedShadow(isDark)
              : const <BoxShadow>[],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
