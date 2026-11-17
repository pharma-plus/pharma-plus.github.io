// ============================================================
// SOUS-PAGE 7 : ANNULATIONS ET RETOURS
// ============================================================
// Phase 2 : les listes utilisent le jeu complet de transactions
// (cohérence avec les compteurs serveur) et le style de tableau
// harmonisé avec la vue générale. Aucune valeur de démonstration.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

class SalesReturnsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesReturnsPage({super.key, required this.analytics});

  @override
  State<SalesReturnsPage> createState() => _SalesReturnsPageState();
}

class _SalesReturnsPageState extends State<SalesReturnsPage> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.analytics.addListener(_listener);
  }

  @override
  void dispose() {
    widget.analytics.removeListener(_listener);
    super.dispose();
  }

  void _requestFull() {
    final c = widget.analytics;
    if (c.analytics == null || c.fullLoading) return;
    if (c.fullRows.isNotEmpty || c.fullError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.ensureFullTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    _requestFull();
    final k = c.analytics?.kpis;
    final tx = c.fullRows;
    final cancelled = tx
        .where((t) => t.status == 'voided' || t.status == 'cancelled')
        .toList();
    final returned = tx
        .where((t) => t.status == 'returned' || t.status == 'refunded')
        .toList();
    final refunded = k?.refundedAmount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        SalesDateFilter(
          period: c.period,
          customRange: c.custom,
          periodLabel: c.periodLabelText,
          onSelect: (p) => c.setPeriod(p),
          onCustomRange: (r) => c.setCustomRange(r),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesSectionHeader(
          title: 'Annulations et retours',
          subtitle: '${c.fullScopeLabel} · comptages calculés côté API',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        SalesPanel(
          child: Wrap(
            spacing: SalesDesign.spacingLG,
            runSpacing: SalesDesign.spacingSM,
            children: [
              SalesMetric(
                  label: 'Annulées',
                  value: '${k?.cancelledCount ?? 0}',
                  color: AppColors.pharmaDanger),
              SalesMetric(
                  label: 'Remboursées / Retours',
                  value: '${k?.returnedCount ?? 0}',
                  color: AppColors.pharmaMuted),
              SalesMetric(
                  label: 'Remboursements réels',
                  value: refunded == null
                      ? 'N/D'
                      : Fmt.number(refunded, decimals: 2),
                  unit: refunded == null ? null : 'MAD',
                  color: AppColors.champagneInk,
                  hint: refunded == null ? 'non exposé par l\'API' : null),
            ],
          ),
        ),
        const SizedBox(height: SalesDesign.spacingLG),
        SalesSectionHeader(
          title: 'Détail des opérations',
          subtitle:
              '${cancelled.length + returned.length} ligne(s) sur la période',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        if (c.fullLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.sageGreenInk)),
          )
        else if (c.fullError != null)
          SalesNotice(
              message: 'Détail indisponible : ${c.fullError!.userMessage}')
        else if (!c.fullComplete)
          const SalesNotice(
              message:
                  'Jeu de transactions tronqué : le détail est masqué pour éviter une liste partielle.')
        else if (cancelled.isEmpty && returned.isEmpty)
          const SalesEmptyState(
              message: 'Aucune annulation ou retour sur la période')
        else
          for (final t in [...cancelled, ...returned]) _buildTransactionRow(t),
        if (c.coverageNote.isNotEmpty) ...[
          const SizedBox(height: SalesDesign.spacingMD),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              c.coverageNote,
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Date/heure locales sans dépendance aux données de locale `intl`.
  static String _dateLabel(DateTime? value) {
    if (value == null) return '—';
    final d = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _buildTransactionRow(SalesTransaction t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SalesDesign.spacingXS),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
          border: Border.all(
              color: AppColors.goldBorder, width: SalesDesign.borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.number.isEmpty ? '—' : t.number,
                      style: const TextStyle(
                        color: AppColors.inkDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateLabel(t.createdAt),
                      style: const TextStyle(
                        color: AppColors.pharmaMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                t.statusLabel,
                style: const TextStyle(
                  color: AppColors.pharmaDanger,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Fmt.number(t.total, decimals: 2),
                style: const TextStyle(
                  color: AppColors.champagneInkLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
