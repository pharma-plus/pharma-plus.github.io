import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/supplier_integration.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/shared/app_search_field.dart';

/// Page de gestion des connexions fournisseurs (Supplier Integration Hub)
class SupplierConnectivityPage extends StatefulWidget {
  const SupplierConnectivityPage({super.key});

  @override
  State<SupplierConnectivityPage> createState() => _SupplierConnectivityPageState();
}

class _SupplierConnectivityPageState extends State<SupplierConnectivityPage> {
  final _hub = SupplierIntegrationHub.instance;
  List<SupplierAdapterConfig> _configs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    // Charger depuis la base / SharedPreferences
    // Pour l'instant, on utilise des configs par défaut
    setState(() {
      _configs = _hub.configured;
      _loading = false;
    });
  }

  Future<void> _testConnection(String supplierCode) async {
    final adapter = _hub.get(supplierCode);
    if (adapter == null) return;
    
    final config = _configs.firstWhere((c) => c.supplierCode == supplierCode);
    setState(() => config.enabled = false); // Disable pendant test
    
    try {
      final result = await adapter.testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.success 
              ? 'Connexion OK (${result.latency?.inMilliseconds}ms)'
              : 'Échec: ${result.error}'),
          backgroundColor: result.success ? AppColors.success : AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => config.enabled = true);
    }
  }

  Future<void> _syncCatalog(String supplierCode) async {
    final adapter = _hub.get(supplierCode);
    if (adapter == null) return;

    setState(() => _loading = true);
    try {
      final result = await adapter.syncCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.success
              ? 'Sync OK: +${result.productsAdded} ~${result.productsUpdated} !${result.conflicts} (${result.duration.inSeconds}s)'
              : 'Échec sync: ${result.error}'),
          backgroundColor: result.success ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 8),
        ));
        _load();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSupplierDialog(onSaved: _load),
    );
  }

  void _editConfig(SupplierAdapterConfig config) {
    showDialog(
      context: context,
      builder: (_) => _EditSupplierDialog(config: config, onSaved: _load),
    );
  }

  void _toggleEnabled(SupplierAdapterConfig config) {
    setState(() => config.enabled = !config.enabled);
    // Persister...
  }

  void _deleteConfig(SupplierAdapterConfig config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la connexion'),
        content: Text('Supprimer "${config.displayName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      // Supprimer de la config persistée
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('supplierConnectivity', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.pharmaGold),
            tooltip: S.t('syncAll', locale),
            onPressed: _loading ? null : () => _syncAll(),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.pharmaGold),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _configs.isEmpty
                  ? _EmptyState(onAdd: _showAddDialog, locale: locale)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _configs.length,
                      itemBuilder: (context, i) {
                        final config = _configs[i];
                        final adapter = _hub.get(config.supplierCode);
                        return _SupplierCard(
                          config: config,
                          adapter: adapter,
                          onTest: () => _testConnection(config.supplierCode),
                          onSync: () => _syncCatalog(config.supplierCode),
                          onEdit: () => _editConfig(config),
                          onToggle: () => _toggleEnabled(config),
                          onDelete: () => _deleteConfig(config),
                        );
                      },
                    ),
    );
  }

  Future<void> _syncAll() async {
    setState(() => _loading = true);
    try {
      final results = await _hub.syncAllActive();
      if (mounted) {
        final ok = results.values.where((r) => r.success).length;
        final total = results.length;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync globale: $ok/$total OK'),
          backgroundColor: ok == total ? AppColors.success : AppColors.warning,
        ));
        _load();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final String locale;
  const _EmptyState({required this.onAdd, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.link_off, size: 64, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(S.t('noSupplierConnections', locale),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(S.t('addFirstConnection', locale),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          GradientButton(
            label: S.t('addConnection', locale),
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ]),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierAdapterConfig config;
  final SupplierAdapter? adapter;
  final VoidCallback onTest;
  final VoidCallback onSync;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.config,
    this.adapter,
    required this.onTest,
    required this.onSync,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: config.enabled ? AppColors.goldGradient : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            config.supplierCode == 'csv' ? Icons.file_upload : Icons.cloud_sync,
            color: config.enabled ? const Color(0xFF3E2A00) : Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(config.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              StatusChip(
                label: config.enabled ? 'Actif' : 'Inactif',
                color: config.enabled ? AppColors.success : Colors.grey,
              ),
            ]),
            const SizedBox(height: 4),
            Text(config.supplierCode.toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (config.lastSync != null) ...[
              const SizedBox(height: 4),
              Text('Dernière sync: ${DateFormat('dd/MM/yyyy HH:mm').format(config.lastSync!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Tester la connexion',
            icon: const Icon(Icons.wifi_find, size: 20, color: AppColors.pharmaGold),
            onPressed: onTest,
          ),
          IconButton(
            tooltip: 'Synchroniser',
            icon: const Icon(Icons.sync, size: 20, color: AppColors.emerald),
            onPressed: onSync,
          ),
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit, size: 20, color: AppColors.info),
            onPressed: onEdit,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                onTap: onToggle,
                child: Row(children: [
                  Icon(config.enabled ? Icons.pause : Icons.play_arrow, size: 18, color: AppColors.pharmaGold),
                  const SizedBox(width: 10),
                  Text(config.enabled ? 'Désactiver' : 'Activer'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                onTap: onDelete,
                child: Row(children: [
                  const Icon(Icons.delete, size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _AddSupplierDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddSupplierDialog({required this.onSaved});

  @override
  State<_AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<_AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  String _type = 'rest';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(S.t('newSupplierConnection', locale),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(labelText: S.t('code', locale)),
                validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: S.t('name', locale)),
                validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: S.t('connectionType', locale)),
                items: ['rest', 'oauth', 'csv', 'xml', 'edi']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'rest'),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale)))),
                const SizedBox(width: 12),
                Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.save, loading: _saving, onPressed: _save)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    // Sauvegarder config...
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pop(context, true);
      widget.onSaved();
    }
  }
}

class _EditSupplierDialog extends StatefulWidget {
  final SupplierAdapterConfig config;
  final VoidCallback onSaved;
  const _EditSupplierDialog({required this.config, required this.onSaved});

  @override
  State<_EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends State<_EditSupplierDialog> {
  late final _code = TextEditingController(text: widget.config.supplierCode);
  late final _name = TextEditingController(text: widget.config.displayName);
  late bool _enabled = widget.config.enabled;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(S.t('editConnection', locale),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(controller: _code, enabled: false, decoration: InputDecoration(labelText: S.t('code', locale))),
            const SizedBox(height: 12),
            TextFormField(controller: _name, decoration: InputDecoration(labelText: S.t('name', locale))),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(S.t('enabled', locale)),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale)))),
              const SizedBox(width: 12),
              Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.save, loading: false, onPressed: _save)),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Sauvegarder...
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }
}