import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../dashboard/dashboard_page.dart';
import '../pos/pos_page.dart';
import '../catalog/catalog_page.dart';
import '../stock/stock_page.dart';
import '../modules/modules_page.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../settings/settings_page.dart';

/// Coquille principale : menu sombre 3D + navigation par onglets.
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
    StockPage(),
    PharmacyPlanPage(),
    ModulesPage(),
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

    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: S.t('dashboard', locale)),
      NavigationDestination(
          icon: const Icon(Icons.point_of_sale_outlined),
          selectedIcon: const Icon(Icons.point_of_sale),
          label: S.t('pos', locale)),
      NavigationDestination(
          icon: const Icon(Icons.medication_outlined),
          selectedIcon: const Icon(Icons.medication),
          label: S.t('catalog', locale)),
      NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: S.t('stock', locale)),
      NavigationDestination(
          icon: const Icon(Icons.storefront_outlined),
          selectedIcon: const Icon(Icons.storefront),
          label: S.t('pharmacyPlan', locale)),
      NavigationDestination(
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view),
          label: S.t('modules', locale)),
      NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: S.t('settings', locale)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _DarkRail(
                selectedIndex: _index,
                labels: destinations.map((d) => d.label).toList(),
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
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: destinations,
            ),
    );
  }
}

/// Menu latéral vert très sombre avec effet 3D (design premium).
class _DarkRail extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  const _DarkRail({
    required this.selectedIndex,
    required this.labels,
    required this.onSelect,
  });

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.point_of_sale_outlined,
    Icons.medication_outlined,
    Icons.inventory_2_outlined,
    Icons.storefront_outlined,
    Icons.grid_view_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
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
          const SizedBox(height: 24),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_pharmacy, color: Color(0xFF3E2A00)),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _RailItem(
                icon: _icons[i],
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              'GOLD',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: Color(0x66FFFFFF),
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
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppColors.goldGradient : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Icon(
                icon,
                color: selected ? const Color(0xFF3E2A00) : Colors.white54,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.accent : Colors.white60,
              ),
            ),
          ],
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
