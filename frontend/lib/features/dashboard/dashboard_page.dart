import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/pharma_logo.dart';
import '../accounting/accounting_page.dart';
import '../ai/ai_page.dart';
import '../attendance/attendance_page.dart';
import '../cameras/cameras_page.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../employees/employees_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../modules/modules_page.dart';
import '../notifications/notifications_page.dart';
import '../pos/pos_page.dart';
import '../prescriptions/prescriptions_page.dart';
import '../purchases/purchases_page.dart';
import '../reference/reference_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../website/website_page.dart';
import 'kpi_art.dart';

/// ============================================================
/// DASHBOARD PHARMA+ — reconstruction IDENTIQUE à la maquette :
/// SIDEBAR (logo croix+feuille, 13 modules, admin, horloge)
/// TOPBAR (recherche + scan or + pharmacie + alertes)
/// 8 KPI 3D en 4x2 · ALERTES STOCK · PLAN 3D ISOMÉTRIQUE
/// BARRE STATS (5 tuiles) · POINT DE VENTE
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

  void _onLogout() => context.read<AuthStore>().signOut();

  void _onMenuSelect(int index) {
    switch (index) {
      case 1:
        _push(const PosPage());
      case 2:
        _push(const CatalogPage());
      case 3:
        _push(const StockPage());
      case 4:
        _push(const SuppliersPage());
      case 5:
        _push(const PurchasesPage());
      case 6:
        _push(const CustomersPage());
      case 7:
        _push(const EmployeesPage());
      case 8:
        _push(const ReportsPage());
      case 9:
        _push(const PharmacyPlanPage());
      case 10:
        _push(const CamerasPage());
      case 11:
        _push(const PosPage());
      case 12:
        _push(const SettingsPage());
    }
  }

  /// Menu « Autres modules » : s'ouvre à la demande depuis la sidebar et
  /// se referme au choix d'une option ou au clic en dehors (barrière).
  void _showModulesMenu() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => _ModulesMenuDialog(
        onOpen: (page) {
          Navigator.of(dialogContext).pop();
          _push(page);
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.cloud_off, size: 64, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
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
        final posWidth = constraints.maxWidth >= 1500 ? 430.0 : 385.0;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 232,
              child: _Sidebar(
                  onSelect: _onMenuSelect,
                  onLogout: _onLogout,
                  onMoreModules: _showModulesMenu)),
          Container(width: 1, color: AppColors.dividerDark),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _TopBar(
                onSearch: () => _push(const CatalogPage()),
                onScan: () => _push(const PosPage()),
                onNotifications: () => _push(const NotificationsPage()),
                onSettings: () => _push(const SettingsPage()),
                onLogout: _onLogout,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKpiGrid(),
                        const SizedBox(height: 12),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _AlertsStockPanel(
                                  lowStock: _lowStock,
                                  expiring: _expiring,
                                  onViewAll: () => _push(
                                      const StockPage(initialFilter: 'low')),
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
                        const SizedBox(height: 12),
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
          SizedBox(
              width: posWidth,
              child: _PosPanel(onCheckout: () => _push(const PosPage()))),
        ]);
      }),
    );
  }

  Widget _buildKpiGrid() {
    final kpis = <(String, String, String, KpiArt, bool)>[
      ('VENTES DU JOUR', Fmt.money(_revenueToday), '+12,5% vs hier',
          KpiArt.register, true),
      ('MÉDICAMENTS', Fmt.number(_medications), 'Références', KpiArt.bottle,
          false),
      ('STOCK FAIBLE', '$_lowStock', 'Produits', KpiArt.boxes, false),
      ('COMMANDES', '$_pendingOrders', 'En attente', KpiArt.clipboard, false),
      ('FOURNISSEURS', Fmt.number(_suppliers), 'Actifs', KpiArt.truck, false),
      ('CLIENTS', Fmt.number(_customers), 'Total', KpiArt.people, false),
      ('EMPLOYÉS', '$_employees', 'Actifs', KpiArt.pharmacist, false),
      ('BÉNÉFICE MOIS', Fmt.money(_profitMonth), '+8,3% vs mois dernier',
          KpiArt.bars, true),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        for (var i = 0; i < kpis.length; i++)
          _KpiCard(
            key: ValueKey('kpi-$i'),
            label: kpis[i].$1,
            value: kpis[i].$2,
            subtitle: kpis[i].$3,
            art: kpis[i].$4,
            trend: kpis[i].$5,
            onTap: _kpiTap(i),
          ),
      ],
    );
  }
}

/// Carte KPI maquette : label · grande valeur · sous-titre ·
/// illustration 3D sur socle vert en bas à droite.
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final KpiArt art;
  final bool trend;
  final VoidCallback? onTap;
  const _KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.art,
    required this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10291B), Color(0xFF0A1D13)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Stack(children: [
            Positioned(
              right: 2,
              bottom: 0,
              child: SizedBox(
                width: 84,
                height: 62,
                child: CustomPaint(painter: KpiArtPainter(art)),
              ),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 7),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: trend
                              ? AppColors.emeraldLight
                              : AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600)),
                ]),
          ]),
        ),
      ),
    );
  }
}

