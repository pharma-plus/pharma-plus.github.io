import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/app_guards.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/services/system_back_guard.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_background.dart';
import '../shell/shell_nav.dart';
import '../dashboard/dashboard_page.dart';
import '../modules/modules_page.dart';
import '../pos/pos_page.dart';
import '../catalog/catalog_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../profit/profit_page.dart';
import '../suppliers/supplier_connectivity_page.dart';
import '../customers/customers_page_v2.dart';
import '../employees/employees_page.dart';
import '../reports/reports_page.dart';
import '../purchases/purchases_page.dart';
import '../security/lock_screen.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../settings/settings_page.dart';
import '../reference/reference_page.dart';
import '../reorder/reorder_page.dart';
import '../ai/ai_page_v2.dart';
import '../whatsapp/whatsapp_center_page.dart';
import '../super_admin/super_admin_crm_page.dart';
import 'app_side_menu.dart';
import 'mobile_nav.dart';

/// Global key for the HomeShell scaffold, accessible from DashboardPage to open the drawer.
import 'package:pharma_maroc_gold/core/services/scaffold_key.dart';

/// Force tree-shaking prevention by referencing SuperAdminCRMPage at top level
@pragma('vm:entry-point')
final _superAdminPages = <Widget>[
  SuperAdminCRMPage(),
];

/// Coquille principale : sidebar 3D + navigation.
/// La navigation est filtrée par `AuthStore.canSeeModule(key)` :
/// les modules non visibles pour le rôle sont masqués de la bottom bar
/// et de la page Modules. Le dashboard (index 0) reste toujours visible.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Clé de module par index de page (null = toujours visible).
const _pageModuleKeys = <int, String?>{
  0: null, // Dashboard — toujours visible
  1: null, // Modules — toujours visible (hub)
  2: 'pos',
  3: 'catalog',
  4: 'stock',
  5: 'suppliers',
  6: 'purchases',
  7: 'customers',
  8: 'employees',
  9: 'reports',
  10: 'plan',
  11: 'settings',
  12: 'reference', // Catalogue centralisé
  13: 'supplier_connectivity', // Connectivité fournisseurs
  14: 'reorder', // Réapprovisionnement intelligent
  15: 'ai', // Assistant IA
  16: 'whatsapp', // Centre WhatsApp
  17: 'superadmin_crm', // Super Admin CRM
  18: null, // profit — toujours visible
};

