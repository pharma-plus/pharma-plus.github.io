/// ============================================================
/// VENTES DU JOUR — Filtre de dates (périodes prédéfinies + sur mesure)
/// ============================================================
/// Aujourd'hui · Hier · Cette semaine · Ce mois · Personnalisé
/// (showDateRangePicker). Bornes honnêtes [inclus, exclus) locales,
/// exportées en ISO avec décalage — voir SalesAnalyticsService.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../models/sales_day_model.dart' show SalesDayFailure;
import '../services/sales_analytics_service.dart';

class SalesDateFilter extends StatelessWidget {
  final SalesPeriod period;
  final DateTimeRange? customRange;
  final ValueChanged<SalesPeriod> onSelect;
  final ValueChanged<DateTimeRange> onCustomRange;
  final String periodLabel;

  const SalesDateFilter({
    super.key,
    required this.period,
    required this.customRange,
    required this.onSelect,
    required this.onCustomRange,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final chips = SalesPeriod.values.map((p) {
      final active = p == period && !(p == SalesPeriod.custom && customRange == null);
      return InkWell(
        onTap: () async {
          if (p == SalesPeriod.custom) {
            final now = DateTime.now();
            final r = await showDateRangePicker(
              context: context,
              initialDateRange: DateTimeRange(
                start: DateTime(now.year, now.month, now.day - 6),
                end: DateTime(now.year, now.month, now.day),
              ),
              firstDate: DateTime(now.year - 3),
              lastDate: DateTime(now.year, now.month, now.day)
                  .add(const Duration(days: 1)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: Theme.of(ctx).colorScheme.copyWith(
                        primary: AppColors.emerald,
                        onPrimary: Colors.white,
                        surface: AppColors.pharmaSurface,
                        onSurface: AppColors.pharmaText,
                      ),
                ),
                child: child!,
              ),
            );
            if (r != null) onCustomRange(r);
            return;
          }
          onSelect(p);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.emerald.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.emerald : AppColors.goldBorder,
              width: 1,
            ),
          ),
          child: Text(
            p.label,
            style: TextStyle(
              color: active ? AppColors.emeraldLight : AppColors.pharmaMuted,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        const SizedBox(width: 4),
        Icon(Icons.date_range, size: 14, color: AppColors.pharmaGold),
        const SizedBox(width: 2),
        Text(
          periodLabel,
          style: const TextStyle(
            color: AppColors.pharmaGoldLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Bloc d'état : erreurs différenciées / vide / chargement squelette.
class SalesStateBlock extends StatelessWidget {
  final SalesDayFailure? error;
  final VoidCallback onRetry;
  final bool showSkeleton;

  const SalesStateBlock({
    super.key,
    required this.error,
    required this.onRetry,
    required this.showSkeleton,
  });

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaDanger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.pharmaDanger.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_off,
                      color: AppColors.pharmaDanger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.userMessage,
                      style: const TextStyle(
                        color: AppColors.pharmaDanger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Détail technique : ${e.technical}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.pharmaMuted.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emeraldLight,
                  side: BorderSide(
                      color: AppColors.emerald.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (showSkeleton) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }
}
