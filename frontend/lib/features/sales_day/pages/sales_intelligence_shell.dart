/// ============================================================
/// PHARMA+ SALES INTELLIGENCE — Shell principal
/// ============================================================
/// Conteneur des 10 sous-pages. Orchestre :
///  · Menu latéral indépendant (PC) / bouton hamburger (mobile)
///  · Navigation Précédent / Suivant / Retour / Maison / Dashboard
///  · Filtres globaux conservés entre les pages
///  · Design sombre premium à RELIEF 2D (ombres, dégradés, liserés) —
///    aucune géométrie 3D réelle ; responsive PC / tablette / smartphone
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/services/auth_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/marble_texture.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../services/sales_financials.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';
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
  /// Contrôleur optionnel : permet aux tests de fournir une période fixe
  /// (goldens déterministes). En production, le shell crée le sien.
  final SalesDayController? controller;

  const SalesIntelligenceShell({super.key, this.controller});

  @override
  State<SalesIntelligenceShell> createState() => _SalesIntelligenceShellState();
}

class _SalesIntelligenceShellState extends State<SalesIntelligenceShell> {
  late SalesDayController _analytics;
  late bool _ownsController;
  late SalesNavigationController _nav;
  SalesIntelligencePage _current = SalesIntelligencePage.overview;
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _analytics = widget.controller ?? SalesDayController();
    SalesDayController.setActiveInstance(_analytics);
    _nav = SalesNavigationController(SalesMenuController());
    _listener = () {
      if (mounted) setState(() {});
    };
    _analytics.addListener(_listener);
    // Correctif P0 : le menu des 10 rubriques et le contrôleur de navigation
    // sont des ChangeNotifier. Sans abonnement, le clic sur le hamburger ne
    // provoquait aucun rebuild et le menu restait invisible/inerte.
    _nav.addListener(_listener);
    _nav.menu.addListener(_listener);
    if (_ownsController) _analytics.initialLoad();
  }

  @override
  void dispose() {
    _analytics.removeListener(_listener);
    _nav.removeListener(_listener);
    _nav.menu.removeListener(_listener);
    if (_ownsController) _analytics.dispose();
    // Nettoyer la référence statique si c'est cette instance qui est active.
    SalesDayController.clearActiveInstance();
    _nav.dispose();
    super.dispose();
  }

  void _goTo(SalesIntelligencePage page) {
    _nav.navigateTo(page.id).then((_) {
      if (mounted) setState(() => _current = page);
    });
  }

  void _previous() {
    // « Précédent » suit l'ordre logique des 10 rubriques ; « Retour »
    // (historique) reste géré séparément par _nav.goBack().
    final previousId = SalesPageOrder.previousId(_nav.currentId);
    _nav.navigateTo(previousId).then((_) {
      if (mounted)
        setState(() {
          _current = SalesIntelligencePage.values.firstWhere(
            (p) => p.id == previousId,
            orElse: () => SalesIntelligencePage.overview,
          );
        });
    });
  }

  void _next() {
    final nextId = SalesPageOrder.nextId(_nav.currentId);
    _nav.navigateTo(nextId).then((_) {
      if (mounted)
        setState(() => _current = SalesIntelligencePage.values.firstWhere(
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
    // Garde-fou client : l'autorité reste le serveur (sales:view + session),
    // mais on évite d'ouvrir un écran voué à l'échec pour un rôle non habilité.
    // (Pas de contrôle quand aucun utilisateur n'est chargé : tests unitaires.)
    final auth = AuthStore.instance;
    if (auth.user != null && !auth.canViewSales) {
      return Scaffold(
        backgroundColor: AppColors.pharmaBg,
        appBar: AppBar(title: const Text('Ventes du jour')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Accès refusé : la permission « sales:view » est requise pour '
              'consulter les ventes de cet établissement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SalesDesign.onDark, fontSize: 14),
            ),
          ),
        ),
      );
    }
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
          foregroundColor: SalesDesign.onDark,
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
                      color: SalesDesign.onDark,
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
                            color: SalesDesign.onDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _current.title,
                          style: const TextStyle(
                            color: SalesDesign.onDark,
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
                // Correction P1 : le libellé doit suivre la période courante du
                // contrôleur, qui peut changer depuis n'importe quelle page.
                'Période : ${_analytics.periodLabelText}',
                style: const TextStyle(
                  color: SalesDesign.onDarkSoft,
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
                  color: SalesDesign.onDark,
                  size: 20,
                ),
                tooltip: menuOpen ? 'Fermer le menu' : 'Menu',
              ),
            ],
            IconButton(
              onPressed: () => _analytics.reload(),
              icon: const Icon(Icons.refresh, size: 20),
              color: SalesDesign.onDark,
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
                // La barre de navigation reste présente même quand le menu
                // est ouvert (Maison / Dashboard / Suivant ne doivent pas
                // disparaître de l'arbre, y compris pour le clavier).
                navRow,
                Expanded(child: page),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile / tablette : menu en overlay (Drawer), navigation en bas.
    // Correction P1 : la barre inférieure était en Positioned sans espace
    // réservé et masquait les dernières lignes des listes.
    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: page),
            const SizedBox(height: 56),
          ],
        ),
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
              color: SalesDesign.panelFillStrong,
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
      color: SalesDesign.panelFill,
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
    // Correction P1 : toutes les rubriques restent montées dans un IndexedStack
    // afin de préserver leur état local (filtres, tri, saisie de clôture) lors
    // d'un changement de rubrique, comme le fait déjà le HomeShell principal.
    return IndexedStack(
      index: _current.index,
      children: [
        SalesDayOverviewPage(
          analytics: _analytics,
          onNavigate: (id) => _goTo(
            SalesIntelligencePage.values.firstWhere(
              (p) => p.id == id,
              orElse: () => SalesIntelligencePage.overview,
            ),
          ),
        ),
        SalesAnalysisPage(analytics: _analytics),
        SalesProfitsPage(analytics: _analytics),
        SalesProductsPage(analytics: _analytics),
        SalesEmployeesPage(analytics: _analytics),
        SalesPaymentsPage(analytics: _analytics),
        SalesReturnsPage(analytics: _analytics),
        SalesComparisonsPage(analytics: _analytics),
        SalesReportsPage(analytics: _analytics),
        SalesAlertsPage(analytics: _analytics),
      ],
    );
  }
}

