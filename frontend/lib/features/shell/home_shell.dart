import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/pharma_background.dart';
import '../dashboard/dashboard_page.dart';
import '../modules/modules_page.dart';
import '../pos/pos_page.dart';
import '../catalog/catalog_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../purchases/purchases_page.dart';
import '../customers/customers_page.dart';
import '../employees/employees_page.dart';
import '../reports/reports_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../settings/settings_page.dart';

/// Coquille principale : sidebar 3D + navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _syncing = false;

  static const _pages = [
    DashboardPage(),
    ModulesPage(),
    PosPage(),
    CatalogPage(),
    StockPage(),
    SuppliersPage(),
    PurchasesPage(),
    CustomersPage(),
    EmployeesPage(),
    ReportsPage(),
    PharmacyPlanPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _kickSync();
  }

  Future<void> _kickSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await SyncEngine.instance.sync(verbose: true);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final deviceType = ResponsiveHelper.getDeviceType(MediaQuery.of(context).size.width);
    final showBottomNav = deviceType == DeviceType.mobile;

    // Navigation items
    const mobileItems = <(IconData, IconData, String, int)>[
      (Icons.dashboard_outlined, Icons.dashboard, 'dashboard', 0),
      (Icons.grid_view_rounded, Icons.grid_view_rounded, 'modules', 1),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, 'pos', 2),
      (Icons.medication_outlined, Icons.medication, 'medications', 3),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'stock', 4),
      (Icons.storefront_outlined, Icons.storefront, 'pharmacyPlan', 10),
      (Icons.settings_outlined, Icons.settings, 'settings', 11),
    ];

    final mobileDestinations = [
      for (final (ic, icS, key, _) in mobileItems)
        NavigationDestination(
          icon: Icon(ic),
          selectedIcon: Icon(icS),
          label: S.t(key, locale),
        ),
    ];

    return Scaffold(
      body: PharmaBackground(
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              canvasColor: Colors.transparent,
            ),
            child: Stack(
              children: [
                IndexedStack(index: _index, children: _pages),
                if (_syncing) _SyncBanner(label: S.t('syncing', locale)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex:
                  mobileItems.map((m) => m.$4).toList().indexOf(_index),
              onDestinationSelected: (i) =>
                  setState(() => _index = mobileItems[i].$4),
              destinations: mobileDestinations,
              // Optimisation tactile : hauteur augmentée pour doigts
              height: 80,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            )
          : null,
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
