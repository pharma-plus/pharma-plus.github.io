/// ============================================================
/// PHARMA+ SALES INTELLIGENCE — Navigation entre sous-pages
/// ============================================================
/// Boutons : Précédent, Suivant, Retour, Maison (SALES INTELLIGENCE),
/// Dashboard (PHARMA+ principal).
/// Conserve les filtres et la période lors de la navigation.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../widgets/sales_sidebar_menu.dart';

/// Informations de navigation pour une sous-page.
class SalesPageInfo {
  final String id;
  final String title;
  final IconData icon;

  const SalesPageInfo({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// Ordre de navigation des 10 sous-pages.
class SalesPageOrder {
  static final List<SalesPageInfo> pages = [
    SalesPageInfo(id: 'overview', title: 'Vue générale', icon: Icons.dashboard_outlined),
    SalesPageInfo(id: 'analysis', title: 'Analyse des ventes', icon: Icons.bar_chart_outlined),
    SalesPageInfo(id: 'profits', title: 'Bénéfices & marges', icon: Icons.trending_up_outlined),
    SalesPageInfo(id: 'products', title: 'Produits vendus', icon: Icons.local_pharmacy),
    SalesPageInfo(id: 'employees', title: 'Performance employés', icon: Icons.people_outlined),
    SalesPageInfo(id: 'payments', title: 'Paiements & caisse', icon: Icons.account_balance_wallet_outlined),
    SalesPageInfo(id: 'returns', title: 'Annulations & retours', icon: Icons.cancel_outlined),
    SalesPageInfo(id: 'comparisons', title: 'Comparaisons', icon: Icons.compare_outlined),
    SalesPageInfo(id: 'reports', title: 'Rapports & exports', icon: Icons.description_outlined),
    SalesPageInfo(id: 'alerts', title: 'Alertes intelligentes', icon: Icons.notifications_outlined),
  ];

  static int indexOf(String id) {
    return pages.indexWhere((p) => p.id == id);
  }

  static SalesPageInfo? find(String id) {
    try {
      return pages.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static String nextId(String id) {
    final idx = indexOf(id);
    if (idx < 0 || idx >= pages.length - 1) return id;
    return pages[idx + 1].id;
  }

  static String previousId(String id) {
    final idx = indexOf(id);
    if (idx <= 0) return id;
    return pages[idx - 1].id;
  }
}

/// Contrôleur de navigation : historique, page courante, filtres conservés.
class SalesNavigationController extends ChangeNotifier {
  final SalesMenuController menu;
  String _currentId = 'overview';
  final List<String> _history = [];
  final Map<String, Map<String, dynamic>> _pageFilters = {};

  String get currentId => _currentId;
  SalesPageInfo? get currentPage => SalesPageOrder.find(_currentId);
  bool get hasPrevious => _history.isNotEmpty;
  bool get canGoNext => SalesPageOrder.nextId(_currentId) != _currentId;

  SalesNavigationController(this.menu);

  /// Navigue vers une page (ajoute à l'historique sauf si c'est la même).
  Future<void> navigateTo(String id) async {
    if (id == _currentId) return;
    if (_history.isEmpty || _history.last != _currentId) {
      _history.add(_currentId);
    }
    _currentId = id;
    menu.select(id);
    notifyListeners();
  }

  /// Retour à la page précédente.
  Future<void> goBack() async {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    _currentId = previous;
    menu.select(previous);
    notifyListeners();
  }

  /// Retour à la vue générale SALES INTELLIGENCE.
  Future<void> goHome() async {
    _history.clear();
    _currentId = 'overview';
    menu.select('overview');
    notifyListeners();
  }

  /// Passer au dashboard principal PHARMA+ (quitte SALES INTELLIGENCE).
  Future<void> goDashboard() async {
    _history.clear();
    notifyListeners();
  }

  /// Sauvegarde les filtres d'une page pour les restaurer au retour.
  void saveFilters(String pageId, Map<String, dynamic> filters) {
    _pageFilters[pageId] = filters;
    notifyListeners();
  }

  Map<String, dynamic>? getFilters(String pageId) =>
      _pageFilters[pageId];

  /// Bouton « Maison » : retourne à la vue générale.
  Widget buildHomeButton(BuildContext context, VoidCallback onPressed,
      {bool compact = false}) {
    return _navButton(
      icon: Icons.home_outlined,
      label: 'Maison',
      tooltip: 'Vue générale SALES INTELLIGENCE',
      color: AppColors.pharmaGold,
      onPressed: onPressed,
      compact: compact,
    );
  }

  /// Bouton « Dashboard » : quitte SALES INTELLIGENCE.
  Widget buildDashboardButton(BuildContext context, VoidCallback onPressed,
      {bool compact = false}) {
    return _navButton(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      tooltip: 'Retour Dashboard PHARMA+',
      color: AppColors.pharmaMuted.withValues(alpha: 0.9),
      onPressed: onPressed,
      compact: compact,
    );
  }

  /// Bouton « Précédent ».
  Widget buildPreviousButton(BuildContext context, VoidCallback onPressed,
      {bool compact = false}) {
    return _navButton(
      icon: Icons.chevron_left,
      label: 'Précédent',
      tooltip: 'Page précédente',
      color: AppColors.pharmaMuted.withValues(alpha: 0.9),
      onPressed: hasPrevious ? onPressed : () {},
      enabled: hasPrevious,
      compact: compact,
    );
  }

  /// Bouton « Suivant ».
  Widget buildNextButton(BuildContext context, VoidCallback onPressed,
      {bool compact = false}) {
    return _navButton(
      icon: Icons.chevron_right,
      label: 'Suivant',
      tooltip: 'Page suivante',
      color: AppColors.pharmaMuted.withValues(alpha: 0.9),
      onPressed: canGoNext ? onPressed : () {},
      enabled: canGoNext,
      compact: compact,
    );
  }

  /// Bouton « Retour » (historique).
  Widget buildBackButton(BuildContext context, VoidCallback onPressed) {
    return _navButton(
      icon: Icons.arrow_back,
      label: 'Retour',
      tooltip: 'Retour',
      color: AppColors.pharmaMuted.withValues(alpha: 0.9),
      onPressed: hasPrevious ? onPressed : () {},
      enabled: hasPrevious,
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
    bool enabled = true,
    bool compact = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: compact
                ? const EdgeInsets.all(8)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: 0.12)
                  : AppColors.pharmaSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.45)
                    : AppColors.dividerDark,
                width: 1,
              ),
            ),
            child: compact
                ? Icon(icon, size: 17, color: enabled ? color : AppColors.textDisabled)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 17, color: enabled ? color : AppColors.textDisabled),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: enabled ? color : AppColors.textDisabled,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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