/// Or de marque utilisé par les accents dorés du dashboard.
const Color _gold = Color(0xFFD9B45C);

/// ============================================================
/// SIDEBAR — logo croix+feuille · PHARMA+ blanc · 13 modules ·
/// carte Admin · Se déconnecter · horloge + date (maquette).
/// ============================================================
class _Sidebar extends StatefulWidget {
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onMoreModules;
  const _Sidebar({
    required this.onSelect,
    required this.onLogout,
    required this.onMoreModules,
  });
  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Tableau de bord'),
    (Icons.shopping_cart_outlined, 'Point de vente'),
    (Icons.medication_outlined, 'Catalogue'),
    (Icons.inventory_2_outlined, 'Stock'),
    (Icons.local_shipping_outlined, 'Fournisseurs'),
    (Icons.assignment_outlined, 'Commandes'),
    (Icons.people_alt_outlined, 'Clients'),
    (Icons.badge_outlined, 'Employés'),
    (Icons.insert_chart_outlined, 'Rapports'),
    (Icons.view_in_ar_outlined, 'Plan 3D'),
    (Icons.videocam_outlined, 'Caméras'),
    (Icons.qr_code_scanner, 'Scanner'),
    (Icons.settings_outlined, 'Paramètres'),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dateLabel() {
    var s = DateFormat('EEEE d MMMM y', 'fr').format(_now);
    s = s[0].toUpperCase() + s.substring(1);
    return s.replaceAll('août', 'Aout');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSidebar,
      child: Column(children: [
        // ---- Marque : logo officiel complet (textes inclus dans l'asset) ----
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.dividerDark.withValues(alpha: 0.7)))),
          child: const Center(
            child: PharmaFullLogo(width: 152),
          ),
        ),
        // ---- Menu 13 modules ----
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final active = i == 0;
              final (icon, label) = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.onSelect(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10.5),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF07271C) : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: active
                              ? const Color(0xFFC9A24B).withValues(alpha: 0.55)
                              : Colors.transparent),
                    ),
                    child: Row(children: [
                      Icon(icon,
                          size: 19, color: const Color(0xFFC9A24B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        // ---- Autres modules (menu à la demande) ----
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onMoreModules,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFF07271C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFC9A24B).withValues(alpha: 0.55))),
            child: Row(children: [
              const Icon(Icons.apps_rounded, color: _gold, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Autres modules',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.keyboard_arrow_right_rounded,
                  color: _gold, size: 18),
            ]),
          ),
        ),
        // ---- Carte Admin ----
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.goldBorder)),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF123327),
                    border: Border.all(
                        color:
                            const Color(0xFFC9A24B).withValues(alpha: 0.5))),
                child:
                    const Icon(Icons.person, color: Colors.white70, size: 24),
              ),
              Positioned(
                right: -1,
                bottom: -1,
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
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    Text('Administrateur',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10.5)),
                    Text('Pharmacie Dar Al Shifa',
                        style: TextStyle(
                            color: AppColors.emeraldLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ]),
        ),
        // ---- Se déconnecter ----
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onLogout,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08))),
            child: Row(children: [
              const Icon(Icons.restart_alt, color: _gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Se déconnecter',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.logout, color: _gold, size: 17),
            ]),
          ),
        ),
        // ---- Horloge + date ----
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08))),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('HH:mm').format(_now),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(_dateLabel(),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFC9A24B).withValues(alpha: 0.55))),
              child: const Icon(Icons.calendar_today_outlined,
                  color: _gold, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// ============================================================
/// MENU « AUTRES MODULES » — panneau ouvert à la demande depuis
/// la sidebar. Se referme au choix d'une option ou au clic en
/// dehors (barrière du dialog). Regroupe les modules absents du
/// menu latéral : ordonnances, pointage, comptabilité, IA...
/// ============================================================
class _ModulesMenuDialog extends StatelessWidget {
  final ValueChanged<Widget> onOpen;
  const _ModulesMenuDialog({required this.onOpen});

  static const _entries = <(IconData, String, String, Widget)>[
    (Icons.receipt_long_outlined, 'Ordonnances', 'Saisie et délivrance',
        PrescriptionsPage()),
    (Icons.fact_check_outlined, 'Pointage', 'Présences équipe',
        AttendancePage()),
    (Icons.account_balance_wallet_outlined, 'Comptabilité',
        'Caisse et écritures', AccountingPage()),
    (Icons.auto_awesome_outlined, 'Assistant IA', 'Prévisions et conseils',
        AiPage()),
    (Icons.menu_book_outlined, 'Référentiel', 'Données de référence',
        ReferencePage()),
    (Icons.notifications_outlined, 'Notifications', 'Alertes et messages',
        NotificationsPage()),
    (Icons.widgets_outlined, 'Modules', 'Gestionnaire de modules',
        ModulesPage()),
    (Icons.language_rounded, 'Site web', 'Blog et contenu public',
        WebsitePage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10291B), Color(0xFF0A1D13)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.goldBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 34,
                  offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF123327),
                      border: Border.all(
                          color: const Color(0xFFC9A24B)
                              .withValues(alpha: 0.5))),
                  child:
                      const Icon(Icons.apps_rounded, color: _gold, size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Autres modules',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('Modules absents du menu latéral',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ]),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10))),
                    child: const Icon(Icons.close_rounded,
                        size: 17, color: AppColors.textSecondary),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: [
                  for (final (icon, label, subtitle, page) in _entries)
                    _ModuleMenuTile(
                        icon: icon,
                        label: label,
                        subtitle: subtitle,
                        onTap: () => onOpen(page)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile du menu modules : icône encadrée or + titre + sous-titre.
class _ModuleMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: const Color(0xFFC9A24B).withValues(alpha: 0.45)),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF123327),
                  border: Border.all(
                      color: const Color(0xFFC9A24B).withValues(alpha: 0.45))),
              child: Icon(icon, size: 18, color: const Color(0xFFC9A24B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 10)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ============================================================
/// TOP BAR — recherche pleine largeur + scan or + sélecteur
/// pharmacie + notifications (badge 3) + réglages + sortie.
/// ============================================================
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
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
              bottom:
                  BorderSide(color: AppColors.dividerDark.withValues(alpha: 0.7)))),
      child: Row(children: [
        // Identité PHARMA+ (logo officiel) à gauche du header.
        const PharmaPlusLogo(size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFF0A201A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldBorder)),
              child: Row(children: [
                const Icon(Icons.search,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onSearch,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                        'Rechercher un médicament, client, facture...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onScan,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFC9A24B).withValues(alpha: 0.6))),
                    child: const Icon(Icons.qr_code_scanner,
                        size: 17, color: _gold),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.10))),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Pharmacie Dar Al Shifa',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: AppColors.textSecondary),
                ]),
                const Text('Admin',
                    style: TextStyle(
                        color: AppColors.emeraldLight,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ]),
        ),
        const SizedBox(width: 14),
        _TopIcon(icon: Icons.notifications_outlined, badge: '3', onTap: onNotifications),
        const SizedBox(width: 8),
        _TopIcon(icon: Icons.settings_outlined, onTap: onSettings),
        const SizedBox(width: 8),
        _TopIcon(icon: Icons.logout_rounded, onTap: onLogout),
      ]),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;
  const _TopIcon({required this.icon, this.badge, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: _gold),
          if (badge != null)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.surfaceDark, width: 1.5)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      ),
    );
  }
}
/// ============================================================
/// PANNEAU SOMBRE (cadre or, titre) + ALERTES STOCK
/// ============================================================
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
              colors: [Color(0xFF101F18), Color(0xFF0B1512)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 10),
            child,
          ]),
    );
  }
}

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
    const rows = <(String, String, Color, IconData)>[
      ('Amoxicilline 500mg', 'Stock faible (8)', Color(0xFFF0A73B),
          Icons.priority_high_rounded),
      ('Doliprane 1g', 'Stock faible (12)', Color(0xFFF0A73B),
          Icons.priority_high_rounded),
      ('Vitamine D3', 'Rupture de stock', AppColors.danger,
          Icons.close_rounded),
      ('Fer B9', 'Expire dans 15 j', Color(0xFFF0A73B),
          Icons.hourglass_bottom_rounded),
    ];
    return _DarkPanel(
      title: 'ALERTES STOCK',
      icon: Icons.notifications_active_outlined,
      iconColor: const Color(0xFFF0A73B),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          _AlertRow(
              name: rows[i].$1,
              detail: rows[i].$2,
              color: rows[i].$3,
              icon: rows[i].$4),
          if (i < rows.length - 1) const SizedBox(height: 7),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton(
            onPressed: onViewAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF0E2A1C),
              side: BorderSide(color: AppColors.goldBorderStrong),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Voir toutes',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Row(children: [
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5)),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                Text(detail, style: TextStyle(color: color, fontSize: 10.5)),
              ]),
        ),
      ]),
    );
  }
}
/// ============================================================
/// PLAN 3D DE LA PHARMACIE — scène isométrique (maquette) :
/// murs sombres, rayonnages bois, gondoles, caisse liseré or,
/// plantes, étiquettes de rayons, contrôles et légende A-E.
/// ============================================================
class _Plan3DPanel extends StatelessWidget {
  final VoidCallback onOpen;
  const _Plan3DPanel({required this.onOpen});
  static const _legend = <(String, String)>[
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 258,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D1713), Color(0xFF080E0C)]),
                  border: Border.all(
                      color: AppColors.dividerDark.withValues(alpha: 0.9))),
              child: Stack(children: [
                Positioned.fill(
                    child: CustomPaint(
                        painter: _IsoPainter())),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Column(children: [
                    _PlanBtn(
                        icon: Icons.view_in_ar_rounded,
                        label: 'Vue 3D',
                        onTap: onOpen),
                    const SizedBox(height: 6),
                    _PlanBtn(
                        icon: Icons.rotate_right_rounded,
                        label: 'Tourner',
                        onTap: onOpen),
                    const SizedBox(height: 6),
                    _PlanBtn(icon: Icons.add_rounded, onTap: onOpen),
                    const SizedBox(height: 6),
                    _PlanBtn(icon: Icons.remove_rounded, onTap: onOpen),
                    const SizedBox(height: 6),
                    _PlanBtn(icon: Icons.fullscreen_rounded, onTap: onOpen),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (letter, name) in _legend) _LegendItem(letter, name),
            ]),
      ]),
    );
  }
}

