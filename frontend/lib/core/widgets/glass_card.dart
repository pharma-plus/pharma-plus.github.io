import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Carte vitrée avec profondeur (fond translucide, liseré lumineux).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final BorderRadius? radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effective = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceDark,
                  AppColors.surfaceDark.withValues(alpha: 0.85)
                ]
              : [Colors.white, Colors.white.withValues(alpha: 0.92)],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: effective,
        borderRadius: radius ?? BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius ?? BorderRadius.circular(20),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
