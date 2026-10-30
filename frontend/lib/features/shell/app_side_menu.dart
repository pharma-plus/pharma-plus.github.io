import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_logo.dart';
import '../accounting/accounting_page.dart';
import '../ai/ai_page.dart';
import '../attendance/attendance_page.dart';
import '../audit/audit_page.dart';
import '../cameras/cameras_page.dart';
import '../doctors/doctor_page.dart';
import '../invoices/invoices_page.dart';
import '../modules/modules_page.dart';
import '../notifications/notifications_page.dart';
import '../prescriptions/prescriptions_page.dart';
import '../reference/reference_page.dart';
import '../returns/returns_page.dart';
import '../scanner/scanner_page.dart';
import '../shell/shell_nav.dart';
import '../website/website_page.dart';

/// ============================================================
/// MENU LATÉRAL PHARMA+ — extrait du dashboard pour être partagé.
///
/// Rendu par [HomeShell] (desktop ≥1150 px) : le menu est FIXE pendant
/// que le contenu de chaque page (ex. tableau Stock) défile
/// indépendamment à droite. Le dashboard l'utilisait déjà seul ; le
/// code est désormais unique (une seule source de vérité).
///
/// NAVIGATION DYNAMIQUE : les entrées sont filtrées selon les
/// permissions de l'utilisateur connecté. Cacher un bouton ne suffit
/// pas : le backend refuse aussi la requête (enforcePathPermission,
/// matrice ROUTE_MODULE).
/// ============================================================
const Color _sideGold = Color(0xFFD9B45C);

/// État partagé de la sidebar rétractable (64 px rail / 232 px ouverte).
/// Préférence historique conservée : `pmg_dashboard_sidebar_collapsed`.
class SideMenuState {
  SideMenuState._();

  static const String prefKey = 'pmg_dashboard_sidebar_collapsed';

  /// true = rail réduit (icônes seules + tooltips).
  static final ValueNotifier<bool> collapsed = ValueNotifier<bool>(false);
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    collapsed.value = prefs.getBool(prefKey) ?? false;
  }

  static Future<void> toggle() async {
    final next = !collapsed.value;
    collapsed.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, next);
  }
}

class AppSideNavItem {
  final IconData icon;
  final String label;

  /// Code permission requis (null = toujours visible).
  final String? permission;

  /// Clé de module visible (null = toujours visible).
  final String? module;

  /// Index ShellNav de destination (null = page poussée hors shell).
  final int? shellIndex;

  /// Constructeur de page hors shell (Caméras, Scanner).
  final Widget Function()? pageBuilder;

  /// Ouvre le panneau regroupant les modules secondaires.
  final bool opensMoreModules;

  const AppSideNavItem(
    this.icon,
    this.label, {
    this.permission,
    this.module,
    this.shellIndex,
    this.pageBuilder,
    this.opensMoreModules = false,
  });
}

class AppSideMenu extends StatefulWidget {
  final ValueChanged<AppSideNavItem> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback? onLock;
  final VoidCallback onMoreModules;

  /// true = rail réduit (icônes seules + tooltips).
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  const AppSideMenu({
    required this.onNavigate,
    required this.onLogout,
    this.onLock,
    required this.onMoreModules,
    this.collapsed = false,
    this.onToggleCollapse,
    super.key,
  });

  @override
  State<AppSideMenu> createState() => _AppSideMenuState();
}