/// ============================================================
/// SOUS-PAGE 1 : VUE GÉNÉRALE
/// ============================================================
class SalesDayOverviewPage extends StatefulWidget {
  final SalesDayController analytics;
  final ValueChanged<String>? onNavigate;

  const SalesDayOverviewPage({
    super.key,
    required this.analytics,
    this.onNavigate,
  });

  @override
  State<SalesDayOverviewPage> createState() => _SalesDayOverviewPageState();
}

class _SalesDayOverviewPageState extends State<SalesDayOverviewPage> {
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

  /// Charge le jeu complet nécessaire au KPI « Produits vendus ».
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
    _requestFull();
    final c = widget.analytics;
    final kpis = c.analytics?.kpis;
    final finance = SalesFinancials.fromKpis(kpis);
    final hourly = c.analytics?.hourly ?? const <SalesHourBucket>[];
    final payments = c.analytics?.payments ?? const <SalesPaymentSlice>[];
    final topQty = c.analytics?.topProductsQty ?? const <SalesProductRank>[];
    final topRev = c.analytics?.topProductsRev ?? const <SalesProductRank>[];
    final topProfit =
        c.analytics?.topProductsProfit ?? const <SalesProductRank>[];

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
          title: 'Vue générale',
          subtitle:
              '${c.periodLabelText} · KPI et montants réels · source Supabase',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        SalesKpiSection(
          kpis: kpis ??
              const SalesDayKpis(
                grossRevenue: 0,
                netRevenue: 0,
                taxTotal: 0,
                discountsTotal: 0,
                salesCount: 0,
                averageBasket: 0,
                cancelledCount: 0,
                returnedCount: 0,
                paidAmount: 0,
                outstandingAmount: 0,
                refundedAmount: null,
                costTotal: null,
                totalRows: 0,
              ),
          grossDeltaPct: c.grossDelta.pct,
          countDeltaPct: c.countDelta.pct,
          productsSold: c.fullRows
              .fold<int>(0, (s, t) => s + (t.itemsCount?.toInt() ?? 0)),
          grossProfitLabel: c.dataUnavailable
              ? 'N/D'
              : finance.grossProfit == null
                  ? (finance.costReliability == SalesCostReliability.absent
                      ? 'N/D'
                      : 'Non vérifiable')
                  : Fmt.number(finance.grossProfit!, decimals: 2),
          marginLabel: c.dataUnavailable
              ? 'N/D'
              : finance.grossMarginPct == null
                  ? (finance.costReliability == SalesCostReliability.absent
                      ? 'N/D'
                      : 'Non vérifiable')
                  : '${finance.grossMarginPct!.toStringAsFixed(1)} %',
          dataUnavailable: c.dataUnavailable,
          productsUnavailable: !c.fullComplete,
          onNavigate: widget.onNavigate,
        ),
        if (c.coverageNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              c.coverageNote,
              style: const TextStyle(
                color: SalesDesign.onDarkSoft,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: SalesDesign.spacingLG),
        SalesPanel(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
          child: SalesHourlyChart(
            hourly: hourly,
            height: SalesDesign.chartHourlyHeight,
            loading: c.loading,
            errorMessage: c.error?.userMessage ??
                (c.analytics?.incomplete == true
                    ? 'Données indisponibles (réponse vide)'
                    : null),
          ),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final charts = <Widget>[
            SalesPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: SalesPaymentChart(
                slices: payments,
                unavailable: c.dataUnavailable,
              ),
            ),
            SalesPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SalesProductRanking(
                    title: 'Top 10 par quantité',
                    products: topQty,
                    sortBy: 'qty',
                    onProductTap: (_) => widget.onNavigate?.call('products'),
                  ),
                  const SizedBox(height: SalesDesign.spacingMD),
                  SalesProductRanking(
                    title: 'Top 10 par CA',
                    products: topRev,
                    sortBy: 'rev',
                    onProductTap: (_) => widget.onNavigate?.call('products'),
                  ),
                  const SizedBox(height: SalesDesign.spacingMD),
                  SalesProductRanking(
                    title: 'Top 10 par bénéfice',
                    products: topProfit,
                    sortBy: 'profit',
                    onProductTap: (_) => widget.onNavigate?.call('products'),
                  ),
                ],
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
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: SalesTransactionsTable(
            controller: c,
            onSearch: (v) => c.setSearch(v),
            onStatus: (s) => c.setStatus(s),
            onLoadMore: () => c.loadMore(),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Source : Supabase · ventes · paiements · lignes de vente',
            style: TextStyle(color: SalesDesign.onDarkSoft, fontSize: 9.5),
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
    final kpis = c.analytics?.kpis;
    final hourly = c.analytics?.hourly ?? const <SalesHourBucket>[];
    final tx = c.txRows;
    _requestFull();
    final quantities =
        c.fullRows.fold<int>(0, (s, t) => s + (t.itemsCount?.toInt() ?? 0));

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
          title: 'Analyse des ventes',
          subtitle: '${c.periodLabelText} · indicateurs et répartition horaire',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        SalesPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalesSectionHeader(
                title: 'Résumé analytique',
                subtitle: '${c.fullScopeLabel} · montants MAD',
              ),
              const SizedBox(height: SalesDesign.spacingMD),
              Wrap(
                spacing: SalesDesign.spacingLG,
                runSpacing: SalesDesign.spacingSM,
                children: [
                  SalesMetric(
                      label: 'Tickets',
                      value: '${kpis?.salesCount ?? 0}',
                      color: AppColors.sageGreenInk),
                  SalesMetric(
                      label: 'CA TTC',
                      value: Fmt.number(kpis?.grossRevenue ?? 0, decimals: 2),
                      unit: 'MAD',
                      color: AppColors.champagneInk),
                  SalesMetric(
                      label: 'Panier moyen',
                      value: Fmt.number(kpis?.averageBasket ?? 0, decimals: 2),
                      unit: 'MAD',
                      color: AppColors.cardBlue),
                  SalesMetric(
                      label: 'Quantités',
                      value: c.fullLoading ? '…' : Fmt.number(quantities),
                      color: AppColors.cardPurple,
                      hint: c.fullComplete ? null : 'jeu complet indisponible'),
                  SalesMetric(
                      label: 'CA HT',
                      value: Fmt.number(kpis?.netRevenue ?? 0, decimals: 2),
                      unit: 'MAD',
                      color: AppColors.cardAmber),
                  SalesMetric(
                      label: 'Remises',
                      value: Fmt.number(kpis?.discountsTotal ?? 0, decimals: 2),
                      unit: 'MAD',
                      color: AppColors.pharmaWarning),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
          child: SalesHourlyChart(
            hourly: hourly,
            height: SalesDesign.chartHourlyHeightDetail,
            title: 'Répartition horaire des ventes',
            loading: c.loading,
            errorMessage: c.error?.userMessage ??
                (c.analytics?.incomplete == true
                    ? 'Données indisponibles (réponse vide)'
                    : null),
          ),
        ),
        const SizedBox(height: SalesDesign.spacingLG),
        SalesSectionHeader(
          title: 'Dernières transactions',
          subtitle: '10 premières lignes de la période · triées par date API',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        if (c.txError != null)
          SalesNotice(message: c.txError!.userMessage)
        else if (tx.isEmpty)
          const SalesEmptyState(message: 'Aucune transaction sur la période')
        else ...[
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
                                color: SalesDesign.onDark,
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
                                color: SalesDesign.onDarkMuted,
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
}
