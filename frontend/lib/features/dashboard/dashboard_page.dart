import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/pharma_logo.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../employees/employees_page.dart';
import '../notifications/notifications_page.dart';
import '../pos/pos_page.dart';
import '../purchases/purchases_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';

/// ============================================================
/// DASHBOARD PHARMA+ — Reconstruit selon la maquette
/// Structure : SIDEBAR 230px | DASHBOARD central | POS 400-470px
/// 8 cartes 4x2 — dark premium — sans neon excessif
/// ============================================================
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

  double get _revenueToday => _flat(_data, 'revenue', 'revenue_today', 4280);
  double get _revenueMonth => _flat(_data, 'revenue', 'revenue_month', 128650);
  double get _profitMonth => _flat(_data, 'revenue', 'profit_month', 28650);
  int get _medications =>
      _nested(_data, 'counts', 'medications', 'total', 2145);
  int get _lowStock => _flat(_data, 'alerts', 'low_stock', 28).toInt();
  int get _expiring => _flat(_data, 'alerts', 'expiring', 7).toInt();
  int get _pendingOrders =>
      _flat(_data, 'alerts', 'pending_orders', 12).toInt();
  int get _suppliers => _nested(_data, 'counts', 'suppliers', 'total', 56);
  int get _customers => _nested(_data, 'counts', 'customers', 'total', 1328);
  int get _employees => _top(_data, 'employees_present', 15);

  static double _flat(
      Map<String, dynamic>? data, String section, String key, num fallback) {
    final m = data?[section];
    if (m is Map) {
      final v = m[key];
      if (v is num) return v.toDouble();
    }
    return fallback.toDouble();
  }

  static int _nested(Map<String, dynamic>? data, String a, String b, String key,
      int fallback) {
    final m1 = data?[a];
    if (m1 is Map) {
      final m2 = m1[b];
      if (m2 is Map) {
        final v = m2[key];
        if (v is num) return v.toInt();
      }
    }
    return fallback;
  }

  static int _top(Map<String, dynamic>? data, String key, int fallback) {
    final v = data?[key];
    if (v is num) return v.toInt();
    return fallback;
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off, size: 64, color: AppColors.warning),
              SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recommencer')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: LayoutBuilder(builder: (context, constraints) {
        final sidebar =
            _Sidebar(activeIndex: 0, onSelect: (i) => _onMenuSelect(i, auth));
        final pos = _PosPanel(onCheckout: () => _push(const PosPage()));
        final posWidth = constraints.maxWidth >= 1500 ? 440.0 : 390.0;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 220, child: sidebar),
          Container(width: 1, color: AppColors.dividerDark),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    onSearch: () => _push(const CatalogPage()),
                    onScan: () => _push(const PosPage()),
                    onNotifications: () => _push(const NotificationsPage()),
                    onSettings: () => _push(const SettingsPage()),
                    onLogout: _onLogout,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKpiGrid(),
                            const SizedBox(height: 14),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _AlertsStockPanel(
                                      lowStock: _lowStock,
                                      expiring: _expiring,
                                      onViewAll: () => _push(const StockPage(
                                          initialFilter: 'low')),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 7,
                                    child: _Plan3DPanel(
                                        onOpen: () =>
                                            _push(const PharmacyPlanPage())),
                                  ),
                                ]),
                            const SizedBox(height: 14),
                            _BottomBar(
                              revenueToday: _revenueToday,
                              revenueMonth: _revenueMonth,
                              profitMonth: _profitMonth,
                              expiring: _expiring,
                              lowStock: _lowStock,
                            ),
                          ]),
                    ),
                  ),
                ]),
          ),
          Container(width: 1, color: AppColors.dividerDark),
          SizedBox(width: posWidth, child: pos),
        ]);
      }),
    );
  }

  Widget _buildKpiGrid() {
    final kpis = [
      _KpiData(
          label: 'Ventes du jour',
          subtitle: '+12.5% vs hier',
          value: Fmt.money(_revenueToday),
          theme: _KpiTheme.green,
          icon: Icons.sell_outlined),
      _KpiData(
          label: 'Médicaments',
          subtitle: 'Références',
          value: Fmt.number(_medications),
          theme: _KpiTheme.blue,
          icon: Icons.medication_outlined),
      _KpiData(
          label: 'Stock faible',
          subtitle: 'Produits',
          value: '$_lowStock',
          theme: _KpiTheme.orange,
          icon: Icons.warning_amber_rounded),
      _KpiData(
          label: 'Commandes',
          subtitle: 'En attente',
          value: '$_pendingOrders',
          theme: _KpiTheme.purple,
          icon: Icons.inventory_2_outlined),
      _KpiData(
          label: 'Fournisseurs',
          subtitle: 'Actifs',
          value: Fmt.number(_suppliers),
          theme: _KpiTheme.cyan,
          icon: Icons.local_shipping_outlined),
      _KpiData(
          label: 'Clients',
          subtitle: 'Total',
          value: Fmt.number(_customers),
          theme: _KpiTheme.pink,
          icon: Icons.people_outline),
      _KpiData(
          label: 'Employés',
          subtitle: 'Actifs',
          value: '$_employees',
          theme: _KpiTheme.olive,
          icon: Icons.badge_outlined),
      _KpiData(
          label: 'Bénéfice',
          subtitle: '+8.3% ce mois',
          value: Fmt.money(_profitMonth),
          theme: _KpiTheme.blue,
          icon: Icons.trending_up_rounded),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.42,
      children: [
        for (var i = 0; i < kpis.length; i++)
          _KpiCard(key: ValueKey('kpi-$i'), data: kpis[i], onTap: _kpiTap(i))
      ],
    );
  }

  void _onLogout() => context.read<AuthStore>().signOut();
  VoidCallback? _kpiTap(int index) {
    switch (index) {
      case 0:
        return () => _push(const ReportsPage());
      case 1:
        return () => _push(const CatalogPage());
      case 2:
        return () => _push(const StockPage(initialFilter: 'low'));
      case 3:
        return () => _push(const PurchasesPage());
      case 4:
        return () => _push(const SuppliersPage());
      case 5:
        return () => _push(const CustomersPage());
      case 6:
        return () => _push(const EmployeesPage());
      default:
        return () => _push(const ReportsPage());
    }
  }

  void _onMenuSelect(int index, AuthStore auth) {
    switch (index) {
      case 0:
        return;
      case 1:
        _push(const PosPage());
        return;
      case 2:
        _push(const CatalogPage());
        return;
      case 3:
        _push(const StockPage());
        return;
      case 4:
        _push(const SuppliersPage());
        return;
      case 5:
        _push(const PurchasesPage());
        return;
      case 6:
        _push(const CustomersPage());
        return;
      case 7:
        _push(const EmployeesPage());
        return;
      case 8:
        _push(const ReportsPage());
        return;
      case 9:
        _push(const PharmacyPlanPage());
        return;
      case 10:
        _push(const SettingsPage());
    }
  }
}

