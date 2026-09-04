import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Carte premium PHARMA+ — surface sombre unie, liseré or, ombre subtile.
///
/// Refonte v3 : plus d'effet verre/transparence. On utilise une surface unie
/// sombre (palette officielle) avec bordure or champagne (1px rgba(214,168,79,0.15))
/// et une ombre douce pour la profondeur.
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
    final bgColor = isDark
        ? AppColors.pharmaSurface
        : Colors.white.withValues(alpha: 0.92);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        gradient: gradient,
        borderRadius: radius ?? BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.goldBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius ?? BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
