import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/app_guards.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_logo.dart';
import '../../core/widgets/pharma_background.dart';
import '../../core/widgets/glass_card.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../pos/pos_page.dart';
import '../reports/reports_page.dart';
import '../scanner/scanner_page.dart';
import '../stock/stock_page.dart';

/// ============================================================
/// ESPACE EMPLOYÉ PHARMA+ — sous-dashboard simplifié.
/// Affiche UNIQUEMENT les modules autorisés par les permissions
/// réelles du rôle (RBAC module:action). Aucun accès au dashboard
/// administrateur. Les modules sensibles restent réservés.
/// ============================================================
class _EmployeeModule {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget? Function(Map<String, bool>) page;
  final bool Function(Map<String, bool>) visible;
  const _EmployeeModule(this.icon, this.label, this.subtitle,
      {required this.page, this.visible = _always});
  static bool _always(Map<String, bool> c) => true;
}

class EmployeeSpacePage extends StatelessWidget {
  const EmployeeSpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final user = auth.user;
    final locale = auth.locale;
    final can = <String, bool>{
      'sales:create': user?.hasPermission('sales:create') ?? false,
      'customers:view': user?.hasPermission('customers:view') ?? false,
      'stock:view': user?.hasPermission('stock:view') ?? false,
      'catalog:view': user?.hasPermission('catalog:view') ?? false,
      'reports:view': user?.hasPermission('reports:view') ?? false,
    };

    final modules = <_EmployeeModule>[
      _EmployeeModule(Icons.qr_code_scanner_rounded, 'Scanner',
          'Scanner un produit', page: (_) => const ScannerPage()),
      _EmployeeModule(
          Icons.point_of_sale_rounded, S.t('pos', locale),
          'Vente et encaissement',
          page: (c) => c['sales:create'] == true ? const PosPage() : null,
          visible: (c) => c['sales:create'] == true),
      _EmployeeModule(
          Icons.people_alt_rounded, S.t('customers', locale),
          'Fiches clients',
          page: (c) => c['customers:view'] == true ? const CustomersPage() : null,
          visible: (c) => c['customers:view'] == true),
      _EmployeeModule(
          Icons.inventory_2_rounded, S.t('stock', locale),
          'Consultation du stock',
          page: (c) => c['stock:view'] == true ? const StockPage() : null,
          visible: (c) => c['stock:view'] == true),
      _EmployeeModule(
          Icons.medication_rounded, S.t('catalog', locale),
          'Consultation du catalogue',
          page: (c) => c['catalog:view'] == true ? const CatalogPage() : null,
          visible: (c) => c['catalog:view'] == true),
      _EmployeeModule(
          Icons.insert_chart_rounded, S.t('reports', locale),
          'Ventes et performance',
          page: (c) => c['reports:view'] == true ? const ReportsPage() : null,
          visible: (c) => c['reports:view'] == true),
    ].where((m) => m.visible(can)).toList();
    return _Scaffold(
        modules: modules,
        user: user,
        locale: locale,
        can: can);
  }
}

class _Scaffold extends StatelessWidget {
  final List<_EmployeeModule> modules;
  final dynamic user;
  final String locale;
  final Map<String, bool> can;
  const _Scaffold(
      {required this.modules,
      required this.user,
      required this.locale,
      required this.can});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pharmaBg,
      body: PharmaBackground(
        assetImage: 'assets/images/background.webp',
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(children: [
                  const PharmaFullLogo(width: 132),
                  const Spacer(),
                  IconButton(
                    tooltip: S.t('logout', locale),
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.pharmaGold),
                    onPressed: () async {
                      final auth = context.read<AuthStore>();
                      if (await confirmSignOut(context)) {
                        await auth.signOut();
                      }
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${user?.fullName ?? ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    if ('${user?.roleName ?? ''}'.isNotEmpty)
                      Text('${user?.roleName ?? ''} · ${user?.pharmacyName ?? ''}',
                          style: const TextStyle(
                              color: AppColors.pharmaGold, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text('Espace Employé — modules autorisés uniquement',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 118,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (context, i) {
                    final m = modules[i];
                    final page = m.page(can);
                    if (page == null) return const SizedBox.shrink();
                    return GlassCard(
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => page)),
                      radius: BorderRadius.circular(18),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(m.icon, color: const Color(0xFF3E2A00)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(m.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5)),
                              const SizedBox(height: 3),
                              Text(m.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.pharmaGold),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

