import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../accounting/accounting_page.dart';
import '../ai/ai_page.dart';
import '../attendance/attendance_page.dart';
import '../cameras/cameras_page.dart';
import '../catalog/catalog_page.dart';
import '../customers/customers_page.dart';
import '../dashboard/dashboard_page.dart';
import '../employees/employees_page.dart';
import '../pos/pos_page.dart';
import '../prescriptions/prescriptions_page.dart';
import '../purchases/purchases_page.dart';
import '../reference/reference_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../stock/stock_page.dart';
import '../suppliers/suppliers_page.dart';
import '../website/website_page.dart';

/// Grille des modules : point d'entrée vers toutes les sections.
class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final tiles = <_ModuleTile>[
      _ModuleTile(
          icon: Icons.dashboard_outlined,
          label: S.t('dashboard', locale),
          builder: (_) => const DashboardPage()),
      _ModuleTile(
          icon: Icons.point_of_sale_outlined,
          label: S.t('pos', locale),
          builder: (_) => const PosPage()),
      _ModuleTile(
          icon: Icons.medication_outlined,
          label: S.t('catalog', locale),
          builder: (_) => const CatalogPage()),
      _ModuleTile(
          icon: Icons.inventory_2_outlined,
          label: S.t('stock', locale),
          builder: (_) => const StockPage()),
      _ModuleTile(
          icon: Icons.people_alt_outlined,
          label: S.t('customers', locale),
          builder: (_) => const CustomersPage()),
      _ModuleTile(
          icon: Icons.description_outlined,
          label: S.t('prescriptions', locale),
          builder: (_) => const PrescriptionsPage()),
      _ModuleTile(
          icon: Icons.badge_outlined,
          label: S.t('employees', locale),
          builder: (_) => const EmployeesPage()),
      _ModuleTile(
          icon: Icons.schedule_outlined,
          label: S.t('attendance', locale),
          builder: (_) => const AttendancePage()),
      _ModuleTile(
          icon: Icons.shopping_cart_outlined,
          label: S.t('purchases', locale),
          builder: (_) => const PurchasesPage()),
      _ModuleTile(
          icon: Icons.local_shipping_outlined,
          label: S.t('suppliers', locale),
          builder: (_) => const SuppliersPage()),
      _ModuleTile(
          icon: Icons.account_balance_outlined,
          label: S.t('accounting', locale),
          builder: (_) => const AccountingPage()),
      _ModuleTile(
          icon: Icons.bar_chart_outlined,
          label: S.t('reports', locale),
          builder: (_) => const ReportsPage()),
      _ModuleTile(
          icon: Icons.language_outlined,
          label: S.t('website', locale),
          builder: (_) => const WebsitePage()),
      _ModuleTile(
          icon: Icons.smart_toy_outlined,
          label: S.t('pharmaAi', locale),
          builder: (_) => const AiPage()),
      _ModuleTile(
          icon: Icons.medication_liquid_outlined,
          label: S.t('baseMaroc', locale),
          builder: (_) => const ReferencePage()),
      _ModuleTile(
          icon: Icons.videocam_outlined,
          label: S.t('cameras', locale),
          builder: (_) => const CamerasPage()),
      _ModuleTile(
          icon: Icons.settings_outlined,
          label: S.t('settings', locale),
          builder: (_) => const SettingsPage()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(S.t('modules', locale))),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;

  const _ModuleTile(
      {required this.icon, required this.label, required this.builder});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: BorderRadius.circular(20),
      onTap: () {
        final page = builder(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF3E2A00), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
