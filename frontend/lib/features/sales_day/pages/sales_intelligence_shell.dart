/// ============================================================
/// PHARMA+ SALES INTELLIGENCE — Shell principal
/// ============================================================
/// Conteneur des 10 sous-pages. Orchestre :
///  · Menu latéral indépendant (PC) / bouton hamburger (mobile)
///  · Navigation Précédent / Suivant / Retour / Maison / Dashboard
///  · Filtres globaux conservés entre les pages
///  · Design sombre premium 3D, responsive PC / tablette / smartphone
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/marble_texture.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../services/sales_export_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_hourly_chart.dart';
import '../widgets/sales_kpi_section.dart';
import '../widgets/sales_navigation.dart';
import '../widgets/sales_payment_chart.dart';
import '../widgets/sales_product_ranking.dart';
import '../widgets/sales_sidebar_menu.dart';
import '../widgets/sales_transactions_table.dart';
import '../pages/sales_comparisons_page.dart';
import '../pages/sales_reports_page.dart';
import '../pages/sales_alerts_page.dart';
import '../pages/sales_profits_page.dart';
import '../pages/sales_products_page.dart';
import '../pages/sales_employees_page.dart';
import '../pages/sales_payments_page.dart';
import '../pages/sales_returns_page.dart';

/// Sous-pages disponibles.
enum SalesIntelligencePage {
  overview,
  analysis,
  profits,
  products,
  employees,
  payments,
  returns,
  comparisons,
  reports,
  alerts,
}

extension SalesIntelligencePageX on SalesIntelligencePage {
  String get id {
    switch (this) {
      case SalesIntelligencePage.overview:
        return 'overview';
      case SalesIntelligencePage.analysis:
        return 'analysis';
      case SalesIntelligencePage.profits:
        return 'profits';
      case SalesIntelligencePage.products:
        return 'products';
      case SalesIntelligencePage.employees:
        return 'employees';
      case SalesIntelligencePage.payments:
        return 'payments';
      case SalesIntelligencePage.returns:
        return 'returns';
      case SalesIntelligencePage.comparisons:
        return 'comparisons';
      case SalesIntelligencePage.reports:
        return 'reports';
      case SalesIntelligencePage.alerts:
        return 'alerts';
    }
  }

  String get title {
    switch (this) {
      case SalesIntelligencePage.overview:
        return 'Vue générale';
      case SalesIntelligencePage.analysis:
        return 'Analyse des ventes';
      case SalesIntelligencePage.profits:
        return 'Bénéfices & marges';
      case SalesIntelligencePage.products:
        return 'Produits vendus';
      case SalesIntelligencePage.employees:
        return 'Performance employés';
      case SalesIntelligencePage.payments:
        return 'Paiements & caisse';
      case SalesIntelligencePage.returns:
        return 'Annulations & retours';
      case SalesIntelligencePage.comparisons:
        return 'Comparaisons';
      case SalesIntelligencePage.reports:
        return 'Rapports & exports';
      case SalesIntelligencePage.alerts:
        return 'Alertes intelligentes';
    }
  }

  IconData get icon {
    switch (this) {
      case SalesIntelligencePage.overview:
        return Icons.dashboard_outlined;
      case SalesIntelligencePage.analysis:
        return Icons.bar_chart_outlined;
      case SalesIntelligencePage.profits:
        return Icons.trending_up_outlined;
      case SalesIntelligencePage.products:
        return Icons.local_pharmacy;
      case SalesIntelligencePage.employees:
        return Icons.people_outlined;
      case SalesIntelligencePage.payments:
        return Icons.account_balance_wallet_outlined;
      case SalesIntelligencePage.returns:
        return Icons.cancel_outlined;
      case SalesIntelligencePage.comparisons:
        return Icons.compare_outlined;
      case SalesIntelligencePage.reports:
        return Icons.description_outlined;
      case SalesIntelligencePage.alerts:
        return Icons.notifications_outlined;
    }
  }
}

/// Shell principal de PHARMA+ SALES INTELLIGENCE.
/// Le POS et le dashboard principal restent totalement intacts :
/// ce shell est uniquement invoqué depuis le KPI 'VENTES DU JOUR'.
class SalesIntelligenceShell extends StatefulWidget {
  const SalesIntelligenceShell({super.key});

  @override
  State<SalesIntelligenceShell> createState() => _SalesIntelligenceShellState();
}

class _SalesIntelligenceShellState extends State<SalesIntelligenceShell> {
  late SalesDayController _analytics;
  late SalesNavigationController _nav;
  SalesIntelligencePage _current = SalesIntelligencePage.overview;
  late final VoidCallback _listener;