class _PlanBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  const _PlanBtn({required this.icon, this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 42,
        height: label != null ? 46 : 34,
        decoration: BoxDecoration(
            color: const Color(0xFF0E231B).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: const Color(0xFFC9A24B).withValues(alpha: 0.45))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: _gold),
          if (label != null) ...[
            const SizedBox(height: 1),
            Text(label!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 8,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String letter;
  final String name;
  const _LegendItem(this.letter, this.name);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
                color: AppColors.pharmaGreen, shape: BoxShape.circle),
            child: Center(
                child: Text(letter,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900)))),
        const SizedBox(width: 4),
        Text(name,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10)),
      ]);
}
/// Peintre de la scène isométrique 2.5D (projection axonométrique).
class _IsoPainter extends CustomPainter {
  late double ux, uy, uz, ox, oy;
  static const room = 12.0, wallH = 3.6;

  Offset P(double x, double y, double z) =>
      Offset(ox + (x - y) * ux, oy + (x + y) * uy - z * uz);

  void quad(Canvas canvas, List<Offset> pts, Color c) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = c);
  }

  void stroke(Canvas canvas, Offset a, Offset b, Color c, double w) {
    canvas.drawLine(a, b, Paint()..color = c..strokeWidth = w);
  }

  /// Boîte isométrique : face dessus + face droite + face gauche.
  void box(Canvas canvas, double x0, double y0, double x1, double y1,
      double z0, double z1, Color base) {
    Color l(Color c, double a) => Color.lerp(c, Colors.white, a)!;
    Color d(Color c, double a) => Color.lerp(c, Colors.black, a)!;
    quad(canvas, [
      P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)
    ], l(base, 0.16));
    quad(canvas, [
      P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1)
    ], d(base, 0.30));
    quad(canvas, [
      P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)
    ], d(base, 0.06));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final u = math.min(w / 25.5, h / 15.4);
    ux = u;
    uy = u * 0.5;
    uz = u * 0.62;
    ox = w * 0.5;
    oy = h / 2 - room * uy + wallH * uz / 2 + u * 0.4;

    // ---- Sol : dalle sombre + grille de tuiles ----
    quad(canvas, [
      P(0, 0, 0), P(room, 0, 0), P(room, room, 0), P(0, room, 0)
    ], const Color(0xFF161510));
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= 12; i++) {
      canvas.drawLine(P(i.toDouble(), 0, 0), P(i.toDouble(), room, 0), grid);
      canvas.drawLine(P(0, i.toDouble(), 0), P(room, i.toDouble(), 0), grid);
    }

    // ---- Mur arrière gauche (x = 0) ----
    quad(canvas, [
      P(0, 0, wallH), P(0, room, wallH), P(0, room, 0), P(0, 0, 0)
    ], const Color(0xFF232E27));
    final panel = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var i = 0; i <= 12; i += 2) {
      canvas.drawLine(P(0, i.toDouble(), 0), P(0, i.toDouble(), wallH), panel);
    }
    // ---- Mur arrière droit (y = 0) ----
    quad(canvas, [
      P(0, 0, wallH), P(room, 0, wallH), P(room, 0, 0), P(0, 0, 0)
    ], const Color(0xFF1B241F));
    for (var i = 0; i <= 12; i += 2) {
      canvas.drawLine(P(i.toDouble(), 0, 0), P(i.toDouble(), 0, wallH), panel);
    }
    // Plinthes.
    stroke(canvas, P(0, 0, 0.18), P(0, room, 0.18), const Color(0xFF31413A), 2);
    stroke(canvas, P(0, 0, 0.18), P(room, 0, 0.18), const Color(0xFF31413A), 2);

    // ---- Porte d'entrée (mur droit) ----
    quad(canvas, [
      P(5.6, 0, 2.5), P(6.8, 0, 2.5), P(6.8, 0, 0), P(5.6, 0, 0)
    ], const Color(0xFF0F1A15));
    stroke(canvas, P(5.6, 0, 2.5), P(6.8, 0, 2.5), const Color(0xFF31413A), 1.4);

    // ---- Rayonnages muraux : 2 segments x 3 niveaux, bois + produits ----
    const prodColors = [
      Color(0xFF2FB563), Color(0xFFE0557C), Color(0xFF5B8FD9),
      Color(0xFFF0B429), Color(0xFFF2F7F4), Color(0xFF9B5FC0),
      Color(0xFF2BD4C4), Color(0xFFE9C873),
    ];
    var ci = 0;
    void wallShelfLeft(double y0, double y1) {
      for (final z in const [1.05, 1.95, 2.85]) {
        quad(canvas, [
          P(0, y0, z), P(0.55, y0, z), P(0.55, y1, z), P(0, y1, z)
        ], const Color(0xFF8A6238));
        quad(canvas, [
          P(0.55, y0, z), P(0.55, y1, z), P(0.55, y1, z - 0.09),
          P(0.55, y0, z - 0.09)
        ], const Color(0xFF5E4123));
        var py = y0 + 0.22;
        while (py < y1 - 0.3) {
          final c = prodColors[ci++ % prodColors.length];
          box(canvas, 0.08, py, 0.48, py + 0.34, z, z + 0.26, c);
          py += 0.52;
        }
      }
    }

    void wallShelfRight(double x0, double x1) {
      for (final z in const [1.05, 1.95, 2.85]) {
        quad(canvas, [
          P(x0, 0, z), P(x0, 0.55, z), P(x1, 0.55, z), P(x1, 0, z)
        ], const Color(0xFF7E5A32));
        quad(canvas, [
          P(x0, 0.55, z), P(x0, 0.55, z - 0.09), P(x1, 0.55, z - 0.09),
          P(x1, 0.55, z)
        ], const Color(0xFF563B20));
        var px = x0 + 0.22;
        while (px < x1 - 0.3) {
          final c = prodColors[ci++ % prodColors.length];
          box(canvas, px, 0.08, px + 0.34, 0.48, z, z + 0.26, c);
          px += 0.52;
        }
      }
    }

    wallShelfLeft(1.2, 5.2);
    wallShelfLeft(6.8, 10.8);
    wallShelfRight(1.2, 4.4);
    wallShelfRight(8.0, 10.8);

    // ---- Plante d'angle (fond droite) ----
    void plant(double x, double y) {
      box(canvas, x - 0.35, y - 0.35, x + 0.35, y + 0.35, 0, 0.55,
          const Color(0xFF7A4A2E));
      final leaves = [
        (x, y, 1.05, const Color(0xFF2E7D4F)),
        (x - 0.3, y + 0.15, 1.2, const Color(0xFF3C9A63)),
        (x + 0.3, y - 0.1, 1.18, const Color(0xFF57B878)),
      ];
      for (final (lx, ly, lz, lc) in leaves) {
        final c = P(lx, ly, lz);
        canvas.drawCircle(c, u * 0.42, Paint()..color = lc);
      }
    }

    plant(11.1, 1.1);

    // ---- Gondoles centrales double-face ----
    void gondola(double y0, double y1) {
      box(canvas, 2.4, y0, 9.6, y1, 0, 1.7, const Color(0xFF6E4E2E));
      for (final z in const [0.62, 1.18]) {
        stroke(canvas, P(2.4, y1, z), P(9.6, y1, z),
            const Color(0xFF4A3520), 1.4);
        stroke(canvas, P(9.6, y0, z), P(9.6, y1, z),
            const Color(0xFF3B2A18), 1.2);
        var px = 2.7;
        var k = 0;
        while (px < 9.2) {
          final c = prodColors[(k++ + y0.toInt()) % prodColors.length];
          quad(canvas, [
            P(px, y1, z + 0.06), P(px + 0.42, y1, z + 0.06),
            P(px + 0.42, y1, z + 0.36), P(px, y1, z + 0.36)
          ], c);
          px += 0.58;
        }
        var pxr = 9.3;
        k = 0;
        while (pxr > 2.8) {
          final c = prodColors[(k++ + 3) % prodColors.length];
          final yA = y0 + (pxr - 2.4) / 7.2 * (y1 - y0);
          final yB = y0 + (pxr - 2.4 + 0.42) / 7.2 * (y1 - y0);
          quad(canvas, [
            P(9.6, yA, z + 0.05), P(9.6, yB, z + 0.05),
            P(9.6, yB, z + 0.35), P(9.6, yA, z + 0.35)
          ], c);
          pxr -= 0.58;
        }
      }
    }

    gondola(4.8, 5.7);
    gondola(7.3, 8.2);
    // ---- Comptoir / caisse avec liseré or (maquette) ----
    box(canvas, 5.0, 9.6, 9.0, 11.2, 0, 1.05, const Color(0xFF3A2A1C));
    final top = [
      P(5.0, 9.6, 1.05), P(9.0, 9.6, 1.05),
      P(9.0, 11.2, 1.05), P(5.0, 11.2, 1.05)
    ];
    final goldTrim = Paint()
      ..color = const Color(0xFFD6A84F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final topPath = Path()..moveTo(top[0].dx, top[0].dy);
    for (var i = 1; i < 4; i++) {
      topPath.lineTo(top[i].dx, top[i].dy);
    }
    topPath.close();
    canvas.drawPath(topPath, goldTrim);
    stroke(canvas, P(5.0, 11.2, 0.98), P(9.0, 11.2, 0.98),
        const Color(0xFFD6A84F), 1.4);
    // Terminal de caisse vert + écran.
    box(canvas, 6.2, 10.0, 7.3, 10.8, 1.05, 1.62, const Color(0xFF0E5C38));
    quad(canvas, [
      P(6.45, 10.15, 1.62), P(7.05, 10.15, 1.62),
      P(7.05, 10.65, 1.62), P(6.45, 10.65, 1.62)
    ], const Color(0xFFBFF0D6));
    box(canvas, 7.9, 10.3, 8.5, 10.8, 1.05, 1.32, const Color(0xFF20302A));

    // ---- Plante d'angle (avant gauche) ----
    plant(1.0, 11.0);

    // ---- Étiquettes de rayons (chips verts, maquette) ----
    void chip(Offset c, String letter, String text) {
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final rect = Rect.fromCenter(center: c, width: tp.width + 32, height: 19);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xCC00C96B));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      final lc = Offset(rect.left + 10, c.dy);
      canvas.drawCircle(
          lc, 6, Paint()..color = Colors.white.withValues(alpha: 0.30));
      final ltp = TextPainter(
        text: TextSpan(
            text: letter,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      ltp.paint(canvas, lc - Offset(ltp.width / 2, ltp.height / 2));
      tp.paint(canvas, Offset(rect.left + 20, c.dy - tp.height / 2));
    }

    chip(P(6.0, 5.25, 2.55), 'A', 'Antalgiques');
    chip(P(0.9, 8.8, 3.05), 'B', 'Antibiotiques');
    chip(P(10.6, 0.9, 3.05), 'C', 'Cardiologie');
    chip(P(8.4, 7.75, 2.55), 'D', 'Digestif');
    chip(P(7.0, 10.4, 1.95), 'C', 'Caisse');
  }

  @override
  bool shouldRepaint(covariant _IsoPainter old) => false;
}