// ============================================================
// DATA
// ============================================================
enum _KpiTheme { green, blue, orange, purple, cyan, pink, olive }

class _KpiData {
  final String label;
  final String value;
  final String subtitle;
  final _KpiTheme theme;
  final IconData icon;
  const _KpiData(
      {required this.label,
      required this.value,
      required this.subtitle,
      required this.theme,
      required this.icon});
}

// ============================================================
// SIDEBAR 230px
// ============================================================
class _Sidebar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.activeIndex, required this.onSelect});
  static const _items = [
    (Icons.dashboard_outlined, 'Tableau de bord'),
    (Icons.point_of_sale, 'Point de vente'),
    (Icons.inventory_2_outlined, 'Catalogue'),
    (Icons.warehouse_outlined, 'Stock'),
    (Icons.local_shipping_outlined, 'Fournisseurs'),
    (Icons.assignment_outlined, 'Commandes'),
    (Icons.people_outline, 'Clients'),
    (Icons.badge_outlined, 'Employés'),
    (Icons.insert_chart_outlined, 'Rapports'),
    (Icons.view_in_ar_outlined, 'Plan 3D'),
    (Icons.settings_outlined, 'Paramètres'),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: AppColors.sidebarGradient,
          border: Border(
              right: BorderSide(
                  color: AppColors.dividerDark.withValues(alpha: 0.6)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.dividerDark.withValues(alpha: 0.6)))),
          child: Row(children: [
            const PharmaPlusLogo(size: 76),
            const SizedBox(width: 12),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PHARMA+',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  Text('Gestion de pharmacie',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ]),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final active = i == activeIndex;
              final (icon, label) = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: active ? const Color(0xFF143D2F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: active
                            ? Border.all(
                                color:
                                    AppColors.emerald.withValues(alpha: 0.35))
                            : null,
                      ),
                      child: Row(children: [
                        Icon(icon,
                            size: 19,
                            color: active
                                ? AppColors.emeraldLight
                                : AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(label,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: AppColors.dividerDark.withValues(alpha: 0.6)))),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E2E31),
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.emerald, width: 2))),
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        border: Border.all(
                            color: AppColors.surfaceSidebar, width: 2))),
              ),
            ]),
            const SizedBox(width: 12),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('Administrateur',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5)),
                ]),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================
