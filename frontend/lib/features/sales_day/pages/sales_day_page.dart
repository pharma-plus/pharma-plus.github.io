/// ============================================================
/// VENTES DU JOUR — Page premium 3D (module indépendant)
/// ============================================================
/// Reconstruction complète du module « Ventes du jour » :
///  · Données réelles Supabase via l'API officielle (/sales/day et
///    /sales/day/transactions) avec JWT + RBAC sales:view ;
///  · 8 KPI métier + graphes (heures / paiements) + classement produits
///    + historique de transactions paginé ;
///  · Exports PDF / Excel / Impression fidèles à l'affichage ;
///  · POS strictement intact (aucun fichier features/pos modifié).
/// Événements dépassés ? Un état honnête est affiché (« — », notes de
/// couverture) — jamais de valeur inventée.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_export_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_hourly_chart.dart';
import '../widgets/sales_kpi_section.dart';
import '../widgets/sales_payment_chart.dart';
import '../widgets/sales_product_ranking.dart';
import '../widgets/sales_transactions_table.dart';

class SalesDayPage extends StatefulWidget {
  const SalesDayPage({super.key});

  @override
  State<SalesDayPage> createState() => _SalesDayPageState();
}

class _SalesDayPageState extends State<SalesDayPage> {
  late SalesDayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SalesDayController();
    _controller.addListener(_onChanged);
    _controller.initialLoad();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final kpis = c.analytics?.kpis;
    final hourly = c.analytics?.hourly ?? const <SalesHourBucket>[];
    final payments = c.analytics?.payments ?? const <SalesPaymentSlice>[];
    final top = c.analytics?.topProducts ?? const <SalesProductRank>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.pharmaText,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventes du jour',
              style: TextStyle(
                color: AppColors.pharmaText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Période : ${c.periodLabelText}',
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.ios_share, color: AppColors.pharmaGold, size: 20),
            tooltip: 'Export / impression',
            color: AppColors.pharmaSurface,
            onSelected: (v) => _export(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'pdf',
                child: Row(children: [
                  Icon(Icons.picture_as_pdf, size: 18, color: AppColors.pharmaGold),
                  SizedBox(width: 8),
                  Text('Exporter en PDF',
                      style: TextStyle(fontSize: 12.5)),
                ]),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(children: [
                  Icon(Icons.table_view, size: 18, color: AppColors.pharmaGold),
                  SizedBox(width: 8),
                  Text('Exporter Excel (CSV)',
                      style: TextStyle(fontSize: 12.5)),
                ]),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(children: [
                  Icon(Icons.print, size: 18, color: AppColors.pharmaGold),
                  SizedBox(width: 8),
                  Text('Imprimer', style: TextStyle(fontSize: 12.5)),
                ]),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _controller.reload(),
            icon: Icon(Icons.refresh, color: AppColors.pharmaGold, size: 20),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: c.loading
          ? _buildLoading()
          : _buildContent(context, c, kpis, hourly, payments, top),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SalesDateFilterSkeleton(),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (_, c) {
          final cross = c.maxWidth >= 900 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cross == 4 ? 2.55 : 1.65,
            ),
            itemBuilder: (_, __) => _SkeletonCard(),
            itemCount: 8,
          );
        }),
        const SizedBox(height: 26),
        const SizedBox(
          height: 60,
          child: Center(
            child: Text(
              'Chargement des ventes réelles…',
              style: TextStyle(color: AppColors.pharmaMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    SalesDayController c,
    SalesDayKpis? kpis,
    List<SalesHourBucket> hourly,
    List<SalesPaymentSlice> payments,
    List<SalesProductRank> top,
  ) {
    const padding = EdgeInsets.fromLTRB(16, 12, 16, 30);
    if (kpis == null && c.error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SalesStateBlock(
            error: c.error,
            onRetry: () => _controller.reload(),
            showSkeleton: false,
          ),
        ),
      );
    }
    if (kpis == null) {
      // Aucune donnée et aucune erreur : état neutre honnête.
      return const Center(
        child: Text(
          'Aucune donnée disponible pour cette période',
          style: TextStyle(color: AppColors.pharmaMuted),
        ),
      );
    }

    final note = c.coverageNote;
    return ListView(
      padding: padding,
      children: [
        SalesDateFilter(
          period: c.period,
          customRange: c.custom,
          periodLabel: c.periodLabelText,
          onSelect: (p) => _controller.setPeriod(p),
          onCustomRange: (r) => _controller.setCustomRange(r),
        ),
        const SizedBox(height: 14),
        SalesKpiSection(
          kpis: kpis,
          grossDeltaPct: c.grossDelta.pct,
          countDeltaPct: c.countDelta.pct,
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              note,
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 20),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: SalesHourlyChart(hourly: hourly),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final charts = <Widget>[
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: SalesPaymentChart(slices: payments),
              ),
            ),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: SalesProductRanking(products: top),
              ),
            ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: charts[0]),
                const SizedBox(width: 16),
                Expanded(child: charts[1]),
              ],
            );
          }
          return Column(
            children: [
              charts[0],
              const SizedBox(height: 16),
              charts[1],
            ],
          );
        }),
        const SizedBox(height: 20),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: SalesTransactionsTable(
              controller: c,
              onSearch: (v) => _controller.setSearch(v),
              onStatus: (s) => _controller.setStatus(s),
              onLoadMore: () => _controller.loadMore(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Source : Supabase · ventes · paiements · lignes de vente',
            style: TextStyle(color: AppColors.pharmaMuted, fontSize: 9.5),
          ),
        ),
      ],
    );
  }

  // (aucun champ résiduel ; le texte de recherche vit dans le tableau)

  void _export(BuildContext context, String kind) {
    final a = _controller.analytics;
    if (a == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Export indisponible : aucune donnée chargée pour cette période.'),
          backgroundColor: AppColors.pharmaSurface2,
        ),
      );
      return;
    }
    final label = _controller.periodLabelText;
    final tx = _controller.txRows;
    switch (kind) {
      case 'pdf':
        SalesExportService.exportPdf(
            periodLabel: label, analytics: a, transactions: tx);
        break;
      case 'excel':
        SalesExportService.exportExcel(
            periodLabel: label, analytics: a, transactions: tx);
        break;
      case 'print':
        SalesExportService.printReport(
            periodLabel: label, analytics: a, transactions: tx);
        break;
    }
  }
}

// -- widgets internes ---------------------------------------------------

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.emerald,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

class SalesDateFilterSkeleton extends StatelessWidget {
  const SalesDateFilterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Chargement des périodes…',
        style: TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
      ),
    );
  }
}
