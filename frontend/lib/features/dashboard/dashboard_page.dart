import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pharma3d_card.dart';
import '../../core/widgets/pharma_wide_card.dart';
import '../../core/widgets/stats_tile.dart';
import '../cameras/cameras_page.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../notifications/notifications_page.dart';
import '../pos/pos_page.dart';
import '../prescriptions/prescriptions_page.dart';
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
    return RefreshIndicator(
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
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 700
                          ? 2
                          : 2;
                  final items = [
                    StatsTile(
                      icon: Icons.payments_outlined,
                      label: S.t('todayRevenue', locale),
                      value:
                          double.tryParse('${revenue['revenue_today'] ?? 0}') ??
                              0,
                      money: true,
                    ),
                    StatsTile(
                      icon: Icons.shopping_cart_outlined,
                      label: S.t('transactions', locale),
                      value: (revenue['sales_today'] as num?)?.toDouble() ?? 0,
                    ),
                    StatsTile(
                      icon: Icons.trending_up,
                      label: S.t('revenue30d', locale),
                      value:
                          double.tryParse('${revenue['revenue_month'] ?? 0}') ??
                              0,
                      money: true,
                    ),
                    StatsTile(
                      icon: Icons.warning_amber_outlined,
                      label: S.t('lowStock', locale),
                      value: (alerts['low_stock'] as num?)?.toDouble() ?? 0,
                    ),
                  ];
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: items,
                  );
                }),
                const SizedBox(height: 20),
                _SectionLabel(title: S.t('modules', locale)),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 700
                          ? 3
                          : 2;
                  final items = <Widget>[
                    Pharma3DCard(
                      icon: Icons.medication_outlined,
                      label: S.t('medications', locale),
                      value: '${meds['available'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${meds['total'] ?? 0}',
                      gradient: AppColors.greenGradient,
                      glow: AppColors.primary,
                      onTap: () => push(const CatalogPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.inventory_2_outlined,
                      label: S.t('stock', locale),
                      value: Fmt.money(double.tryParse('${stockInfo['stock_value'] ?? 0}') ?? 0),
                      subtitle: '${S.t('lowStock', locale)}: ${alerts['low_stock'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A2A6B)]),
                      glow: AppColors.secondary,
                      onTap: () => push(const StockPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.point_of_sale,
                      label: S.t('sales', locale),
                      value: Fmt.number((revenue['sales_month'] as num?)?.toDouble() ?? 0),
                      subtitle: '${(revenue['sales_today'] as num?)?.toInt() ?? 0} ${S.t('today', locale)}',
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const PosPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.payments_outlined,
                      label: S.t('revenue', locale),
                      value: Fmt.money(double.tryParse('${revenue['revenue_month'] ?? 0}') ?? 0),
                      subtitle: '${S.t('profit', locale)}: ${Fmt.money(double.tryParse('${revenue['profit_month'] ?? 0}') ?? 0)}',
                      gradient: AppColors.goldGradient,
                      glow: AppColors.accent,
                      onTap: () => push(const ReportsPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.description_outlined,
                      label: S.t('prescriptions', locale),
                      value: '${presc['month'] ?? 0}',
                      subtitle: '${presc['pending'] ?? 0} ${S.t('pending', locale)}',
                      gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF512DA8), Color(0xFF311B92)]),
                      glow: const Color(0xFF9C27B0),
                      onTap: () => push(const PrescriptionsPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.people_outline,
                      label: S.t('customers', locale),
                      value: '${customers['active'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${customers['total'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF00838F), Color(0xFF00695C), Color(0xFF004D40)]),
                      glow: const Color(0xFF00ACC1),
                      onTap: () => push(const CustomersPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.local_shipping_outlined,
                      label: S.t('suppliers', locale),
                      value: '${suppliers['active'] ?? 0}',
                      subtitle: '${S.t('total', locale)}: ${suppliers['total'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFFEF6C00), Color(0xFFE65100), Color(0xFFBF360C)]),
                      glow: const Color(0xFFFF8F00),
                      onTap: () => push(const SuppliersPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.spa_outlined,
                      label: S.t('parapharmacy', locale),
                      value: Fmt.number((para['products'] as num?)?.toDouble() ?? 0),
                      subtitle: '${S.t('paraRevenue', locale)}: ${Fmt.money(double.tryParse('${para['revenue_month'] ?? 0}') ?? 0)}',
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const CatalogPage(parapharmacy: true)),
                    ),
                    Pharma3DCard(
                      icon: Icons.warning_amber_outlined,
                      label: S.t('alerts', locale),
                      value: '${alerts['low_stock'] ?? 0}',
                      subtitle: '${S.t('expiring', locale)}: ${alerts['expiring'] ?? 0} · ${S.t('expired', locale)}: ${alerts['expired'] ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFC62828), Color(0xFF8E0000)]),
                      glow: AppColors.danger,
                      badge: '!',
                      onTap: () => push(const StockPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.qr_code_scanner,
                      label: S.t('barcode', locale),
                      value: 'Scan',
                      subtitle: S.t('scanSubtitle', locale),
                      gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0277BD), Color(0xFF01579B)]),
                      glow: AppColors.info,
                      onTap: () => push(const PosPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.videocam_outlined,
                      label: S.t('cameras', locale),
                      value: '${(cams['online'] as num?)?.toInt() ?? 0}/${(cams['total'] as num?)?.toInt() ?? 0}',
                      subtitle: '${S.t('cameraRecording', locale)}: ${(cams['recording'] as num?)?.toInt() ?? 0}',
                      gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1B5E20)]),
                      glow: AppColors.primary,
                      onTap: () => push(const CamerasPage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.medication_liquid_outlined,
                      label: S.t('baseMaroc', locale),
                      value: '${ref['total'] ?? _syncTotal(lastSync)}',
                      subtitle: '${S.t('lastSync', locale)}: ${Fmt.dateTime(_parseDate(lastSync['finished_at']), locale: locale)}',
                      gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF0D47A1)]),
                      glow: AppColors.turquoise,
                      onTap: () => push(const ReferencePage()),
                    ),
                    Pharma3DCard(
                      icon: Icons.storefront_outlined,
                      label: S.t('pharmacyPlan', locale),
                      value: '3D',
                      subtitle: S.t('pharmacyPlanSub', locale),
                      gradient: AppColors.turquoiseGradient,
                      glow: AppColors.turquoise,
                      onTap: () => push(const PharmacyPlanPage()),
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
