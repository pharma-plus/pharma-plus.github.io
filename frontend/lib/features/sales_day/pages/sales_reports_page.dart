/// ============================================================
/// SOUS-PAGE 9 : RAPPORTS ET EXPORTS
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../services/sales_export_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesReportsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesReportsPage({super.key, required this.analytics});

  @override
  State<SalesReportsPage> createState() => _SalesReportsPageState();
}

class _SalesReportsPageState extends State<SalesReportsPage> {
  @override
  void initState() {
    super.initState();
    widget.analytics.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.analytics.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    final a = c.analytics;

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
        const SizedBox(height: 14),
        const Text(
          'Rapports et exports',
          style: TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Les documents exportés utilisent les mêmes données affichées à l\'écran (mêmes KPI, mêmes transactions, mêmes filtres).',
          style: TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 20),
        if (a == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune donnée chargée. Chargez d\'abord la vue générale.',
                style: TextStyle(color: AppColors.pharmaMuted),
              ),
            ),
          )
        else
          Column(
            children: [
              _exportCard(
                context,
                'Export PDF',
                Icons.picture_as_pdf,
                'Rapport PDF complet avec KPI, graphiques et transactions',
                () => SalesExportService.exportPdf(
                  periodLabel: c.periodLabelText,
                  analytics: a,
                  transactions: c.txRows,
                ),
              ),
              const SizedBox(height: 12),
              _exportCard(
                context,
                'Export Excel (CSV)',
                Icons.table_view,
                'Fichier CSV UTF-8 avec BOM, ouvrable dans Excel',
                () => SalesExportService.exportExcel(
                  periodLabel: c.periodLabelText,
                  analytics: a,
                  transactions: c.txRows,
                ),
              ),
              const SizedBox(height: 12),
              _exportCard(
                context,
                'Export Excel (.xlsx)',
                Icons.grid_on,
                'Véritable fichier Excel avec mise en forme',
                () async {
                  await SalesExportService.exportXlsx(
                    periodLabel: c.periodLabelText,
                    analytics: a,
                    transactions: c.txRows,
                  );
                },
              ),
              const SizedBox(height: 12),
              _exportCard(
                context,
                'Imprimer',
                Icons.print,
                'Impression directe du rapport PDF',
                () => SalesExportService.exportPdf(
                  periodLabel: c.periodLabelText,
                  analytics: a,
                  transactions: c.txRows,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _exportCard(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onPressed,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.pharmaGold, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.pharmaMuted),
        onTap: onPressed,
      ),
    );
  }
}