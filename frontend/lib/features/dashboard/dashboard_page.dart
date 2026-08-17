import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/services/offline_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/pharma3d_card.dart';
import '../../core/widgets/pharma_wide_card.dart';
import '../pos/pos_models.dart';
import '../cameras/cameras_page.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../employees/employees_page.dart';
import '../notifications/notifications_page.dart';
import '../pos/pos_page.dart';
import '../prescriptions/prescriptions_page.dart';
import '../purchases/purchases_page.dart';
import '../reference/reference_page.dart';
import '../reports/reports_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../ai/ai_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/dashboard/overview');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message ?? 'Erreur';
      });
      return;
    }
    setState(() {
      _data = result.data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final auth = context.watch<AuthStore>();

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final revenue = (_data?['revenue'] as Map<String, dynamic>?) ?? {};
    final alerts = (_data?['alerts'] as Map<String, dynamic>?) ?? {};
    final counts = (_data?['counts'] as Map<String, dynamic>?) ?? {};
    final stockInfo = (_data?['stock'] as Map<String, dynamic>?) ?? {};
    final topProducts = (_data?['top_products'] as List? ?? const []);
    final trend = (_data?['sales_trend'] as List? ?? const []);
    final pp = (_data?['pharma_plus'] as Map<String, dynamic>?) ?? {};
    final para = (pp['parapharmacy'] as Map<String, dynamic>?) ?? {};
    final cams = (pp['cameras'] as Map<String, dynamic>?) ?? {};
    final ai = (pp['pharma_ai'] as Map<String, dynamic>?) ?? {};
    final ref = (pp['reference'] as Map<String, dynamic>?) ?? {};
    final lastSync = (ref['last_sync'] as Map<String, dynamic>?) ?? {};
    final meds = (counts['medications'] as Map<String, dynamic>?) ?? {};
    final presc = (counts['prescriptions'] as Map<String, dynamic>?) ?? {};
    final customers = (counts['customers'] as Map<String, dynamic>?) ?? {};
    final suppliers = (counts['suppliers'] as Map<String, dynamic>?) ?? {};

    final firstName = auth.user?.firstName.trim();
    final greetingName = (firstName == null || firstName.isEmpty)
        ? S.t('dashboard', locale)
        : firstName;

    void push(Widget p) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => p));
    return LayoutBuilder(builder: (context, constraints) {
      final showPos = constraints.maxWidth >= 1180;
      final Widget center = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.menu, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                gradient: AppColors.goldGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  auth.user?.initials ?? 'P',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3E2A00),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                S.format(
                                    'greeting', locale, {'name': greetingName}),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _GlobalSearchBar(
                          onSearch: () =>
                              push(const CatalogPage()),
                          onScan: () => push(const PosPage()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1500
                      ? 4
                      : constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 640
                              ? 2
                              : 1;
                  final kpis = <({
                    IconData icon,
                    String label,
                    String value,
                    String? subtitle,
                    Gradient gradient,
                    Color glow,
                    VoidCallback onTap,
                    String? badge,
                  })>[
                    (
                      icon: Icons.payments_outlined,
                      label: S.t('todayRevenue', locale),
                      value: Fmt.money(
                          double.tryParse('${revenue['revenue_today'] ?? 0}') ??
                              0),
                      subtitle:
                          '${S.t('transactions', locale)}: ${revenue['sales_today'] ?? 0}',
                      gradient: AppColors.goldGradient,
                      glow: AppColors.accent,
                      onTap: () => push(const ReportsPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.medication_outlined,
                      label: S.t('medications', locale),
                      value: '${meds['total'] ?? 0}',
                      subtitle:
                          '${S.t('total', locale)}: ${meds['available'] ?? 0}',
                      gradient: AppColors.greenGradient,
                      glow: AppColors.primary,
                      onTap: () => push(const CatalogPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.warning_amber_outlined,
                      label: S.t('lowStock', locale),
                      value: '${alerts['low_stock'] ?? 0}',
                      subtitle:
                          '${S.t('expiring', locale)}: ${alerts['expiring'] ?? 0}',
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7A4F00), Color(0xFFC77700)]),
                      glow: AppColors.warning,
                      onTap: () =>
                          push(const StockPage(initialFilter: 'low')),
                      badge: null,
                    ),
                    (
                      icon: Icons.receipt_long_outlined,
                      label: S.t('pendingOrders', locale),
                      value: '${alerts['pending_orders'] ?? 0}',
                      subtitle: S.t('purchases', locale),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]),
                      glow: const Color(0xFF42A5F5),
                      onTap: () => push(const PurchasesPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.local_shipping_outlined,
                      label: S.t('suppliers', locale),
                      value: '${suppliers['total'] ?? 0}',
                      subtitle:
                          '${S.t('active', locale)}: ${suppliers['active'] ?? 0}',
                      gradient: const LinearGradient(
                          colors: [Color(0xFF283593), Color(0xFF3949AB)]),
                      glow: const Color(0xFF5C6BC0),
                      onTap: () => push(const SuppliersPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.people_outline,
                      label: S.t('customers', locale),
                      value: '${customers['total'] ?? 0}',
                      subtitle:
                          '${S.t('active', locale)}: ${customers['active'] ?? 0}',
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
                      glow: const Color(0xFFAB47BC),
                      onTap: () => push(const CustomersPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.badge_outlined,
                      label: S.t('employees', locale),
                      value: '${_data?['employees_present'] ?? 0}',
                      subtitle: S.t('present', locale),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00695C), Color(0xFF00897B)]),
                      glow: const Color(0xFF26A69A),
                      onTap: () => push(const EmployeesPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.trending_up,
                      label: S.t('profit', locale),
                      value: Fmt.money(double.tryParse(
                              '${revenue['profit_month'] ?? 0}') ??
                          0),
                      subtitle: S.t('revenue30d', locale),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
                      glow: const Color(0xFF66BB6A),
                      onTap: () => push(const ReportsPage()),
                      badge: null,
                    ),
                  ];
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      for (var i = 0; i < kpis.length; i++)
                        Pharma3DCard(
                          key: ValueKey('kpi-${kpis[i].label}'),
                          icon: kpis[i].icon,
                          label: kpis[i].label,
                          value: kpis[i].value,
                          subtitle: kpis[i].subtitle,
                          gradient: kpis[i].gradient,
                          glow: kpis[i].glow,
                          onTap: kpis[i].onTap,
                          badge: kpis[i].badge,
                          entranceDelay: Duration(milliseconds: i * 60),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                 _WorkspaceSection(
                   todayRevenue:
                       double.tryParse('${revenue['revenue_today'] ?? 0}') ?? 0,
                   lowStock: (alerts['low_stock'] as num?)?.toDouble() ?? 0,
                   onOpenPlan: () => push(const PharmacyPlanPage()),
                 ),
                const SizedBox(height: 20),
                _SectionLabel(title: S.t('modules', locale)),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 700
                          ? 3
                          : 2;
                  final cardData = <({
                    IconData icon,
                    String label,
                    String value,
                    String? subtitle,
                    Gradient gradient,
                    Color glow,
                    VoidCallback onTap,
                    String? badge,
                  })>[
                    (
                      icon: Icons.medication_outlined,
                      label: S.t('medications', locale),
                      value: '${meds['available'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${meds['total'] ?? 0}',
                      gradient: AppColors.greenGradient,
                      glow: AppColors.primary,
                      onTap: () => push(const CatalogPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.inventory_2_outlined,
                      label: S.t('stock', locale),
                      value: Fmt.money(double.tryParse('${stockInfo['stock_value'] ?? 0}') ?? 0),
                      subtitle: '${S.t('lowStock', locale)}: ${alerts['low_stock'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A2A6B)]),
                      glow: AppColors.secondary,
                      onTap: () => push(const StockPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.point_of_sale,
                      label: S.t('sales', locale),
                      value: Fmt.number((revenue['sales_month'] as num?)?.toDouble() ?? 0),
                      subtitle: '${(revenue['sales_today'] as num?)?.toInt() ?? 0} ${S.t('today', locale)}',
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const PosPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.payments_outlined,
                      label: S.t('revenue', locale),
                      value: Fmt.money(double.tryParse('${revenue['revenue_month'] ?? 0}') ?? 0),
                      subtitle: '${S.t('profit', locale)}: ${Fmt.money(double.tryParse('${revenue['profit_month'] ?? 0}') ?? 0)}',
                      gradient: AppColors.goldGradient,
                      glow: AppColors.accent,
                      onTap: () => push(const ReportsPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.description_outlined,
                      label: S.t('prescriptions', locale),
                      value: '${presc['month'] ?? 0}',
                      subtitle: '${presc['pending'] ?? 0} ${S.t('pending', locale)}',
                      gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF512DA8), Color(0xFF311B92)]),
                      glow: const Color(0xFF9C27B0),
                      onTap: () => push(const PrescriptionsPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.people_outline,
                      label: S.t('customers', locale),
                      value: '${customers['active'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${customers['total'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF00838F), Color(0xFF00695C), Color(0xFF004D40)]),
                      glow: const Color(0xFF00ACC1),
                      onTap: () => push(const CustomersPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.local_shipping_outlined,
                      label: S.t('suppliers', locale),
                      value: '${suppliers['active'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${suppliers['total'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFFEF6C00), Color(0xFFE65100), Color(0xFFBF360C)]),
                      glow: const Color(0xFFFF8F00),
                      onTap: () => push(const SuppliersPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.spa_outlined,
                      label: S.t('parapharmacy', locale),
                      value: Fmt.number((para['products'] as num?)?.toDouble() ?? 0),
                      subtitle: '${S.t('paraRevenue', locale)}: ${Fmt.money(double.tryParse('${para['revenue_month'] ?? 0}') ?? 0)}',
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const CatalogPage(parapharmacy: true)),
                      badge: null,
                    ),
                    (
                      icon: Icons.warning_amber_outlined,
                      label: S.t('alerts', locale),
                      value: '${alerts['low_stock'] ?? 0}',
                      subtitle: '${S.t('expiring', locale)}: ${alerts['expiring'] ?? 0} · ${S.t('expired', locale)}: ${alerts['expired'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFC62828), Color(0xFF8E0000)]),
                      glow: AppColors.danger,
                      onTap: () => push(const StockPage()),
                      badge: '!',
                    ),
                    (
                      icon: Icons.qr_code_scanner,
                      label: S.t('barcode', locale),
                      value: 'Scan',
                      subtitle: S.t('scanSubtitle', locale),
                      gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0277BD), Color(0xFF01579B)]),
                      glow: AppColors.info,
                      onTap: () => push(const PosPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.videocam_outlined,
                      label: S.t('cameras', locale),
                      value: '${(cams['online'] as num?)?.toInt() ?? 0}/${(cams['total'] as num?)?.toInt() ?? 0}',
                      subtitle: '${S.t('cameraRecording', locale)}: ${(cams['recording'] as num?)?.toInt() ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1B5E20)]),
                      glow: AppColors.primary,
                      onTap: () => push(const CamerasPage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.medication_liquid_outlined,
                      label: S.t('baseMaroc', locale),
                      value: '${ref['total'] ?? _syncTotal(lastSync)}',
                      subtitle: '${S.t('lastSync', locale)}: ${Fmt.dateTime(_parseDate(lastSync['finished_at']), locale: locale)}',
                      gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF0D47A1)]),
                      glow: AppColors.turquoise,
                      onTap: () => push(const ReferencePage()),
                      badge: null,
                    ),
                    (
                      icon: Icons.storefront_outlined,
                      label: S.t('pharmacyPlan', locale),
                      value: '3D',
                      subtitle: S.t('pharmacyPlanSub', locale),
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const PharmacyPlanPage()),
                      badge: null,
                    ),
                  ];
                  final items = <Widget>[
                    for (var i = 0; i < cardData.length; i++)
                      Pharma3DCard(
                        key: ValueKey('mod-${cardData[i].label}'),
                        icon: cardData[i].icon,
                        label: cardData[i].label,
                        value: cardData[i].value,
                        subtitle: cardData[i].subtitle,
                        gradient: cardData[i].gradient,
                        glow: cardData[i].glow,
                        onTap: cardData[i].onTap,
                        badge: cardData[i].badge,
                        entranceDelay: Duration(milliseconds: i * 70),
                      ),
                  ];
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: items,
                  );
                }),
                const SizedBox(height: 20),
                PharmaWideCard(
                  icon: Icons.auto_awesome,
                  title: S.t('pharmaAi', locale),
                  subtitle: '${S.t('aiAnalytics', locale)} · ${S.t('aiProductivity', locale)}',
                  badge: 'PHARMA+',
                  gradient: AppColors.aiGradient,
                  glow: const Color(0xFF7C4DFF),
                  onTap: () => push(const AiPage()),
                  metrics: Row(children: [
                    WideMetric(label: S.t('aiRequests7d', locale), value: '${ai['requests_7d'] ?? 0}'),
                    WideMetric(label: S.t('aiSuccess7d', locale), value: '${ai['success_7d'] ?? 0}'),
                    WideMetric(label: S.t('stockValue', locale), value: Fmt.money(double.tryParse('${stockInfo['stock_value'] ?? 0}') ?? 0)),
                  ]),
                ),
                const SizedBox(height: 14),
                PharmaWideCard(
                  icon: Icons.insights,
                  title: S.t('analytics', locale),
                  subtitle: S.t('analyticsSubtitle', locale),
                  badge: S.t('reports', locale),
                  gradient: const LinearGradient(colors: [Color(0xFF283593), Color(0xFF3949AB), Color(0xFF1A237E)]),
                  glow: const Color(0xFF5C6BC0),
                  onTap: () => push(const ReportsPage()),
                  metrics: Row(children: [
                    WideMetric(label: S.t('revenue30dShort', locale), value: Fmt.money(double.tryParse('${revenue['revenue_month'] ?? 0}') ?? 0)),
                    WideMetric(label: S.t('transactions', locale), value: Fmt.number((revenue['sales_month'] as num?)?.toDouble() ?? 0)),
                    WideMetric(label: S.t('profit', locale), value: Fmt.money(double.tryParse('${revenue['profit_month'] ?? 0}') ?? 0)),
                    WideMetric(label: S.t('pendingOrders', locale), value: '${alerts['pending_orders'] ?? 0}'),
                  ]),
                ),
                const SizedBox(height: 20),
                // Section d'export de rapports
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(S.t('exportPdf', locale)),
                        onPressed: () => _exportPdfReport(context),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: Text(S.t('exportCsv', locale)),
                        onPressed: () => _exportCsvReport(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _RevenueChart(points: _trendPoints(trend)),
                const SizedBox(height: 16),
                if (topProducts.isNotEmpty) _TopProducts(items: topProducts),
              ],
            ),
          ),
        ],
      ),
      );
      if (!showPos) return center;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: center),
          Container(width: 1, color: Theme.of(context).dividerColor),
          SizedBox(width: 400, child: const DashboardPosPanel()),
        ],
      );
    });
  }

  List<FlSpot> _trendPoints(List<dynamic> rows) {
    if (rows.isEmpty) return const [];
    final spots = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      final value = double.tryParse('${(rows[i] as Map)['total'] ?? 0}') ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }
}

