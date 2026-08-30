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
/// Structure : SIDEBAR gauche | DASHBOARD central | POS droite
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

  // ---- Données telles que décrites par la maquette (fallbacks) ----
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
    final map = data?[section];
    if (map is Map) {
      final v = map[key];
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
        body: Center(
          child: CircularProgressIndicator(color: AppColors.emerald),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: AppColors.warning),
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recommencer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: LayoutBuilder(builder: (context, constraints) {
        final sidebar = _Sidebar(
          activeIndex: 0,
          onSelect: (index) => _onMenuSelect(index, auth),
        );
        final pos = _PosPanel(
          onCheckout: () => _push(const PosPage()),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 232, child: sidebar),
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildKpiGrid(),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            flex: 5,
                            child: LayoutBuilder(builder: (context, c) {
                              final sideBySide = c.maxWidth >= 700;
                              final alerts = _AlertsStockPanel(
                                lowStock: _lowStock,
                                expiring: _expiring,
                                onViewAll: () => _push(
                                    const StockPage(initialFilter: 'low')),
                              );
                              final plan = _Plan3DPanel(
                                onOpen: () => _push(const PharmacyPlanPage()),
                              );
                              if (!sideBySide) {
                                return Row(
                                  children: [
                                    Expanded(child: alerts),
                                    const SizedBox(width: 10),
                                    Expanded(child: plan),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(flex: 5, child: alerts),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 7, child: plan),
                                ],
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: _BottomBar(
                              revenueToday: _revenueToday,
                              revenueMonth: _revenueMonth,
                              profitMonth: _profitMonth,
                              expiring: _expiring,
                              lowStock: _lowStock,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, color: AppColors.dividerDark),
            SizedBox(
              width: constraints.maxWidth >= 1280 ? 360 : 330,
              child: pos,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildKpiGrid() {
    final kpis = [
      _KpiData(
        label: 'VENTES DU JOUR',
        subtitle: '+12.5% vs hier',
        value: Fmt.money(_revenueToday),
        theme: _KpiTheme.green,
        visual: _KpiVisual.kTerminal(this),
      ),
      _KpiData(
        label: 'MÉDICAMENTS',
        subtitle: 'Références',
        value: Fmt.number(_medications),
        theme: _KpiTheme.blue,
        visual: _KpiVisual.kBottle(this),
      ),
      _KpiData(
        label: 'STOCK FAIBLE',
        subtitle: 'Produits',
        value: '$_lowStock',
        theme: _KpiTheme.orange,
        visual: _KpiVisual.kBoxes(this),
      ),
      _KpiData(
        label: 'COMMANDES',
        subtitle: 'En attente',
        value: '$_pendingOrders',
        theme: _KpiTheme.purple,
        visual: _KpiVisual.kClipboard(this),
      ),
      _KpiData(
        label: 'FOURNISSEURS',
        subtitle: 'Actifs',
        value: Fmt.number(_suppliers),
        theme: _KpiTheme.cyan,
        visual: _KpiVisual.kTruck(this),
      ),
      _KpiData(
        label: 'CLIENTS',
        subtitle: 'Total',
        value: Fmt.number(_customers),
        theme: _KpiTheme.pink,
        visual: _KpiVisual.kPeople(this),
      ),
      _KpiData(
        label: 'EMPLOYÉS',
        subtitle: 'Actifs',
        value: '$_employees',
        theme: _KpiTheme.olive,
        visual: _KpiVisual.kPharmacist(this),
      ),
      _KpiData(
        label: 'BÉNÉFICE MOIS',
        subtitle: '+8.3% vs mois dernier',
        value: Fmt.money(_profitMonth),
        theme: _KpiTheme.blue,
        visual: _KpiVisual.kChart(this),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      final columns = maxW >= 900
          ? 4
          : maxW >= 640
              ? 3
              : 2;
      final spacing = 12.0;
      final rows = (kpis.length / columns).ceil();
      final cardWidth = (maxW - (columns - 1) * spacing) / columns;
      final cardHeight = (maxH - (rows - 1) * spacing) / rows - 2;
      final cardAspect = (cardWidth / cardHeight).clamp(0.9, 2.6);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: cardAspect,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        children: [
          for (var i = 0; i < kpis.length; i++)
            _KpiCard(
              key: ValueKey('kpi-$i'),
              data: kpis[i],
              onTap: _kpiTap(i),
            ),
        ],
      );
    });
  }

  void _onLogout() {
    context.read<AuthStore>().signOut();
  }

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
// DATA STRUCTURES
// ============================================================

enum _KpiTheme { green, blue, orange, purple, cyan, pink, olive }

class _KpiData {
  final String label;
  final String value;
  final String subtitle;
  final _KpiTheme theme;
  final _KpiVisual visual;

  const _KpiData({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.theme,
    required this.visual,
  });
}

// ============================================================
// SIDEBAR GAUCHE (230px)
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
          right:
              BorderSide(color: AppColors.dividerDark.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête logo
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: AppColors.dividerDark.withValues(alpha: 0.6)),
              ),
            ),
            child: Row(
              children: [
                const PharmaPlusLogo(size: 38),
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
                  ],
                ),
              ],
            ),
          ),
          // Menu
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final active = i == activeIndex;
                final (icon, label) = _items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: active
                        ? AppColors.emerald.withValues(alpha: 0.18)
                        : Colors.transparent,
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
                                      AppColors.emerald.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Pied : avatar Admin
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppColors.dividerDark.withValues(alpha: 0.6)),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E2E31),
                        border: Border(
                            bottom:
                                BorderSide(color: AppColors.emerald, width: 2)),
                      ),
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
                              color: AppColors.surfaceSidebar, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
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

