/// ============================================================
/// SUPER ADMIN — GESTION DES RÔLES ET PERMISSIONS
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';

/// Page de gestion des rôles et permissions (Super Admin)
class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;
  String? _error;
  String? _searchQuery;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.instance.get('/superadmin/roles', query: {
      'limit': 50,
      if (_searchQuery != null && _searchQuery!.isNotEmpty) 'q': _searchQuery!,
    });
    if (!mounted) return;
    if (!r.success) {
      setState(() { _loading = false; _error = r.error?.readableMessage ?? 'Erreur'; });
      return;
    }
    setState(() {
      _roles = ApiList.of(r.data);
      _loading = false;
    });
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchQuery = q.trim();
      _load(reset: true);
    });
  }

  Future<void> _createRole() async {
    final locale = context.read<AuthStore>().locale;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RoleForm(role: null),
        ),
      ),
    );
    if (saved == true) { _load(reset: true); }
  }

  Future<void> _editRole(Map<String, dynamic> role) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: RoleForm(role: role),
        ),
      ),
    );
    if (saved == true) _load(reset: true);
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final locale = context.read<AuthStore>().locale;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.t('deleteRole', locale)),
        content: Text('Supprimer le rôle "${role['name']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.t('cancel', locale))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(S.t('delete', locale), style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    final r = await ApiClient.instance.delete('/superadmin/roles/${role['id']}');
    if (mounted) {
      if (r.success) {
        _load(reset: true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('roleDeleted', locale))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error?.readableMessage ?? 'Erreur')));
      }
    }
  }

  void _managePermissions(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
          child: PermissionMatrixDialog(role: role, onSaved: () => _load(reset: true)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('roleManagement', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRole,
        icon: const Icon(Icons.add),
        label: Text(S.t('newRole', locale)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: AppSearchField(
                        hint: S.t('search', locale),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    Expanded(
                      child: _roles.isEmpty
                          ? Center(child: Text(S.t('noRoles', locale)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                              itemCount: _roles.length,
                              itemBuilder: (context, i) {
                                final r = _roles[i];
                                return _RoleCard(
                                  role: r,
                                  onEdit: () => _editRole(r),
                                  onPermissions: () => _managePermissions(r),
                                  onDelete: () => _deleteRole(r),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      );
  }
}

/// Carte de rôle
class _RoleCard extends StatelessWidget {
  final Map<String, dynamic> role;
  final VoidCallback onEdit;
  final VoidCallback onPermissions;
  final VoidCallback onDelete;

  const _RoleCard({
    required this.role,
    required this.onEdit,
    required this.onPermissions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final isSystem = role['is_system'] == true;
    final roleName = role['name']?.toString() ?? '';
    final roleDesc = role['description']?.toString() ?? '';
    final permissions = role['permissions'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: null,
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Color(0xFF3E2A00)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(roleName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              if (isSystem) StatusChip(label: 'Système', color: AppColors.info),
            ]),
            const SizedBox(height: 2),
            Text(roleDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              if (permissions is Map)
                for (final m in permissions.keys.take(3))
                  StatusChip(label: m.toString(), color: AppColors.info),
            ]),
          ])),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () { Navigator.pop(context); onEdit(); },
                child: Row(children: [const Icon(Icons.edit, size: 18, color: AppColors.pharmaGold), const SizedBox(width: 10), Text('Modifier')])),
              PopupMenuItem(
                onTap: () { Navigator.pop(context); onPermissions(); },
                child: Row(children: [const Icon(Icons.security, size: 18, color: AppColors.info), const SizedBox(width: 10), Text('Permissions')])),
              PopupMenuItem(
                onTap: () { Navigator.pop(context); onDelete(); },
                child: Row(children: [const Icon(Icons.delete, size: 18, color: AppColors.danger), const SizedBox(width: 10), Text('Supprimer', style: TextStyle(color: AppColors.danger))])),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Formulaire de rôle
class RoleForm extends StatefulWidget {
  final Map<String, dynamic>? role;
  const RoleForm({this.role});
  @override State<RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends State<RoleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: (widget.role?['name'] as String?) ?? '');
  late final _description = TextEditingController(text: (widget.role?['description'] as String?) ?? '');
  late final _code = TextEditingController(text: (widget.role?['code'] as String?) ?? '');
  bool _saving = false;
  bool _isSystem = false;

  @override
  void initState() {
    super.initState();
    _isSystem = widget.role?['is_system'] == true;
  }

  @override void dispose() { _name.dispose(); _description.dispose(); _code.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final body = {
      'name': _name.text.trim(),
      'code': _code.text.trim().toLowerCase(),
      'description': _description.text.trim(),
      'is_system': false,
    };
    final result = widget.role == null
        ? await ApiClient.instance.post('/superadmin/roles', body: body)
        : await ApiClient.instance.put('/superadmin/roles/${(widget.role!['id'] as String?)}', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.role == null ? 'Nouveau rôle' : 'Modifier rôle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(controller: _code, autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => v?.isEmpty == true ? 'Code requis' : null, decoration: InputDecoration(labelText: 'Code (unique)'), enabled: widget.role == null),
          const SizedBox(height: 12),
          TextFormField(controller: _name, autovalidateMode: AutovalidateMode.onUserInteraction, validator: (v) => v?.isEmpty == true ? 'Nom requis' : null, decoration: InputDecoration(labelText: S.t('name', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _description, decoration: InputDecoration(labelText: S.t('description', locale)), maxLines: 3),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: Text(S.t('cancel', locale)))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.check, loading: _saving, onPressed: _save)),
          ]),
        ])))));
  }
}

