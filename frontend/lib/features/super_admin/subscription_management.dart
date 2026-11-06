/// ========================================================================
/// PHARMA+ — SUPER ADMIN : GESTION ABONNEMENTS BASIC / GOLD
/// ========================================================================
/// Gestion complète des plans d'abonnement, licences, activation,
/// suspension, renouvellement, et contrôle des permissions par formule.
/// ========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/shared/app_search_field.dart';
import '../../../core/widgets/status_chip.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() => _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage> {
  List<Map<String, dynamic>> _licenses = [];
  List<Map<String, dynamic>> _pharmacies = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'all';
  String _filterType = 'all';
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/licenses', query: {
          'limit': 100,
          if (_filterStatus != 'all') 'status': _filterStatus,
          if (_filterType != 'all') 'type': _filterType,
        }),
        ApiClient.instance.get('/pharmacies', query: {'limit': 200}),
      ]);
      if (!mounted) return;
      setState(() {
        _licenses = (results[0].success ? results[0].data : [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() as List<Map<String, dynamic>>;
        _pharmacies = (results[1].success ? results[1].data : [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _createLicense() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => LicenseFormDialog(pharmacies: _pharmacies),
    );
    if (result == true && mounted) _loadAll();
  }

  Future<void> _toggleLicenseStatus(String licenseId, String status) async {
    final locale = context.read<AuthStore>().locale;
    final result = await ApiClient.instance.post(
      '/licenses/$licenseId/status',
      body: {'status': status},
    );
    if (!mounted) return;
    if (result.success) {
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('licenseUpdated', locale))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? S.t('loadError', locale))),
      );
    }
  }

  Future<void> _renewLicense(String licenseId) async {
    final locale = context.read<AuthStore>().locale;
    final days = await showDialog<int>(
      context: context,
      builder: (_) => RenewDialog(),
    );
    if (days == null || !mounted) return;
    final result = await ApiClient.instance.post(
      '/licenses/$licenseId/renew',
      body: {'days': days},
    );
    if (result.success) {
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('licenseRenewed', locale))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? S.t('loadError', locale))),
      );
    }
  }

  String _planLabel(String? type, String locale) {
    switch (type) {
      case 'basic': return 'BASIC';
      case 'gold': return 'GOLD';
      case 'standard': return S.t('standard', locale);
      case 'professional': return S.t('professional', locale);
      case 'enterprise': return S.t('enterprise', locale);
      case 'trial': return S.t('trial', locale);
      default: return type ?? '—';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active': return Colors.green;
      case 'suspended': return Colors.orange;
      case 'expired': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    final filtered = _licenses.where((l) {
      final matchesStatus = _filterStatus == 'all' || l['status'] == _filterStatus;
      final matchesType = _filterType == 'all' || l['type'] == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          (l['pharmacy_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (l['type']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesStatus && matchesType && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      appBar: AppBar(
        backgroundColor: _kSuperAdminDark.withValues(alpha: 0.95),
        elevation: 0,
        leading: const ShellBackButton(),
        title: const Text('Abonnements BASIC / GOLD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          GradientButton(
            label: 'Nouvelle licence',
            icon: Icons.add_circle_outline,
            onPressed: _createLicense,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchField(
                              hint: 'Rechercher licence ou pharmacie',
                              onChanged: (v) {
                                _debounce?.cancel();
                                _debounce = Timer(const Duration(milliseconds: 300), () {
                                  if (mounted) setState(() => _searchQuery = v.trim());
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          _FilterChip(
                            label: 'Statut',
                            value: _filterStatus,
                            items: const ['all', 'active', 'suspended', 'expired'],
                            onChanged: (v) => setState(() => _filterStatus = v),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Formule',
                            value: _filterType,
                            items: const ['all', 'basic', 'gold', 'trial', 'standard', 'professional', 'enterprise'],
                            onChanged: (v) => setState(() => _filterType = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_licenses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _KPISummary(licenses: _licenses, locale: locale),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
                      : filtered.isEmpty
                          ? Center(child: Text('Aucune licence', style: TextStyle(color: Colors.white70)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _LicenseCard(
                                license: filtered[i],
                                locale: locale,
                                onToggle: _toggleLicenseStatus,
                                onRenew: _renewLicense,
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// KPI SUMMARY
// ──────────────────────────────────────────────────────────────────────
class _KPISummary extends StatelessWidget {
  final List<Map<String, dynamic>> licenses;
  final String locale;
  const _KPISummary({required this.licenses, required this.locale});

  @override
  Widget build(BuildContext context) {
    final active = licenses.where((l) => l['status'] == 'active').length;
    final suspended = licenses.where((l) => l['status'] == 'suspended').length;
    final expired = licenses.where((l) => l['status'] == 'expired').length;
    final basic = licenses.where((l) => l['type'] == 'basic').length;
    final gold = licenses.where((l) => l['type'] == 'gold').length;

    return Row(
      children: [
        _KPIItem('Total', licenses.length.toString(), Colors.white),
        _KPIItem('Actives', active.toString(), Colors.green),
        _KPIItem('Suspendues', suspended.toString(), Colors.orange),
        _KPIItem('Expirées', expired.toString(), Colors.red),
        _KPIItem('BASIC', basic.toString(), _kSuperAdminGold),
        _KPIItem('GOLD', gold.toString(), _kSuperAdminGoldLight),
      ],
    );
  }

  Widget _KPIItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSuperAdminSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// LICENSE CARD
// ──────────────────────────────────────────────────────────────────────
class _LicenseCard extends StatelessWidget {
  final Map<String, dynamic> license;
  final String locale;
  final Function(String, String) onToggle;
  final Function(String) onRenew;
  const _LicenseCard({required this.license, required this.locale, required this.onToggle, required this.onRenew});

  /// Couleur du badge de statut (copie locale : la méthode de la classe
  /// State parente n'est pas accessible depuis cette card).
  Color _statusColor(String? s) {
    switch (s) {
      case 'active': return Colors.green;
      case 'suspended': return Colors.orange;
      case 'expired': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = license['status'] as String? ?? 'active';
    final type = license['type'] as String? ?? 'trial';
    final isGold = type == 'gold';
    final isExpired = status == 'expired';
    final isSuspended = status == 'suspended';

    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      gradient: isGold
          ? LinearGradient(
              colors: [Color(0xFF1A1E12), Color(0xFF0A1E15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderColor: (isGold ? _kSuperAdminGoldLight : Colors.white).withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: isGold ? AppColors.goldGradient : null,
              color: !isGold ? Colors.white.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(type.toUpperCase(), style: TextStyle(color: isGold ? Color(0xFF03100D) : Colors.white70, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${license['pharmacy_name'] ?? 'Pharmacie'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    if (isGold)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _kSuperAdminGoldLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('GOLD', style: TextStyle(color: Color(0xFF03100D), fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${license['expiry_date']?.toString().substring(0, 10) ?? '—'} · ${license['type'] ?? '—'}', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(
                label: status == 'active' ? S.t('pharmacyActive', locale) : status == 'suspended' ? S.t('suspended', locale) : S.t('expired', locale),
                color: _statusColor(status),
              ),
              const SizedBox(height: 8),
              if (status == 'active')
                GradientButton(
                  label: 'Suspendre',
                  icon: Icons.block,
                  onPressed: () => onToggle(license['id'] as String? ?? '', 'suspended'),
                  fullWidth: false,
                )
              else if (status == 'suspended')
                GradientButton(
                  label: 'Réactiver',
                  icon: Icons.check_circle,
                  onPressed: () => onToggle(license['id'] as String? ?? '', 'active'),
                  fullWidth: false,
                )
              else
                GradientButton(
                  label: 'Renouveler',
                  icon: Icons.refresh,
                  onPressed: () => onRenew(license['id'] as String? ?? ''),
                  fullWidth: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ──────────────────────────────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String) onChanged;
  const _FilterChip({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  String _selected = '';
  @override
  void initState() {
    super.initState();
    _selected = widget.value;
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selected,
              items: widget.items.map((i) => DropdownMenuItem(
                value: i,
                child: Text(i.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 11)),
              )).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selected = v);
                  widget.onChanged(v);
                }
              },
              dropdownColor: _kSuperAdminSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// LICENSE FORM DIALOG
// ──────────────────────────────────────────────────────────────────────
class LicenseFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pharmacies;
  const LicenseFormDialog({required this.pharmacies});

  @override
  State<LicenseFormDialog> createState() => _LicenseFormDialogState();
}

class _LicenseFormDialogState extends State<LicenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyId = TextEditingController();
  String _type = 'basic';
  String _billingCycle = 'monthly';
  int _durationDays = 30;
  int _maxUsers = 1;
  int _maxBranches = 1;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kSuperAdminSurface,
      title: const Text('Nouvelle licence', style: TextStyle(color: Colors.white)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _pharmacyId.text.isNotEmpty ? _pharmacyId.text : null,
                  decoration: InputDecoration(labelText: 'Pharmacie'),
                  items: widget.pharmacies
                      .map<DropdownMenuItem<String>>(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'] as String? ?? '',
                          child: Text('${p['name']} (${p['slug']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => _pharmacyId.text = v ?? '',
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: InputDecoration(labelText: 'Type d\'abonnement'),
                  items: ['basic', 'gold', 'trial', 'standard', 'professional', 'enterprise'].map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.toUpperCase(), style: TextStyle(color: t == 'gold' ? _kSuperAdminGoldLight : Colors.white)),
                  )).toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _billingCycle,
                  decoration: InputDecoration(labelText: 'Cycle de facturation'),
                  items: ['monthly', 'annual'].map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c == 'monthly' ? 'Mensuel' : 'Annuel'),
                  )).toList(),
                  onChanged: (v) => setState(() => _billingCycle = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _durationDays.toString(),
                  decoration: InputDecoration(labelText: 'Durée (jours)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _durationDays = int.tryParse(v) ?? 30,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _maxUsers.toString(),
                  decoration: InputDecoration(labelText: 'Utilisateurs max'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _maxUsers = int.tryParse(v) ?? 1,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _maxBranches.toString(),
                  decoration: InputDecoration(labelText: 'Succursales max'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _maxBranches = int.tryParse(v) ?? 1,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        GradientButton(
          label: 'Créer',
          icon: Icons.add,
          onPressed: _saving ? null : _save,
          loading: _saving,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ApiClient.instance.post('/licenses', body: {
      'pharmacyId': _pharmacyId.text,
      'type': _type,
      'billing_cycle': _billingCycle,
      'duration_days': _durationDays,
      'max_users': _maxUsers,
      'max_branches': _maxBranches,
      'modules': {},
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')),
      );
    }
  }
}

/// ──────────────────────────────────────────────────────────────────────
// RENEW DIALOG
// ──────────────────────────────────────────────────────────────────────
class RenewDialog extends StatefulWidget {
  const RenewDialog();

  @override
  State<RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<RenewDialog> {
  int _days = 30;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kSuperAdminSurface,
      title: const Text('Renouveler la licence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nombre de jours de prolongation :'),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _days.toString(),
            keyboardType: TextInputType.number,
            onChanged: (v) => _days = int.tryParse(v) ?? 30,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        GradientButton(
          label: 'Renouveler',
          icon: Icons.refresh,
          onPressed: () => Navigator.pop(context, _days),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// THÈME
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

class AppColors {
  static const Color dark = Color(0xFF03100D);
  static const Color surface = Color(0xFF0A1E15);
  static const Color gold = Color(0xFFD9B45C);
  static const Color goldLight = Color(0xFFE9C873);
  static const Color accent = Color(0xFF2FB563);
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD9B45C), Color(0xFFE9C873)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color success = Color(0xFF2FB563);
  static const Color danger = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFF6AD55);
  static const Color info = Color(0xFF4299E1);
}