// TOP BAR
// ============================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  const _TopBar(
      {required this.onSearch,
      required this.onScan,
      required this.onNotifications,
      required this.onSettings,
      required this.onLogout});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
              bottom: BorderSide(
                  color: AppColors.dividerDark.withValues(alpha: 0.6)))),
      child: Row(children: [
        const Text('PHARMA+',
            style: TextStyle(
                color: AppColors.emeraldLight,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(width: 24),
        Expanded(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.dividerLight.withValues(alpha: 0.5))),
              child: Row(children: [
                const Icon(Icons.search,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Rechercher un médicament, client, facture...',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.qr_code_scanner,
                        size: 18, color: AppColors.emeraldLight),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 24),
        const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Pharmacie Dar Al Shifa',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Admin',
                    style: TextStyle(
                        color: AppColors.emeraldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: AppColors.textSecondary),
              ]),
            ]),
        const SizedBox(width: 14),
        _TopIcon(
            icon: Icons.notifications_outlined,
            badge: '3',
            onTap: onNotifications),
        const SizedBox(width: 6),
        _TopIcon(icon: Icons.settings_outlined, onTap: onSettings),
        const SizedBox(width: 6),
        _TopIcon(icon: Icons.logout, onTap: onLogout, color: AppColors.warning),
      ]),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;
  final Color? color;
  const _TopIcon(
      {required this.icon, this.badge, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 21, color: color ?? AppColors.textPrimary),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ============================================================
// CARTES KPI — 4 x 2 — dark premium sans neon
// ============================================================
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final VoidCallback? onTap;
  const _KpiCard({super.key, required this.data, this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = _themeColors(data.theme);
    final accent = colors[2];
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors[0], colors[1]]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(data.icon, color: accent, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      data.subtitle,
                      style: TextStyle(
                          color: colors[4],
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                data.label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Color> _themeColors(_KpiTheme theme) {
  switch (theme) {
    case _KpiTheme.green:
      return const [
        Color(0xFF0F2A1E),
        Color(0xFF0A1A12),
        Color(0xFF00C853),
        Color(0xFF00C853),
        Color(0xFF69F0AE)
      ];
    case _KpiTheme.blue:
      return const [
        Color(0xFF0F2435),
        Color(0xFF0A1620),
        Color(0xFF42A5F5),
        Color(0xFF1E88E5),
        Color(0xFF90CAF9)
      ];
    case _KpiTheme.orange:
      return const [
        Color(0xFF2A1E0F),
        Color(0xFF1A1006),
        Color(0xFFFF8F00),
        Color(0xFFFF8F00),
        Color(0xFFFFB347)
      ];
    case _KpiTheme.purple:
      return const [
        Color(0xFF23152E),
        Color(0xFF130A18),
        Color(0xFF9C27B0),
        Color(0xFFAB47BC),
        Color(0xFFCE93D8)
      ];
    case _KpiTheme.cyan:
      return const [
        Color(0xFF0E262E),
        Color(0xFF07151C),
        Color(0xFF00BCD4),
        Color(0xFF00BCD4),
        Color(0xFF80DEEA)
      ];
    case _KpiTheme.pink:
      return const [
        Color(0xFF2A1428),
        Color(0xFF180A16),
        Color(0xFFE91E63),
        Color(0xFFEC407A),
        Color(0xFFF48FB1)
      ];
    case _KpiTheme.olive:
      return const [
        Color(0xFF1C2612),
        Color(0xFF0F1809),
        Color(0xFF8BC34A),
        Color(0xFF9CCC65),
        Color(0xFFC5E1A5)
      ];
  }
}

// ============================================================
// ALERTES STOCK
// ============================================================
class _AlertsStockPanel extends StatelessWidget {
  final int lowStock;
  final int expiring;
  final VoidCallback onViewAll;
  const _AlertsStockPanel(
      {required this.lowStock,
      required this.expiring,
      required this.onViewAll});
  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        'Amoxicilline 500mg',
        'Stock faible (8)',
        AppColors.warning,
        Icons.arrow_downward
      ),
      (
        'Doliprane 1g',
        'Stock faible (12)',
        AppColors.warning,
        Icons.arrow_downward
      ),
      ('Vitamine D3', 'Rupture de stock', AppColors.danger, Icons.block),
      ('Fer B9', 'Expire dans 15 j', AppColors.info, Icons.hourglass_bottom)
    ];
    return _DarkPanel(
      title: 'ALERTES STOCK',
      icon: Icons.notifications_active_outlined,
      iconColor: AppColors.warning,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          _AlertRow(
              name: rows[i].$1,
              detail: rows[i].$2,
              color: rows[i].$3,
              icon: rows[i].$4),
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onViewAll,
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.emerald.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.visibility_outlined,
                size: 17, color: AppColors.emeraldLight),
            label: const Text('Voir toutes',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String name;
  final String detail;
  final Color color;
  final IconData icon;
  const _AlertRow(
      {required this.name,
      required this.detail,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppColors.dividerDark.withValues(alpha: 0.8))),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(detail, style: TextStyle(color: color, fontSize: 11))
        ])),
      ]),
    );
  }
}

