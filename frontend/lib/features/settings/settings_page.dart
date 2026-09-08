import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pharma_logo.dart';

/// Paramètres : profil pharmacie, compte/sécurité, utilisateurs, journal
/// d'activité, langue, thème, synchronisation et serveur.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _syncing = false;
  Map<String, dynamic>? _pharmacy;
  bool _pharmacyLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _audit = [];
  bool _usersLoading = true;
  bool _auditLoading = true;
  String? _usersError;
  String? _auditError;

  @override
  void initState() {
    super.initState();
    _loadPharmacy();
    _loadUsers();
    _loadRoles();
    _loadAudit();
  }

  Future<void> _loadPharmacy() async {
    final r = await ApiClient.instance.get<Map<String, dynamic>>('/pharmacies/me');
    if (!mounted) return;
    setState(() {
      _pharmacy = r.success ? r.data : null;
      _pharmacyLoading = false;
    });
  }

  Future<void> _loadUsers() async {
    final r = await ApiClient.instance.get<Map<String, dynamic>>('/users?limit=100');
    if (!mounted) return;
    if (r.success) {
      _users = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } else {
      _usersError = r.error?.readableMessage;
    }
    _usersLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadRoles() async {
    final r = await ApiClient.instance.get<Map<String, dynamic>>('/roles');
    if (!mounted) return;
    if (r.success) {
      _roles = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    }
  }

  Future<void> _loadAudit() async {
    final r = await ApiClient.instance.get<Map<String, dynamic>>('/audit?limit=50');
    if (!mounted) return;
    if (r.success) {
      _audit = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } else {
      _auditError = r.error?.readableMessage;
    }
    _auditLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await SyncEngine.instance.sync(verbose: true);
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('synced', context.read<AuthStore>().locale))),
      );
    }
  }

  Future<void> _editServerUrl() async {
    final auth = context.read<AuthStore>();
    final locale = auth.locale;
    final controller = TextEditingController(text: auth.baseUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('serverUrl', locale)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://api.exemple.com/api/v1'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.t('cancel', locale))),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(S.t('save', locale)),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      await auth.setBaseUrl(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final locale = auth.locale;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(S.t('settings', locale))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Carte de marque : logo officiel complet PHARMA+ ----
          GlassCard(
            child: Row(
              children: [
                const PharmaFullLogo(width: 190),
                const Spacer(),
                Text('v1.0.0',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: AppColors.goldGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3E2A00),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? '',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('pharmacyProfile', locale),
            child: _pharmacyLoading
                ? const Center(child: CircularProgressIndicator())
                : _PharmacyProfileTile(
                    pharmacy: _pharmacy,
                    onSaved: _loadPharmacy,
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('accountSecurity', locale),
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: Text(S.t('changePassword', locale)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('users', locale),
            child: _UsersTile(
              loading: _usersLoading,
              users: _users,
              roles: _roles,
              error: _usersError,
              pharmacyId: _pharmacy?['id'] as String?,
              onChanged: () {
                _loadUsers();
                _loadAudit();
              },
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('activityLog', locale),
            child: _AuditTile(
              loading: _auditLoading,
              entries: _audit,
              error: _auditError,
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('language', locale),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Français'),
                  selected: locale == 'fr',
                  onSelected: (_) => auth.setLocale('fr'),
                ),
                ChoiceChip(
                  label: const Text('العربية'),
                  selected: locale == 'ar',
                  onSelected: (_) => auth.setLocale('ar'),
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected: locale == 'en',
                  onSelected: (_) => auth.setLocale('en'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: S.t('theme', locale),
            child: Column(
              children: [
                _RadioTheme(label: S.t('system', locale), mode: ThemeMode.system, current: auth.themeMode),
                _RadioTheme(label: S.t('light', locale), mode: ThemeMode.light, current: auth.themeMode),
                _RadioTheme(label: S.t('dark', locale), mode: ThemeMode.dark, current: auth.themeMode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrintingSection(pharmacyName: auth.user?.pharmacyName ?? 'PHARMA+'),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
                  title: Text(S.t('sync', locale)),
                  subtitle: Text(auth.baseUrl),
                  trailing: _syncing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  onTap: _syncNow,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: Text(S.t('server', locale)),
                  subtitle: Text(auth.baseUrl),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _editServerUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: Text(S.t('logout', locale), style: const TextStyle(color: AppColors.danger)),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('PHARMA+  v2.0.0',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final locale = context.read<AuthStore>().locale;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(locale: locale),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.t('passwordChanged', locale))));
    }
  }
}

class _PharmacyProfileTile extends StatelessWidget {
  final Map<String, dynamic>? pharmacy;
  final VoidCallback onSaved;
  const _PharmacyProfileTile({this.pharmacy, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final p = pharmacy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p != null) ...[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name'] ?? ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${p['city'] ?? ''} · ${p['phone'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (p['email'] != null) Text('${p['email']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        ListTile(
          leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
          title: Text(S.t('edit', locale)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final saved = await showDialog<bool>(
              context: context,
              builder: (_) => _PharmacyEditDialog(locale: locale, pharmacy: p),
            );
            if (saved == true) onSaved();
          },
        ),
      ],
    );
  }
}

class _UsersTile extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> roles;
  final String? error;
  final VoidCallback onChanged;
  final String? pharmacyId;
  const _UsersTile({
    required this.loading,
    required this.users,
    required this.roles,
    this.error,
    required this.onChanged,
    this.pharmacyId,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Column(
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: AppColors.danger)),
          ),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          ...users.map((u) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                  child: Text('${(u['first_name'] ?? '?')[0]}${(u['last_name'] ?? '')[0]}'.toUpperCase()),
                ),
                title: Text('${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'),
                subtitle: Text('${u['email'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.restart_alt_outlined, color: AppColors.warning),
                  tooltip: S.t('resetPassword', locale),
                  onPressed: () => _resetPassword(context, locale, u),
                ),
              )),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
          title: Text(S.t('addUser', locale)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final created = await showDialog<bool>(
              context: context,
              builder: (_) => _AddUserDialog(
                locale: locale,
                roles: roles,
                pharmacyId: pharmacyId,
              ),
            );
            if (created == true) onChanged();
          },
        ),
      ],
    );
  }

  Future<void> _resetPassword(BuildContext context, String locale, Map<String, dynamic> u) async {
    final ctl = TextEditingController();
    final nv = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('resetPassword', locale)),
        content: TextField(
          controller: ctl,
          obscureText: true,
          decoration: InputDecoration(labelText: S.t('newPassword', locale)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('cancel', locale))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (nv == null || nv.isEmpty) return;
    final res = await ApiClient.instance
        .post('/users/${u['id']}/reset-password', body: {'newPassword': nv});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.success ? S.t('passwordChanged', locale) : (res.error?.readableMessage ?? 'Erreur'))),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> entries;
  final String? error;
  const _AuditTile({required this.loading, required this.entries, this.error});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: AppColors.danger)));
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (entries.isEmpty) {
      return Padding(padding: const EdgeInsets.all(14), child: Text(S.t('noActivity', locale)));
    }
    return Column(
      children: entries.take(20).map((a) {
        final who = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history_outlined, size: 18, color: AppColors.info),
          title: Text('${a['action']} · ${a['module'] ?? ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${who.isNotEmpty ? who : a['email'] ?? ''} · ${a['created_at'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        );
      }).toList(),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final String locale;
  const _ChangePasswordDialog({required this.locale});
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _cur = TextEditingController();
  final _nv = TextEditingController();
  final _conf = TextEditingController();
  String? _err;
  bool _saving = false;

  Future<void> _submit() async {
    if (_nv.text != _conf.text) {
      setState(() => _err = S.t('passwordMismatch', widget.locale));
      return;
    }
    if (_nv.text.length < 8) {
      setState(() => _err = S.t('passwordTooShort', widget.locale));
      return;
    }
    setState(() => _saving = true);
    final res = await ApiClient.instance.post('/auth/change-password',
        body: {'currentPassword': _cur.text, 'newPassword': _nv.text});
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _err = res.error?.readableMessage ?? S.t('loadError', widget.locale);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.locale;
    return AlertDialog(
      title: Text(S.t('changePassword', l)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _cur, obscureText: true, decoration: InputDecoration(labelText: S.t('currentPassword', l))),
          const SizedBox(height: 10),
          TextField(controller: _nv, obscureText: true, decoration: InputDecoration(labelText: S.t('newPassword', l))),
          const SizedBox(height: 10),
          TextField(controller: _conf, obscureText: true, decoration: InputDecoration(labelText: S.t('confirmPassword', l))),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', l))),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(S.t('save', l))),
      ],
    );
  }
}