int _syncTotal(Map<String, dynamic> last) =>
    ((last['new_count'] as num?)?.toInt() ?? 0) +
    ((last['modified_count'] as num?)?.toInt() ?? 0) +
    ((last['price_changed_count'] as num?)?.toInt() ?? 0);

Future<void> _exportPdfReport(BuildContext ctx) async {
    // Génération simplifiée d'un PDF de rapport de ventes
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(S.t('exportInProgress', ctx.watch<AuthStore>().locale)),
          backgroundColor: AppColors.info),
    );
  }

  Future<void> _exportCsvReport(BuildContext ctx) async {
    // Export CSV des ventes - les données seront récupérées depuis l'API
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(S.t('exportInProgress', ctx.watch<AuthStore>().locale)),
          backgroundColor: AppColors.info),
    );
  }

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: AppColors.goldGradient,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<FlSpot> points;
  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('revenueChart', locale),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: points.length < 2
                ? Center(child: Text(S.t('noData', locale)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: points.length > 14 ? 4 : 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          barWidth: 3,
                          color: AppColors.primary,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.35),
                                AppColors.primary.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  final List<dynamic> items;
  const _TopProducts({required this.items});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('topProducts', locale),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication, color: AppColors.primary),
              ),
              title: Text('${item['name']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${S.t('quantity', locale)}: ${Fmt.number(double.tryParse('${item['qty_sold'] ?? 0}') ?? 0)}'),
              trailing: Text(
                Fmt.money(double.tryParse('${item['revenue'] ?? 0}') ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(S.t('retry', locale)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section centrale du Dashboard (composition image 1) :
/// grand Plan 3D à gauche + Point de vente à droite.
class _WorkspaceSection extends StatelessWidget {
  final double todayRevenue;
  final double lowStock;
  final VoidCallback onOpenPlan;

  const _WorkspaceSection({
    required this.todayRevenue,
    required this.lowStock,
    required this.onOpenPlan,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sideBySide = constraints.maxWidth >= 1000;
      final plan = _Plan3DPanel(onOpen: onOpenPlan);
      final alerts = _AlertsPanel(
        todayRevenue: todayRevenue,
        lowStock: lowStock,
      );
      if (sideBySide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: plan),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: alerts),
          ],
        );
      }
      return Column(
        children: [
          plan,
          const SizedBox(height: 16),
          alerts,
        ],
      );
    });
  }
}