// ============================================================
// PLAN 3D
// ============================================================
class _Plan3DPanel extends StatelessWidget {
  final VoidCallback onOpen;
  const _Plan3DPanel({required this.onOpen});
  static const _legend = [
    ('A', 'Antalgiques'),
    ('B', 'Antibiotiques'),
    ('C', 'Cardiologie'),
    ('D', 'Digestif'),
    ('E', 'Soins')
  ];
  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      title: 'PLAN 3D DE LA PHARMACIE',
      icon: Icons.view_in_ar_outlined,
      iconColor: AppColors.emerald,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 204,
          child: Container(
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101C16), Color(0xFF0A120E)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.dividerDark.withValues(alpha: 0.9))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _PlanPainter())),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Column(children: [
                    _PlanChip(label: 'Vue 3D', icon: Icons.view_in_ar),
                    const SizedBox(height: 6),
                    _PlanChip(label: 'Tourner', icon: Icons.rotate_right),
                    const SizedBox(height: 6),
                    const Row(children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: _MiniRound(icon: Icons.add)),
                      SizedBox(width: 4),
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: _MiniRound(icon: Icons.remove))
                    ]),
                    const SizedBox(height: 6),
                    _PlanChip(label: 'Plein écran', icon: Icons.fullscreen),
                  ]),
                ),
                const Positioned(
                    left: 20, top: 26, child: _ZoneMarker(label: 'A')),
                const Positioned(
                    left: 72, top: 18, child: _ZoneMarker(label: 'D')),
                const Positioned(
                    left: 34, bottom: 30, child: _ZoneMarker(label: 'C')),
                const Positioned(
                    left: 84, bottom: 24, child: _ZoneMarker(label: 'E')),
                const Positioned(
                    left: 46, bottom: 4, child: _ZoneMarker(label: 'B')),
                const Positioned(
                    right: 70,
                    bottom: 24,
                    child: _ZoneMarker(label: 'Caisse', special: true)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (letter, name) in _legend) _LegendItem(letter, name)
        ]),
      ]),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlanChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.emeraldLight),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5))
      ]),
    );
  }
}