// ============================================================
// TOP BAR
// ============================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _TopBar({
    required this.onSearch,
    required this.onScan,
    required this.onNotifications,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom:
              BorderSide(color: AppColors.dividerDark.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          const Text('PHARMA+',
              style: TextStyle(
                  color: AppColors.emeraldLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          const SizedBox(width: 24),
          // Barre de recherche centrale
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
                      color: AppColors.dividerLight.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Rechercher un médicament, client, facture...',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_scanner,
                            size: 18, color: AppColors.emeraldLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Droite : pharmacie + admin + icônes
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Pharmacie Dar Al Shifa',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Admin',
                      style: TextStyle(
                          color: AppColors.emeraldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(width: 14),
          _TopIcon(
            icon: Icons.notifications_outlined,
            badge: '3',
            onTap: onNotifications,
          ),
          const SizedBox(width: 6),
          _TopIcon(icon: Icons.settings_outlined, onTap: onSettings),
          const SizedBox(width: 6),
          _TopIcon(
            icon: Icons.logout,
            onTap: onLogout,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 21, color: color ?? AppColors.textPrimary),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARTES KPI — 8 cartes, grille 4 × 2
// ============================================================
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final VoidCallback? onTap;

  const _KpiCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _themeColors(data.theme);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0],
                colors[1],
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors[2].withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: colors[3].withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight;
              final visual = (h * 0.82).clamp(40.0, 104.0);
              return Stack(
                children: [
                  // Reflet lumière
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: h * 0.5,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Illustration 3D (bas/droite)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: SizedBox(
                        width: visual,
                        height: visual,
                        child: data.visual,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 26,
                    child: Text(
                      data.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 51,
                    child: Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors[4].withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Renvoie [fond1, fond2, bordure, glow, accentTexte] selon le thème.
List<Color> _themeColors(_KpiTheme theme) {
  switch (theme) {
    case _KpiTheme.green:
      return const [
        Color(0xFF123126),
        Color(0xFF081A11),
        Color(0xFF00C853),
        Color(0xFF00C853),
        Color(0xFF69F0AE),
      ];
    case _KpiTheme.blue:
      return const [
        Color(0xFF122A3A),
        Color(0xFF081821),
        Color(0xFF42A5F5),
        Color(0xFF1E88E5),
        Color(0xFF90CAF9),
      ];
    case _KpiTheme.orange:
      return const [
        Color(0xFF2E1F10),
        Color(0xFF1A1005),
        Color(0xFFFF8F00),
        Color(0xFFFF8F00),
        Color(0xFFFFB347),
      ];
    case _KpiTheme.purple:
      return const [
        Color(0xFF2A1330),
        Color(0xFF150A18),
        Color(0xFF9C27B0),
        Color(0xFFAB47BC),
        Color(0xFFCE93D8),
      ];
    case _KpiTheme.cyan:
      return const [
        Color(0xFF0F2A30),
        Color(0xFF071820),
        Color(0xFF00BCD4),
        Color(0xFF00BCD4),
        Color(0xFF80DEEA),
      ];
    case _KpiTheme.pink:
      return const [
        Color(0xFF2E1230),
        Color(0xFF180818),
        Color(0xFFE91E63),
        Color(0xFFEC407A),
        Color(0xFFF48FB1),
      ];
    case _KpiTheme.olive:
      return const [
        Color(0xFF1E2A12),
        Color(0xFF0E1808),
        Color(0xFF8BC34A),
        Color(0xFF9CCC65),
        Color(0xFFC5E1A5),
      ];
  }
}

// ============================================================
// ILLUSTRATIONS 3D (CUSTOM PAINTER) — sans icônes Material
// ============================================================
enum _KpiVisualKind {
  terminal,
  bottle,
  boxes,
  clipboard,
  truck,
  people,
  pharmacist,
  chart,
}

class _KpiVisual extends StatelessWidget {
  final _KpiVisualKind kind;
  final Color color;

  const _KpiVisual(this.kind, this.color);

  factory _KpiVisual.kTerminal(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.terminal, AppColors.emerald);
  factory _KpiVisual.kBottle(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.bottle, AppColors.info);
  factory _KpiVisual.kBoxes(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.boxes, AppColors.warning);
  factory _KpiVisual.kClipboard(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.clipboard, AppColors.purple);
  factory _KpiVisual.kTruck(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.truck, AppColors.cyan);
  factory _KpiVisual.kPeople(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.people, AppColors.pink);
  factory _KpiVisual.kPharmacist(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.pharmacist, AppColors.olive);
  factory _KpiVisual.kChart(dynamic _) =>
      const _KpiVisual(_KpiVisualKind.chart, AppColors.info);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KpiVisualPainter(kind, color),
      size: const Size(118, 118),
    );
  }
}

class _KpiVisualPainter extends CustomPainter {
  final _KpiVisualKind kind;
  final Color color;

  _KpiVisualPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _KpiVisualKind.terminal:
        _drawTerminal(canvas, size, color);
      case _KpiVisualKind.bottle:
        _drawBottle(canvas, size, color);
      case _KpiVisualKind.boxes:
        _drawBoxes(canvas, size, color);
      case _KpiVisualKind.clipboard:
        _drawClipboard(canvas, size, color);
      case _KpiVisualKind.truck:
        _drawTruck(canvas, size, color);
      case _KpiVisualKind.people:
        _drawPeople(canvas, size, color);
      case _KpiVisualKind.pharmacist:
        _drawPharmacist(canvas, size, color);
      case _KpiVisualKind.chart:
        _drawChart(canvas, size, color);
    }
  }

  // Plateforme perspective 3D
  void _platform(Canvas canvas, Size size, Color c) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [c.withValues(alpha: 0.95), c.withValues(alpha: 0.35)],
      ).createShader(Rect.fromLTWH(0, size.height - 16, size.width, 16));
    final path = Path()
      ..moveTo(size.width * 0.10, size.height - 8)
      ..lineTo(size.width * 0.90, size.height - 8)
      ..lineTo(size.width * 0.80, size.height - 2)
      ..lineTo(size.width * 0.20, size.height - 2)
      ..close();
    canvas.drawPath(path, paint);
    final edge = Paint()..color = c.withValues(alpha: 0.5);
    canvas.drawLine(Offset(size.width * 0.10, size.height - 8),
        Offset(size.width * 0.90, size.height - 8), edge);
  }

  void _shadow(Canvas canvas, Rect rect, double blur, Color c) {
    final paint = Paint()
      ..color = c.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rect.center.dx, rect.bottom + 2),
            width: rect.width * 0.8,
            height: 8),
        paint);
  }

  void _drawTerminal(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    // Écran incliné
    final screen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFF3A4048), Color(0xFF171B21)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final screenRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.18, size.height * 0.16, size.width * 0.62,
            size.height * 0.42),
        const Radius.circular(8));
    canvas.drawRRect(screenRect, screen);
    canvas.drawRRect(
        screenRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Affichage vert
    final display = Paint()..color = color.withValues(alpha: 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.26, size.height * 0.24,
                size.width * 0.46, size.height * 0.2),
            const Radius.circular(4)),
        display);
    // Clavier
    final key = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 4; c++) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(
                    size.width * (0.20 + c * 0.15),
                    size.height * (0.62 + r * 0.08),
                    size.width * 0.11,
                    size.height * 0.05),
                const Radius.circular(3)),
            key);
      }
    }
    _shadow(
        canvas, screenRect.inflate(6).outerRect, 10, const Color(0xFF000000));
  }

  void _drawBottle(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFFF4F6F8), Color(0xFFCFD6DC)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    // Corps de la bouteille
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.34, size.height * 0.26, size.width * 0.34,
            size.height * 0.52),
        const Radius.circular(10));
    canvas.drawRRect(body, bodyPaint);
    // Bouchon bleu
    final cap = Paint()
      ..shader = LinearGradient(colors: [color, color.withValues(alpha: 0.6)])
          .createShader(Rect.fromLTWH(size.width * 0.40, size.height * 0.12,
              size.width * 0.22, size.height * 0.14));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.40, size.height * 0.12,
                size.width * 0.22, size.height * 0.14),
            const Radius.circular(4)),
        cap);
    // Croix médicale bleue
    final cross = Paint()..color = color;
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(size.width * 0.51, size.height * 0.50),
            width: 10,
            height: 26),
        cross);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(size.width * 0.51, size.height * 0.50),
            width: 26,
            height: 10),
        cross);
    // Comprimés
    final pill = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  size.width * (0.28 + i * 0.18), size.height * 0.84, 16, 7),
              const Radius.circular(4)),
          pill);
    }
    _shadow(canvas, body.outerRect, 10, const Color(0xFF000000));
  }

  void _drawBoxes(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    final boxPaint = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFF8D6E63), Color(0xFF5D4037)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    // Cartons empilés
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.16, size.height * 0.30,
                size.width * 0.30, size.height * 0.18),
            const Radius.circular(3)),
        boxPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.22, size.height * 0.48,
                size.width * 0.34, size.height * 0.20),
            const Radius.circular(3)),
        boxPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.30, size.height * 0.66,
                size.width * 0.40, size.height * 0.18),
            const Radius.circular(3)),
        boxPaint);
    _drawBoxLid(
        canvas,
        Rect.fromLTWH(size.width * 0.16, size.height * 0.30, size.width * 0.30,
            size.height * 0.18));
    _drawBoxLid(
        canvas,
        Rect.fromLTWH(size.width * 0.30, size.height * 0.66, size.width * 0.40,
            size.height * 0.18));
    // Panneau triangle + point d'exclamation
    final warn = Paint()..color = color;
    final triangle = Path()
      ..moveTo(size.width * 0.68, size.height * 0.34)
      ..lineTo(size.width * 0.86, size.height * 0.52)
      ..lineTo(size.width * 0.50, size.height * 0.52)
      ..close();
    canvas.drawPath(triangle, warn);
    final exclaim = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.68, size.height * 0.40),
        Offset(size.width * 0.68, size.height * 0.47), exclaim);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.50), 1.6,
        exclaim..style = PaintingStyle.fill);
    _shadow(
        canvas,
        Rect.fromLTWH(size.width * 0.16, size.height * 0.30, size.width * 0.54,
            size.height * 0.54),
        10,
        const Color(0xFF000000));
  }

  void _drawBoxLid(Canvas canvas, Rect rect) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top - 4, rect.width, 4), paint);
  }

  void _drawClipboard(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    // Clip en haut
    final clip = Paint()..color = const Color(0xFF9E9E9E);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.44, size.height * 0.10,
                size.width * 0.12, size.height * 0.06),
            const Radius.circular(3)),
        clip);
    // Planche violette
    final boardPaint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.55)
          ]).createShader(Rect.fromLTWH(size.width * 0.20, size.height * 0.14,
          size.width * 0.60, size.height * 0.72));
    final board = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22, size.height * 0.14, size.width * 0.56,
            size.height * 0.72),
        const Radius.circular(8));
    canvas.drawRRect(board, boardPaint);
    // Feuille blanche
    final sheet = Paint()..color = const Color(0xFFF2F4F7);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.30, size.height * 0.22,
                size.width * 0.40, size.height * 0.56),
            const Radius.circular(4)),
        sheet);
    // Lignes + cases cochées
    final lines = Paint()..color = Colors.black.withValues(alpha: 0.18);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(size.width * 0.34, size.height * (0.28 + i * 0.10),
                  size.width * 0.30, 3),
              const Radius.circular(2)),
          lines);
    }
    final checks = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.28 + i * 0.10) - 1;
      final path = Path()
        ..moveTo(size.width * 0.315, y + 5)
        ..lineTo(size.width * 0.325, y + 9)
        ..lineTo(size.width * 0.34, y + 3);
      canvas.drawPath(path, checks);
    }
    _shadow(canvas, board.outerRect, 10, const Color(0xFF000000));
  }

  void _drawTruck(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    // Caisse bleue
    final boxPaint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.5)
          ]).createShader(Rect.fromLTWH(size.width * 0.12, size.height * 0.20,
          size.width * 0.46, size.height * 0.44));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.12, size.height * 0.22,
                size.width * 0.46, size.height * 0.46),
            const Radius.circular(4)),
        boxPaint);
    // Cabine blanche
    final cabPaint = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFFF2F4F7), Color(0xFFB9C0C8)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.58, size.height * 0.28,
                size.width * 0.28, size.height * 0.40),
            const Radius.circular(6)),
        cabPaint);
    // Fenêtre
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.62, size.height * 0.32,
                size.width * 0.18, size.height * 0.14),
            const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.6));
    // Roues
    final wheel = Paint()..color = const Color(0xFF22262B);
    canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.76), 7, wheel);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.76), 7, wheel);
    // Lignes caisse
    final boxLines = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 2; i++) {
      canvas.drawLine(Offset(size.width * (0.12 + i * 0.1), size.height * 0.22),
          Offset(size.width * (0.12 + i * 0.1), size.height * 0.68), boxLines);
    }
    _shadow(
        canvas,
        Rect.fromLTWH(size.width * 0.12, size.height * 0.22, size.width * 0.74,
            size.height * 0.52),
        10,
        const Color(0xFF000000));
  }

  void _drawPeople(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    // Personnages derrière
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.24 + i * 0.20);
      final c = color.withValues(alpha: 0.3 + i * 0.15);
      canvas.drawCircle(Offset(x, size.height * 0.16), 8, Paint()..color = c);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 11, size.height * 0.26, 22, size.height * 0.44),
              const Radius.circular(11)),
          Paint()..color = c);
    }
    // Personnage principal
    final mainC = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.6)
          ]).createShader(Rect.fromLTWH(size.width * 0.42, size.height * 0.10,
          size.width * 0.2, size.height * 0.8));
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.16), 12, mainC);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                size.width * 0.42, size.height * 0.28, 26, size.height * 0.52),
            const Radius.circular(13)),
        mainC);
    // Ombre portée
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.44), 9,
        Paint()..color = Colors.black.withValues(alpha: 0.12));
    _shadow(
        canvas,
        Rect.fromLTWH(size.width * 0.24, size.height * 0.14, size.width * 0.56,
            size.height * 0.62),
        12,
        color);
  }

  void _drawPharmacist(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    // Blouse blanche
    final coat = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFFF6F8FA), Color(0xFFD6DBDF)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.36, size.height * 0.30,
                size.width * 0.28, size.height * 0.50),
            const Radius.circular(14)),
        coat);
    // Tête (cheveux noirs)
    final head = Paint()..color = const Color(0xFF22262B);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.16), 12, head);
    final face = Paint()..color = const Color(0xFFF0C8A0);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.16), 9, face);
    // Col vert (détails)
    final collar = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.42, size.height * 0.30,
                size.width * 0.16, size.height * 0.06),
            const Radius.circular(3)),
        collar);
    // Croix médicale sur la blouse
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(size.width * 0.50, size.height * 0.46),
            width: 7,
            height: 18),
        Paint()..color = color);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(size.width * 0.50, size.height * 0.46),
            width: 18,
            height: 7),
        Paint()..color = color);
    _shadow(
        canvas,
        Rect.fromLTWH(size.width * 0.36, size.height * 0.10, size.width * 0.34,
            size.height * 0.72),
        10,
        const Color(0xFF000000));
  }

  void _drawChart(Canvas canvas, Size size, Color color) {
    _platform(canvas, size, color);
    final bars = [
      (0.12, 0.5),
      (0.26, 0.7),
      (0.40, 0.4),
      (0.54, 0.6),
      (0.68, 0.85),
    ];
    for (final (x, h) in bars) {
      final isLast = x > 0.62;
      final paint = Paint()
        ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isLast
                    ? [AppColors.emerald, const Color(0xFF00A24C)]
                    : [color, color.withValues(alpha: 0.45)])
            .createShader(Rect.fromLTWH(
                size.width * x,
                size.height * (0.62 - 0.5 * h),
                size.width * 0.10,
                size.height * 0.5 * h));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(size.width * x, size.height * (0.62 - 0.5 * h),
                  size.width * 0.10, size.height * 0.5 * h),
              const Radius.circular(3)),
          paint);
    }
    // Flèche ascendante
    final arrow = Paint()
      ..color = AppColors.emeraldLight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.6)
      ..lineTo(size.width * 0.32, size.height * 0.42)
      ..lineTo(size.width * 0.44, size.height * 0.5)
      ..lineTo(size.width * 0.62, size.height * 0.28);
    canvas.drawPath(path, arrow);
    _shadow(
        canvas,
        Rect.fromLTWH(size.width * 0.10, size.height * 0.2, size.width * 0.8,
            size.height * 0.5),
        10,
        const Color(0xFF000000));
    // Courbe verte pour première carte (dessinée au-dessus en overlay)
  }

  @override
  bool shouldRepaint(covariant _KpiVisualPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

// ============================================================
// ALERTES STOCK (bloc gauche bas)
// ============================================================
class _AlertsStockPanel extends StatelessWidget {
  final int lowStock;
  final int expiring;
  final VoidCallback onViewAll;

  const _AlertsStockPanel({
    required this.lowStock,
    required this.expiring,
    required this.onViewAll,
  });

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
      ('Fer B9', 'Expire dans 15 j', AppColors.info, Icons.hourglass_bottom),
    ];
    return _DarkPanel(
      title: 'ALERTES STOCK',
      icon: Icons.notifications_active_outlined,
      iconColor: AppColors.warning,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _AlertRow(
              name: rows[i].$1,
              detail: rows[i].$2,
              color: rows[i].$3,
              icon: rows[i].$4,
            ),
            if (i < rows.length - 1) const SizedBox(height: 6),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              onPressed: onViewAll,
              style: OutlinedButton.styleFrom(
                side:
                    BorderSide(color: AppColors.emerald.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.visibility_outlined,
                  size: 17, color: AppColors.emeraldLight),
              label: const Text('Voir toutes',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String name;
  final String detail;
  final Color color;
  final IconData icon;

  const _AlertRow({
    required this.name,
    required this.detail,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerDark.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 18, color: color),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(detail, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PLAN 3D DE LA PHARMACIE
// ============================================================
class _Plan3DPanel extends StatelessWidget {
  final VoidCallback onOpen;

  const _Plan3DPanel({required this.onOpen});

  static const _legend = [
    ('A', 'Antalgiques'),
    ('B', 'Antibiotiques'),
    ('C', 'Cardiologie'),
    ('D', 'Digestif'),
    ('E', 'Soins'),
  ];

  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      title: 'PLAN 3D DE LA PHARMACIE',
      icon: Icons.view_in_ar_outlined,
      iconColor: AppColors.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vue 3D isométrique
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF101C16), Color(0xFF0A120E)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.dividerDark.withValues(alpha: 0.9)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PlanPainter()),
                    ),
                    // Contrôles à droite
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          _PlanChip(label: 'Vue 3D', icon: Icons.view_in_ar),
                          const SizedBox(height: 6),
                          _PlanChip(label: 'Tourner', icon: Icons.rotate_right),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: const [
                              _MiniRound(icon: Icons.add),
                              _MiniRound(icon: Icons.remove),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _PlanChip(
                              label: 'Plein écran', icon: Icons.fullscreen),
                        ],
                      ),
                    ),
                    // Marqueurs zones
                    const Positioned(
                      left: 20,
                      top: 26,
                      child: _ZoneMarker(label: 'A'),
                    ),
                    const Positioned(
                      left: 72,
                      top: 18,
                      child: _ZoneMarker(label: 'D'),
                    ),
                    const Positioned(
                      left: 34,
                      bottom: 30,
                      child: _ZoneMarker(label: 'C'),
                    ),
                    const Positioned(
                      left: 84,
                      bottom: 24,
                      child: _ZoneMarker(label: 'E'),
                    ),
                    const Positioned(
                      left: 46,
                      bottom: 4,
                      child: _ZoneMarker(label: 'B'),
                    ),
                    const Positioned(
                      right: 70,
                      bottom: 24,
                      child: _ZoneMarker(label: 'Caisse', special: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Légende en bas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (letter, name) in _legend) _LegendItem(letter, name),
            ],
          ),
        ],
      ),
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
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.emeraldLight),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _MiniRound extends StatelessWidget {
  final IconData icon;
  const _MiniRound({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, size: 15, color: Colors.white70),
    );
  }
}

