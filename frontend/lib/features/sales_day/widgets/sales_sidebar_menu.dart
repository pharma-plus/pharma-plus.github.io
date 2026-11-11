/// ============================================================
/// PHARMA+ SALES INTELLIGENCE — Menu latéral indépendant
/// ============================================================
/// Menu appartenant exclusivement au module SALES INTELLIGENCE.
/// Ne remplace pas le menu principal PHARMA+.
/// Design sombre premium, rubrique active mise en évidence,
/// rétractable sur PC, adapté mobile et tablette.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Définition d'une rubrique du menu.
class SalesMenuItem {
  final String id;
  final String title;
  final IconData icon;

  const SalesMenuItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// Les 10 rubriques de SALES INTELLIGENCE.
class SalesMenu {
  static final List<SalesMenuItem> items = [
    SalesMenuItem(
      id: 'overview',
      title: 'Vue générale',
      icon: Icons.dashboard_outlined,
    ),
    SalesMenuItem(
      id: 'analysis',
      title: 'Analyse des ventes',
      icon: Icons.bar_chart_outlined,
    ),
    SalesMenuItem(
      id: 'profits',
      title: 'Bénéfices & marges',
      icon: Icons.trending_up_outlined,
    ),
    SalesMenuItem(
      id: 'products',
      title: 'Produits vendus',
      icon: Icons.local_pharmacy,
    ),
    SalesMenuItem(
      id: 'employees',
      title: 'Performance employés',
      icon: Icons.people_outlined,
    ),
    SalesMenuItem(
      id: 'payments',
      title: 'Paiements & caisse',
      icon: Icons.account_balance_wallet_outlined,
    ),
    SalesMenuItem(
      id: 'returns',
      title: 'Annulations & retours',
      icon: Icons.cancel_outlined,
    ),
    SalesMenuItem(
      id: 'comparisons',
      title: 'Comparaisons',
      icon: Icons.compare_outlined,
    ),
    SalesMenuItem(
      id: 'reports',
      title: 'Rapports & exports',
      icon: Icons.description_outlined,
    ),
    SalesMenuItem(
      id: 'alerts',
      title: 'Alertes intelligentes',
      icon: Icons.notifications_outlined,
    ),
  ];

  static SalesMenuItem? find(String id) {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  static int indexOf(String id) {
    return items.indexWhere((i) => i.id == id);
  }
}

/// Contrôleur du menu latéral (état ouvert/fermé + rubrique active).
class SalesMenuController extends ChangeNotifier {
  bool _open = false;
  String _activeId = 'overview';

  bool get open => _open;
  String get activeId => _activeId;

  void toggle() {
    _open = !_open;
    notifyListeners();
  }

  void openMenu() {
    _open = true;
    notifyListeners();
  }

  void closeMenu() {
    _open = false;
    notifyListeners();
  }

  void select(String id) {
    _activeId = id;
    _open = false; // se referme après sélection sur mobile
    notifyListeners();
  }

  bool isActive(String id) => _activeId == id;
}

/// Bouton de hamburger pour ouvrir/fermer le menu (affiché dans l'AppBar).
class SalesMenuToggle extends StatelessWidget {
  final VoidCallback onPressed;

  const SalesMenuToggle({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.menu, size: 22),
      tooltip: 'Menu SALES INTELLIGENCE',
      color: AppColors.pharmaGold,
    );
  }
}

/// Dessine le menu latéral (à placer dans un Stack ou un Drawer).
class SalesSidebarMenu extends StatelessWidget {
  final SalesMenuController menu;
  final ValueChanged<String> onItemSelected;

  const SalesSidebarMenu({
    super.key,
    required this.menu,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final width = isWide ? 260.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: menu.open ? width : 0,
      color: AppColors.surfaceSidebar,
      child: menu.open
          ? Column(
              children: [
                // En-tête du menu
                _buildHeader(context),
                const Divider(
                  color: AppColors.dividerLight,
                  height: 1,
                ),
                // Liste des rubriques
                Expanded(
                  child: ListView.builder(
                    itemCount: SalesMenu.items.length,
                    itemBuilder: (context, i) {
                      final item = SalesMenu.items[i];
                      final active = menu.isActive(item.id);
                      return _buildItem(context, item, active);
                    },
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.emerald.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.point_of_sale,
              color: AppColors.emerald,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PHARMA+',
                  style: TextStyle(
                    color: AppColors.pharmaGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SALES INTELLIGENCE',
                  style: TextStyle(
                    color: AppColors.pharmaMuted.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (!(MediaQuery.of(context).size.width >= 900))
            IconButton(
              onPressed: menu.closeMenu,
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.pharmaMuted,
              tooltip: 'Fermer le menu',
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, SalesMenuItem item, bool active) {
    return InkWell(
      onTap: () => onItemSelected(item.id),
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? AppColors.emerald.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? AppColors.emerald : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 19,
              color: active
                  ? AppColors.emeraldLight
                  : AppColors.pharmaMuted.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: active
                      ? AppColors.emeraldLight
                      : AppColors.pharmaText.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton flottant pour ouvrir le menu sur mobile/tablette.
class SalesMenuFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SalesMenuFloatingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.emerald,
      foregroundColor: Colors.white,
      child: const Icon(Icons.menu, size: 22),
    );
  }
}