/// ============================================================
/// BARRE STATS — 5 tuiles maquette (3 sparklines or + 2 alertes)
/// ============================================================
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
    const gold = Color(0xFFE9C873);
    return Row(children: [
      Expanded(
          child: _BottomStat(
              label: "VENTES AUJOURD'HUI",
              value: Fmt.money(revenueToday),
              trend: '+12,5%',
              curve: true)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'VENTES MOIS',
              value: Fmt.money(revenueMonth),
              trend: '+8,3%',
              curve: true)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'BÉNÉFICE MOIS',
              value: Fmt.money(profitMonth),
              trend: '+8,3%',
              curve: true)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'PRODUITS EXPIRÉS',
              value: '$expiring',
              subtitle: 'Produits',
              valueColor: const Color(0xFFF0A73B),
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF0A73B))),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'STOCK FAIBLE',
              value: '$lowStock',
              subtitle: 'Produits',
              icon: Icons.warning_amber_rounded,
              iconColor: gold)),
    ]);
  }
}

class _BottomStat extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final String? subtitle;
  final Color valueColor;
  final bool curve;
  final IconData? icon;
  final Color? iconColor;
  const _BottomStat({
    required this.label,
    required this.value,
    this.trend,
    this.subtitle,
    this.valueColor = Colors.white,
    this.curve = false,
    this.icon,
    this.iconColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 8.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                if (trend != null)
                  Text(trend!,
                      style: const TextStyle(
                          color: AppColors.emeraldLight, fontSize: 9.5)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: valueColor.withValues(alpha: 0.85),
                          fontSize: 9.5)),
              ]),
        ),
        if (curve)
          const SizedBox(
              width: 40,
              height: 28,
              child: CustomPaint(painter: _MiniCurvePainter())),
        if (icon != null) Icon(icon, size: 20, color: iconColor ?? valueColor),
      ]),
    );
  }
}