class _MiniRound extends StatelessWidget {
  final IconData icon;
  const _MiniRound({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24)),
      child: Icon(icon, size: 15, color: Colors.white70));
}

class _ZoneMarker extends StatelessWidget {
  final String label;
  final bool special;
  const _ZoneMarker({required this.label, this.special = false});
  @override
  Widget build(BuildContext context) {
    final color = special ? AppColors.warning : AppColors.emerald;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)
            ]),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900))),
      ),
      if (special) ...[
        const SizedBox(width: 4),
        const Text('Caisse',
            style: TextStyle(color: Colors.white70, fontSize: 10))
      ],
    ]);
  }
}

class _LegendItem extends StatelessWidget {
  final String letter;
  final String name;
  const _LegendItem(this.letter, this.name);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
                color: AppColors.emerald, shape: BoxShape.circle),
            child: Center(
                child: Text(letter,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900)))),
        const SizedBox(width: 4),
        Text(name,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10))
      ]);
}

class _PlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final floor = Path()
      ..moveTo(size.width * 0.08, size.height * 0.3)
      ..lineTo(size.width * 0.78, size.height * 0.10)
      ..lineTo(size.width * 0.92, size.height * 0.70)
      ..lineTo(size.width * 0.30, size.height * 0.94)
      ..close();
    canvas.drawPath(
        floor,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFF1B3A2A), Color(0xFF0E1F16)])
              .createShader(Offset.zero & size));
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x <= size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y <= size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    final shelf = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (var row = 0; row < 4; row++) {
      final y = size.height * (0.36 + row * 0.12);
      final path = Path()
        ..moveTo(size.width * (0.14 + row * 0.03), y)
        ..lineTo(size.width * (0.52 + row * 0.03), y - size.height * 0.12)
        ..lineTo(size.width * (0.68 + row * 0.03), y - size.height * 0.06);
      canvas.drawPath(path, shelf);
    }
    // Produits sur etageres — petits points
    final prod = Paint()..color = AppColors.emerald.withValues(alpha: 0.55);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 3; col++) {
        final y =
            size.height * (0.36 + row * 0.12) - size.height * 0.06 + col * 4;
        final x = size.width * (0.22 + row * 0.03 + col * 0.08);
        canvas.drawCircle(Offset(x, y), 2.2, prod);
      }
    }
    // Murs
    final wall = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final wallPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.30)
      ..lineTo(size.width * 0.08, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.04)
      ..lineTo(size.width * 0.78, size.height * 0.10);
    canvas.drawPath(wallPath, wall);
    final counter = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.42, size.height * 0.76, size.width * 0.16,
            size.height * 0.10),
        const Radius.circular(4));
    canvas.drawRRect(counter,
        Paint()..color = const Color(0xFF00C853).withValues(alpha: 0.65));
    canvas.drawRRect(
        counter,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // Caisse — petit rectangle blanc
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.46, size.height * 0.78,
                size.width * 0.08, size.height * 0.05),
            const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// PANEL SOMBRE GENERIQUE
// ============================================================
class _DarkPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _DarkPanel(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101C16), Color(0xFF0B1210)]),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.dividerDark.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 7),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4))
        ]),
        const SizedBox(height: 10),
        child
      ]),
    );
  }
}