class _ZoneMarker extends StatelessWidget {
  final String label;
  final bool special;
  const _ZoneMarker({required this.label, this.special = false});

  @override
  Widget build(BuildContext context) {
    final color = special ? AppColors.warning : AppColors.emerald;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        if (special) ...[
          const SizedBox(width: 4),
          const Text('Caisse',
              style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String letter;
  final String name;
  const _LegendItem(this.letter, this.name);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: const BoxDecoration(
            color: AppColors.emerald,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 4),
        Text(name,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

/// Vue isométrique / perspective de la pharmacie.
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
          colors: [Color(0xFF1B3A2A), Color(0xFF0E1F16)],
        ).createShader(Offset.zero & size),
    );

    // Grille
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Rayons (étagères) en perspective
    final shelf = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var row = 0; row < 4; row++) {
      final y = size.height * (0.36 + row * 0.12);
      final path = Path()
        ..moveTo(size.width * (0.14 + row * 0.03), y)
        ..lineTo(size.width * (0.52 + row * 0.03), y - size.height * 0.12)
        ..lineTo(size.width * (0.68 + row * 0.03), y - size.height * 0.06);
      canvas.drawPath(path, shelf);
    }

    // Comptoir en bas
    final counter = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.42, size.height * 0.76, size.width * 0.16,
          size.height * 0.10),
      const Radius.circular(4),
    );
    canvas.drawRRect(counter,
        Paint()..color = const Color(0xFF00C853).withValues(alpha: 0.7));
    canvas.drawRRect(
        counter,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// PANEL SOMBRE GÉNÉRIQUE
// ============================================================
class _DarkPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _DarkPanel({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101C16), Color(0xFF0B1210)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerDark.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
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
    ('Autres', Icons.more_horiz, Color(0xFFB0BEC5)),
  ];

  static const _products = [
    ('Doliprane 1g', 'Paracétamol', 2, 18.00),
    ('Amoxicilline 500mg', 'Sandoz', 1, 15.00),
    ('Vitamine C 1g', 'Effervescent', 1, 25.00),
    ('Bisolvon Sirop', 'Toux sèche', 1, 32.00),
    ('Lactulose 10g/15ml', 'Sirop', 1, 20.00),
  ];

  @override
  Widget build(BuildContext context) {
    final totalQty = _products.fold<int>(0, (s, p) => s + p.$3);
    final total = _products.fold<double>(0, (s, p) => s + p.$3 * p.$4);
    return Container(
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00C853), Color(0xFF008F57)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_cart,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('POINT DE VENTE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 14),
          // Recherche
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.dividerLight.withValues(alpha: 0.6)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 19, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rechercher un médicament (nom, code, labo...)',
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Catégories 4×2
          Expanded(child: _buildCategories()),
          // Produits
          const _ProductsHeader(),
          const SizedBox(height: 6),
          Expanded(child: _buildProducts()),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00A24C), Color(0xFF007A3D)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ($totalQty produits)',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(Fmt.money(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Boutons VIDER / SUSPENDRE / PAIEMENT
          Row(
            children: [
              Expanded(
                child: _PosButton(
                  label: 'VIDER',
                  color: AppColors.danger,
                  icon: Icons.delete_outline,
                  onTap: onCheckout,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PosButton(
                  label: 'SUSPENDRE',
                  color: AppColors.warning,
                  icon: Icons.pause_circle_outline,
                  onTap: onCheckout,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _PosButton(
                  label: 'PAIEMENT',
                  color: AppColors.emerald,
                  icon: Icons.payment,
                  onTap: onCheckout,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Actions Scanner / Remise / Client / Note
          Row(
            children: [
              for (final action in const [
                (Icons.qr_code_scanner, 'Scanner'),
                (Icons.percent, 'Remise'),
                (Icons.person_outline, 'Client'),
                (Icons.sticky_note_2_outlined, 'Note'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PosAction(icon: action.$1, label: action.$2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return GridView.count(
      crossAxisCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 0.92,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final (name, icon, color) in _categories)
          _CategoryCell(name: name, icon: icon, color: color),
      ],
    );
  }

  Widget _buildProducts() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final (name, labo, qty, price) = _products[i];
        return _ProductRow(
          name: name,
          labo: labo,
          qty: qty,
          price: price,
        );
      },
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 4, child: _HeaderCell('Produit')),
        Expanded(flex: 2, child: _HeaderCell('Qté')),
        Expanded(flex: 2, child: _HeaderCell('Prix')),
        Expanded(flex: 3, child: _HeaderCell('Total', alignRight: true)),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool alignRight;
  const _HeaderCell(this.text, {this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 10.5),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;

  const _CategoryCell(
      {required this.name, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String name;
  final String labo;
  final int qty;
  final double price;

  const _ProductRow({
    required this.name,
    required this.labo,
    required this.qty,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          // Miniature produit
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.medication,
                size: 17, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          // Nom + labo
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
                        color: AppColors.textTertiary, fontSize: 9.5)),
              ],
            ),
          ),
          // Qté − n +
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyBtn(icon: Icons.remove, color: AppColors.danger),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text('$qty',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                _QtyBtn(icon: Icons.add, color: AppColors.emerald),
              ],
            ),
          ),
          // Prix
          Expanded(
            flex: 2,
            child: Text(
              Fmt.money(price),
              textAlign: TextAlign.right,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          // Total
          Expanded(
            flex: 3,
            child: Text(
              Fmt.money(price * qty),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _QtyBtn({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

class _PosButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PosButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PosAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppColors.emeraldLight),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 9.5)),
        ],
      ),
    );
  }
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

  const _BottomBar({
    required this.revenueToday,
    required this.revenueMonth,
    required this.profitMonth,
    required this.expiring,
    required this.lowStock,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerDark.withValues(alpha: 0.9)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101C16), Color(0xFF0B1210)],
        ),
      ),
      child: Row(
        children: [
          _BottomStat(
            label: 'VENTES AUJOURD\'HUI',
            value: Fmt.money(revenueToday),
            trend: '+12.5%',
            color: AppColors.emerald,
            curve: true,
          ),
          _BottomStat(
            label: 'VENTES MOIS',
            value: Fmt.money(revenueMonth),
            trend: '+8.3%',
            color: AppColors.emerald,
            curve: true,
          ),
          _BottomStat(
            label: 'BÉNÉFICE MOIS',
            value: Fmt.money(profitMonth),
            trend: '+8.3%',
            color: AppColors.emerald,
            curve: true,
          ),
          _BottomStat(
            label: 'PRODUITS EXPIRÉS',
            value: '$expiring',
            subtitled: 'Produits',
            color: AppColors.danger,
          ),
          _BottomStat(
            label: 'STOCK FAIBLE',
            value: '$lowStock',
            subtitled: 'Produits',
            color: AppColors.warning,
          ),
          const Spacer(),
          // Date/heure
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.dividerDark),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppColors.emeraldLight),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.time(now),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Text(Fmt.shortDate(now),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10.5)),
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

class _BottomStat extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final String? subtitled;
  final Color color;
  final bool curve;

  const _BottomStat({
    required this.label,
    required this.value,
    this.trend,
    this.subtitled,
    required this.color,
    this.curve = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 9.5)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  if (trend != null)
                    Text(trend!,
                        style: const TextStyle(
                            color: AppColors.emeraldLight, fontSize: 10)),
                  if (subtitled != null)
                    Text(subtitled!,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.9), fontSize: 10)),
                ],
              ),
            ),
            if (curve)
              SizedBox(
                width: 40,
                height: 26,
                child: CustomPaint(painter: _MiniCurvePainter(color)),
              ),
          ],
        ),
      ),
    );
  }
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
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.5);
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
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
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