/// Courbe tendance or champagne (maquette).
class _MiniCurvePainter extends CustomPainter {
  const _MiniCurvePainter();
  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFE9C873);
    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.28, size.height * 0.92,
          size.width * 0.48, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.08,
          size.width, size.height * 0.22);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    final area = Path()
      ..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.0)
              ])
              .createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(covariant _MiniCurvePainter old) => false;
}
/// ============================================================
/// POINT DE VENTE (colonne droite, maquette) :
/// 8 catégories illustrées · table produits · total · actions.
/// ============================================================
enum _CatKind { capsuleGreen, capsuleRed, heart, glucometer, vitamins, lungs, stomach, dots }

class _PosPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  const _PosPanel({required this.onCheckout});

  static const _cats = <(String, _CatKind)>[
    ('Antalgiques', _CatKind.capsuleGreen),
    ('Antibiotiques', _CatKind.capsuleRed),
    ('Cardiologie', _CatKind.heart),
    ('Diabète', _CatKind.glucometer),
    ('Vitamines', _CatKind.vitamins),
    ('Respiratoire', _CatKind.lungs),
    ('Digestif', _CatKind.stomach),
    ('Autres', _CatKind.dots),
  ];
  static const _products = <(String, String, int, double, Color)>[
    ('Doliprane 1g', 'Paracétamol', 2, 18.0, Color(0xFF2FB563)),
    ('Amoxicilline 500mg', 'Sandoz', 1, 15.0, Color(0xFF5B8FD9)),
    ('Vitamine C 1g', 'Effervescent', 1, 25.0, Color(0xFFF0B429)),
    ('Bisolvon Sirop', 'Toux sèche', 1, 32.0, Color(0xFFE0557C)),
    ('Lactulose 10g/15ml', 'Sirop', 1, 20.0, Color(0xFF9B5FC0)),
  ];

  static String _m2(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final totalQty = _products.fold<int>(0, (sum, p) => sum + p.$3);
    final total = _products.fold<double>(0, (sum, p) => sum + p.$3 * p.$4);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF081812), Color(0xFF050E0B)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- Titre ----
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            const Icon(Icons.shopping_cart_outlined, color: _gold, size: 20),
            const SizedBox(width: 9),
            Text('POINT DE VENTE',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6)),
          ]),
        ),
        // ---- Recherche ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF0A201A),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.09))),
            child: Row(children: [
              Expanded(
                child: Text('Rechercher un médicament (nom, code, labo...)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12)),
              ),
              const Icon(Icons.search,
                  size: 18, color: AppColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // ---- Catégories 4 x 2 ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.04,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            children: [
              for (final (name, kind) in _cats)
                _CatCell(name: name, kind: kind),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ---- En-tête table ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(children: [
            const Expanded(flex: 4, child: _HeaderCell('Produit')),
            const Expanded(flex: 2, child: _HeaderCell('Qté')),
            const Expanded(flex: 2, child: _HeaderCell('Prix')),
            const Expanded(flex: 2, child: _HeaderCell('Total')),
            const SizedBox(width: 22),
          ]),
        ),
        // ---- Produits ----
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            itemCount: _products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final p = _products[i];
              return _ProductRow(
                  name: p.$1, labo: p.$2, qty: p.$3, price: p.$4, tint: p.$5);
            },
          ),
        ),
        // ---- Total ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF00A24C), Color(0xFF007A3D)]),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text('Total ($totalQty produits)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_m2(total)} MAD',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // ---- Vider / Suspendre / Paiement ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(
                child: _PosButton(
                    label: 'Vider',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFB3372F),
                    onTap: onCheckout)),
            const SizedBox(width: 8),
            Expanded(
                child: _PosButton(
                    label: 'Suspendre',
                    icon: Icons.pause_circle_outline_rounded,
                    color: const Color(0xFFB98A1F),
                    onTap: onCheckout)),
            const SizedBox(width: 8),
            Expanded(
                child: _PosButton(
                    label: 'Paiement',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF0E8C4F),
                    onTap: onCheckout)),
          ]),
        ),
        const SizedBox(height: 8),
        // ---- Actions rapides ----
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            for (final (icon, label) in const [
              (Icons.qr_code_scanner_rounded, 'Scanner'),
              (Icons.percent_rounded, 'Remise'),
              (Icons.person_outline_rounded, 'Client'),
              (Icons.sticky_note_2_outlined, 'Note'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _PosAction(icon: icon, label: label),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10.5,
          fontWeight: FontWeight.w600));
}