// ============================================================
// POS — colonne droite
// ============================================================
class _PosPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  const _PosPanel({required this.onCheckout});
  static const _categories = [
    ('Antalgiques', Icons.medication_outlined, Color(0xFF00C853)),
    ('Antibiotiques', Icons.medication_liquid_outlined, Color(0xFFF06292)),
    ('Cardiologie', Icons.favorite_outline, Color(0xFFE53935)),
    ('Diabète', Icons.water_drop_outlined, Color(0xFF1E88E5)),
    ('Vitamines', Icons.spa_outlined, Color(0xFFFDD835)),
    ('Respiratoire', Icons.air_outlined, Color(0xFF4FC3F7)),
    ('Digestif', Icons.local_dining_outlined, Color(0xFFEF5350)),
    ('Autres', Icons.more_horiz, Color(0xFFB0BEC5))
  ];
  static const _products = [
    ('Doliprane 1g', 'Paracétamol', 2, 18.00),
    ('Amoxicilline 500mg', 'Sandoz', 1, 15.00),
    ('Vitamine C 1g', 'Effervescent', 1, 25.00),
    ('Bisolvon Sirop', 'Toux sèche', 1, 32.00),
    ('Lactulose 10g/15ml', 'Sirop', 1, 20.00)
  ];

  @override
  Widget build(BuildContext context) {
    final totalQty = _products.fold<int>(0, (s, p) => s + p.$3);
    final total = _products.fold<double>(0, (s, p) => s + p.$3 * p.$4);
    return Container(
      color: AppColors.surfaceDark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00C853), Color(0xFF008F57)]),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shopping_cart,
                    color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            const Text('POINT DE VENTE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: AppColors.dividerLight.withValues(alpha: 0.6))),
            child: const Row(children: [
              Icon(Icons.search, size: 19, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Rechercher un médicament (nom, code, labo...)',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12),
                      overflow: TextOverflow.ellipsis))
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Categories 4x2 — hauteur fixe
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildCategories()),
        const SizedBox(height: 12),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _ProductsHeader()),
        const SizedBox(height: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.separated(
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final (name, labo, qty, price) = _products[i];
                return _ProductRow(
                    name: name, labo: labo, qty: qty, price: price);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00A24C), Color(0xFF007A3D)]),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total ($totalQty produits)',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  Text(Fmt.money(total),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900))
                ]),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(
                child: _PosButton(
                    label: 'VIDER',
                    color: AppColors.danger,
                    icon: Icons.delete_outline,
                    onTap: onCheckout)),
            const SizedBox(width: 8),
            Expanded(
                child: _PosButton(
                    label: 'SUSPENDRE',
                    color: AppColors.warning,
                    icon: Icons.pause_circle_outline,
                    onTap: onCheckout)),
            const SizedBox(width: 8),
            Expanded(
                child: _PosButton(
                    label: 'PAIEMENT',
                    color: AppColors.emerald,
                    icon: Icons.payment,
                    onTap: onCheckout)),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            for (final a in const [
              (Icons.qr_code_scanner, 'Scanner'),
              (Icons.percent, 'Remise'),
              (Icons.person_outline, 'Client'),
              (Icons.sticky_note_2_outlined, 'Note')
            ])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _PosAction(icon: a.$1, label: a.$2))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCategories() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.92,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final (name, icon, color) in _categories)
          _CategoryCell(name: name, icon: icon, color: color)
      ],
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();
  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(flex: 4, child: _HeaderCell('Produit')),
        Expanded(flex: 2, child: _HeaderCell('Qté')),
        Expanded(flex: 2, child: _HeaderCell('Prix')),
        Expanded(flex: 3, child: _HeaderCell('Total', alignRight: true))
      ]);
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool alignRight;
  const _HeaderCell(this.text, {this.alignRight = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 10.5));
}

class _CategoryCell extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  const _CategoryCell(
      {required this.name, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.26))),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: color)),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 9.5))
        ]),
      );
}

