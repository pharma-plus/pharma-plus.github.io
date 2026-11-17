// ============================================================
// SOUS-PAGE 9 : RAPPORTS ET EXPORTS
// ============================================================
// Phase 4 : périmètre explicite = période complète, sans filtre de
// statut/recherche hérité de la vue générale. Ce périmètre est
// affiché à l'écran et inséré dans chaque fichier exporté.
// Aucun export partiel n'est présenté comme complet.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../controllers/sales_day_controller.dart';
import '../services/sales_export_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

class SalesReportsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesReportsPage({super.key, required this.analytics});

  @override
  State<SalesReportsPage> createState() => _SalesReportsPageState();
}

class _SalesReportsPageState extends State<SalesReportsPage> {
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
    final a = c.analytics;
    _requestFull();
    final ready = a != null && c.fullComplete && c.fullError == null;
    final rows = c.fullRows;
    final unavailable = c.fullError != null
        ? 'Chargement complet impossible'
        : (!c.fullComplete
            ? 'Données incomplètes — export refusé'
            : 'Jeu de données non chargé');

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
          title: 'Rapports et exports',
          subtitle:
              '${c.periodLabelText} · mêmes KPI · jeu de transactions complet',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        const Text(
          'Les exports utilisent toutes les transactions de la période, indépendamment des filtres du tableau de la vue générale.',
          style: TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        if (a == null)
          const SalesEmptyState(
            message: 'Aucune donnée chargée. Chargez d\'abord la vue générale.',
          )
        else if (c.fullLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.sageGreenInk),
                  SizedBox(height: 10),
                  Text(
                    'Préparation du jeu complet de transactions…',
                    style:
                        TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else if (c.fullError != null) ...[
          SalesNotice(
            message:
                'Chargement complet impossible : ${c.fullError!.userMessage}. Les exports sont désactivés pour éviter un document incomplet.',
          ),
          const SizedBox(height: SalesDesign.spacingSM),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => c.ensureFullTransactions(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ),
        ] else if (!c.fullComplete)
          const SalesNotice(
            message:
                'Limite de chargement atteinte : le jeu de transactions est tronqué. Les exports sont désactivés plutôt que de produire un rapport incomplet.',
          )
        else ...[
          SalesPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.sageGreenInk, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rows.length} transaction(s) incluse(s) · ${c.fullScopeLabel}',
                        style: const TextStyle(
                            color: AppColors.pharmaMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SalesDesign.spacingMD),
          _exportCard(
            'Export PDF',
            Icons.picture_as_pdf,
            'Rapport PDF complet avec KPI, graphiques et transactions',
            ready
                ? () => SalesExportService.exportPdf(
                      periodLabel: c.periodLabelText,
                      analytics: a,
                      transactions: rows,
                      scopeLabel: c.fullScopeLabel,
                    )
                : null,
            unavailable,
          ),
          const SizedBox(height: SalesDesign.spacingSM),
          _exportCard(
            'Export Word (.doc)',
            Icons.description_outlined,
            'Document Word avec les mêmes sections que le PDF',
            ready
                ? () => SalesExportService.exportWord(
                      periodLabel: c.periodLabelText,
                      analytics: a,
                      transactions: rows,
                      scopeLabel: c.fullScopeLabel,
                    )
                : null,
            unavailable,
          ),
          const SizedBox(height: SalesDesign.spacingSM),
          _exportCard(
            'Export Excel (CSV)',
            Icons.table_view,
            'Fichier CSV UTF-8 avec BOM, ouvrable dans Excel',
            ready
                ? () => SalesExportService.exportExcel(
                      periodLabel: c.periodLabelText,
                      analytics: a,
                      transactions: rows,
                      scopeLabel: c.fullScopeLabel,
                    )
                : null,
            unavailable,
          ),
          const SizedBox(height: SalesDesign.spacingSM),
          _exportCard(
            'Export Excel (.xlsx)',
            Icons.grid_on,
            'Véritable fichier Excel avec mise en forme',
            ready
                ? () => SalesExportService.exportXlsx(
                      periodLabel: c.periodLabelText,
                      analytics: a,
                      transactions: rows,
                      scopeLabel: c.fullScopeLabel,
                    )
                : null,
            unavailable,
          ),
          const SizedBox(height: SalesDesign.spacingSM),
          _exportCard(
            'Imprimer',
            Icons.print,
            'Impression directe du rapport PDF',
            ready
                ? () => SalesExportService.exportPdf(
                      periodLabel: c.periodLabelText,
                      analytics: a,
                      transactions: rows,
                      scopeLabel: c.fullScopeLabel,
                    )
                : null,
            unavailable,
          ),
        ],
      ],
    );
  }

  Widget _exportCard(
    String title,
    IconData icon,
    String subtitle,
    void Function()? onPressed,
    String unavailableReason,
  ) {
    final enabled = onPressed != null;
    final accent = enabled ? AppColors.champagneInk : AppColors.pharmaMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.pharmaSurface.withValues(alpha: 0.6)
            : AppColors.pharmaSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
        border: Border.all(
            color: AppColors.goldBorder, width: SalesDesign.borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
        child: ListTile(
          leading: Icon(icon, color: accent, size: 24),
          title: Text(
            title,
            style: TextStyle(
              color: enabled ? AppColors.inkDark : AppColors.pharmaMuted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            enabled ? subtitle : '$unavailableReason · export indisponible',
            style: const TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
          ),
          trailing: Icon(
            enabled ? Icons.chevron_right : Icons.block,
            color: AppColors.pharmaMuted,
          ),
          onTap: onPressed,
        ),
      ),
    );
  }
}