/// Ligne produit maquette : pack coloré · qté (−/+) · prix · total · corbeille.
class _ProductRow extends StatelessWidget {
  final String name;
  final String labo;
  final int qty;
  final double price;
  final Color tint;
  const _ProductRow({
    required this.name,
    required this.labo,
    required this.qty,
    required this.price,
    required this.tint,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: tint.withValues(alpha: 0.35))),
            child: Icon(Icons.medication_rounded, size: 15, color: tint)),
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
                          fontWeight: FontWeight.w700)),
                  Text(labo,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 9.5)),
                ])),
        Expanded(
            flex: 2,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _QtyBtn(icon: Icons.remove, color: AppColors.danger),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text('$qty',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800))),
              const _QtyBtn(icon: Icons.add, color: AppColors.emerald),
            ])),
        Expanded(
            flex: 2,
            child: Text(_PosPanel._m2(price),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10.5))),
        Expanded(
            flex: 2,
            child: Text(_PosPanel._m2(price * qty),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800))),
        GestureDetector(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.danger.withValues(alpha: 0.9)),
          ),
        ),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _QtyBtn({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Icon(icon, size: 12, color: color));
}
class _PosButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PosButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 42,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)),
          ]),
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
      height: 50,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 17, color: _gold),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 9.5)),
      ]),
    );
  }
}
class _CatCell extends StatelessWidget {
  final String name;
  final _CatKind kind;
  const _CatCell({required this.name, required this.kind});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF0C241A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
            width: 30,
            height: 26,
            child: CustomPaint(painter: _CatGlyphPainter(kind))),
        const SizedBox(height: 4),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92), fontSize: 9.3)),
      ]),
    );
  }
}