class _AlertsPanel extends StatelessWidget {
  final double todayRevenue;
  final double lowStock;

  const _AlertsPanel({required this.todayRevenue, required this.lowStock});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.t('alerts', locale),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lowStock.toInt()}',
                  style: const TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AlertRow(
            icon: Icons.inventory_2_outlined,
            label: S.t('lowStock', locale),
            value: '${lowStock.toInt()}',
            color: AppColors.warning,
          ),
          const SizedBox(height: 10),
          _AlertRow(
            icon: Icons.payments_outlined,
            label: S.t('todayRevenue', locale),
            value: Fmt.money(todayRevenue),
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const StockPage(initialFilter: 'low')),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(S.t('viewAll', locale)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AlertRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70))),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Plan3DPanel extends StatelessWidget {
  final VoidCallback onOpen;
  const _Plan3DPanel({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined, color: AppColors.turquoise),
              const SizedBox(width: 10),
              Text(
                S.t('pharmacyPlan', locale),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Spacer(),
              const Icon(Icons.auto_fix_high, size: 18, color: AppColors.turquoise),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 210,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2A0F), Color(0xFF123B1A), Color(0xFF081F0C)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PlanPreviewPainter(),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.t('shelves', locale),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniControl(icon: Icons.add),
              const SizedBox(width: 6),
              _MiniControl(icon: Icons.remove),
              const SizedBox(width: 6),
              _MiniControl(icon: Icons.rotate_right),
              const SizedBox(width: 6),
              _MiniControl(icon: Icons.center_focus_strong),
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: S.t('pharmacyPlanTitle', locale),
            icon: Icons.open_in_new,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  final IconData icon;
  const _MiniControl({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}

class _PosPanel extends StatelessWidget {
  final double todayRevenue;
  final double lowStock;
  final VoidCallback onOpen;
  const _PosPanel({
    required this.todayRevenue,
    required this.lowStock,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final cats = [
      S.t('zoneMedications', locale),
      S.t('zoneParapharmacy', locale),
      S.t('zoneOtc', locale),
      S.t('zoneCosmetics', locale),
    ];
    return GlassCard(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: AppColors.turquoise),
              const SizedBox(width: 10),
              Text(
                S.t('pos', locale),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Spacer(),
              const Icon(Icons.touch_app, size: 18, color: AppColors.turquoise),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.white54),
                  SizedBox(width: 10),
                  Text('Rechercher un produit…',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.turquoiseGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(S.t('todayRevenue', locale),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  Fmt.money(todayRevenue),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: S.t('checkout', locale),
            icon: Icons.payment,
            onPressed: onOpen,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(S.t('cart', locale)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aperçu simplifié du plan (rectangles de zones + grille), sans données.
class _PlanPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final zone = (Color c, Rect r) => Paint()
      ..color = c.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final border = (Color c) => Paint()
      ..color = c.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final m = 18.0;
    final zones = <(Rect, Color)>[
      (Rect.fromLTWH(m, m, size.width / 2 - m * 1.5, size.height / 2 - m * 1.5), AppColors.greenGradient.colors.first),
      (Rect.fromLTWH(size.width / 2 + m / 2, m, size.width / 2 - m * 1.5, size.height / 2 - m * 1.5), AppColors.turquoiseDark),
      (Rect.fromLTWH(m, size.height / 2 + m / 2, size.width / 2 - m * 1.5, size.height / 2 - m * 1.5), AppColors.teal),
      (Rect.fromLTWH(size.width / 2 + m / 2, size.height / 2 + m / 2, size.width / 2 - m * 1.5, size.height / 2 - m * 1.5), AppColors.accent),
    ];
    for (final (r, c) in zones) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(rr, zone(c, r));
      canvas.drawRRect(rr, border(c));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Colonne Point de vente intégrée au Dashboard (fonctionnelle).
class DashboardPosPanel extends StatefulWidget {
  const DashboardPosPanel({super.key});

  @override
  State<DashboardPosPanel> createState() => _DashboardPosPanelState();
}

class _DashboardPosPanelState extends State<DashboardPosPanel> {
  final Cart _cart = Cart();
  final _search = TextEditingController();
  List<Medication> _results = [];
  bool _searching = false;
  bool _checkout = false;
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  List<CartLine>? _suspended;

  static const _categories = [
    'Antalgiques',
    'Antibiotiques',
    'Cardiologie',
    'Diabète',
    'Vitamines',
    'Respiratoire',
    'Digestif',
    'Autres',
  ];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final r =
        await ApiClient.instance.get<Map<String, dynamic>>('/branches');
    if (!mounted) return;
    if (r.success) {
      final list = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final auth = context.read<AuthStore>();
      setState(() {
        _branches = list;
        _branchId = auth.user?.branchId ??
            (list.isNotEmpty ? '${list[0]['id']}' : null);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _branchName() {
    final b = _branches.where((e) => '${e['id']}' == _branchId).firstOrNull;
    final name = b?['name'];
    return (name != null && '$name'.trim().isNotEmpty) ? '$name' : 'PHARMA+';
  }

  Future<void> _searchMedications(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/catalog/medications',
      query: {'q': query.trim(), 'limit': 20},
    );
    if (!mounted) return;
    final rows = result.success
        ? (result.data?['items'] as List? ?? const [])
        : const [];
    setState(() {
      _results = rows
          .whereType<Map<String, dynamic>>()
          .map(Medication.fromJson)
          .where((m) => m.stockQuantity == null || m.stockQuantity! > 0)
          .toList();
      _searching = false;
    });
  }

  void _selectCategory(String cat) {
    _search.text = cat;
    _searchMedications(cat);
  }

  void _suspend() {
    if (_cart.isEmpty) return;
    setState(() {
      _suspended = List<CartLine>.from(_cart.lines);
      _cart.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${S.t('suspended', context.read<AuthStore>().locale)} (${_suspended!.length})'),
      ),
    );
  }

  void _resume() {
    if (_suspended == null || _suspended!.isEmpty) return;
    setState(() {
      _cart.lines.addAll(_suspended!);
      _suspended = null;
    });
  }

  Future<void> _checkoutFlow() async {
    if (_cart.isEmpty || _checkout) return;
    final auth = context.read<AuthStore>();
    if (_branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('selectBranch', auth.locale))),
      );
      return;
    }
    setState(() => _checkout = true);
    try {
      final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/sales',
        body: {
          'branchId': _branchId,
          'saleType': 'pos',
          'items': _cart.lines.map((l) => l.toPayload()).toList(),
          'payments': [
            {
              'method': 'cash',
              'amount': double.parse(_cart.total.toStringAsFixed(2)),
              'generateInvoice': true,
            }
          ],
        },
      );
      if (result.success) {
        final lines = _cart.lines
            .map((l) => CartLineLike(
                  name: l.medication.name,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  tvaRate: l.tvaRate,
                ))
            .toList();
        final gdp = _cart.globalDiscountPercent;
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('saleSuccess', auth.locale))),
          );
          ReceiptPdf.printSaleReceipt(
            lines: lines,
            pharmacyName: _branchName(),
            locale: auth.locale,
            globalDiscountPercent: gdp,
          );
        }
      } else if (result.error?.code == 'NETWORK_ERROR') {
        await OfflineStore.instance.savePendingSale(
          'sale-${DateTime.now().millisecondsSinceEpoch}',
          {
            'branchId': _branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
            'payments': [
              {
                'method': 'cash',
                'amount': double.parse(_cart.total.toStringAsFixed(2)),
              }
            ],
          },
        );
        await OfflineStore.instance.enqueue(
          method: 'POST',
          path: '/sales',
          body: {
            'branchId': _branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
          },
        );
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('offline', auth.locale))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    result.error?.readableMessage ?? 'Erreur')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checkout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Container(
      color: const Color(0xFF0A100C),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.menu, AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.point_of_sale, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  S.t('pos', locale),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (_suspended != null && _suspended!.isNotEmpty)
                  IconButton(
                    tooltip: 'Reprendre',
                    onPressed: _resume,
                    icon: const Icon(Icons.play_circle_outline,
                        color: Colors.white),
                  ),
                IconButton(
                  tooltip: S.t('barcode', locale),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PosPage()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: _searchMedications,
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final m = _results[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.medication,
                        color: AppColors.primary),
                    title: Text(m.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(Fmt.money(m.priceSale)),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => setState(() {
                      _cart.add(m);
                      _results = [];
                      _search.clear();
                    }),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _categories)
                  InkWell(
                    onTap: () => _selectCategory(c),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 44, color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(S.t('emptyCart', locale),
                            style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.lines.length,
                    itemBuilder: (context, i) {
                      final l = _cart.lines[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.medication.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    '${Fmt.money(l.unitPrice)} × ${Fmt.number(l.quantity)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PosQtyBtn(
                                    icon: Icons.remove,
                                    onTap: () => setState(() => l.quantity =
                                        (l.quantity - 1).clamp(1, 999))),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    Fmt.number(l.quantity),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                _PosQtyBtn(
                                    icon: Icons.add,
                                    onTap: () => setState(() => l.quantity += 1)),
                                const SizedBox(width: 4),
                                _PosQtyBtn(
                                    icon: Icons.close,
                                    color: AppColors.danger,
                                    onTap: () => setState(() => _cart
                                        .removeLine(l.medication.id))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.t('total', locale),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(
                      Fmt.money(_cart.total),
                      style: const TextStyle(
                          color: AppColors.turquoise,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: S.t('checkout', locale),
                  icon: Icons.payments_outlined,
                  loading: _checkout,
                  onPressed: _cart.isEmpty ? null : _checkoutFlow,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cart.isEmpty ? null : _suspend,
                        icon: const Icon(Icons.pause_circle_outline),
                        label: Text(S.t('suspend', locale)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cart.isEmpty ? null : () => setState(_cart.clear),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(S.t('clearCart', locale)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosQtyBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _PosQtyBtn({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: color ?? AppColors.primary),
      ),
    );
  }
}

/// Barre de recherche globale du Dashboard.
class _GlobalSearchBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onScan;
  const _GlobalSearchBar({required this.onSearch, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Row(
      children: [
        Expanded(
          child: TextField(
            onSubmitted: (_) => onSearch(),
            readOnly: true,
            onTap: onSearch,
            decoration: InputDecoration(
              hintText: S.t('search', locale),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: S.t('barcode', locale),
          onPressed: onScan,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
          ),
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
      ],
    );
  }
}
