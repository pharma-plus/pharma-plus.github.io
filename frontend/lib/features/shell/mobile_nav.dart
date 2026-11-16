import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_logo.dart';
import 'app_side_menu.dart';
import 'shell_nav.dart';

/// ============================================================
/// NAVIGATION MOBILE PHARMA+ (smartphone + tablette)
///
/// Source UNIQUE des accès primaires de la navigation inférieure :
/// Point de vente (2), Stock (4), Fournisseur (5), Bénéfice (18).
/// Le filtrage réutilise EXACTEMENT les mêmes règles que la sidebar
/// PC (`hasPermission` + `canSeeModule`) : aucune permission inventée,
/// aucune route dupliquée - on ne fait que pointer les onglets ShellNav
/// déjà existants.
///
/// Ce fichier est rendu uniquement sous 1150 px de largeur de fenêtre.
/// Le desktop (≥ 1150 px) conserve la sidebar `AppSideMenu` inchangée.
/// ============================================================

/// Index ShellNav des 4 accès primaires (barre inférieure mobile).
const List<int> kMobilePrimaryIndexes = <int>[2, 4, 5, 18];

/// Spécification d'un accès primaire : index shell + permission + module.
/// `permission: null` = toujours visible (comme la sidebar).
const List<(int, String?, String?)> kMobilePrimarySpecs =
    <(int, String?, String?)>[
  (2, 'sales:view', 'pos'),
  (4, 'stock:view', 'stock'),
  (5, 'suppliers:view', 'suppliers'),
  (18, null, 'profit'),
];