/// Pictos de catégories dessinés (maquette : gélules, cœur, lecteur...).
class _CatGlyphPainter extends CustomPainter {
  final _CatKind kind;
  const _CatGlyphPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ux = w / 30.0, uy = h / 26.0;
    Offset P(double x, double y) => Offset(x * ux, y * uy);
    RRect RR(double x, double y, double w2, double h2, double r) =>
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x * ux, y * uy, w2 * ux, h2 * uy),
            Radius.circular(r * ux));
    void capsule(double cx, double cy, Color half) {
      canvas.save();
      canvas.translate(P(cx, cy).dx, P(cx, cy).dy);
      canvas.rotate(-0.6);
      final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 20 * ux, height: 9 * uy),
          Radius.circular(4.5 * ux));
      canvas.drawRRect(body, Paint()..color = const Color(0xFFF2F7F4));
      canvas.save();
      canvas.clipRect(Rect.fromCenter(
          center: Offset(-5 * ux, 0), width: 10 * ux, height: 20 * uy));
      canvas.drawRRect(body, Paint()..color = half);
      canvas.restore();
      canvas.drawRRect(
          body,
          Paint()
            ..color = const Color(0xFF0B2418).withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.restore();
    }

    switch (kind) {
      case _CatKind.capsuleGreen:
        capsule(15, 13, const Color(0xFF2FB563));
      case _CatKind.capsuleRed:
        capsule(15, 13, const Color(0xFFE0557C));
      case _CatKind.heart:
        final heart = Path()
          ..moveTo(P(15, 22).dx, P(15, 22).dy)
          ..cubicTo(P(4, 14).dx, P(4, 14).dy, P(6, 4).dx, P(6, 4).dy,
              P(10, 3).dx, P(10, 3).dy)
          ..cubicTo(P(10, 3).dx, P(10, 3).dy, P(15, 8).dx, P(15, 8).dy,
              P(20, 3).dx, P(20, 3).dy)
          ..cubicTo(P(20, 3).dx, P(20, 3).dy, P(24, 3).dx, P(24, 3).dy,
              P(26, 4).dx, P(26, 4).dy)
          ..cubicTo(P(26, 4).dx, P(26, 4).dy, P(26, 14).dx, P(26, 14).dy,
              P(15, 22).dx, P(15, 22).dy)
          ..close();
        canvas.drawPath(heart, Paint()..color = const Color(0xFFE23B4E));
        canvas.drawCircle(P(10, 9), 2 * ux,
            Paint()..color = Colors.white.withValues(alpha: 0.45));
      case _CatKind.glucometer:
        canvas.drawRRect(
            RR(8, 2, 14, 22, 4), Paint()..color = const Color(0xFF5B8FD9));
        canvas.drawRRect(
            RR(10.5, 5, 9, 7, 1.5), Paint()..color = const Color(0xFFDFF1FF));
        canvas.drawRRect(RR(11, 14.5, 8, 2.2, 1),
            Paint()..color = const Color(0xFF2E4A66));
        canvas.drawRRect(RR(11, 18, 8, 2.2, 1),
            Paint()..color = const Color(0xFF2E4A66));
      case _CatKind.vitamins:
        canvas.drawRRect(RR(10, 3, 10, 5, 1.5),
            Paint()..color = const Color(0xFFC98A1B));
        canvas.drawRRect(
            RR(8, 8, 14, 15, 3), Paint()..color = const Color(0xFFF0B429));
        canvas.drawRRect(RR(8, 12, 14, 6, 1),
            Paint()..color = const Color(0xFFFDF4E0));
        canvas.drawCircle(
            P(15, 15), 2 * ux, Paint()..color = const Color(0xFFC98A1B));
      case _CatKind.lungs:
        canvas.drawRRect(RR(13.4, 2, 3.2, 8, 1.5),
            Paint()..color = const Color(0xFFE8B4B4));
        final left = Path()
          ..moveTo(P(13, 10).dx, P(13, 10).dy)
          ..cubicTo(P(4, 12).dx, P(4, 12).dy, P(4, 22).dx, P(4, 22).dy,
              P(6, 24).dx, P(6, 24).dy)
          ..quadraticBezierTo(
              P(6, 24).dx, P(6, 24).dy, P(13, 23).dx, P(13, 23).dy)
          ..close();
        final right = Path()
          ..moveTo(P(17, 10).dx, P(17, 10).dy)
          ..cubicTo(P(26, 12).dx, P(26, 12).dy, P(26, 22).dx, P(26, 22).dy,
              P(24, 24).dx, P(24, 24).dy)
          ..quadraticBezierTo(
              P(24, 24).dx, P(24, 24).dy, P(17, 23).dx, P(17, 23).dy)
          ..close();
        canvas.drawPath(left, Paint()..color = const Color(0xFFE88C9C));
        canvas.drawPath(right, Paint()..color = const Color(0xFFE88C9C));
      case _CatKind.stomach:
        final stomach = Path()
          ..moveTo(P(9, 3).dx, P(9, 3).dy)
          ..cubicTo(P(9, 10).dx, P(9, 10).dy, P(12, 12).dx, P(17, 12).dy,
              P(24, 12).dx, P(24, 12).dy)
          ..cubicTo(P(24, 12).dx, P(24, 12).dy, P(25, 18).dx, P(22, 22).dy,
              P(19, 25).dx, P(19, 25).dy)
          ..cubicTo(P(19, 25).dx, P(19, 25).dy, P(11, 24).dx, P(9, 20).dy,
              P(12, 20).dx, P(12, 20).dy)
          ..cubicTo(P(12, 20).dx, P(12, 20).dy, P(16, 19).dx, P(16, 15).dy,
              P(11, 13).dx, P(11, 13).dy)
          ..cubicTo(P(11, 13).dx, P(11, 13).dy, P(6, 10).dx, P(9, 3).dy,
              P(9, 3).dx, P(9, 3).dy)
          ..close();
        canvas.drawPath(stomach, Paint()..color = const Color(0xFFF08A4B));
      case _CatKind.dots:
        for (final x in const [8.0, 15.0, 22.0]) {
          canvas.drawCircle(P(x, 13), 2.6 * ux,
              Paint()..color = Colors.white.withValues(alpha: 0.85));
        }
    }
  }

  @override
  bool shouldRepaint(covariant _CatGlyphPainter old) => old.kind != kind;
}