class _AppSideMenuState extends State<AppSideMenu> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  /// Entrées visibles : filtrées par permissions réelles de l'utilisateur
  /// (AuthStore.user.permissions, renvoyées par le backend à la connexion)
  /// ET par les modules visibles (AuthStore.canSeeModule).
  List<AppSideNavItem> get _visibleItems {
    final user = AuthStore.instance.user;
    bool p(String code) => user?.hasPermission(code) ?? true;
    bool m(String? key) => key == null || AuthStore.instance.canSeeModule(key);
    return <AppSideNavItem>[
      const AppSideNavItem(Icons.home_outlined, 'Tableau de bord',
          shellIndex: 0),
      const AppSideNavItem(Icons.shopping_cart_outlined, 'Point de vente',
          permission: 'sales:view', module: 'pos', shellIndex: 2),
      const AppSideNavItem(Icons.medication_outlined, 'Catalogue',
          permission: 'catalog:view', module: 'catalog', shellIndex: 3),
      const AppSideNavItem(Icons.inventory_2_outlined, 'Stock',
          permission: 'stock:view', module: 'stock', shellIndex: 4),
      const AppSideNavItem(Icons.local_shipping_outlined, 'Fournisseurs',
          permission: 'suppliers:view', module: 'suppliers', shellIndex: 5),
      const AppSideNavItem(Icons.assignment_outlined, 'Commandes',
          permission: 'purchases:view', module: 'purchases', shellIndex: 6),
      const AppSideNavItem(Icons.people_alt_outlined, 'Clients',
          permission: 'customers:view', module: 'customers', shellIndex: 7),
      const AppSideNavItem(Icons.badge_outlined, 'Employés',
          permission: 'employees:view', module: 'employees', shellIndex: 8),
      const AppSideNavItem(Icons.insert_chart_outlined, 'Rapports',
          permission: 'reports:view', module: 'reports', shellIndex: 9),
      AppSideNavItem(Icons.receipt_long_outlined, 'Factures',
          permission: 'sales:view', pageBuilder: () => const InvoicesPage()),
      const AppSideNavItem(Icons.view_in_ar_outlined, 'Plan 3D',
          module: 'plan', shellIndex: 10),
      AppSideNavItem(Icons.videocam_outlined, 'Caméras',
          pageBuilder: () => const CamerasPage()),
      AppSideNavItem(Icons.qr_code_scanner, 'Scanner',
          pageBuilder: () => const ScannerPage()),
      const AppSideNavItem(Icons.apps_rounded, 'Autres modules',
          opensMoreModules: true),
      const AppSideNavItem(Icons.settings_outlined, 'Tableau de contrôle',
          permission: 'settings:view', module: 'settings', shellIndex: 11),
    ]
        .where((i) => (i.permission == null || p(i.permission!)) && m(i.module))
        .toList();
  }

  /// Entrée active = onglet shell réellement affiché (plus du premier
  /// item en dur) : le menu indique toujours la page courante, y compris
  /// pendant le défilement du tableau Stock.
  bool _isActive(AppSideNavItem item) =>
      item.shellIndex != null && item.shellIndex == ShellNav.index.value;

  void _onItemTap(AppSideNavItem item) {
    if (item.opensMoreModules) {
      widget.onMoreModules();
    } else {
      widget.onNavigate(item);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Recoloration de l'entrée active à chaque changement d'onglet.
    ShellNav.index.addListener(_onIndexChanged);
  }

  @override
  void dispose() {
    ShellNav.index.removeListener(_onIndexChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onIndexChanged() {
    if (mounted) setState(() {});
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
            itemCount: _visibleItems.length,
            itemBuilder: (context, i) {
              final item = _visibleItems[i];
              final active = _isActive(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Center(
                  child: Tooltip(
                    message: item.label,
                    waitDuration: const Duration(milliseconds: 300),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _onItemTap(item),
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
                        child: Icon(item.icon,
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
        const SizedBox(height: 8),
        // PIN uniquement dans le rail (la déconnexion est dans la TopBar).
        // Le bouton est volontairement plus étroit que les entrées
        // principales afin de ne jamais déborder dans le dashboard (rail 64).
        if (widget.onLock != null) ...[
          Tooltip(
            message: 'Verrouiller avec le PIN',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onLock,
              child: Container(
                width: 26,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          const Color(0xFFC9A24B).withValues(alpha: 0.55)),
                ),
                child: const Icon(Icons.lock_open_outlined,
                    color: _sideGold, size: 18),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final visibleItems = _visibleItems;
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
        // ---- Menu modules (filtré par permissions) ----
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            itemCount: visibleItems.length,
            itemBuilder: (context, i) {
              final item = visibleItems[i];
              final active = _isActive(item);
              final menuItem = Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _onItemTap(item),
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
                      Icon(item.icon, size: 19, color: const Color(0xFFC9A24B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.label,
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
              return item.module == 'settings'
                  ? menuItem
                  : menuItem;
            },
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
                        color: const Color(0xFFC9A24B).withValues(alpha: 0.5))),
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
        // ---- PIN uniquement (la déconnexion est dans la TopBar) ----
        if (widget.onLock != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onLock,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF07271C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFC9A24B)
                          .withValues(alpha: 0.55)),
                ),
                child: const Center(
                    child: Icon(Icons.lock_open_outlined,
                        color: _sideGold, size: 19)),
              ),
            ),
          ),
        // ---- Horloge + date ----
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
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
            Tooltip(
              message: 'Ouvrir l’agenda des jours fériés',
              child: Material(
                color: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: const Color(0xFFC9A24B).withValues(alpha: 0.7))),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showMoroccanCalendar(context),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.calendar_today_outlined,
                        color: _sideGold, size: 19),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showMoroccanCalendar(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer l’agenda',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const _MoroccanCalendarDialog(),
    );
  }
}

class _MoroccanCalendarDialog extends StatefulWidget {
  const _MoroccanCalendarDialog();

  @override
  State<_MoroccanCalendarDialog> createState() =>
      _MoroccanCalendarDialogState();
}

class _MoroccanCalendarDialogState extends State<_MoroccanCalendarDialog> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, String> _holidays(int year) {
    final fixed = <String, String>{
      '$year-01-01': 'Nouvel an',
      '$year-01-11': 'Manifeste de l’indépendance',
      '$year-01-14': 'Nouvel an amazigh',
      '$year-05-01': 'Fête du Travail',
      '$year-07-30': 'Fête du Trône',
      '$year-08-14': 'Allégeance Oued Eddahab',
      '$year-08-20': 'Révolution du Roi et du Peuple',
      '$year-08-21': 'Fête de la Jeunesse',
      '$year-11-06': 'Marche Verte',
      '$year-11-18': 'Fête de l’Indépendance',
    };
    // Dates religieuses 2026 selon le calendrier civil prévisionnel. Elles
    // restent indicatives jusqu’à l’annonce officielle des autorités.
    if (year == 2026) {
      fixed.addAll({
        '2026-03-20': 'Aïd Al-Fitr',
        '2026-03-21': 'Aïd Al-Fitr',
        '2026-05-27': 'Aïd Al-Adha',
        '2026-05-28': 'Aïd Al-Adha',
        '2026-06-17': 'Nouvel an de l’Hégire',
        '2026-08-26': 'Aïd Al-Mawlid',
        '2026-08-27': 'Aïd Al-Mawlid',
      });
    }
    return fixed;
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final holidays = _holidays(_month.year);
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final mondayOffset = (first.weekday + 6) % 7;
    final cells = <Widget>[];
    for (var i = 0; i < mondayOffset; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final holiday = holidays[_key(date)];
      final selected = _selected != null && _key(_selected!) == _key(date);
      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() => _selected = date),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.emerald.withValues(alpha: 0.24)
                  : holiday == null
                      ? Colors.transparent
                      : AppColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              border:
                  selected ? Border.all(color: AppColors.emeraldLight) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: holiday == null ? Colors.white : AppColors.danger,
                fontWeight: holiday == null || selected
                    ? FontWeight.w600
                    : FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }
    final selectedHoliday =
        _selected == null ? null : holidays[_key(_selected!)];
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      title: Row(children: [
        const Icon(Icons.calendar_month_rounded, color: _sideGold),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('Agenda marocain',
                style: TextStyle(color: Colors.white, fontSize: 18))),
        IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close, color: Colors.white70)),
      ]),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                tooltip: 'Mois précédent',
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left, color: _sideGold)),
            Text(DateFormat('MMMM yyyy', 'fr').format(_month),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            IconButton(
                tooltip: 'Mois suivant',
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right, color: _sideGold)),
          ]),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekDay('L'),
              _WeekDay('M'),
              _WeekDay('M'),
              _WeekDay('J'),
              _WeekDay('V'),
              _WeekDay('S'),
              _WeekDay('D'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: cells,
          ),
          const SizedBox(height: 12),
          if (selectedHoliday != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
              ),
              child: Text(selectedHoliday,
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w800)),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Les jours fériés apparaissent en rouge.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Les fêtes religieuses peuvent être ajustées après l’annonce officielle.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ]),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  final String label;
  const _WeekDay(this.label);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );
}

