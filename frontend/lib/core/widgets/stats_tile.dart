import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/format.dart';

/// Tuile de statistique du tableau de bord (icône 3D, valeur, tendance).
class StatsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double? delta;
  final bool money;

  const StatsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
    this.money = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deltaUp = (delta ?? 0) >= 0;
    return GlassTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: const Color(0xFF3E2A00), size: 22),
              ),
              const Spacer(),
              if (delta != null)
                _DeltaBadge(
                    up: deltaUp,
                    text: '${deltaUp ? '+' : ''}${Fmt.number(delta!)}%'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money ? Fmt.money(value) : Fmt.number(value),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassTile extends StatelessWidget {
  final Widget child;
  const GlassTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final bool up;
  final String text;
  const _DeltaBadge({required this.up, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = up ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14, color: color),
          const SizedBox(width: 2),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