class _PharmacyEditDialog extends StatefulWidget {
  final String locale;
  final Map<String, dynamic>? pharmacy;
  const _PharmacyEditDialog({required this.locale, this.pharmacy});
  @override
  State<_PharmacyEditDialog> createState() => _PharmacyEditDialogState();
}

class _PharmacyEditDialogState extends State<_PharmacyEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String? _err;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.pharmacy ?? {};
    _name = TextEditingController(text: '${p['name'] ?? ''}');
    _address = TextEditingController(text: '${p['address'] ?? ''}');
    _city = TextEditingController(text: '${p['city'] ?? ''}');
    _phone = TextEditingController(text: '${p['phone'] ?? ''}');
    _email = TextEditingController(text: '${p['email'] ?? ''}');
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final res = await ApiClient.instance.put('/pharmacies/me', body: {
      'name': _name.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
    });
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _err = res.error?.readableMessage ?? S.t('loadError', widget.locale);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.locale;
    return AlertDialog(
      title: Text(S.t('pharmacyProfile', l)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: S.t('name', l))),
            const SizedBox(height: 10),
            TextField(controller: _address, decoration: InputDecoration(labelText: S.t('address', l))),
            const SizedBox(height: 10),
            TextField(controller: _city, decoration: InputDecoration(labelText: S.t('city', l))),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: InputDecoration(labelText: S.t('phone', l))),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: S.t('email', l))),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', l))),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(S.t('saveProfile', l))),
      ],
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  final String locale;
  final List<Map<String, dynamic>> roles;
  final String? pharmacyId;
  const _AddUserDialog({required this.locale, required this.roles, this.pharmacyId});
  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  String? _roleId;
  String? _err;
  bool _saving = false;

  Future<void> _submit() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || _email.text.trim().isEmpty || _roleId == null) {
      setState(() => _err = S.t('loadError', widget.locale));
      return;
    }
    setState(() => _saving = true);
    final res = await ApiClient.instance.post('/users', body: {
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'role_id': _roleId,
      'password': _pass.text.isNotEmpty ? _pass.text : 'ChangeMe123!',
    });
    if (!mounted) return;
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _err = res.error?.readableMessage ?? S.t('loadError', widget.locale);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.locale;
    return AlertDialog(
      title: Text(S.t('addUser', l)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _first, decoration: InputDecoration(labelText: S.t('firstName', l))),
            const SizedBox(height: 10),
            TextField(controller: _last, decoration: InputDecoration(labelText: S.t('lastName', l))),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: S.t('email', l))),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: InputDecoration(labelText: S.t('phone', l))),
            const SizedBox(height: 10),
            TextField(controller: _pass, obscureText: true, decoration: InputDecoration(labelText: S.t('newPassword', l))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _roleId,
              decoration: InputDecoration(labelText: S.t('role', l)),
              items: (() {
                final filtered = widget.pharmacyId == null
                    ? widget.roles
                    : widget.roles
                        .where((r) => r['pharmacy_id'] == null || r['pharmacy_id'] == widget.pharmacyId)
                        .toList();
                final list = filtered.isEmpty ? widget.roles : filtered;
                return list
                    .map((r) => DropdownMenuItem(value: '${r['id']}', child: Text('${r['name']}')))
                    .toList();
              })(),
              onChanged: (v) => setState(() => _roleId = v),
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', l))),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(S.t('create', l))),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        GlassCard(child: child),
      ],
    );
  }
}

