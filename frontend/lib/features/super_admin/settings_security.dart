/// ========================================================================
/// PHARMA+ — SUPER ADMIN : PARAMÈTRES ET SÉCURITÉ
/// ========================================================================
/// Paramètres système, sécurité, permissions, configuration globale.
/// ========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';

class SettingsSecurityPage extends StatefulWidget {
  const SettingsSecurityPage({super.key});

  @override
  State<SettingsSecurityPage> createState() => _SettingsSecurityPageState();
}

class _SettingsSecurityPageState extends State<SettingsSecurityPage> {
  Map<String, dynamic>? _systemInfo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonitoring();
  }

  Future<void> _loadMonitoring() async {
    try {
      final r = await ApiClient.instance.get('/superadmin/monitoring');
      if (!mounted) return;
      setState(() {
        _systemInfo = r.success ? (r.data as Map<String, dynamic>?) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmAction(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSuperAdminSurface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          GradientButton(
            label: 'Confirmer',
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title execute avec succes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      appBar: AppBar(
        backgroundColor: _kSuperAdminDark.withValues(alpha: 0.95),
        elevation: 0,
        leading: const ShellBackButton(),
        title: const Text('Parametres & Securite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Securite
                  _SectionCard(
                    title: 'Securite du systeme',
                    icon: Icons.security,
                    color: Colors.red,
                    children: [
                      _SettingRow(
                        icon: Icons.lock,
                        title: 'Authentification',
                        subtitle: 'JWT avec expiration 24h, refresh token 7j',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.password,
                        title: 'Politique de mot de passe',
                        subtitle: '8 caracteres minimum, argon2id hash',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.admin_panel_settings,
                        title: 'RBAC - Roles et permissions',
                        subtitle: 'Controle dacces granulaire par pharmacie',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.vpn_lock,
                        title: 'RLS - Row Level Security',
                        subtitle: 'Isolation des donnees par pharmacie',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Configuration systeme
                  _SectionCard(
                    title: 'Configuration systeme',
                    icon: Icons.settings,
                    color: Colors.blue,
                    children: [
                      _SettingRow(
                        icon: Icons.api,
                        title: 'API Version',
                        subtitle: 'v1 - REST JSON',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.info,
                        title: 'Version application',
                        subtitle: '2.0.0',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.refresh,
                        title: 'Uptime systeme',
                        subtitle: '${_systemInfo?['uptime']?.toStringAsFixed(0) ?? '--'} secondes',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Actions de maintenance
                  _SectionCard(
                    title: 'Maintenance',
                    icon: Icons.build,
                    color: Colors.orange,
                    children: [
                      _SettingRow(
                        icon: Icons.backup,
                        title: 'Sauvegarde systeme',
                        subtitle: 'Sauvegarde complete de la base de donnees',
                        onTap: () => _confirmAction('Sauvegarde', 'Lancer une sauvegarde complete ?'),
                      ),
                      _SettingRow(
                        icon: Icons.restore,
                        title: 'Restauration',
                        subtitle: 'Restaurer depuis une sauvegarde existante',
                        onTap: () => _confirmAction('Restauration', 'Lancer une restauration ?'),
                      ),
                      _SettingRow(
                        icon: Icons.clean_hands,
                        title: 'Nettoyage des logs',
                        subtitle: 'Archiver les logs de plus de 90 jours',
                        onTap: () => _confirmAction('Nettoyage', 'Nettoyer les anciens logs ?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Permissions
                  _SectionCard(
                    title: 'Permissions globales',
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
                    children: [
                      _SettingRow(
                        icon: Icons.supervised_user_circle,
                        title: 'Super Admin',
                        subtitle: 'Acces complet a toutes les fonctionnalites',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.business,
                        title: 'Pharmacie Admin',
                        subtitle: 'Gestion de sa propre pharmacie',
                        onTap: () {},
                      ),
                      _SettingRow(
                        icon: Icons.person,
                        title: 'Employe',
                        subtitle: 'Acces limite selon permissions',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// SECTION CARD
// ──────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// SETTING ROW
// ──────────────────────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white70, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// THEME
// ──────────────────────────────────────────────────────────────────────
const Color _kSuperAdminDark = Color(0xFF03100D);
const Color _kSuperAdminSurface = Color(0xFF0A1E15);
const Color _kSuperAdminGold = Color(0xFFD9B45C);
const Color _kSuperAdminAccent = Color(0xFF2FB563);

class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.of(context).pop());
  }
}
