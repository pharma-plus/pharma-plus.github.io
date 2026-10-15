import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';

/// Page de gestion des utilisateurs (super-admin / admin pharmacie).
/// CRUD complet : créer, modifier, réinitialiser mot de passe, PIN, désactiver.
class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementState();
}

class _UsersManagementState extends State<UsersManagementPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/users', query: {
          'limit': 200,
          if (_filterStatus != null) 'status': _filterStatus,
        }),
        ApiClient.instance.get('/roles', query: {'limit': 50}),
        ApiClient.instance.get('/employees', query: {'limit': 500}),
      ]);
      if (!mounted) return;
      final usersRes = results[0];
      final rolesRes = results[1];
      final empRes = results[2];
      if (!usersRes.success) {
        setState(() {
          _error = usersRes.error?.message ?? 'Erreur de chargement';
          _loading = false;
        });
        return;
      }
      setState(() {
        _users = ApiList.of(usersRes.data ?? []);
        _roles = rolesRes.success ? ApiList.of(rolesRes.data ?? []) : [];
        _employees = empRes.success ? ApiList.of(empRes.data ?? []) : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addUser() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _UserFormDialog(roles: _roles, employees: _employees),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(
          user: user, roles: _roles, employees: _employees),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final locale = context.read<AuthStore>().locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Text(
            'Un nouveau mot de passe temporaire sera envoyé à ${user['email']}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiClient.instance
        .post('/users/${user['id']}/reset-password');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.success
          ? 'Mot de passe réinitialisé.'
          : res.error?.readableMessage ?? 'Erreur'),
    ));
  }

  Future<void> _resetPin(Map<String, dynamic> user) async {
    final pinCtrl = TextEditingController();
    final locale = context.read<AuthStore>().locale;
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Définir le PIN'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nouveau PIN (4 à 6 chiffres)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim()),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (newPin == null || newPin.isEmpty || !mounted) return;
    if (!RegExp(r'^\d{4,6}$').hasMatch(newPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le PIN doit contenir 4 à 6 chiffres.')));
      return;
    }
    // Note : PUT /auth/pin définit le PIN de l'utilisateur CONNECTÉ.
    // Pour définir le PIN d'un AUTRE utilisateur, le backend doit exposer
    // PUT /users/{id}/pin. Ici on utilise la route existante.
    final res = await ApiClient.instance.put('/users/${user['id']}/pin',
        body: {'pin': newPin});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.success
          ? 'PIN défini pour ${user['email']}.'
          : res.error?.readableMessage ?? 'Erreur'),
    ));
  }

  Future<void> _clearPin(Map<String, dynamic> user) async {
    final locale = context.read<AuthStore>().locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver le PIN'),
        content: Text(
          'Le PIN de ${user['email']} sera supprimé. '
          'Cette personne devra utiliser son mot de passe pour se connecter '
          'et ne pourra plus utiliser le changement rapide d\'employé.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Désactiver')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiClient.instance.delete('/users/${user['id']}/pin');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.success
          ? 'PIN désactivé pour ${user['email']}.'
          : res.error?.readableMessage ?? 'Erreur'),
    ));
    if (res.success) _loadAll();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final locale = context.read<AuthStore>().locale;
    final meId = context.read<AuthStore>().user?.id;
    if (meId != null && '${user['id']}' == meId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vous ne pouvez pas supprimer votre propre compte.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
          'Désactiver définitivement le compte de ${user['email']} ?\n\n'
          '· Les ventes et opérations déjà enregistrées sont conservées.\n'
          '· Le dossier historique de l\'employé rattaché n\'est pas effacé.\n'
          '· Le compte ne pourra plus se connecter.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiClient.instance.delete('/users/${user['id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.success
          ? 'Compte désactivé : ${user['email']}.'
          : res.error?.readableMessage ?? 'Erreur'),
    ));
    if (res.success) _loadAll();
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final current = '${user['status'] ?? 'active'}';
    final newStatus = current == 'active' ? 'inactive' : 'active';
    final label = newStatus == 'active' ? 'réactiver' : 'désactiver';
    final locale = context.read<AuthStore>().locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label ce compte'),
        content: Text(
            'Voulez-vous $label le compte de ${user['email']} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: newStatus == 'inactive'
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiClient.instance
        .put('/users/${user['id']}', body: {'status': newStatus});
    if (!mounted) return;
    if (res.success) {
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error?.readableMessage ?? 'Erreur')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final auth = context.watch<AuthStore>();
    // Seul un admin/super-admin (users:view) peut créer un utilisateur.
    final canCreate = auth.isSuperAdmin || auth.permissions.contains('users:view');
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(S.t('gestion_utilisateurs', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addUser,
            ),
        ],
      ),
      body: _buildBody(locale),
    );
  }

  Widget _buildBody(String locale) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadAll, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    return Column(
      children: [
        // Filtre statut
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tous'),
                selected: _filterStatus == null,
                onSelected: (_) {
                  setState(() => _filterStatus = null);
                  _loadAll();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Actifs'),
                selected: _filterStatus == 'active',
                onSelected: (_) {
                  setState(() => _filterStatus = 'active');
                  _loadAll();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Inactifs'),
                selected: _filterStatus == 'inactive',
                onSelected: (_) {
                  setState(() => _filterStatus = 'inactive');
                  _loadAll();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('Aucun utilisateur trouvé'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    final status = '${u['status'] ?? 'active'}';
                    final isActive = status == 'active';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: AppColors.pharmaSurface2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? AppColors.emerald
                              : AppColors.danger,
                          child: Text(
                            '${(u['first_name'] ?? '?')[0]}${(u['last_name'] ?? '?')[0]}'
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                              .trim(),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${u['email'] ?? ''} · ${u['role_name'] ?? u['role'] ?? 'Aucun rôle'}'
                          '${u['has_pin'] == true ? ' · PIN configuré' : ''}'
                          '${u['employee_name'] != null && '${u['employee_name']}'.isNotEmpty ? ' · Employé : ${u['employee_name']}' : ''}'
                          '${isActive ? '' : ' · DÉSACTIVÉ'}',
                          style: TextStyle(
                            color: isActive
                                ? AppColors.pharmaMuted
                                : AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'modifier':
                                _editUser(u);
                                break;
                              case 'password':
                                _resetPassword(u);
                                break;
                              case 'pin':
                                _resetPin(u);
                                break;
                              case 'pin-clear':
                                _clearPin(u);
                                break;
                              case 'delete':
                                _deleteUser(u);
                                break;
                              case 'status':
                                _toggleStatus(u);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'modifier', child: Text('Modifier')),
                            const PopupMenuItem(
                                value: 'password', child: Text('Mot de passe')),
                            const PopupMenuItem(
                                value: 'pin', child: Text('PIN')),
                            if (u['has_pin'] == true)
                              const PopupMenuItem(
                                  value: 'pin-clear',
                                  child: Text('Désactiver le PIN')),
                            PopupMenuItem(
                              value: 'status',
                              child: Text(isActive
                                  ? 'Désactiver'
                                  : 'Réactiver'),
                            ),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Supprimer le compte')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Formulaire création / modification d'utilisateur
// ────────────────────────────────────────────────────────────
class _UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> employees;
  const _UserFormDialog(
      {this.user, required this.roles, this.employees = const []});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final _first = TextEditingController(
      text: '${widget.user?['first_name'] ?? ''}');
  late final _last =
      TextEditingController(text: '${widget.user?['last_name'] ?? ''}');
  late final _email =
      TextEditingController(text: '${widget.user?['email'] ?? ''}');
  late final _phone =
      TextEditingController(text: '${widget.user?['phone'] ?? ''}');
  late final _pass = TextEditingController();
  String? _roleId;
  // '' = aucun employé (sentinelle « Aucun » du dropdown)
  String _employeeId = '';
  bool _saving = false;
  String? _err;

  /// Modules cochables : clé = slug, libellé affiché.
  static const _moduleOptions = <(String, String)>[
    ('pos', 'Point de vente'),
    ('catalog', 'Catalogue'),
    ('stock', 'Stock'),
    ('suppliers', 'Fournisseurs'),
    ('purchases', 'Achats'),
    ('customers', 'Clients'),
    ('employees', 'Employés'),
    ('reports', 'Rapports'),
    ('plan', 'Plan 3D'),
    ('settings', 'Paramètres'),
  ];

  /// État des cases à cocher : true = module visible.
  /// Initialisé depuis `visible_modules` de l'utilisateur (null = tout visible).
  late final Map<String, bool> _visibleModules;

  bool get _isEdit => widget.user != null;

  /// Employés rattachables : non archivés et soit libres, soit déjà
  /// rattachés à CET utilisateur (relation 1-1).
  List<Map<String, dynamic>> get _linkableEmployees => widget.employees
      .where((e) {
        if ('${e['status'] ?? ''}' == 'archived') return false;
        final linked = e['user_id'];
        return linked == null || '$linked' == '${widget.user?['id']}';
      })
      .toList();

  @override
  void initState() {
    super.initState();
    _roleId = widget.user?['role_id']?.toString();
    final emp = widget.user?['employee_id'];
    _employeeId = emp == null ? '' : '$emp';
    // Initialisation des checkboxes : si l'utilisateur a déjà des
    // visible_modules, on coche ceux-ci ; sinon tout est coché (défaut).
    final existing = widget.user?['visible_modules'];
    _visibleModules = {
      for (final (key, _) in _moduleOptions)
        key: existing is List ? existing.contains(key) : true,
    };
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      setState(() => _err = 'Prénom, nom et email sont obligatoires.');
      return;
    }
    if (!_isEdit && _pass.text.length < 8) {
      setState(() => _err = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    final body = <String, dynamic>{
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      if (_roleId != null) 'role_id': _roleId,
      if (!_isEdit && _pass.text.isNotEmpty) 'password': _pass.text,
      // Association employé <-> compte : null = aucun (PUT délie).
      'employee_id': _employeeId.isEmpty ? null : _employeeId,
      // Modules visibles : liste des clés cochées (null = tout visible).
      'visible_modules': _moduleOptions
          .where((m) => _visibleModules[m.$1] == true)
          .map((m) => m.$1)
          .toList(),
    };
    final res = _isEdit
        ? await ApiClient.instance
            .put('/users/${widget.user!['id']}', body: body)
        : await ApiClient.instance.post('/users', body: body);
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _err = res.error?.readableMessage ?? 'Erreur lors de l\'enregistrement.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                      controller: _first,
                      decoration:
                          const InputDecoration(labelText: 'Prénom')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: _last,
                      decoration:
                          const InputDecoration(labelText: 'Nom')),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isEdit, // email non modifiable en édition
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 10),
              if (!_isEdit)
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Mot de passe (min. 8 caractères)')),
              if (!_isEdit) const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _roleId,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: widget.roles
                    .map((r) => DropdownMenuItem(
                        value: '${r['id']}', child: Text('${r['name']}')))
                    .toList(),
                onChanged: (v) => setState(() => _roleId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _employeeId,
                decoration: const InputDecoration(
                    labelText: 'Employé associé (optionnel)'),
                items: [
                  const DropdownMenuItem<String>(
                      value: '', child: Text('Aucun')),
                  ..._linkableEmployees.map((e) => DropdownMenuItem<String>(
                        value: '${e['id']}',
                        child: Text(
                            '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'
                                .trim()),
                      )),
                  // Employé lié non présent dans la page chargée : on
                  // l'ajoute pour que la valeur initiale existe.
                  if (_employeeId.isNotEmpty &&
                      !_linkableEmployees
                          .any((e) => '${e['id']}' == _employeeId))
                    DropdownMenuItem<String>(
                      value: _employeeId,
                      child: Text(
                          '${widget.user?['employee_name'] ?? 'Employé lié'}'),
                    ),
                ],
                onChanged: (v) => setState(() => _employeeId = v ?? ''),
              ),
              const SizedBox(height: 14),
              // Section : modules visibles sur le dashboard.
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Modules visibles',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Décochez les modules à masquer pour cet utilisateur.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.pharmaMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  for (final (key, label) in _moduleOptions)
                    SizedBox(
                      width: 180,
                      child: CheckboxListTile(
                        value: _visibleModules[key] ?? true,
                        onChanged: (v) =>
                            setState(() => _visibleModules[key] = v ?? true),
                        title: Text(label,
                            style: const TextStyle(fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                ],
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_err!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '…' : 'Enregistrer')),
      ],
    );
  }
}
