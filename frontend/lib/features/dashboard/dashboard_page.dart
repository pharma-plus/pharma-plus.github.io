import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/app_guards.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/pharma_logo.dart';
import '../accounting/accounting_page.dart';
import '../ai/ai_page.dart';
import '../attendance/attendance_page.dart';
import '../cameras/cameras_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../modules/modules_page.dart';
import '../notifications/notifications_page.dart';
import '../pos/pos_page.dart';
import '../prescriptions/prescriptions_page.dart';
import '../reference/reference_page.dart';
import '../audit/audit_page.dart';
import '../returns/returns_page.dart';
import '../scanner/scanner_page.dart';
import '../shell/shell_nav.dart';
import '../stock/stock_page.dart';
import '../website/website_page.dart';
import 'pos_panel.dart';
import 'global_search.dart';

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
    final result = await ApiClient.instance.get('/dashboard/overview');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message ?? 'Erreur';
      });
      return;
    }
    setState(() {
      final d = result.data;
      _data = d is Map<String, dynamic> ? d : (d is Map ? Map<String, dynamic>.from(d) : null);
      _loading = false;
    });
    _loadNotificationCount();
    _loadStockAlerts();
  }

  /// Alertes stock : produits réellement en stock faible / expirant /
  /// expirés (API /stock/alerts). Aucun produit fictif affiché.
  Future<void> _loadStockAlerts() async {
    final r = await ApiClient.instance.get('/stock/alerts');
    if (!mounted || !r.success || r.data == null) return;
    List<Map<String, dynamic>> listOf(dynamic v) =>
        (v is List ? v : const []).whereType<Map<String, dynamic>>().toList();
    final d = r.data;
    if (d is Map) {
      setState(() {
        _lowStockRows = listOf(d['low_stock']);
        _expiringRows = listOf(d['expiring']);
        _expiredRows = listOf(d['expired']);
      });
    } else {
      setState(() {
        _lowStockRows = listOf(d);
        _expiringRows = [];
        _expiredRows = [];
      });
    }
  }

  /// Badge de notifications : valeur réelle depuis l'API (aucun chiffre
  /// codé en dur). Silencieux en cas d'échec (badge = 0).
  Future<void> _loadNotificationCount() async {
    final r = await ApiClient.instance.get('/notifications');
    if (!mounted || !r.success) return;
    final d = r.data;
    final meta = (d is Map) ? d['meta'] : null;
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

  Future<void> _onLogout() async {
    // Déconnexion RÉELLE avec confirmation humaine (jamais par accident).
    if (await confirmSignOut(context)) {
      if (!mounted) return;
      await context.read<AuthStore>().signOut();
    }
  }

  void _onMenuSelect(int index) {
    // Navigation via ShellNav (IndexedStack) au lieu de push : évite les
    // doublons de pages (2× requêtes API, pile Navigator qui grossit).
    switch (index) {
      case 1:
        ShellNav.index.value = 2; // POS
      case 2:
        ShellNav.index.value = 3; // Catalogue
      case 3:
        ShellNav.index.value = 4; // Stock
      case 4:
        ShellNav.index.value = 5; // Fournisseurs
      case 5:
        ShellNav.index.value = 6; // Achats
      case 6:
        ShellNav.index.value = 7; // Clients
      case 7:
        ShellNav.index.value = 8; // Employés
      case 8:
        ShellNav.index.value = 9; // Rapports
      case 9:
        ShellNav.index.value = 10; // Plan pharmacie
      case 10:
        _push(const CamerasPage()); // hors shell (pas d'onglet dédié)
      case 11:
        _push(const ScannerPage()); // hors shell
      case 12:
        ShellNav.index.value = 11; // Tableau de contrôle
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
        // Focus(autofocus) : gère son propre FocusNode (auto-disposé) —
        // l'ancien FocusNode()..requestFocus() fuyait à chaque ouverture.
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(ctx).pop(); // ESC → fermeture
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
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
        return () => ShellNav.index.value = 2; // ventes du jour → POS
      case 1:
        return () => ShellNav.index.value = 3; // catalogue
      case 2:
        // Filtre « stock bas » → paramètre : push conservé (volontaire).
        return () => _push(const StockPage(initialFilter: 'low'));
      case 3:
        return () => ShellNav.index.value = 6; // achats
      case 4:
        return () => ShellNav.index.value = 5; // fournisseurs
      case 5:
        return () => ShellNav.index.value = 7; // clients
      case 6:
        return () => ShellNav.index.value = 8; // employés
      default:
        return () => ShellNav.index.value = 9; // rapports
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
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
                  onScan: () => _push(const ScannerPage()),
                  onNotifications: () => _push(const NotificationsPage()),
                  onSettings: () => ShellNav.index.value = 11,
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
                      onPrefilled: (items, discount, isPercent, received) =>
                          _push(PosPage(initialItems: items,
                              initialDiscount: discount,
                              initialDiscountIsPercent: isPercent,
                              initialReceived: received)),
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
          image: 'assets/images/kpi_bg_1.webp',
          badge: Icons.point_of_sale_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'MÉDICAMENTS',
          value: Fmt.number(_medications),
          sub: 'Références actives',
          image: 'assets/images/kpi_bg_2.webp',
          badge: Icons.medication_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'STOCK FAIBLE',
          value: '$_lowStock',
          sub: 'Produits',
          image: 'assets/images/kpi_bg_3.webp',
          badge: Icons.warning_amber_rounded,
          badgeColor: amber),
      _KpiDef(
          label: 'COMMANDES',
          value: '$_pendingOrders',
          sub: 'En attente',
          image: 'assets/images/kpi_bg_4.webp',
          badge: Icons.fact_check_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'FOURNISSEURS',
          value: Fmt.number(_suppliers),
          sub: 'Fournisseurs',
          image: 'assets/images/kpi_bg_5.webp',
          badge: Icons.local_shipping_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'CLIENTS',
          value: Fmt.number(_customers),
          sub: 'Clients',
          image: 'assets/images/kpi_bg_6.webp',
          badge: Icons.groups_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'EMPLOYÉS',
          value: '$_employees',
          sub: 'Employés',
          image: 'assets/images/kpi_bg_7.webp',
          badge: Icons.person_rounded,
          badgeColor: green),
      _KpiDef(
          label: 'BÉNÉFICE MOIS',
          value: Fmt.money(_profitMonth),
          trendPct: pct(_trendProfitMonth),
          trendVs: 'vs mois dernier',
          image: 'assets/images/kpi_bg_8.webp',
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
      childAspectRatio: compact ? 1.20 : 1.05,
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
  /// Fond photo extrait de la maquette (assets/images/kpi_bg_N.png) :
  /// dégradé du carton + cadre + illustration 3D sur socle, textes de la
  /// maquette effacés — l'app dessine les valeurs réelles par-dessus.
  final String image;
  final IconData badge;
  final Color badgeColor;
  const _KpiDef({
    required this.label,
    required this.value,
    this.sub = '',
    this.trendPct,
    this.trendVs = '',
    required this.image,
    required this.badge,
    required this.badgeColor,
  });
}

/// Carte KPI maquette : titre vert numéroté · badge d'option en haut à
/// droite (chaque image a son icône) · grande valeur · sous-titre ·
/// tendance verte · illustration 3D sur podium lumineux en bas à droite.
/// Animations RÉELLES codées : survol → élévation + liseré or lumineux ;
/// pression → léger retrait (feedback immédiat).
class _KpiCard extends StatefulWidget {
  final int index;
  final _KpiDef def;
  final VoidCallback? onTap;
  const _KpiCard({
    super.key,
    required this.index,
    required this.def,
    this.onTap,
  });
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;
  bool _press = false;
  static const _titleGreen = Color(0xFF43D97C);

  _KpiDef get def => widget.def;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapCancel: () => setState(() => _press = false),
        onTapUp: (_) => setState(() => _press = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _press ? 0.97 : (_hover ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _hover
                      ? const Color(0xFFC9A24B).withValues(alpha: 0.85)
                      : AppColors.goldBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
                if (_hover)
                  BoxShadow(
                      color: const Color(0xFF00C96B).withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
              ],
              // Fond photo : visuel EXACT de la maquette (dégradé du carton,
              // cadre intérieur, illustration 3D sur socle lumineux). Les
              // textes dynamiques (titre/valeur/tendance) sont superposés
              // dans la zone claire en haut à gauche, comme sur la maquette.
              image: DecorationImage(
                image: AssetImage(def.image),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // CONTENU TEXTE — aligné sur la maquette : titre + badge en haut,
            // valeur/sous-titre/tendance dans la moitié haute ; les
            // illustrations de fond vivent en bas à droite du carton.
            child: LayoutBuilder(builder: (context, box) {
              final pr = (box.maxWidth * 0.30).clamp(26.0, 92.0);
              return Padding(
                padding: EdgeInsets.fromLTRB(14, 11, pr, 10),
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
                      const SizedBox(height: 10),
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
                      const Spacer(),
                    ],
                  ),
                );
            }),
          ),
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
    (Icons.settings_outlined, 'Tableau de contrôle'),
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
    (Icons.fact_check_outlined, 'Audit', 'Inventaire et caisse', AuditPage()),
    (Icons.keyboard_return_rounded, 'Retours', 'Retours produits', ReturnsPage()),
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
  final VoidCallback onScan;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final int notificationCount;
  const _TopBar({
    this.onMenu,
    this.collapsed = false,
    this.onToggleSidebar,
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
            child: GlobalSearchField(onScan: onScan),
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
              // MÊME modèle 3D que la page "Plan 3D" (PlanPainter +
              // mêmes zones) : aperçu du plan complet, pas un modèle
              // différent. Tap = ouverture de la page Plan 3D.
              child: Plan3DPreview(onZoneTap: (_) => widget.onOpen()),
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

  /// Paiement validé dans l'encart : [received] = montant reçu réel
  /// (le POS complet encaisse directement, sans seconde saisie).
  final void Function(
          List<Medication> items, double discount, bool isPercent, double received)?
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
