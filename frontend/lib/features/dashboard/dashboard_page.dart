import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
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
import '../scanner/scanner_page.dart';
import '../settings/settings_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../website/website_page.dart';
import 'kpi_art.dart';
import 'pos_panel.dart';

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

  // ---- Sidebar rétractable (desktop) ------------------------------------
  // Préférence persistée : la sidebar réduite n'affiche que les icônes
  // (tooltip au survol) et le contenu central récupère l'espace libéré.
  static const _kSidebarPref = 'pmg_dashboard_sidebar_collapsed';
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSidebarPref();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _sidebarCollapsed = prefs.getBool(_kSidebarPref) ?? false);
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarCollapsed;
    setState(() => _sidebarCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarPref, next);
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
    _loadNotificationCount();
    _loadStockAlerts();
  }

  /// Alertes stock : produits réellement en stock faible / expirant /
  /// expirés (API /stock/alerts). Aucun produit fictif affiché.
  Future<void> _loadStockAlerts() async {
    final r =
        await ApiClient.instance.get<Map<String, dynamic>>('/stock/alerts');
    if (!mounted || !r.success || r.data == null) return;
    List<Map<String, dynamic>> listOf(dynamic v) =>
        (v as List? ?? const []).whereType<Map<String, dynamic>>().toList();
    setState(() {
      _lowStockRows = listOf(r.data!['low_stock']);
      _expiringRows = listOf(r.data!['expiring']);
      _expiredRows = listOf(r.data!['expired']);
    });
  }

  /// Badge de notifications : valeur réelle depuis l'API (aucun chiffre
  /// codé en dur). Silencieux en cas d'échec (badge = 0).
  Future<void> _loadNotificationCount() async {
    final r =
        await ApiClient.instance.get<Map<String, dynamic>>('/notifications');
    if (!mounted || !r.success) return;
    final meta = r.data?['meta'];
    final unread = meta is Map ? meta['unread'] : null;
    setState(() => _notificationCount = _int(unread ?? 0));
  }

  // ============================================================
  // DONNÉES 100 % RÉELLES — aucune valeur de repli : si la base
  // est vide, l'indicateur vaut 0. Les pourcentages de tendance
  // sont calculés depuis les comparatifs renvoyés par l'API.
  // ============================================================
  double _num(dynamic v) => v == null ? 0 : (num.tryParse('$v') ?? 0).toDouble();
  int _int(dynamic v) => v == null ? 0 : (int.tryParse('$v') ?? num.tryParse('$v')?.round() ?? 0);

  double get _revenueToday => _num(_flat0(_data, 'revenue', 'revenue_today'));
  double get _revenueYesterday =>
      _num(_flat0(_data, 'revenue', 'revenue_yesterday'));
  double get _revenueMonth => _num(_flat0(_data, 'revenue', 'revenue_month'));
  double get _revenueLastMonth =>
      _num(_flat0(_data, 'revenue', 'revenue_last_month'));
  double get _profitMonth => _num(_flat0(_data, 'revenue', 'profit_month'));
  double get _profitLastMonth =>
      _num(_flat0(_data, 'revenue', 'profit_last_month'));
  int get _medications => _int(_nested(_data, 'counts', 'medications', 'total'));
  int get _lowStock => _int(_flat0(_data, 'alerts', 'low_stock'));
  int get _expiring => _int(_flat0(_data, 'alerts', 'expiring'));
  int get _expired => _int(_flat0(_data, 'alerts', 'expired'));
  int get _pendingOrders => _int(_flat0(_data, 'alerts', 'pending_orders'));
  int get _suppliers => _int(_nested(_data, 'counts', 'suppliers', 'total'));
  int get _customers => _int(_nested(_data, 'counts', 'customers', 'total'));
  int get _employees => _int(_top0(_data, 'employees_present'));

  /// Tendances réelles (% de variation vs période précédente) —
  /// null = pas de comparaison possible → aucune invention affichée.
  double? get _trendRevenueToday =>
      periodVariation(_revenueToday, _revenueYesterday);
  double? get _trendRevenueMonth =>
      periodVariation(_revenueMonth, _revenueLastMonth);
  double? get _trendProfitMonth =>
      periodVariation(_profitMonth, _profitLastMonth);

  int _notificationCount = 0;

  /// Alertes stock RÉELLES (listes renvoyées par /stock/alerts).
  List<Map<String, dynamic>> _lowStockRows = [];
  List<Map<String, dynamic>> _expiringRows = [];
  List<Map<String, dynamic>> _expiredRows = [];

  static dynamic _flat0(
    Map<String, dynamic>? map,
    String section,
    String key,
  ) =>
      _nested(map, section, key);

  static dynamic _top0(Map<String, dynamic>? map, String key) =>
      map == null ? null : map[key];

  static dynamic _nested(
    Map<String, dynamic>? map,
    String a,
    String b,
    [String? c,
  ]) {
    if (map == null) return null;
    final section = map[a];
    if (section is! Map) return null;
    if (c == null) return section[b];
    final inner = section[b];
    return inner is Map ? inner[c] : null;
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
        _push(const ScannerPage());
      case 12:
        _push(const SettingsPage());
    }
  }

  /// Menu latéral rétractable (tablettes / mobiles) : overlay plein écran,
  /// fermeture par ESC, par clic extérieur et à chaque navigation.
  void _openMenuDrawer() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true, // clic HORS du menu → fermeture
      builder: (ctx) {
        return KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (event) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(ctx).pop(); // ESC → fermeture
            }
          },
          child: Dialog(
            alignment: Alignment.centerLeft,
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: SizedBox(
              width: 250,
              child: _Sidebar(
                onSelect: (index) {
                  Navigator.of(ctx).pop(); // navigation → referme le menu
                  _onMenuSelect(index);
                },
                onLogout: () {
                  Navigator.of(ctx).pop();
                  _onLogout();
                },
                onMoreModules: () {
                  Navigator.of(ctx).pop();
                  _showModulesMenu();
                },
              ),
            ),
          ),
        );
      },
    );
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
        return () => _push(const PosPage()); // ventes du jour → POS
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
        final w = constraints.maxWidth;
        // Large POS latéral uniquement sur les grands écrans ; en dessous,
        // le POS complet reste accessible via le panneau réduit et les menus.
        final showPosPanel = w >= 1300;
        final posWidth = w >= 1560 ? 430.0 : 385.0;
        // Sidebar fixe sur desktop ; hamburger + overlay sur écrans réduits.
        final showSidebar = w >= 1150;
        // Écrans bas (1366×768, 1536×864...) : proportions compactes pour
        // que TOUT le dashboard (KPI, alertes, plan 3D, barre basse) reste
        // entièrement visible, sans carte ni cellule coupée.
        final vh = MediaQuery.of(context).size.height;
        final compact = vh < 900;
        return Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (showSidebar) ...[
              // Sidebar RÉTRACTABLE : 232px ouverte · 64px réduite (icônes
              // seules + tooltips) · animation fluide · préférence persistée.
              // Le contenu central (dashboard + POS) récupère l'espace libéré.
              AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: _sidebarCollapsed ? 64 : 232,
                  child: _Sidebar(
                      collapsed: _sidebarCollapsed,
                      onToggleCollapse: _toggleSidebar,
                      onSelect: _onMenuSelect,
                      onLogout: _onLogout,
                      onMoreModules: _showModulesMenu)),
              Container(width: 1, color: AppColors.dividerDark),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _TopBar(
                  onMenu: showSidebar ? null : _openMenuDrawer,
                  collapsed: _sidebarCollapsed,
                  onToggleSidebar: _toggleSidebar,
                  onSearch: () => _push(const CatalogPage()),
                  onScan: () => _push(const ScannerPage()),
                  onNotifications: () => _push(const NotificationsPage()),
                  onSettings: () => _push(const SettingsPage()),
                  onLogout: _onLogout,
                  notificationCount: _notificationCount,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, compact ? 8 : 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKpiGrid(compact: compact),
                          SizedBox(height: compact ? 10 : 12),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _AlertsStockPanel(
                                    lowStock: _lowStock,
                                    expiring: _expiring,
                                    lowStockRows: _lowStockRows,
                                    expiringRows: _expiringRows,
                                    expiredRows: _expiredRows,
                                    onViewAll: () => _push(
                                        const StockPage(initialFilter: 'low')),
                                    compact: compact,
                                  ),
                                ),
                                SizedBox(width: compact ? 10 : 12),
                                Expanded(
                                  flex: 7,
                                  child: _Plan3DPanel(
                                      onOpen: () =>
                                          _push(const PharmacyPlanPage()),
                                      compact: compact),
                                ),
                              ]),
                          SizedBox(height: compact ? 10 : 12),
                          _BottomBar(
                            revenueToday: _revenueToday,
                            revenueMonth: _revenueMonth,
                            profitMonth: _profitMonth,
                            expiring: _expiring,
                            expired: _expired,
                            lowStock: _lowStock,
                            trendToday: _trendRevenueToday == null
                                ? null
                                : '${_trendRevenueToday! >= 0 ? '+' : ''}${_trendRevenueToday!.toStringAsFixed(1)}%',
                            trendMonth: _trendRevenueMonth == null
                                ? null
                                : '${_trendRevenueMonth! >= 0 ? '+' : ''}${_trendRevenueMonth!.toStringAsFixed(1)}%',
                            trendProfit: _trendProfitMonth == null
                                ? null
                                : '${_trendProfitMonth! >= 0 ? '+' : ''}${_trendProfitMonth!.toStringAsFixed(1)}%',
                            compact: compact,
                          ),
                        ]),
                  ),
                ),
              ]),
            ),
            if (showPosPanel) ...[
              Container(width: 1, color: AppColors.dividerDark),
              SizedBox(
                  width: posWidth,
                  child: _PosPanel(
                      onCheckout: () => _push(const PosPage()),
                      onPrefilled: (items, discount, isPercent) => _push(
                          PosPage(initialItems: items,
                              initialDiscount: discount,
                              initialDiscountIsPercent: isPercent)),
                      compact: compact)),
            ],
          ]),
        ]);
      }),
    );
  }

  Widget _buildKpiGrid({required bool compact}) {
    const green = Color(0xFF43D97C);
    const amber = Color(0xFFFFA24A);
    // Tendance affichée UNIQUEMENT si un comparatif réel existe.
    String? pct(double? v) =>
        v == null ? null : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';
    final kpis = <_KpiDef>[
      _KpiDef(
          label: 'VENTES DU JOUR',
          value: Fmt.money(_revenueToday),
          trendPct: pct(_trendRevenueToday),
          trendVs: 'vs hier',
          art: KpiArt.register,
          badge: Icons.point_of_sale_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'MÉDICAMENTS',
          value: Fmt.number(_medications),
          sub: 'Références actives',
          art: KpiArt.bottle,
          badge: Icons.medication_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'STOCK FAIBLE',
          value: '$_lowStock',
          sub: 'Produits',
          art: KpiArt.boxes,
          badge: Icons.warning_amber_rounded,
          badgeColor: amber),
      _KpiDef(
          label: 'COMMANDES',
          value: '$_pendingOrders',
          sub: 'En attente',
          art: KpiArt.clipboard,
          badge: Icons.fact_check_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'FOURNISSEURS',
          value: Fmt.number(_suppliers),
          sub: 'Fournisseurs',
          art: KpiArt.truck,
          badge: Icons.local_shipping_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'CLIENTS',
          value: Fmt.number(_customers),
          sub: 'Clients',
          art: KpiArt.people,
          badge: Icons.groups_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'EMPLOYÉS',
          value: '$_employees',
          sub: 'Employés',
          art: KpiArt.pharmacist,
          badge: Icons.person_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'BÉNÉFICE MOIS',
          value: Fmt.money(_profitMonth),
          trendPct: pct(_trendProfitMonth),
          trendVs: 'vs mois dernier',
          art: KpiArt.bars,
          badge: Icons.bar_chart_rounded,
          badgeColor: green),
    ];
    // 4 colonnes sur desktop ; 2 sur les écrans étroits (lisible partout).
    final cols = MediaQuery.of(context).size.width >= 980 ? 4 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: compact ? 10 : 12,
      mainAxisSpacing: compact ? 10 : 12,
      childAspectRatio: compact ? 1.60 : 1.45,
      children: [
        for (var i = 0; i < kpis.length; i++)
          _KpiCard(
            key: ValueKey('kpi-$i'),
            index: i + 1,
            def: kpis[i],
            onTap: _kpiTap(i),
          ),
      ],
    );
  }
}

