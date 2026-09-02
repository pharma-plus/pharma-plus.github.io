import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Bouton principal au dégradé 3D (or / vert) avec reflet.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final LinearGradient gradient;
  final bool fullWidth;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient = AppColors.greenGradient,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ),
    );
  }
}