class _RadioTheme extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  const _RadioTheme({required this.label, required this.mode, required this.current});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Icon(
        current == mode ? Icons.radio_button_checked : Icons.radio_button_off,
        color: current == mode ? AppColors.primary : null,
      ),
      onTap: () => context.read<AuthStore>().setThemeMode(mode),
    );
  }
}

/// ============================================================
/// IMPRESSION (§16-18) — carte de réglages des tickets :
/// · largeur de rouleau 58 / 80 mm (préférence persistée)
/// · TICKET DE TEST : vérifie alignement et découpe sur
///   l'imprimante réelle via la boîte d'impression système
/// · RÉIMPRESSION du dernier ticket sans relancer la vente
/// Toute imprimante installée (thermique, USB, réseau, pilote
/// Windows) est proposée par la boîte d'impression du système.
/// ============================================================
class _PrintingSection extends StatefulWidget {
  final String pharmacyName;
  const _PrintingSection({required this.pharmacyName});
  @override
  State<_PrintingSection> createState() => _PrintingSectionState();
}

class _PrintingSectionState extends State<_PrintingSection> {
  ReceiptWidth _width = ReceiptWidth.mm80;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ReceiptPrefs.load().then((w) {
      if (!mounted) return;
      setState(() {
        _width = w;
        _loading = false;
      });
    });
  }

  Future<void> _setWidth(ReceiptWidth w) async {
    setState(() => _width = w);
    await ReceiptPrefs.save(w);
  }

  Future<void> _run(Future<void> Function() action, String doneLabel) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$doneLabel — boîte d\'impression ouverte')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impression impossible sur cet appareil')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return _Section(
      title: 'Impression des tickets',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- Format du rouleau : 58 mm / 80 mm ----
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Rouleau 58 mm'),
            selected: _width == ReceiptWidth.mm58,
            onSelected: (_) => _setWidth(ReceiptWidth.mm58),
          ),
          ChoiceChip(
            label: const Text('Rouleau 80 mm'),
            selected: _width == ReceiptWidth.mm80,
            onSelected: (_) => _setWidth(ReceiptWidth.mm80),
          ),
        ]),
        const SizedBox(height: 4),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.print_outlined, color: AppColors.primary),
          title: const Text('Ticket de test'),
          subtitle: const Text(
              'Vérifier l\'alignement et la découpe sur l\'imprimante'),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap:
              _busy ? null : () => _run(() => ReceiptPdf.printTestTicket(widget.pharmacyName), 'Ticket de test envoyé'),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading:
              const Icon(Icons.replay_outlined, color: AppColors.primary),
          title: const Text('Réimprimer le dernier ticket'),
          subtitle: const Text(
              'Même contenu, même format — sans relancer la vente'),
          enabled: ReceiptPdf.hasLastReceipt && !_busy,
          trailing: const Icon(Icons.chevron_right),
          onTap: (ReceiptPdf.hasLastReceipt && !_busy)
              ? () => _run(ReceiptPdf.reprintLast, 'Réimpression envoyée')
              : null,
        ),
        Text(
          'L\'impression passe par la boîte système : toutes les imprimantes '
          'installées (USB, réseau, Bluetooth via pilote, thermiques '
          '58/80 mm) sont utilisables. L\'ESC/POS brut n\'est pas '
          'disponible depuis le navigateur.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]),
    );
  }
}