/// ============================================================
/// MENU « AUTRES MODULES » — panneau ouvert à la demande depuis
/// la sidebar. Se referme au choix d'une option ou au clic en
/// dehors (barrière du dialog). Regroupe les modules absents du
/// menu latéral : ordonnances, pointage, comptabilité, IA...
/// ============================================================
class ModulesMenuDialog extends StatelessWidget {
  final ValueChanged<Widget> onOpen;
  const ModulesMenuDialog({required this.onOpen, super.key});

  static const _entries = <(IconData, String, String, Widget)>[
    (
      Icons.receipt_long_outlined,
      'Ordonnances',
      'Saisie et délivrance',
      PrescriptionsPage()
    ),
    (Icons.fact_check_outlined, 'Audit', 'Inventaire et caisse', AuditPage()),
    (
      Icons.keyboard_return_rounded,
      'Retours',
      'Retours produits',
      ReturnsPage()
    ),
    (
      Icons.fact_check_outlined,
      'Pointage',
      'Présences équipe',
      AttendancePage()
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Comptabilité',
      'Caisse et écritures',
      AccountingPage()
    ),
    (
      Icons.auto_awesome_outlined,
      'Assistant IA',
      'Prévisions et conseils',
      AiPage()
    ),
    (
      Icons.menu_book_outlined,
      'Référentiel',
      'Données de référence',
      ReferencePage()
    ),
    (
      Icons.notifications_outlined,
      'Notifications',
      'Alertes et messages',
      NotificationsPage()
    ),
    (
      Icons.widgets_outlined,
      'Modules',
      'Gestionnaire de modules',
      ModulesPage()
    ),
    (
      Icons.language_rounded,
      'Site web',
      'Blog et contenu public',
      WebsitePage()
    ),
    // Interface Médecin : lecteur de médicaments en lecture seule, réservé
    // au rôle « Médecin » (5 permissions limitées — voir doctor_page.dart).
    (
      Icons.medication_outlined,
      'Médecins',
      'Consultation des médicaments',
      DoctorPage()
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // L'interface Médecin n'est proposée qu'au rôle Médecin.
    final isDoctor = context.watch<AuthStore>().user?.roleName == 'Médecin';
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
                          color:
                              const Color(0xFFC9A24B).withValues(alpha: 0.5))),
                  child: const Icon(Icons.apps_rounded,
                      color: _sideGold, size: 21),
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
                    if (label != 'Médecins' || isDoctor)
                      ModuleMenuTile(
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
class ModuleMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const ModuleMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    super.key,
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
