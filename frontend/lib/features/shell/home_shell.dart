import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_logo.dart';
import '../dashboard/dashboard_page.dart';
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
    PosPage(),
    CatalogPage(),
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    // Navigation complète (12 entrées) : icône + icône actif + clé de libellé.
    const navItems = <(IconData, IconData, String)>[
      (Icons.dashboard_outlined, Icons.dashboard, 'dashboard'),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, 'pos'),
      (Icons.grid_view_outlined, Icons.grid_view, 'catalog'),
      (Icons.medication_outlined, Icons.medication, 'medications'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'stock'),
      (Icons.local_shipping_outlined, Icons.local_shipping, 'suppliers'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'purchases'),
      (Icons.people_outline, Icons.people, 'customers'),
      (Icons.badge_outlined, Icons.badge, 'employees'),
      (Icons.insights_outlined, Icons.insights, 'reports'),
      (Icons.storefront_outlined, Icons.storefront, 'pharmacyPlan'),
      (Icons.settings_outlined, Icons.settings, 'settings'),
    ];

    // Barre basse (écrans étroits) : sous-ensemble représentatif.
    const mobileItems = <(IconData, IconData, String, int)>[
      (Icons.dashboard_outlined, Icons.dashboard, 'dashboard', 0),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, 'pos', 1),
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
    final navLabels = [
      for (final (_, _, key) in navItems) S.t(key, locale),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _DarkRail(
                selectedIndex: _index,
                labels: navLabels,
                icons: navItems.map((n) => n.$1).toList(),
                selectedIcons: navItems.map((n) => n.$2).toList(),
                onSelect: (i) => setState(() => _index = i),
              ),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(index: _index, children: _pages),
                  if (_syncing) _SyncBanner(label: S.t('syncing', locale)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: mobileItems
                  .map((m) => m.$4)
                  .toList()
                  .indexOf(_index),
              onDestinationSelected: (i) =>
                  setState(() => _index = mobileItems[i].$4),
              destinations: mobileDestinations,
            ),
    );
  }
}

/// Menu latéral vert très sombre avec effet 3D (design premium).
class _DarkRail extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final ValueChanged<int> onSelect;

  const _DarkRail({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.menu, Color(0xFF081F0C)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const PharmaPlusLogo(size: 46),
          const SizedBox(height: 20),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: labels.length,
              itemBuilder: (context, i) => _RailItem(
                icon: icons[i],
                selectedIcon: selectedIcons[i],
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'PHARMA+',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                color: Color(0x55FFFFFF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.greenGradient : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? Colors.white : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