class _HomeShellState extends State<HomeShell> {
  bool _syncing = false;
  bool _lockRouteShown = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Expose the scaffold key globally so DashboardPage can access the drawer.
  @override
  void initState() {
    super.initState();
    ScaffoldKeyService.setScaffoldKey(_scaffoldKey);
    // Restaure la préférence rail 64 px / menu ouvert 232 px (persistée).
    SideMenuState.init();
    // Référence sauvegardée : context.read est INTERDIT dans dispose()
    // (l'ancêtre Provider peut être déjà déactivé pendant le démontage).
    _auth = context.read<AuthStore>();
    // Onglet déjà visité au montage (index non nul possible en restauration).
    _visited.add(ShellNav.index.value);
    // Retour système smartphone/tablette : une entrée d'historique par onglet
    // pour reculer Onglet → Dashboard → dialogue de confirmation.
    ShellNav.index.addListener(_onShellIndexChanged);
    systemBackNoteShellIndex(ShellNav.index.value);
    // Verrouillage automatique : dès que le store bascule en `isLocked`,
    // l'écran PIN est posé par-dessus le shell (inactivité ou manuel).
    _auth.addListener(_onAuthLockChanged);
    // Sync différée : on ne la lance pas pendant la première frame qui
    // charge déjà le dashboard (concurrence réseau inutile).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _kickSync();
      });
    });
  }

  /// Pages déjà visitées : montées à la demande (lazy) pour éviter
  /// d'inflammer ~24 requêtes API + 12 initState d'un coup au login.
  final Set<int> _visited = {0};

  /// Seuil partagé avec le dashboard (TopBar hamburger/menu) : la sidebar
  /// fixe apparaît à 1150 px de largeur TOTALE de fenêtre.
  static const double _sideMenuBreakpoint = 1150;

  late final AuthStore _auth;

  Widget _page(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    // TickerMode coupe les animations (glow POS, horloge…) des pages
    // non visibles : elles ne tournent plus en arrière-plan à 60 fps.
    return TickerMode(enabled: i == ShellNav.index.value, child: _pages[i]);
  }

  static final _pages = [
    const DashboardPage(),
    const ModulesPage(),
    const PosPage(),
    const CatalogPage(),
    const StockPage(),
    const SuppliersPage(),
    const PurchasesPage(),
    const CustomersPageV2(),
    const EmployeesPage(),
    const ReportsPage(),
    const PharmacyPlanPage(),
    const SettingsPage(),
    const ReferencePage(),
    const SupplierConnectivityPage(),
    const ReorderPage(),
    const AIPageV2(),
    const WhatsAppCenterPage(),
    SuperAdminCRMPage(),
    const ProfitPage(),
  ];

  void _onAuthLockChanged() {
    final locked = context.read<AuthStore>().isLocked;
    if (locked && !_lockRouteShown && mounted) {
      _lockRouteShown = true;
      // Route TRANSLUCIDE (opaque: false) : le shell réel reste peint
      // derrière le voile PIN, tout en étant masqué et inutilisable.
      Navigator.of(context)
          .push(PageRouteBuilder(
        opaque: false,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        pageBuilder: (_, __, ___) => const LockScreen(),
      ))
          .whenComplete(() {
        if (mounted) setState(() => _lockRouteShown = false);
      });
    }
  }

  void _onShellIndexChanged() {
    systemBackNoteShellIndex(ShellNav.index.value);
    _visit(ShellNav.index.value);
  }

  void _visit(int i) {
    if (_visited.add(i) && mounted) setState(() {});
  }

  Future<void> _kickSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await SyncEngine.instance.sync(verbose: true);
    if (mounted) setState(() => _syncing = false);
  }

  /// Navigation depuis la sidebar fixe (desktop ≥1150 px) : onglets via
  /// ShellNav, pages hors shell (Caméras, Scanner) poussées par-dessus.
  void _onSideNavNavigate(AppSideNavItem item) {
    if (item.shellIndex != null) {
      ShellNav.index.value = item.shellIndex!;
    } else if (item.pageBuilder != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => item.pageBuilder!()));
    }
    // Fermeture directe du DrawerController (pas de pop de route racine).
    _closeDrawer();
  }

  /// Fermeture sûre du drawer : DrawerController (pas Navigator.pop).
  void _closeDrawer() {
    if (!mounted) return;
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _onSideNavLogout() async {
    if (await confirmSignOut(context)) {
      if (!mounted) return;
      await context.read<AuthStore>().signOut();
    }
  }

  /// Menu « Autres modules » depuis la sidebar fixe.
  void _onSideNavMoreModules() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => ModulesMenuDialog(
        onOpen: (page) {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }

  // ---- Handlers du menu mobile (drawer smartphone/tablette) ----
  void _onMobileShellIndex(int index) {
    _closeDrawer();
    ShellNav.index.value = index;
  }

  void _onMobilePush(Widget page) {
    _closeDrawer();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _onMobileLock() {
    _closeDrawer();
    context.read<AuthStore>().lockSession(manual: true);
  }

  Future<void> _onMobileLogout() async {
    _closeDrawer();
    await _onSideNavLogout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final locale = auth.locale;
    // Smartphones ET tablettes : navigation inférieure persistante.
    // Desktop (≥ 1150 px) : navigation par sidebar, apparence inchangée.
    final showBottomNav =
        MediaQuery.sizeOf(context).width < _sideMenuBreakpoint;

    // Barre inférieure COMPACTE (règle UX mobile/tablette) : exactement 4
    // raccourcis essentiels — Point de vente (2), Stock (4), Fournisseur
    // (5), Bénéfice (18), filtrés par permissions (source unique
    // `visibleMobileDestinations`). Dashboard et Modules restent
    // accessibles via le menu mobile « Tous les modules ».
    final primaryDestinations = visibleMobileDestinations(auth, locale);
    final primaryIndexes = primaryDestinations.map((d) => d.shellIndex).toSet();

    return ValueListenableBuilder<int>(
      valueListenable: ShellNav.index,
      builder: (context, shellIndex, _) {
        // Garde-fou : si l'index courant pointe un module masqué,
        // on revient au dashboard (index 0), Sauf si l'utilisateur a
        // explicitement sélectionné un onglet de la bottom navigation
        // (ce qui signifie qu'il veut accéder à cette page).
        var effectiveIndex = shellIndex;
        final moduleKey = _pageModuleKeys[shellIndex];
        final wasBottomNavSelection = <int>{0, 1, 2}.contains(shellIndex);
        if (moduleKey != null && !auth.canSeeModule(moduleKey)) {
          // Ne pas réinitialiser vers dashboard si la sélection vient
          // de la bottom navigation — on respecte le choix de l'utilisateur.
          if (!wasBottomNavSelection) {
            effectiveIndex = 0;
            if (ShellNav.index.value != 0) {
              ShellNav.index.value = 0;
            }
          }
        }
        // Contenu = pages (IndexedStack) + bannière de sync superposée.
        final content = Stack(
          children: [
            IndexedStack(
              index: effectiveIndex,
              children: [for (var i = 0; i < _pages.length; i++) _page(i)],
            ),
            if (_syncing) _SyncBanner(label: S.t('syncing', locale)),
            // NOTE : l'indicateur de connexion (pastille sync) n'est plus
            // superposé ici — il déborde/chevauche les icônes des en-têtes
            // de page (cloche de notification). Il est désormais INTÉGRÉ
            // dans la barre du haut, à droite de la cloche (dashboard).
          ],
        );
        // Desktop ≥1150 px : menu latéral FIXE à gauche (contenu de la page
        // courante défile seul à droite, y compris le tableau Stock).
        final vw = MediaQuery.sizeOf(context).width;
        final showSideMenu = vw >= _sideMenuBreakpoint;
        return Scaffold(
          key: _scaffoldKey,
          // Smartphones ET tablettes (< 1150 px) : menu mobile dédié
          // « Tous les modules ». JAMAIS la sidebar PC `AppSideMenu`
          // (réservée au desktop ≥ 1150 px, apparence préservée).
          drawer: !showSideMenu
              ? MobileNavDrawer(
                  onShellIndex: _onMobileShellIndex,
                  onPushPage: _onMobilePush,
                  onClose: _closeDrawer,
                  onLock: _onMobileLock,
                  onLogout: _onMobileLogout,
                )
              : null,
          body: PharmaBackground(
            assetImage: 'assets/images/background.webp',
            child: SafeArea(
              child: Theme(
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: Colors.transparent,
                  canvasColor: Colors.transparent,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                  ),
                  inputDecorationTheme: const InputDecorationThemeData(
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                ),
                child: showSideMenu
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Rail réduit (64 px, icônes + tooltips) ou menu
                          // ouvert (232 px) — état persisté partagé.
                          ValueListenableBuilder<bool>(
                            valueListenable: SideMenuState.collapsed,
                            builder: (context, collapsed, _) =>
                                AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              width: collapsed ? 64 : 232,
                              child: AppSideMenu(
                                collapsed: collapsed,
                                onToggleCollapse: SideMenuState.toggle,
                                onLock: () => context
                                    .read<AuthStore>()
                                    .lockSession(manual: true),
                                onNavigate: _onSideNavNavigate,
                                onLogout: _onSideNavLogout,
                                onMoreModules: _onSideNavMoreModules,
                              ),
                            ),
                          ),
                          Container(width: 1, color: AppColors.dividerDark),
                          Expanded(child: content),
                        ],
                      )
                    : content,
              ),
            ),
          ),
          bottomNavigationBar: showBottomNav
              ? MobileBottomBar(
                  destinations: primaryDestinations,
                  selectedIndex: primaryIndexes.contains(effectiveIndex)
                      ? effectiveIndex
                      : -1,
                  onSelected: (index) => ShellNav.index.value = index,
                )
              : null,
        );
      },
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final String label;
  const _SyncBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF3E2A00)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3E2A00)),
            ),
          ],
        ),
      ),
    );
  }
}