  // Filtres globaux partagés entre les pages.
  SalesPeriod _period = SalesPeriod.today;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _analytics = SalesDayController();
    _nav = SalesNavigationController(SalesMenuController());
    _listener = () {
      if (mounted) setState(() {});
    };
    _analytics.addListener(_listener);
    _analytics.initialLoad();
  }

  @override
  void dispose() {
    _analytics.removeListener(_listener);
    _analytics.dispose();
    _nav.dispose();
    super.dispose();
  }

  void _goTo(SalesIntelligencePage page) {
    _nav.navigateTo(page.id).then((_) {
      if (mounted) setState(() => _current = page);
    });
  }

  void _previous() {
    _nav.goBack().then((_) {
      if (mounted) setState(() {
        _current = SalesIntelligencePage.values.firstWhere(
          (p) => p.id == _nav.currentId,
          orElse: () => SalesIntelligencePage.overview,
        );
      });
    });
  }

  void _next() {
    final nextId = SalesPageOrder.nextId(_nav.currentId);
    _nav.navigateTo(nextId).then((_) {
      if (mounted) setState(() => _current = SalesIntelligencePage.values.firstWhere(
        (p) => p.id == nextId,
        orElse: () => SalesIntelligencePage.overview,
      ));
    });
  }

  void _home() {
    _nav.goHome().then((_) {
      if (mounted) setState(() => _current = SalesIntelligencePage.overview);
    });
  }

  void _dashboard() {
    _nav.goDashboard();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final menuOpen = _nav.menu.open;

    // Le module SALES INTELLIGENCE a sa propre présentation « Marbre
    // gris argenté » (thème clair de la charte), indépendante du
    // themeMode global — écritures encre foncée toujours lisibles.
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.inkDark,
        elevation: 0,
        leading: isWide
            ? null
            : SalesMenuToggle(
                onPressed: () => _nav.menu.toggle(),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreenInk.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: AppColors.sageGreenInk.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.point_of_sale,
                    color: AppColors.sageGreenInk,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PHARMA+ SALES INTELLIGENCE',
                        style: TextStyle(
                          color: AppColors.champagneInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _current.title,
                        style: const TextStyle(
                          color: AppColors.inkDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              'Période : ${SalesAnalyticsService.periodLabel(_period, SalesAnalyticsService.rangeFor(_period, custom: _customRange))}',
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          if (isWide) ...[
            IconButton(
              onPressed: () => _nav.menu.toggle(),
              icon: Icon(
                menuOpen ? Icons.close : Icons.menu,
                color: AppColors.champagneInk,
                size: 20,
              ),
              tooltip: menuOpen ? 'Fermer le menu' : 'Menu',
            ),
          ],
          IconButton(
            onPressed: () => _analytics.reload(),
            icon: const Icon(Icons.refresh, size: 20),
            color: AppColors.champagneInk,
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MarbleBackground(
        dark: false,
        child: _buildBody(context, isWide),
      ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    final navRow = _buildNavigationRow();
    final page = _buildPage();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SalesSidebarMenu(
            menu: _nav.menu,
            onItemSelected: (id) {
              final page = SalesIntelligencePage.values.firstWhere(
                (p) => p.id == id,
                orElse: () => SalesIntelligencePage.overview,
              );
              _goTo(page);
            },
          ),
          const SizedBox(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_nav.menu.open) navRow else const SizedBox.shrink(),
                Expanded(child: page),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile / tablette : menu en overlay (Drawer), navigation en bas
    return Stack(
      children: [
        page,
        if (_nav.menu.open)
          GestureDetector(
            onTap: () => _nav.menu.closeMenu(),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        if (_nav.menu.open)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 240,
            child: SalesSidebarMenu(
              menu: _nav.menu,
              onItemSelected: (id) {
                final page = SalesIntelligencePage.values.firstWhere(
                  (p) => p.id == id,
                  orElse: () => SalesIntelligencePage.overview,
                );
                _goTo(page);
              },
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MarbleBackground(
            dark: false,
            child: Container(
            color: AppColors.silver,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _nav.buildPreviousButton(context, _previous, compact: true),
                _nav.buildHomeButton(context, _home, compact: true),
                _nav.buildDashboardButton(context, _dashboard, compact: true),
                _nav.buildNextButton(context, _next, compact: true),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationRow() {
    return Container(
      color: AppColors.silver.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _nav.buildBackButton(context, _previous),
          const SizedBox(width: 8),
          _nav.buildPreviousButton(context, _previous),
          const SizedBox(width: 8),
          _nav.buildHomeButton(context, _home),
          const SizedBox(width: 8),
          _nav.buildDashboardButton(context, _dashboard),
          const SizedBox(width: 8),
          _nav.buildNextButton(context, _next),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_current) {
      case SalesIntelligencePage.overview:
        return SalesDayOverviewPage(analytics: _analytics);
      case SalesIntelligencePage.analysis:
        return SalesAnalysisPage(analytics: _analytics);
      case SalesIntelligencePage.profits:
        return SalesProfitsPage(analytics: _analytics);
      case SalesIntelligencePage.products:
        return SalesProductsPage(analytics: _analytics);
      case SalesIntelligencePage.employees:
        return SalesEmployeesPage(analytics: _analytics);
      case SalesIntelligencePage.payments:
        return SalesPaymentsPage(analytics: _analytics);
      case SalesIntelligencePage.returns:
        return SalesReturnsPage(analytics: _analytics);
      case SalesIntelligencePage.comparisons:
        return SalesComparisonsPage(analytics: _analytics);
      case SalesIntelligencePage.reports:
        return SalesReportsPage(analytics: _analytics);
      case SalesIntelligencePage.alerts:
        return SalesAlertsPage(analytics: _analytics);
    }
  }
}

/// ============================================================
/// SOUS-PAGE 1 : VUE GÉNÉRALE
/// ============================================================
class SalesDayOverviewPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesDayOverviewPage({super.key, required this.analytics});

  @override
  State<SalesDayOverviewPage> createState() => _SalesDayOverviewPageState();
}

class _SalesDayOverviewPageState extends State<SalesDayOverviewPage> {
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
    final kpis = c.analytics?.kpis;
    final hourly = c.analytics?.hourly ?? const <SalesHourBucket>[];
    final payments = c.analytics?.payments ?? const <SalesPaymentSlice>[];
    final topQty = c.analytics?.topProductsQty ?? const <SalesProductRank>[];
    final topRev = c.analytics?.topProductsRev ?? const <SalesProductRank>[];
    final topProfit = c.analytics?.topProductsProfit ?? const <SalesProductRank>[];

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
        SalesKpiSection(
          kpis: kpis ?? const SalesDayKpis(
            grossRevenue: 0, netRevenue: 0, taxTotal: 0,
            discountsTotal: 0, salesCount: 0, averageBasket: 0,
            cancelledCount: 0, returnedCount: 0, paidAmount: 0,
            outstandingAmount: 0, refundedAmount: null, costTotal: 0,
            totalRows: 0,
          ),
          grossDeltaPct: c.grossDelta.pct,
          countDeltaPct: c.countDelta.pct,
        ),
        if (c.coverageNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              c.coverageNote,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SalesProductRanking(
                      title: 'Top 10 par quantité',
                      products: topQty,
                      sortBy: 'qty',
                    ),
                    const SizedBox(height: 16),
                    SalesProductRanking(
                      title: 'Top 10 par CA',
                      products: topRev,
                      sortBy: 'rev',
                    ),
                    const SizedBox(height: 16),
                    SalesProductRanking(
                      title: 'Top 10 par bénéfice',
                      products: topProfit,
                      sortBy: 'profit',
                    ),
                  ],
                ),
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
              onSearch: (v) => c.setSearch(v),
              onStatus: (s) => c.setStatus(s),
              onLoadMore: () => c.loadMore(),
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
}

/// ============================================================
/// SOUS-PAGE 2 : ANALYSE DES VENTES
/// ============================================================
class SalesAnalysisPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesAnalysisPage({super.key, required this.analytics});

  @override
  State<SalesAnalysisPage> createState() => _SalesAnalysisPageState();
}

class _SalesAnalysisPageState extends State<SalesAnalysisPage> {
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
    final kpis = c.analytics?.kpis;
    final hourly = c.analytics?.hourly ?? const <SalesHourBucket>[];
    final tx = c.txRows;

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
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Résumé analytique',
                  style: TextStyle(
                    color: AppColors.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _kpiItem(
                        'Tickets', '${kpis?.salesCount ?? 0}',
                        AppColors.sageGreenInk,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'CA TTC', Fmt.number(kpis?.grossRevenue ?? 0,
                            decimals: 2),
                        AppColors.champagneInk,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Panier moyen', Fmt.number(
                          kpis?.averageBasket ?? 0, decimals: 2),
                        AppColors.cardBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kpiItem(
                        'Quantités', '${tx.fold<int>(0, (s, t) =>
                            s + (t.itemsCount?.toInt() ?? 0))}',
                        AppColors.cardPurple,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'CA HT', Fmt.number(kpis?.netRevenue ?? 0,
                            decimals: 2),
                        AppColors.cardAmber,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Remises', Fmt.number(kpis?.discountsTotal ?? 0,
                            decimals: 2),
                        AppColors.pharmaWarning,
                      ),
                    ),
                  ],
                ),
              ],
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
        const SizedBox(height: 20),
        const Text(
          'Dernières transactions',
          style: TextStyle(
            color: AppColors.inkDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (tx.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune transaction sur la période',
                style: TextStyle(color: AppColors.pharmaMuted),
              ),
            ),
          )
        else
          ...[
            for (final t in tx.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.pharmaSurface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
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
                                t.createdAt == null
                                    ? '—'
                                    : '${SalesAnalyticsService.hourMinute(t.createdAt)} · ${t.statusLabel}',
                                style: const TextStyle(
                                  color: AppColors.pharmaMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.number(t.total, decimals: 2),
                          style: const TextStyle(
                            color: AppColors.champagneInkLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }

  Widget _kpiItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
