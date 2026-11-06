/// ========================================================================
/// PHARMA+ — SUPER ADMIN : CRM, SUPPORT ET TICKETS
/// ========================================================================
/// Gestion des prospects, tickets support, contacts commerciaux et communication.
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
import '../../../core/widgets/shared/app_search_field.dart';
import '../../../core/widgets/status_chip.dart';

class CRMSupportPage extends StatefulWidget {
  const CRMSupportPage({super.key});

  @override
  State<CRMSupportPage> createState() => _CRMSupportPageState();
}

class _CRMSupportPageState extends State<CRMSupportPage> {
  List<Map<String, dynamic>> _prospects = [];
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  String _activeTab = 'prospects';
  String _searchQuery = '';
  Timer? _debounce;

  static const _tabs = [
    ('prospects', Icons.people_outline, 'Prospects'),
    ('tickets', Icons.support_agent_outlined, 'Tickets'),
  ];

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
        ApiClient.instance.get('/superadmin/dashboard-stats'),
        ApiClient.instance.get('/support/tickets', query: {'limit': 50}),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = (results[0].success ? results[0].data : null) as Map<String, dynamic>?;
        _tickets = List<Map<String, dynamic>>.from(
            (results[1].success ? results[1].data : []) as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createTicket() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => TicketFormDialog(),
    );
    if (result == true && mounted) _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    final filteredTickets = _tickets.where((t) =>
      _searchQuery.isEmpty ||
      (t['subject']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      (t['pharmacy_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();

    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      appBar: AppBar(
        backgroundColor: _kSuperAdminDark.withValues(alpha: 0.95),
        elevation: 0,
        leading: const ShellBackButton(),
        title: const Text('CRM & Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          GradientButton(
            label: 'Nouveau ticket',
            icon: Icons.add_circle_outline,
            onPressed: _createTicket,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _CRMKPI(stats: _stats, locale: locale),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: _tabs.map((e) => _TabChip(
                keyId: e.$1,
                icon: e.$2,
                label: e.$3,
                active: _activeTab == e.$1,
                onTap: () => setState(() => _activeTab = e.$1),
              )).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AppSearchField(
              hint: 'Rechercher tickets',
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _searchQuery = v.trim());
                });
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
                : _activeTab == 'tickets'
                    ? _buildTicketsList(filteredTickets, locale)
                    : _buildProspectsList(locale),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList(List<Map<String, dynamic>> tickets, String locale) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...tickets.take(15).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _kSuperAdminAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.support_agent, color: _kSuperAdminAccent, size: 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['subject'] as String? ?? 'Ticket', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${t['pharmacy_name'] ?? ''} · ${t['status'] ?? '—'}', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    StatusChip(
                      label: t['status'] == 'open' ? 'Ouvert' : t['status'] == 'closed' ? 'Fermé' : 'En cours',
                      color: t['status'] == 'open' ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          )).toList(),
          if (tickets.isEmpty) Center(child: Text('Aucun ticket', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildProspectsList(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prospects commerciaux', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Text('Aucun prospect enregistré', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Ajouter un prospect',
            icon: Icons.person_add,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Donnée d'une tuile KPI du CRM (utilitaire local).
class _Item {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Item(this.label, this.value, this.icon, this.color);
}

class _CRMKPI extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final String locale;
  const _CRMKPI({required this.stats, required this.locale});

  @override
  Widget build(BuildContext context) {
    final ph = stats?['pharmacies'] as Map? ?? {};
    final lic = stats?['licenses'] as Map? ?? {};
    final items = [
      _Item('Pharmacies totales', '${ph['total'] ?? 0}', Icons.local_pharmacy, Colors.white),
      _Item('Actives', '${ph['active'] ?? 0}', Icons.check_circle, Colors.green),
      _Item('Suspendues', '${ph['suspended'] ?? 0}', Icons.block, Colors.orange),
      _Item('Licences actives', '${lic['active'] ?? 0}', Icons.verified, Colors.green),
      _Item('Expirant bientôt', '${lic['expiring_soon'] ?? 0}', Icons.schedule, Colors.orange),
      _Item('Utilisateurs', '${stats?['users']?['total'] ?? 0}', Icons.people, Colors.white),
    ];
    return Row(
      children: items
          .map((e) => _KPIItem(e.label, e.value, e.icon, e.color))
          .toList(),
    );
  }

  Widget _KPIItem(String label, String value, IconData icon, Color color) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String keyId;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.keyId, required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        selected: active,
        onSelected: (_) => onTap(),
        selectedColor: _kSuperAdminGold,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class TicketFormDialog extends StatefulWidget {
  const TicketFormDialog();

  @override
  State<TicketFormDialog> createState() => _TicketFormDialogState();
}

class _TicketFormDialogState extends State<TicketFormDialog> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _pharmacyId = TextEditingController();
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kSuperAdminSurface,
      title: const Text('Nouveau ticket'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Sujet'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pharmacyId,
                  decoration: const InputDecoration(labelText: 'ID Pharmacie'),
                  keyboardType: TextInputType.number,
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
          onPressed: _saving ? null : () => Navigator.pop(context, true),
          loading: _saving,
        ),
      ],
    );
  }
}

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
