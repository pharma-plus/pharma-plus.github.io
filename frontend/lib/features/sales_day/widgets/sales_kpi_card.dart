/// ============================================================
/// VENTES DU JOUR — Carte KPI premium 3D (profondeur, or, émeraude)
/// ============================================================
/// Design validé :
///  · Surface opaque sombre (palette officielle) + bordure or champagne.
///  · Profondeur : ombre douce + léger dégradé vertical + liseré lumineux
///    en haut (reflet métallique discret, sans moteur 3D lourd).
///  · Valeur réelle uniquement ; « — » quand l'indicateur est indisponible.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class SalesKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final double? deltaPct;

  const SalesKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.unit = '',
    required this.icon,
    required this.accent,
    this.deltaPct,
  });

  @override
  Widget build(BuildContext context) {
    final delta = deltaPct;
    final unavailable = value.isEmpty || value == '—';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pharmaSurface2,
            AppColors.pharmaSurface,
          ],
        ),
        border: Border.all(color: AppColors.goldBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, -6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Reflet en haut (liseré métallique discret)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        accent.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child:
                            Icon(icon, size: 15, color: accent),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.pharmaMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            unavailable ? 'Non disponible' : value,
                            maxLines: 1,
                            style: TextStyle(
                              color: unavailable
                                  ? AppColors.pharmaMuted
                                  : AppColors.inkDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      if (!unavailable && unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            unit,
                            style: const TextStyle(
                              color: AppColors.champagneInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _deltaChip(delta) ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _deltaChip(double? delta) {
    if (delta == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline,
              size: 10,
              color: AppColors.pharmaMuted.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(
            'Évolution indisponible',
            style: TextStyle(
              color: AppColors.pharmaMuted.withValues(alpha: 0.7),
              fontSize: 9,
            ),
          ),
        ],
      );
    }
    final up = delta >= 0;
    final color = up ? AppColors.sageGreenInk : AppColors.pharmaDanger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.trending_up : Icons.trending_down,
            size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '${up ? '+' : ''}${delta.toStringAsFixed(1)} % vs période précédente',
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