/// Icônes par index shell (normale / sélectionnée).
const Map<int, (IconData, IconData)> _primaryIcons =
    <int, (IconData, IconData)>{
  2: (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
  4: (Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  5: (Icons.local_shipping_outlined, Icons.local_shipping_rounded),
  18: (Icons.trending_up_outlined, Icons.trending_up_rounded),
};

/// Clés de traduction S.t pour les langues sans libellé court dédié.
const Map<int, String> _primaryLabelKeys = <int, String>{
  2: 'pos',
  4: 'stock',
  5: 'suppliers',
  18: 'profit',
};

/// Libellés courts français (lisibles à 320 px en 4 colonnes).
const Map<int, String> _shortLabelsFr = <int, String>{
  2: 'Vente',
  4: 'Stock',
  5: 'Fournisseur',
  18: 'Bénéfice',
};

/// Destination d'un accès primaire mobile.
class MobileNavDestination {
  final int shellIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const MobileNavDestination({
    required this.shellIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Accès primaires VISIBLES pour l'utilisateur connecté.
/// Mêmes règles que `visibleAppSideNavItems()` : permission + module.
List<MobileNavDestination> visibleMobileDestinations(
  AuthStore auth,
  String locale,
) {
  bool p(String? code) =>
      code == null || (auth.user?.hasPermission(code) ?? true);
  bool m(String? key) => key == null || auth.canSeeModule(key);
  final ar = locale == 'ar';
  return <MobileNavDestination>[
    for (final (index, permission, module) in kMobilePrimarySpecs)
      if (p(permission) && m(module))
        MobileNavDestination(
          shellIndex: index,
          icon: _primaryIcons[index]!.$1,
          selectedIcon: _primaryIcons[index]!.$2,
          label: ar
              ? S.t(_primaryLabelKeys[index]!, locale)
              : (_shortLabelsFr[index] ??
                  S.t(_primaryLabelKeys[index]!, locale)),
        ),
  ];
}

/// ============================================================
/// BARRE INFÉRIEURE FIXE - exactement 4 accès (Point de vente, Stock,
/// Fournisseur, Bénéfice). Icônes + libellés courts, état actif visible
/// (pastille or), zones tactiles ≥ 48 px, SafeArea basse (encoches).
/// ============================================================
class MobileBottomBar extends StatelessWidget {
  final List<MobileNavDestination> destinations;

  /// Index ShellNav courant (-1 = aucune sélection dans la barre).
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const MobileBottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.champagne;
    const inactive = AppColors.textSecondary;
    return Material(
      key: const ValueKey('mobile-bottom-bar'),
      color: AppColors.graphiteDark,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.goldBorder),
            ),
          ),
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final d in destinations)
                Expanded(
                  child: InkWell(
                    key: ValueKey('mobile-nav-item-${d.shellIndex}'),
                    onTap: () => onSelected(d.shellIndex),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pastille or de l'état actif.
                        Container(
                          width: 24,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: d.shellIndex == selectedIndex
                                ? activeColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          d.shellIndex == selectedIndex
                              ? d.selectedIcon
                              : d.icon,
                          size: 26,
                          color: d.shellIndex == selectedIndex
                              ? activeColor
                              : inactive,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: d.shellIndex == selectedIndex
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: d.shellIndex == selectedIndex
                                ? activeColor
                                : inactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// MENU MOBILE « TOUS LES MODULES » - drawer dédié smartphone/tablette.
///
/// N'EST PAS la sidebar PC : `AppSideMenu` reste réservé au desktop.
/// Contenu : identité (PHARMA+ / pharmacie / utilisateur), accès
/// Tableau de bord, hub « Tous les modules », puis tous les modules
/// restants filtrés par permissions (`visibleAppSideNavItems()`),
/// hors des 4 accès primaires pour éviter tout doublon de navigation.
/// ============================================================
class MobileNavDrawer extends StatelessWidget {
  final ValueChanged<int> onShellIndex;
  final ValueChanged<Widget> onPushPage;
  final VoidCallback onClose;
  final VoidCallback onLock;
  final VoidCallback onLogout;

  const MobileNavDrawer({
    super.key,
    required this.onShellIndex,
    required this.onPushPage,
    required this.onClose,
    required this.onLock,
    required this.onLogout,
  });

  void _activateItem(BuildContext context, AppSideNavItem item) {
    onClose();
    if (item.shellIndex != null) {
      onShellIndex(item.shellIndex!);
    } else if (item.pageBuilder != null) {
      onPushPage(item.pageBuilder!());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final locale = auth.locale;
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Couleur de texte adaptée au fond (émeraude = champagne, graphite = porcelain).
    final textColor = isDark ? AppColors.porcelain : AppColors.champagne;
    final primary = visibleMobileDestinations(auth, locale);
    final primaryIndexes = primary.map((d) => d.shellIndex).toSet();

    // Tous les modules restants : même source que la sidebar PC, hors
    // Tableau de bord (dédié) et hors des 4 accès primaires (doublons).
    final rest = visibleAppSideNavItems()
        .where((item) =>
            !item.opensMoreModules &&
            item.shellIndex != 0 &&
            item.shellIndex != 1 &&
            !primaryIndexes.contains(item.shellIndex))
        .toList();

    return Drawer(
      key: const ValueKey('mobile-nav-drawer'),
      // Largeur ≈ 3,5 cm physique au lieu de 86 % de l'écran :
      // - smartphone (~60 px logiques / cm) -> 210 px ;
      // - tablette (shortestSide >= 600, ~50 px / cm) -> 175 px ;
      // - très petits écrans : jamais plus de 86 % de la largeur.
      width: () {
        final size = MediaQuery.sizeOf(context);
        final target = size.shortestSide >= 600 ? 175.0 : 210.0;
        final cap = size.width * 0.86;
        return cap < target ? cap : target;
      }(),
      backgroundColor: AppColors.surfaceSidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Identité PHARMA+ ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PharmaFullLogo(width: 132),
                  const SizedBox(height: 10),
                  if ((user?.pharmacyName ?? '').trim().isNotEmpty)
                    Text(
                      user!.pharmacyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.champagne,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    ((user?.fullName ?? '').trim().isNotEmpty
                            ? user!.fullName.trim()
                            : 'Admin') +
                        ((user?.roleName ?? '').trim().isNotEmpty
                            ? ' · ${user!.roleName!.trim()}'
                            : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.dividerDark),
            // ---- Navigation ----
            Expanded(
              child: ListView(
                key: const ValueKey('mobile-drawer-list'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: [
                  _DrawerTile(
                    key: const ValueKey('mobile-drawer-all-modules'),
                    icon: Icons.apps_rounded,
                    label: S.t('modules', locale),
                    subtitle: 'Tous les modules',
                    active: false,
                    isDark: isDark,
                    onTap: () {
                      onClose();
                      onShellIndex(1);
                    },
                  ),
                  _DrawerTile(
                    key: const ValueKey('mobile-drawer-dashboard'),
                    icon: Icons.dashboard_outlined,
                    label: S.t('dashboard', locale),
                    active: ShellNav.index.value == 0,
                    isDark: isDark,
                    onTap: () {
                      onClose();
                      onShellIndex(0);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(6, 10, 6, 6),
                    child: Text(
                      'NAVIGATION',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final item in rest)
                    _DrawerTile(
                      key: ValueKey(
                          'mobile-drawer-item-${item.shellIndex ?? item.label}'),
                      icon: item.icon,
                      label: S.t(item.label, locale),
                      active: item.shellIndex != null &&
                          item.shellIndex == ShellNav.index.value,
                      isDark: isDark,
                      onTap: () => _activateItem(context, item),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.dividerDark),
            // ---- Sécurité ----
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _DrawerTile(
                      icon: Icons.lock_open_outlined,
                      label: 'Verrouiller',
                      active: false,
                      isDark: isDark,
                      onTap: () {
                        onClose();
                        onLock();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DrawerTile(
                      icon: Icons.logout_rounded,
                      label: S.t('logout', locale),
                      active: false,
                      isDark: isDark,
                      onTap: () {
                        onClose();
                        onLogout();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile du drawer mobile : icône + libellé, état actif visible.
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  const _DrawerTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? (isDark
                    ? AppColors.graphiteDark
                    : AppColors.sageGreen.withValues(alpha: 0.35))
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? (isDark
                      ? AppColors.champagne.withValues(alpha: 0.55)
                      : AppColors.sageGreenDark.withValues(alpha: 0.65))
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDark ? AppColors.porcelain : AppColors.champagne,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppColors.porcelain : AppColors.champagne,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.porcelain : AppColors.champagne,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