/// Dialogue de gestion des permissions (matrice)
class PermissionMatrixDialog extends StatefulWidget {
  final Map<String, dynamic> role;
  final VoidCallback onSaved;
  const PermissionMatrixDialog({required this.role, required this.onSaved});
  @override State<PermissionMatrixDialog> createState() => _PermissionMatrixDialogState();
}

class _PermissionMatrixDialogState extends State<PermissionMatrixDialog> {
  late Map<String, Set<PermissionAction>> _permissions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _permissions = {};
    final perms = widget.role['permissions'] as Map?;
    if (perms != null) {
      perms.forEach((k, v) {
        _permissions[k as String] = (v as List<dynamic>).map((e) => PermissionAction.values.byName(e as String)).toSet();
      });
    }
    // Initialiser avec les permissions par défaut du rôle si aucune
    if (_permissions.isEmpty) {
      final roleStr = (widget.role['code'] as String?) ?? '';
      final role = Role.values.firstWhere((r) => r.name == roleStr, orElse: () => Role.viewer);
      for (final m in Module.values) {
        _permissions[m.name] = PermissionChecker.getPermissions(role, Module.values.byName(m.name));
      }
    }
  }

  void _toggle(Module module, PermissionAction action) {
    setState(() {
      final set = _permissions[module.name] ?? {};
      if (set.contains(action)) {
        set.remove(action);
      } else {
        set.add(action);
      }
      _permissions[module.name] = set;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final permsJson = _permissions.map((k, v) => MapEntry(k, v.map((e) => e.name).toList()));
    final roleId = (widget.role['id'] as String?);
    if (roleId == null) return;
    final r = await ApiClient.instance.put('/superadmin/roles/$roleId', body: {'permissions': permsJson});
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error?.readableMessage ?? 'Erreur')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    final roleName = (widget.role['name'] as String?) ?? '';
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('Permissions: $roleName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(S.t('module', context.read<AuthStore>().locale), style: const TextStyle(fontWeight: FontWeight.w800))),
                  for (final a in PermissionAction.values) DataColumn(label: Text(a.name, style: const TextStyle(fontSize: 10)), numeric: true),
                ],
                rows: Module.values.map((m) {
                  final perms = _permissions[m.name] ?? {};
                  return DataRow(cells: [
                    DataCell(Text(S.t(m.name, locale), style: const TextStyle(fontWeight: FontWeight.w600))),
                    for (final a in PermissionAction.values)
                      DataCell(Checkbox(
                        value: _permissions[m.name]?.contains(a) ?? false,
                        onChanged: (v) => setState(() {
                          final set = _permissions[m.name] ?? {};
                          if (v ?? false) {
                            set.add(a);
                          } else {
                            set.remove(a);
                          }
                          _permissions[m.name] = set;
                        }),
                      )),
                  ]);
                }).toList(),
              ),
            )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : () { _save(); widget.onSaved(); }, child: Text(S.t('save', locale))),
            ],
          ),
        ],
      ),
    ),
  ),
);
}
}