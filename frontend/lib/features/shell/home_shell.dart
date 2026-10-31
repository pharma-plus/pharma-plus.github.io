import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/app_guards.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/services/system_back_guard.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/pharma_background.dart';
import '../shell/shell_nav.dart';
import '../dashboard/dashboard_page.dart';
import '../modules/modules_page.dart';
import '../pos/pos_page.dart';
import '../catalog/catalog_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../suppliers/supplier_connectivity_page.dart';
import '../customers/customers_page.dart';
import '../employees/employees_page.dart';
import '../reports/reports_page.dart';
import '../purchases/purchases_page.dart';
import '../security/lock_screen.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../settings/settings_page.dart';
import '../reference/reference_page.dart';
import '../reorder/reorder_page.dart';
import 'app_side_menu.dart';

/// Global key for the HomeShell scaffold, accessible from DashboardPage to open the drawer.
import 'package:pharma_maroc_gold/core/services/scaffold_key.dart';

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
    const CustomersPage(),
    const EmployeesPage(),
    const ReportsPage(),
    const PharmacyPlanPage(),
    const SettingsPage(),
    const ReferencePage(),
    const SupplierConnectivityPage(),
    const ReorderPage(),
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
    // Sur mobile, fermer le drawer après sélection.
    final vw = MediaQuery.sizeOf(context).width;
    if (vw < _sideMenuBreakpoint) {
      Navigator.of(_scaffoldKey.currentContext!).pop();
    }
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final locale = auth.locale;
    final deviceType =
        ResponsiveHelper.getDeviceType(MediaQuery.of(context).size.width);
    final showBottomNav = deviceType == DeviceType.mobile;

    // Navigation items — filtrés par visibilité de module.
    const allMobileItems = <(IconData, IconData, String, int)>[
      (Icons.dashboard_outlined, Icons.dashboard, 'dashboard', 0),
      (Icons.grid_view_rounded, Icons.grid_view_rounded, 'modules', 1),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, 'pos', 2),
      (Icons.medication_outlined, Icons.medication, 'medications', 3),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'stock', 4),
      (Icons.local_shipping_outlined, Icons.local_shipping, 'reorder', 14),
      (Icons.link_outlined, Icons.link, 'supplierConnectivity', 13),
      (Icons.menu_book_outlined, Icons.menu_book, 'reference', 12),
      (Icons.storefront_outlined, Icons.storefront, 'pharmacyPlan', 10),
      (Icons.settings_outlined, Icons.settings, 'settings', 11),
    ];

    // Clé de module pour les items de la bottom bar mobile.
    const mobileModuleKeys = <int, String?>{
      0: null, // dashboard — toujours visible
      1: null, // modules — toujours visible
      2: 'pos',
      3: 'catalog',
      4: 'stock',
      10: 'plan',
      11: 'settings',
      12: 'reference',
      13: 'supplier_connectivity',
      14: 'reorder',
    };

    final mobileItems = allMobileItems.where((m) {
      final key = mobileModuleKeys[m.$4];
      return key == null || auth.canSeeModule(key);
    }).toList();

    final mobileDestinations = [
      for (final (ic, icS, key, _) in mobileItems)
        NavigationDestination(
          icon: Icon(ic),
          selectedIcon: Icon(icS),
          label: S.t(key, locale),
        ),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: ShellNav.index,
      builder: (context, shellIndex, _) {
        // Garde-fou : si l'index courant pointe un module masqué,
        // on revient au dashboard (index 0).
        var effectiveIndex = shellIndex;
        final moduleKey = _pageModuleKeys[shellIndex];
        if (moduleKey != null && !auth.canSeeModule(moduleKey)) {
          effectiveIndex = 0;
          if (ShellNav.index.value != 0) {
            ShellNav.index.value = 0;
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
          ],
        );
        // Desktop ≥1150 px : menu latéral FIXE à gauche (contenu de la page
        // courante défile seul à droite, y compris le tableau Stock).
        final vw = MediaQuery.sizeOf(context).width;
        final showSideMenu = vw >= _sideMenuBreakpoint;
        return Scaffold(
          key: _scaffoldKey,
          drawer: !showSideMenu
              ? Drawer(
                  backgroundColor: AppColors.surfaceSidebar,
                  child: SafeArea(
                    child: AppSideMenu(
                      collapsed: false,
                      onToggleCollapse: SideMenuState.toggle,
                      onLock: () => context
                          .read<AuthStore>()
                          .lockSession(manual: true),
                      onNavigate: _onSideNavNavigate,
                      onLogout: _onSideNavLogout,
                      onMoreModules: _onSideNavMoreModules,
                    ),
                  ),
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
              ? NavigationBar(
                  selectedIndex: () {
                    final idx = mobileItems
                        .map((m) => m.$4)
                        .toList()
                        .indexOf(effectiveIndex);
                    // Pages hors barre mobile (ex : fournisseurs, achats,
                    // clients, employés, rapports) : repli non-destructif sur
                    // l'onglet Modules au lieu de -1 (crash/assert).
                    // Si Modules n'est pas visible non plus → dashboard (0).
                    if (idx >= 0) return idx;
                    return mobileItems.any((m) => m.$4 == 1) ? 1 : 0;
                  }(),
                  onDestinationSelected: (i) =>
                      ShellNav.index.value = mobileItems[i].$4,
                  destinations: mobileDestinations,
                  // Optimisation tactile : hauteur augmentée pour doigts
                  height: 80,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