/// Définition d'une carte KPI : badge, sous-titre et tendance RÉELLE
/// (null = pas de comparaison disponible → rien n'est inventé).
class _KpiDef {
  final String label;
  final String value;
  final String sub;
  final String? trendPct;
  final String trendVs;
  final KpiArt art;
  final IconData badge;
  final Color badgeColor;
  const _KpiDef({
    required this.label,
    required this.value,
    this.sub = '',
    this.trendPct,
    this.trendVs = '',
    required this.art,
    required this.badge,
    required this.badgeColor,
  });
}

/// Carte KPI maquette : titre vert numéroté · badge d'option en haut à
/// droite (chaque image a son icône) · grande valeur · sous-titre ·
/// tendance verte · illustration 3D sur socle en bas à droite.
class _KpiCard extends StatelessWidget {
  final int index;
  final _KpiDef def;
  final VoidCallback? onTap;
  const _KpiCard({
    super.key,
    required this.index,
    required this.def,
    this.onTap,
  });

  static const _titleGreen = Color(0xFF43D97C);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: LayoutBuilder(builder: (context, box) {
            // ENCART VISUEL : l'illustration (transparence totale, aucun
            // arrière-plan) vit dans sa propre zone en bas à droite.
            // Elle ne passe JAMAIS derrière le titre, la valeur ou les
            // textes : la colonne de texte est réservée à gauche.
            final artW = (box.maxWidth * 0.42).clamp(84.0, 180.0);
            final artH = artW * 80.0 / 100.0;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Illustration transparente — encart dédié, indépendant
                // du fond de la carte (pas d'image de fond, pas d'overlay).
                Positioned(
                  bottom: 6,
                  right: 8,
                  width: artW,
                  height: artH,
                  child: RepaintBoundary(
                    child: CustomPaint(painter: KpiArtPainter(def.art)),
                  ),
                ),
                // CONTENU TEXTE — zone protégée, jamais recouverte.
                Padding(
                  padding: EdgeInsets.only(right: artW * 0.42),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre vert numéroté + badge
                      Row(children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('$index. ${def.label}',
                                maxLines: 1,
                                style: const TextStyle(
                                    color: _titleGreen,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1D13),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2A4A38)),
                          ),
                          child: Icon(def.badge, size: 14, color: def.badgeColor),
                        ),
                      ]),
                      const Spacer(),
                      // Valeur
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(def.value,
                            maxLines: 1,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ),
                      if (def.sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(def.sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 4),
                      // Tendance réelle uniquement (sinon rien d'inventé).
                      if (def.trendPct != null) ...[
                        Text(def.trendPct!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _titleGreen,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                        Text(def.trendVs,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
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

  /// true = rail réduit (icônes seules + tooltips) ; le bouton de la
  /// TopBar (chevron) et ce mode sont pilotés par l'état du dashboard.
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  const _Sidebar({
    required this.onSelect,
    required this.onLogout,
    required this.onMoreModules,
    this.collapsed = false,
    this.onToggleCollapse,
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
    // Mode RÉDUIT : rail d'icônes (64px) avec tooltips au survol.
    if (widget.collapsed) return _buildCollapsed(context);
    return _buildExpanded(context);
  }

  /// Rail réduit : logo compact, icônes seules (tooltip au survol),
  /// accès déconnexion conservé — aucun grand espace vide.
  Widget _buildCollapsed(BuildContext context) {
    return Container(
      color: AppColors.surfaceSidebar,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.dividerDark.withValues(alpha: 0.7)))),
          child: const Center(child: PharmaPlusLogo(size: 30)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final active = i == 0;
              final (icon, label) = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Center(
                  child: Tooltip(
                    message: label,
                    waitDuration: const Duration(milliseconds: 300),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onSelect(i),
                      child: Container(
                        width: 44,
                        height: 40,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF07271C) : null,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active
                                  ? const Color(0xFFC9A24B)
                                      .withValues(alpha: 0.55)
                                  : Colors.transparent),
                        ),
                        child: Icon(icon,
                            size: 20,
                            color: active
                                ? Colors.white
                                : const Color(0xFFC9A24B)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Autres modules (rail) — même action qu'en mode étendu.
        Center(
          child: Tooltip(
            message: 'Autres modules',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onMoreModules,
              child: Container(
                width: 44,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFF07271C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            const Color(0xFFC9A24B).withValues(alpha: 0.55))),
                child: const Icon(Icons.apps_rounded, color: _gold, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Déconnexion (rail).
        Center(
          child: Tooltip(
            message: 'Se déconnecter',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onLogout,
              child: Container(
                width: 44,
                height: 40,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08))),
                child: const Icon(Icons.logout, color: _gold, size: 18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildExpanded(BuildContext context) {
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
            Expanded(
              child: Builder(builder: (context) {
                // Identité RÉELLE de la session (aucun nom inventé) :
                // nom affiché = prénom + nom, rôle et pharmacie renvoyés
                // par l'API de connexion.
                final user = context.watch<AuthStore>().user;
                final role = user?.roleName;
                final pharmacy = user?.pharmacyName;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          (user?.fullName.trim().isNotEmpty ?? false)
                              ? user!.fullName
                              : 'Admin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      if (role != null && role.isNotEmpty)
                        Text(role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5)),
                      if (pharmacy != null && pharmacy.isNotEmpty)
                        Text(pharmacy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.emeraldLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                    ]);
              }),
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
/// TOP BAR — hamburger (écrans réduits) + recherche pleine
/// largeur + scan or + identité RÉELLE (pharmacie/utilisateur)
/// + notifications (badge réel) + réglages + sortie.
/// ============================================================
class _TopBar extends StatelessWidget {
  final VoidCallback? onMenu;

  /// Bouton « réduire/ouvrir la sidebar » (desktop) : icône dynamique
  /// chevron_left / chevron_right selon l'état actuel.
  final bool collapsed;
  final VoidCallback? onToggleSidebar;
  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final int notificationCount;
  const _TopBar({
    this.onMenu,
    this.collapsed = false,
    this.onToggleSidebar,
    required this.onSearch,
    required this.onScan,
    required this.onNotifications,
    required this.onSettings,
    required this.onLogout,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final pharmacyName =
        (user?.pharmacyName?.trim().isNotEmpty ?? false) ? user!.pharmacyName! : 'PHARMA+';
    final roleLabel = user?.roleName ?? 'Admin';
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
              bottom:
                  BorderSide(color: AppColors.dividerDark.withValues(alpha: 0.7)))),
      child: Row(children: [
        // ☰ — menu rétractable sur tablette/mobile (masqué sur desktop).
        if (onMenu != null) ...[
          InkWell(
            onTap: onMenu,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.menu, size: 26, color: _gold),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // ← / → — réduire ou rouvrir la sidebar (desktop) : le dashboard
        // et le POS récupèrent l'espace libéré en temps réel.
        if (onToggleSidebar != null) ...[
          Tooltip(
            message: collapsed ? 'Ouvrir le menu' : 'Réduire le menu',
            waitDuration: const Duration(milliseconds: 350),
            child: InkWell(
              onTap: onToggleSidebar,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 26,
                    color: _gold),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                  Flexible(
                    child: Text(pharmacyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: AppColors.textSecondary),
                ]),
                Text(roleLabel,
                    style: const TextStyle(
                        color: AppColors.emeraldLight,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ]),
        ),
        const SizedBox(width: 14),
        // Badge notifications : compteur RÉEL depuis l'API (0 = pas de badge).
        _TopIcon(
            icon: Icons.notifications_outlined,
            badge: notificationCount > 0 ? '$notificationCount' : null,
            onTap: onNotifications),
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
  final List<Map<String, dynamic>> lowStockRows;
  final List<Map<String, dynamic>> expiringRows;
  final List<Map<String, dynamic>> expiredRows;
  final VoidCallback onViewAll;
  final bool compact;
  const _AlertsStockPanel(
      {required this.lowStock,
      required this.expiring,
      required this.lowStockRows,
      required this.expiringRows,
      required this.expiredRows,
      required this.onViewAll,
      this.compact = false});

  /// Construit les lignes RÉELLES à partir de /stock/alerts :
  /// produits en stock faible, péremptions proches, produits expirés.
  List<(String, String, Color, IconData)> _buildRows() {
    String d(dynamic v) => '$v';
    final rows = <(String, String, Color, IconData)>[
      for (final m in lowStockRows.take(3))
        (
          d(m['name']),
          'Stock faible (${_fmtQty(m['available'])} / seuil ${_fmtQty(m['reorder_level'])})',
          const Color(0xFFF0A73B),
          Icons.priority_high_rounded
        ),
      for (final m in expiringRows.take(2))
        (
          d(m['name']),
          'Expire le ${_fmtDate(m['expiry_date'])}',
          const Color(0xFFF0A73B),
          Icons.hourglass_bottom_rounded
        ),
      for (final m in expiredRows.take(2))
        (d(m['name']), 'Produit expiré', AppColors.danger, Icons.close_rounded),
    ];
    return rows.take(5).toList();
  }

  static String _fmtQty(dynamic v) {
    final n = num.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);
  }

  static String _fmtDate(dynamic v) {
    final dt = DateTime.tryParse('$v');
    if (dt == null) return '?';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return _DarkPanel(
      title: 'ALERTES STOCK',
      icon: Icons.notifications_active_outlined,
      iconColor: const Color(0xFFF0A73B),
      child: Column(children: [
        if (rows.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 14 : 22),
            child: Column(children: [
              const Icon(Icons.verified_rounded,
                  size: 26, color: AppColors.emeraldLight),
              const SizedBox(height: 6),
              Text('Aucune alerte — stock et péremptions sains',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11)),
            ]),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            _AlertRow(
                name: rows[i].$1,
                detail: rows[i].$2,
                color: rows[i].$3,
                icon: rows[i].$4,
                compact: compact),
            if (i < rows.length - 1)
              SizedBox(height: compact ? 5 : 7),
          ],
        SizedBox(height: compact ? 9 : 12),
        SizedBox(
          width: double.infinity,
          height: compact ? 30 : 36,
          child: OutlinedButton(
            onPressed: onViewAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF0E2A1C),
              side: const BorderSide(color: AppColors.goldBorderStrong),
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
  final bool compact;
  const _AlertRow(
      {required this.name,
      required this.detail,
      required this.color,
      required this.icon,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 11, vertical: compact ? 6 : 9),
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
/// Boutons RÉELS : rotation et zoom s'appliquent à la scène
/// affichée ; « Vue 3D » / plein écran ouvrent la page complète.
/// ============================================================
class _Plan3DPanel extends StatefulWidget {
  final VoidCallback onOpen;
  final bool compact;
  const _Plan3DPanel({required this.onOpen, this.compact = false});
  @override
  State<_Plan3DPanel> createState() => _Plan3DPanelState();
}

class _Plan3DPanelState extends State<_Plan3DPanel> {
  double _rot = 0.0;
  double _zoom = 1.0;
  static const _legend = <(String, String)>[
    ('M', 'Médicaments'),
    ('O', 'Ordonnances'),
    ('S', 'Stock'),
    ('C', 'Caisse'),
  ];
  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      title: 'PLAN 3D DE LA PHARMACIE',
      icon: Icons.view_in_ar_outlined,
      iconColor: AppColors.emerald,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          // Hauteur adaptative : écrans bas => scène réduite mais complète
          // (le bas du dashboard reste entièrement visible, rien n'est masqué).
          height: widget.compact ? 152.0 : 236.0,
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
                // Glisser pour faire tourner la scène (interaction réelle).
                Positioned.fill(
                    child: GestureDetector(
                  onPanUpdate: (d) =>
                      setState(() => _rot += d.delta.dx * 0.008),
                  child: CustomPaint(painter: _IsoPainter(rot: _rot, zoom: _zoom)),
                )),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Column(children: [
                    _PlanBtn(
                        icon: Icons.view_in_ar_rounded,
                        label: 'Vue 3D',
                        onTap: widget.onOpen),
                    const SizedBox(height: 6),
                    _PlanBtn(
                        icon: Icons.rotate_right_rounded,
                        label: 'Tourner',
                        onTap: () => setState(() => _rot += 0.25)),
                    const SizedBox(height: 6),
                    _PlanBtn(
                        icon: Icons.add_rounded,
                        onTap: () => setState(
                            () => _zoom = math.min(1.8, _zoom * 1.15))),
                    const SizedBox(height: 6),
                    _PlanBtn(
                        icon: Icons.remove_rounded,
                        onTap: () =>
                            setState(() => _zoom = math.max(0.6, _zoom / 1.15))),
                    const SizedBox(height: 6),
                    _PlanBtn(
                        icon: Icons.fullscreen_rounded, onTap: widget.onOpen),
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
/// Supporte une rotation [rot] (radians) et un zoom [zoom] pilotés
/// par les boutons du panneau du dashboard.
class _IsoPainter extends CustomPainter {
  final double rot;
  final double zoom;
  // Pas de constructeur const : les champs de projection sont mutables.
  _IsoPainter({this.rot = 0.0, this.zoom = 1.0});
  late double ux, uy, uz, ox, oy;
  static const room = 12.0, wallH = 3.6;

  Offset P(double x, double y, double z) {
    // Rotation horizontale du plan avant projection isométrique.
    final cr = math.cos(rot), sr = math.sin(rot);
    final rx = x * cr - y * sr;
    final ry = x * sr + y * cr;
    return Offset(ox + (rx - ry) * ux * zoom,
        oy + (rx + ry) * uy * zoom - z * uz * zoom);
  }

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
    oy = h / 2 - room * uy * zoom + wallH * uz * zoom / 2 + u * 0.4;

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

    // Étiquette de prix verte sur tête de gondole (maquette).
    void priceTag(Offset c, String s) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final rect = Rect.fromCenter(center: c, width: tp.width + 14, height: 15);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xE60E7A44));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFF7BEBA4).withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      tp.paint(canvas, Offset(rect.left + 7, c.dy - tp.height / 2));
    }

    // Zones nommées de la maquette.
    chip(P(5.5, 0.75, 3.15), 'M', 'MÉDICAMENTS');
    chip(P(0.9, 8.8, 3.05), 'O', 'ORDONNANCES');
    chip(P(10.6, 0.9, 3.05), 'S', 'STOCK');
    chip(P(7.0, 10.4, 1.95), 'C', 'CAISSE');
    // Étiquettes de prix vertes sur les têtes de gondoles (maquette).
    priceTag(P(10.15, 5.25, 1.75), 'PARACÉTAMOL 23,50 DHS');
    priceTag(P(10.15, 7.75, 1.75), 'DOLIPRANE 15,80 DHS');
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
  final int expired;
  final int lowStock;
  final String? trendToday;
  final String? trendMonth;
  final String? trendProfit;
  final bool compact;
  const _BottomBar({
    required this.revenueToday,
    required this.revenueMonth,
    required this.profitMonth,
    required this.expiring,
    required this.expired,
    required this.lowStock,
    this.trendToday,
    this.trendMonth,
    this.trendProfit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE9C873);
    return Row(children: [
      Expanded(
          child: _BottomStat(
              label: "VENTES AUJOURD'HUI",
              value: Fmt.money(revenueToday),
              trend: trendToday,
              curve: trendToday != null,
              compact: compact)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'VENTES MOIS',
              value: Fmt.money(revenueMonth),
              trend: trendMonth,
              curve: trendMonth != null,
              compact: compact)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'BÉNÉFICE MOIS',
              value: Fmt.money(profitMonth),
              trend: trendProfit,
              curve: trendProfit != null,
              compact: compact)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'PRODUITS EXPIRÉS',
              value: '$expired',
              subtitle: 'Produits',
              valueColor: const Color(0xFFF0A73B),
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF0A73B),
              compact: compact)),
      const SizedBox(width: 8),
      Expanded(
          child: _BottomStat(
              label: 'STOCK FAIBLE',
              value: '$lowStock',
              subtitle: 'Produits',
              icon: Icons.warning_amber_rounded,
              iconColor: gold,
              compact: compact)),
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
  final bool compact;
  const _BottomStat({
    required this.label,
    required this.value,
    this.trend,
    this.subtitle,
    this.valueColor = Colors.white,
    this.curve = false,
    this.icon,
    this.iconColor,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 52 : 64,
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
/// POINT DE VENTE (colonne droite) — délègue au VRAI mini-POS
/// (`pos_panel.dart`) : recherche API réelle, panier, remise,
/// totaux centralisés, suspendre/reprendre, paiement → POS.
/// ============================================================
class _PosPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  final void Function(List<Medication> items, double discount, bool isPercent)?
      onPrefilled;
  final bool compact;
  const _PosPanel(
      {required this.onCheckout, this.onPrefilled, this.compact = false});

  @override
  Widget build(BuildContext context) => PosPanel(
        onCheckout: onCheckout,
        onPrefilled: onPrefilled,
        compact: compact,
      );
}
