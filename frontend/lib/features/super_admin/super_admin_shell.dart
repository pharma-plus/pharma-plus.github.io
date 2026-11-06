/// ========================================================================
/// PHARMA+ — SUPER ADMIN : SHELL NAVIGATION (Menu principal)
/// ========================================================================
/// Navigation laterale avec tous les modules Super Admin :
/// Dashboard, Pharmacies, Utilisateurs, Abonnements, WhatsApp,
/// Chatbot, CRM/Support, Rapports, Monitoring, Paramètres.
/// ========================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../../../core/theme/colors.dart' as core_colors;
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import 'super_admin_dashboard.dart';
import 'super_admin_portal.dart';
import 'subscription_management.dart';
import 'whatsapp_management.dart';
import 'chatbot_management.dart';
import 'crm_support.dart';
import 'reports_monitoring.dart';
import 'settings_security.dart';
import 'users_management_page.dart';
import 'role_management_page.dart';

/// Items de navigation Super Admin
class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Widget page;
  _NavItem({required this.id, required this.label, required this.icon, required this.color, required this.page});
}

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  String _selected = 'dashboard';
  Map<String, dynamic>? _globalStats;

  final List<_NavItem> _items = [];

  @override
  void initState() {
    super.initState();
    _buildItems();
    _loadStats();
  }

  void _buildItems() {
    _items
      ..add(_NavItem(id: 'dashboard', label: 'Tableau de bord', icon: Icons.dashboard, color: _kSuperAdminGold, page: const SuperAdminDashboardPage()))
      ..add(_NavItem(id: 'pharmacies', label: 'Pharmacies', icon: Icons.local_pharmacy, color: _kSuperAdminAccent, page: const SuperAdminPortal()))
      ..add(_NavItem(id: 'users', label: 'Utilisateurs', icon: Icons.people, color: Colors.blue, page: const UsersManagementPage()))
      ..add(_NavItem(id: 'subscriptions', label: 'Abonnements', icon: Icons.payment, color: _kSuperAdminGoldLight, page: const SubscriptionManagementPage()))
      ..add(_NavItem(id: 'whatsapp', label: 'WhatsApp', icon: Icons.chat, color: Colors.green, page: const WhatsAppManagementPage()))
      ..add(_NavItem(id: 'chatbot', label: 'Chatbot IA', icon: Icons.smart_toy, color: Colors.purple, page: const ChatbotManagementPage()))
      ..add(_NavItem(id: 'crm', label: 'CRM / Support', icon: Icons.support_agent, color: Colors.orange, page: const CRMSupportPage()))
      ..add(_NavItem(id: 'roles', label: 'Rôles & Permissions', icon: Icons.admin_panel_settings, color: Colors.purple, page: const RoleManagementPage()))
      ..add(_NavItem(id: 'reports', label: 'Rapports / Monitoring', icon: Icons.assignment, color: Colors.teal, page: const ReportsMonitoringPage()))
      ..add(_NavItem(id: 'settings', label: 'Paramètres / Securite', icon: Icons.settings, color: Colors.pink, page: const SettingsSecurityPage()));
  }

  Future<void> _loadStats() async {
    try {
      final r = await ApiClient.instance.get('/superadmin/dashboard-stats');
      if (!mounted) return;
      setState(() => _globalStats = r.success ? (r.data as Map<String, dynamic>?) : null);
    } catch (_) {}
  }

  Widget _buildItem(_NavItem item) {
    final isSelected = _selected == item.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isSelected ? item.color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selected = item.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? item.color : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: isSelected ? Color(0xFF03100D) : Colors.white70, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item.label, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = (_globalStats?['pharmacies'] as Map? ?? {});
    final lic = (_globalStats?['licenses'] as Map? ?? {});
    // Responsive : sous 800 px (smartphone / petite tablette), la sidebar
    // 280 px devient un drawer — le portail SA reste utilisable en portrait
    // au lieu d'un Row qui déborde de l'écran (le "nouveau dashboard invisible"
    // sur téléphone). Au-dessus de 800 px : layout PC inchangé.
    final compact = MediaQuery.sizeOf(context).width < 800;

    final sidebar = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kSuperAdminDark, Color(0xFF020A09)],
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: core_colors.AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield, color: Color(0xFF03100D), size: 22),
                ),
                const SizedBox(height: 12),
                const Text('PHARMA+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Super Admin', style: TextStyle(color: _kSuperAdminGold, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Stats rapides
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('APERÇU', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 12),
                _MiniStat('Pharmacies', '${ph['total'] ?? 0}', Icons.local_pharmacy, Colors.white),
                const SizedBox(height: 10),
                _MiniStat('Licences actives', '${lic['active'] ?? 0}', Icons.verified, Colors.green),
                const SizedBox(height: 10),
                _MiniStat('Suspendues', '${ph['suspended'] ?? 0}', Icons.block, Colors.orange),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Navigation
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('NAVIGATION', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
                ..._items.map((item) => _buildItem(item)).toList(),
              ],
            ),
          ),
          // Déconnexion
          Padding(
            padding: const EdgeInsets.all(20),
            child: GradientButton(
              label: 'Déconnexion',
              icon: Icons.logout,
              onPressed: () => context.read<AuthStore>().signOut(),
              fullWidth: true,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (compact) {
      return Scaffold(
        backgroundColor: _kSuperAdminDark,
        appBar: AppBar(
          backgroundColor: _kSuperAdminDark,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.shield, color: _kSuperAdminGold, size: 20),
              const SizedBox(width: 8),
              Text(
                _items.firstWhere((i) => i.id == _selected, orElse: () => _items.first).label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ),
        drawer: Drawer(backgroundColor: _kSuperAdminDark, child: SafeArea(child: sidebar)),
        body: SafeArea(child: _buildPage(_selected)),
      );
    }

    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: sidebar,
          ),
          // Contenu principal
          Expanded(
            child: _buildPage(_selected),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(String id) {
    final item = _items.firstWhere((i) => i.id == id, orElse: () => _items.first);
    return item.page;
  }

  Widget _MiniStat(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// THÈME SUPER ADMIN
// ──────────────────────────────────────────────────────────────────────
const Color _kSuperAdminDark = Color(0xFF03100D);
const Color _kSuperAdminSurface = Color(0xFF0A1E15);
const Color _kSuperAdminGold = Color(0xFFD9B45C);
const Color _kSuperAdminGoldLight = Color(0xFFE9C873);
const Color _kSuperAdminAccent = Color(0xFF2FB563);

class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.of(context).pop());
  }
}