class _ProductRow extends StatelessWidget {
  final String name;
  final String labo;
  final int qty;
  final double price;
  const _ProductRow(
      {required this.name,
      required this.labo,
      required this.qty,
      required this.price});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.dividerDark)),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: const Icon(Icons.medication,
                  size: 17, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
              flex: 4,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                    Text(labo,
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 9.5))
                  ])),
          Expanded(
              flex: 2,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(icon: Icons.remove, color: AppColors.danger),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text('$qty',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
                _QtyBtn(icon: Icons.add, color: AppColors.emerald)
              ])),
          Expanded(
              flex: 2,
              child: Text(Fmt.money(price),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11))),
          Expanded(
              flex: 3,
              child: Text(Fmt.money(price * qty),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
        ]),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _QtyBtn({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(icon, size: 13, color: color));
}

class _PosButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _PosButton(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800))
              ]))));
}

class _PosAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PosAction({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(children: [
        Icon(icon, size: 17, color: AppColors.emeraldLight),
        const SizedBox(height: 3),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 9.5))
      ]));
}

// ============================================================
// BARRE DU BAS — 5 cartes + date/heure
// ============================================================
class _BottomBar extends StatelessWidget {
  final double revenueToday;
  final double revenueMonth;
  final double profitMonth;
  final int expiring;
  final int lowStock;
  const _BottomBar(
      {required this.revenueToday,
      required this.revenueMonth,
      required this.profitMonth,
      required this.expiring,
      required this.lowStock});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.dividerDark.withValues(alpha: 0.9)),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101C16), Color(0xFF0B1210)])),
      child: LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth;
        final statWidth = available > 1200 ? 170.0 : 150.0;
        final dateWidth = available > 1200 ? 180.0 : 150.0;

        return Row(
          children: [
            SizedBox(
              width: statWidth,
              child: _BottomStat(
                  label: 'VENTES AUJOURD\'HUI',
                  value: Fmt.money(revenueToday),
                  trend: '+12.5%',
                  color: AppColors.emerald,
                  curve: true),
            ),
            SizedBox(
              width: statWidth,
              child: _BottomStat(
                  label: 'VENTES MOIS',
                  value: Fmt.money(revenueMonth),
                  trend: '+8.3%',
                  color: AppColors.emerald,
                  curve: true),
            ),
            SizedBox(
              width: statWidth,
              child: _BottomStat(
                  label: 'BÉNÉFICE MOIS',
                  value: Fmt.money(profitMonth),
                  trend: '+8.3%',
                  color: AppColors.emerald,
                  curve: true),
            ),
            SizedBox(
              width: statWidth,
              child: _BottomStat(
                  label: 'PRODUITS EXPIRÉS',
                  value: '$expiring',
                  subtitled: 'Produits',
                  color: AppColors.danger),
            ),
            SizedBox(
              width: statWidth,
              child: _BottomStat(
                  label: 'STOCK FAIBLE',
                  value: '$lowStock',
                  subtitled: 'Produits',
                  color: AppColors.warning),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: dateWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dividerDark)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: AppColors.emeraldLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Fmt.time(now),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          Text(Fmt.shortDate(now),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5))
                        ]),
                  ),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BottomStat extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final String? subtitled;
  final Color color;
  final bool curve;
  const _BottomStat(
      {required this.label,
      required this.value,
      this.trend,
      this.subtitled,
      required this.color,
      this.curve = false});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 9.2)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  if (trend != null)
                    Text(trend!,
                        style: const TextStyle(
                            color: AppColors.emeraldLight, fontSize: 10)),
                  if (subtitled != null)
                    Text(subtitled!,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.9), fontSize: 10))
                ])),
            if (curve)
              SizedBox(
                  width: 36,
                  height: 24,
                  child: CustomPaint(painter: _MiniCurvePainter(color))),
          ]),
        ),
      );
}

class _MiniCurvePainter extends CustomPainter {
  final Color color;
  const _MiniCurvePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.9, size.width * 0.5,
          size.height * 0.45)
      ..quadraticBezierTo(
          size.width * 0.7, size.height * 0.05, size.width, size.height * 0.2);
    canvas.drawPath(path, paint);
    final fill = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0)
          ]).createShader(Offset.zero & size);
    final area = Path()
      ..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniCurvePainter oldDelegate) =>
      oldDelegate.color != color;
}
