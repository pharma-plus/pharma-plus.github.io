import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/app_guards.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pharma_logo.dart';
import '../ai/ai_page.dart';
import '../audit/audit_page.dart';
import '../notifications/notifications_page.dart';
import '../scanner/scanner_page.dart';
import '../shell/shell_nav.dart';

/// Tableau de contrôle : grille de cartes (chargée seule à l'ouverture),
/// chaque outil ne charge ses données qu'au clic.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _syncing = false;

  /// Outil actif (null = grille seule, aucun appel API).
  String? _tool;

  Map<String, dynamic>? _pharmacy;
  bool _pharmacyLoading = true;
  bool _pharmacyLoaded = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _audit = [];
  bool _usersLoading = true;
  bool _auditLoading = true;
  bool _usersLoaded = false;
  bool _auditLoaded = false;
  String? _usersError;
  String? _auditError;

  Future<void> _loadPharmacy() async {
    final r = await ApiClient.instance.get('/pharmacies/me');
    if (!mounted) return;
    setState(() {
      final d = r.data;
      _pharmacy = r.success
          ? (d is Map<String, dynamic>
              ? d
              : (d is Map ? Map<String, dynamic>.from(d) : null))
          : null;
      _pharmacyLoading = false;
      _pharmacyLoaded = true;
    });
  }

  Future<void> _loadUsers() async {
    final r = await ApiClient.instance.get('/users?limit=100');
    if (!mounted) return;
    if (r.success) {
      // Non-destructif : accepte data=[...] et data={items/rows:[...]}.
      _users = ApiList.of(r.data);
    } else {
      _usersError = r.error?.readableMessage;
    }
    _usersLoading = false;
    _usersLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _loadRoles() async {
    final r = await ApiClient.instance.get('/roles');
    if (!mounted) return;
    if (r.success) {
      // Non-destructif : accepte data=[...] et data={items/rows:[...]}.
      _roles = ApiList.of(r.data);
      setState(() {}); // sans ça, les rôles ne s'affichaient jamais seuls
    }
  }

  Future<void> _loadAudit() async {
    final r = await ApiClient.instance.get('/audit?limit=50');
    if (!mounted) return;
    if (r.success) {
      // Non-destructif : accepte data=[...] et data={items/rows:[...]}.
      _audit = ApiList.of(r.data);
    } else {
      _auditError = r.error?.readableMessage;
    }
    _auditLoading = false;
    _auditLoaded = true;
    if (mounted) setState(() {});
  }

  /// Ouvre un outil : la grille seule ne déclenchait AUCUN appel API ;
  /// ici on ne charge que ce que l'outil demandé exige, une seule fois.
  Future<void> _openTool(String key) async {
    setState(() => _tool = key);
    final needsPharmacy =
        key == 'pharmacy' || key == 'users' || key == 'tva';
    if (needsPharmacy && !_pharmacyLoaded) await _loadPharmacy();
    if (key == 'users') {
      if (!_usersLoaded) await _loadUsers();
      if (_roles.isEmpty) await _loadRoles();
    }
    if (key == 'security' && !_auditLoaded) await _loadAudit();
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await SyncEngine.instance.sync(verbose: true);
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.t('synced', context.read<AuthStore>().locale))),
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
          decoration:
              const InputDecoration(hintText: 'https://api.exemple.com/api/v1'),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          leading: const ShellBackButton(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.t('settings', locale)),
              Text(
                S.t('controlCenterSub', locale),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
            ],
          )),
      body: _tool != null
          ? _buildToolView(context, locale)
          : _buildGrid(context, locale, user?.initials ?? '?'),
    );
  }

  /// Grille de cartes — seule vue chargée à l'ouverture (zéro appel API).
  Widget _buildGrid(BuildContext context, String locale, String initials) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 5
        : width >= 800
            ? 4
            : width >= 520
                ? 3
                : 2;

    final cards = <_CardDef>[
      _CardDef('cardPharmacy', Icons.local_pharmacy_outlined,
          available: true, onTap: () => _openTool('pharmacy')),
      _CardDef('users', Icons.people_alt_outlined,
          available: true, onTap: () => _openTool('users')),
      _CardDef('cardSecurity', Icons.lock_outline,
          available: true, onTap: () => _openTool('security')),
      _CardDef('tva', Icons.receipt_long_outlined,
          available: true, onTap: () => _openTool('tva')),
      _CardDef('cardTickets', Icons.confirmation_number_outlined,
          available: true, onTap: () => _openTool('tickets')),
      _CardDef('cardPayments', Icons.payments_outlined,
          available: false), // ⛔ MANQUANT : aucun module paiements branché
      _CardDef('cardPrinters', Icons.print_outlined,
          available: true, onTap: () => _openTool('printers')),
      _CardDef('cardScanner', Icons.qr_code_scanner,
          available: true, onTap: () => _openTool('scanner')),
      _CardDef('cardCash', Icons.point_of_sale_outlined,
          available: true, onTap: () => _openTool('cash')),
      _CardDef('stock', Icons.inventory_2_outlined,
          available: true, onTap: () => ShellNav.index.value = 4),
      _CardDef('suppliers', Icons.local_shipping_outlined,
          available: true, onTap: () => ShellNav.index.value = 5),
      _CardDef('sync', Icons.cloud_sync_outlined,
          available: true, onTap: () => _openTool('sync')),
      _CardDef('cardBackup', Icons.backup_outlined,
          available: false), // ⛔ MANQUANT : pas de sauvegarde dédiée
      _CardDef('reports', Icons.bar_chart_outlined,
          available: true, onTap: () => ShellNav.index.value = 9),
      _CardDef('cardAi', Icons.smart_toy_outlined,
          available: true,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiPage()))),
      _CardDef('cardAppearance', Icons.palette_outlined,
          available: true, onTap: () => _openTool('appearance')),
      _CardDef('cardDevices', Icons.devices_outlined,
          available: false), // ⛔ MANQUANT : pas de gestion d'appareils
      _CardDef('notifications', Icons.notifications_outlined,
          available: true,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()))),
      _CardDef('cardMaintenance', Icons.build_outlined,
          available: true, onTap: () => _openTool('maintenance')),
      _CardDef('cardReset', Icons.restart_alt_outlined,
          available: true, onTap: () => _openTool('reset')),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Row(
            children: [
              const PharmaFullLogo(width: 170),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3E2A00),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            for (final c in cards)
              _ControlCard(
                def: c,
                label: S.t(c.key, locale),
                unavailableLabel: S.t('notAvailable', locale),
              ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmSignOut(context)) {
              await context.read<AuthStore>().signOut();
            }
          },
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: Text(S.t('logout', locale),
              style: const TextStyle(color: AppColors.danger)),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('PHARMA+  v2.0.0',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ],
    );
  }

  /// Vue outil : affichée uniquement après clic sur une carte.
  Widget _buildToolView(BuildContext context, String locale) {
    final auth = context.watch<AuthStore>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              tooltip: S.t('backToGrid', locale),
              onPressed: () => setState(() => _tool = null),
            ),
            Text(_toolTitle(locale),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ..._buildToolContent(locale, auth),
        const SizedBox(height: 24),
      ],
    );
  }

  String _toolTitle(String locale) {
    switch (_tool) {
      case 'pharmacy':
        return S.t('pharmacyProfile', locale);
      case 'users':
        return S.t('users', locale);
      case 'security':
        return S.t('accountSecurity', locale);
      case 'tva':
        return S.t('tva', locale);
      case 'tickets':
      case 'printers':
        return S.t('cardTickets', locale);
      case 'scanner':
        return S.t('cardScanner', locale);
      case 'cash':
        return S.t('cardCash', locale);
      case 'sync':
        return S.t('sync', locale);
      case 'appearance':
        return S.t('cardAppearance', locale);
      case 'maintenance':
        return S.t('cardMaintenance', locale);
      case 'reset':
        return S.t('cardReset', locale);
      default:
        return S.t('settings', locale);
    }
  }

  List<Widget> _buildToolContent(String locale, AuthStore auth) {
    switch (_tool) {
      case 'pharmacy':
        return [
          _Section(
            title: S.t('pharmacyProfile', locale),
            child: _pharmacyLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _PharmacyProfileTile(
                    pharmacy: _pharmacy,
                    onSaved: _loadPharmacy,
                  ),
          ),
        ];
      case 'users':
        return [
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
        ];
      case 'security':
        return [
          _Section(
            title: S.t('accountSecurity', locale),
            child: ListTile(
              leading:
                  const Icon(Icons.lock_outline, color: AppColors.primary),
              title: Text(S.t('changePassword', locale)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
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
        ];
      case 'tva':
        return [
          _Section(
            title: 'Fiscalité — TVA',
            child: _TvaSection(
              pharmacy: _pharmacy,
              onSaved: _loadPharmacy,
            ),
          ),
        ];
      case 'tickets':
      case 'printers':
        return [
          _PrintingSection(
              pharmacyName: auth.user?.pharmacyName ?? 'PHARMA+'),
        ];
      case 'scanner':
        return [
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner,
                      color: AppColors.primary),
                  title: Text(S.t('cardScanner', locale)),
                  subtitle: const Text(
                      'Ouvrir le scanner code-barres produit'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScannerPage())),
                ),
              ],
            ),
          ),
        ];
      case 'cash':
        return [
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined,
                      color: AppColors.primary),
                  title: Text(S.t('cardCash', locale)),
                  subtitle: const Text('Ouvrir la caisse et les écritures'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuditPage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.point_of_sale,
                      color: AppColors.primary),
                  title: Text(S.t('pos', locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ShellNav.index.value = 2,
                ),
              ],
            ),
          ),
        ];
      case 'sync':
        return [
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined,
                      color: AppColors.primary),
                  title: Text(S.t('sync', locale)),
                  subtitle: Text(auth.baseUrl),
                  trailing: _syncing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  onTap: _syncNow,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined,
                      color: AppColors.primary),
                  title: Text(S.t('server', locale)),
                  subtitle: Text(auth.baseUrl),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _editServerUrl,
                ),
              ],
            ),
          ),
        ];
      case 'appearance':
        return [
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
                _RadioTheme(
                    label: S.t('system', locale),
                    mode: ThemeMode.system,
                    current: auth.themeMode),
                _RadioTheme(
                    label: S.t('light', locale),
                    mode: ThemeMode.light,
                    current: auth.themeMode),
                _RadioTheme(
                    label: S.t('dark', locale),
                    mode: ThemeMode.dark,
                    current: auth.themeMode),
              ],
            ),
          ),
        ];
      case 'maintenance':
      case 'reset':
        return [
          _Section(
            title: 'Maintenance — Réinitialisation',
            child: _MaintenanceSection(),
          ),
        ];
      default:
        return const [];
    }
  }

  Future<void> _changePassword() async {
    final locale = context.read<AuthStore>().locale;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(locale: locale),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('passwordChanged', locale))));
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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${p['city'] ?? ''} · ${p['phone'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (p['email'] != null)
                  Text('${p['email']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
            ]),
          ),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          ...users.map((u) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.2),
                  child: Text(
                      '${(u['first_name'] ?? '?')[0]}${(u['last_name'] ?? '')[0]}'
                          .toUpperCase()),
                ),
                title: Text('${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'),
                subtitle: Text('${u['email'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.restart_alt_outlined,
                      color: AppColors.warning),
                  tooltip: S.t('resetPassword', locale),
                  onPressed: () => _resetPassword(context, locale, u),
                ),
              )),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.person_add_alt_1_outlined,
              color: AppColors.primary),
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

  Future<void> _resetPassword(
      BuildContext context, String locale, Map<String, dynamic> u) async {
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (nv == null || nv.isEmpty) return;
    final res = await ApiClient.instance
        .post('/users/${u['id']}/reset-password', body: {'newPassword': nv});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.success
              ? S.t('passwordChanged', locale)
              : (res.error?.readableMessage ?? 'Erreur'))),
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
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
        ]),
      );
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (entries.isEmpty) {
      return Padding(
          padding: const EdgeInsets.all(14),
          child: Text(S.t('noActivity', locale)));
    }
    return Column(
      children: entries.take(20).map((a) {
        final who = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history_outlined,
              size: 18, color: AppColors.info),
          title: Text('${a['action']} · ${a['module'] ?? ''}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${who.isNotEmpty ? who : a['email'] ?? ''} · ${a['created_at'] ?? ''}',
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

  @override
  void dispose() {
    _cur.dispose();
    _nv.dispose();
    _conf.dispose();
    super.dispose();
  }

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
          TextField(
              controller: _cur,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: S.t('currentPassword', l))),
          const SizedBox(height: 10),
          TextField(
              controller: _nv,
              obscureText: true,
              decoration: InputDecoration(labelText: S.t('newPassword', l))),
          const SizedBox(height: 10),
          TextField(
              controller: _conf,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: S.t('confirmPassword', l))),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(child: Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 11))),
              ]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.t('cancel', l))),
        FilledButton(
            onPressed: _saving ? null : _submit, child: Text(S.t('save', l))),
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

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
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
            TextField(
                controller: _name,
                decoration: InputDecoration(labelText: S.t('name', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _address,
                decoration: InputDecoration(labelText: S.t('address', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _city,
                decoration: InputDecoration(labelText: S.t('city', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _phone,
                decoration: InputDecoration(labelText: S.t('phone', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: S.t('email', l))),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 11))),
                ]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.t('cancel', l))),
        FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(S.t('saveProfile', l))),
      ],
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  final String locale;
  final List<Map<String, dynamic>> roles;
  final String? pharmacyId;
  const _AddUserDialog(
      {required this.locale, required this.roles, this.pharmacyId});
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

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _roleId == null) {
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
            TextField(
                controller: _first,
                decoration: InputDecoration(labelText: S.t('firstName', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _last,
                decoration: InputDecoration(labelText: S.t('lastName', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: S.t('email', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _phone,
                decoration: InputDecoration(labelText: S.t('phone', l))),
            const SizedBox(height: 10),
            TextField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(labelText: S.t('newPassword', l))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _roleId,
              decoration: InputDecoration(labelText: S.t('role', l)),
              items: (() {
                final filtered = widget.pharmacyId == null
                    ? widget.roles
                    : widget.roles
                        .where((r) =>
                            r['pharmacy_id'] == null ||
                            r['pharmacy_id'] == widget.pharmacyId)
                        .toList();
                final list = filtered.isEmpty ? widget.roles : filtered;
                return list
                    .map((r) => DropdownMenuItem(
                        value: '${r['id']}', child: Text('${r['name']}')))
                    .toList();
              })(),
              onChanged: (v) => setState(() => _roleId = v),
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_err!, style: const TextStyle(color: AppColors.danger, fontSize: 11))),
                ]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.t('cancel', l))),
        FilledButton(
            onPressed: _saving ? null : _submit, child: Text(S.t('create', l))),
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
          child: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        GlassCard(child: child),
      ],
    );
  }
}

/// Définition d'une carte du Tableau de contrôle.
class _CardDef {
  final String key;
  final IconData icon;
  final bool available;
  final VoidCallback? onTap;
  const _CardDef(this.key, this.icon, {required this.available, this.onTap});
}

/// Carte icône du Tableau de contrôle (design premium or/vert pétrole).
class _ControlCard extends StatelessWidget {
  final _CardDef def;
  final String label;
  final String unavailableLabel;
  const _ControlCard({
    required this.def,
    required this.label,
    required this.unavailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = !def.available;
    return GlassCard(
      radius: BorderRadius.circular(18),
      onTap: () {
        if (unavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(unavailableLabel)),
          );
          return;
        }
        def.onTap?.call();
      },
      child: Opacity(
        opacity: unavailable ? 0.45 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(def.icon, color: const Color(0xFF3E2A00), size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioTheme extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  const _RadioTheme(
      {required this.label, required this.mode, required this.current});

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$doneLabel — boîte d\'impression ouverte')));
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
          onTap: _busy
              ? null
              : () => _run(
                  () => ReceiptPdf.printTestTicket(widget.pharmacyName),
                  'Ticket de test envoyé'),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.replay_outlined, color: AppColors.primary),
          title: const Text('Réimprimer le dernier ticket'),
          subtitle:
              const Text('Même contenu, même format — sans relancer la vente'),
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

/* ==================== FISCALITÉ — TAUX DE TVA PAR DÉFAUT ==================== */

/// Paramètres → Fiscalité → TVA (section 22 du cahier des charges).
/// Les taux par défaut sont configurables et stockés dans
/// pharmacies.settings.tva (merge JSONB, PUT /pharmacies/me, settings:edit).
/// Le taux effectif de chaque vente reste celui du produit, sauvegardé
/// dans la transaction : changer ces défauts ne modifie JAMAIS l'historique.
class _TvaSection extends StatefulWidget {
  final Map<String, dynamic>? pharmacy;
  final VoidCallback onSaved;
  const _TvaSection({required this.pharmacy, required this.onSaved});

  @override
  State<_TvaSection> createState() => _TvaSectionState();
}

class _TvaSectionState extends State<_TvaSection> {
  final _medication = TextEditingController();
  final _parapharmacie = TextEditingController();
  final _other = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tva = (widget.pharmacy?['settings'] is Map
            ? (widget.pharmacy!['settings'] as Map)['tva']
            : null) as Map?;
    _medication.text = '${_rate(tva?['medication'], 16)}';
    _parapharmacie.text = '${_rate(tva?['parapharmacie'], 20)}';
    _other.text = '${_rate(tva?['other'], 20)}';
  }

  @override
  void dispose() {
    _medication.dispose();
    _parapharmacie.dispose();
    _other.dispose();
    super.dispose();
  }

  double _rate(dynamic v, double def) => double.tryParse('$v') ?? def;

  Future<void> _save() async {
    if (_saving) return;
    final med = double.tryParse(_medication.text.replaceAll(',', '.'));
    final par = double.tryParse(_parapharmacie.text.replaceAll(',', '.'));
    final other = double.tryParse(_other.text.replaceAll(',', '.'));
    if (med == null || par == null || other == null ||
        med < 0 || par < 0 || other < 0 || med > 100 || par > 100 || other > 100) {
      setState(() => _error = 'Taux invalides (0 à 100 attendus).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await ApiClient.instance.put('/pharmacies/me', body: {
      'settings': {
        'tva': {
          'medication': med,
          'parapharmacie': par,
          'other': other,
        },
      },
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Taux de TVA par défaut enregistrés. '
              'Les ventes existantes restent inchangées.')));
      widget.onSaved();
    } else {
      setState(() =>
          _error = r.error?.readableMessage ?? 'Erreur d\u2019enregistrement');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _medication,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Médicaments (%)', suffixText: '%'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _parapharmacie,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Parapharmacie (%)', suffixText: '%'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _other,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Autre (%)', suffixText: '%'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        'Taux par défaut utilisés lors de la création de produits. '
        'Le taux réellement appliqué à chaque vente reste celui du produit, '
        'sauvegardé dans la transaction — l\u2019historique fiscal ne change jamais.',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
            const SizedBox(width: 6),
            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 11))),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ),
    ]);
  }
}

/// ============================================================
/// MAINTENANCE — Réinitialisations contrôlées (Phase 21).
/// · Ventes de test : supprime UNIQUEMENT les ventes marquées
///   'VENTE-TEST' (jamais les ventes réelles).
/// · Stock à zéro : quantités remises à 0, références conservées.
/// · Réinitialisation complète : volontairement NON automatisée
///   (protection des données de production).
/// Double confirmation : case cochée + texte REINITIALISER.
/// ============================================================
class _MaintenanceSection extends StatefulWidget {
  @override
  State<_MaintenanceSection> createState() => _MaintenanceSectionState();
}

class _MaintenanceSectionState extends State<_MaintenanceSection> {
  bool _busy = false;

  Future<void> _confirmAndRun(String level, String title, String description,
      String consequence) async {
    final checkedCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.pharmaSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Text('Conséquence : $consequence',
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: checkedCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tapez REINITIALISER pour confirmer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () =>
                  Navigator.pop(context, checkedCtrl.text.trim() == 'REINITIALISER'),
              child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await ApiClient.instance.post('/maintenance/reset',
        body: {'level': level, 'confirmation': 'REINITIALISER'});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r.success
          ? 'Réinitialisation effectuée : ${r.data}'
          : (r.error?.readableMessage ?? 'Échec')),
      backgroundColor: r.success ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Réinitialisation opérationnelle (données de démonstration/test '
          'uniquement). Le référentiel médicaments, les comptes, les '
          'paramètres et la structure Supabase ne sont JAMAIS touchés.',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.receipt_long_rounded,
              color: AppColors.warning),
          title: const Text('Ventes de test',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text(
              'Supprime uniquement les ventes marquées VENTE-TEST',
              style: TextStyle(fontSize: 12, color: Colors.white60)),
          onTap: () => _confirmAndRun(
              'test_sales',
              'Réinitialisation des ventes de test',
              'Recherche toutes les ventes marquées "VENTE-TEST" en notes.',
              'Ces ventes, leurs paiements et leurs mouvements de stock seront définitivement supprimés.'),
        ),
        const Divider(height: 1),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.inventory_2_outlined,
              color: AppColors.warning),
          title: const Text('Stock à zéro',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text(
              'Met toutes les quantités de stock à 0 (références conservées)',
              style: TextStyle(fontSize: 12, color: Colors.white60)),
          onTap: () => _confirmAndRun(
              'stock_zero',
              'Réinitialisation du stock',
              'Toutes les quantités de stock de la pharmacie seront mises à 0.',
              'Les références médicaments, le référentiel et le catalogue sont conservés.'),
        ),
        const Divider(height: 1),
        ListTile(
          enabled: false,
          leading:
              const Icon(Icons.dangerous_rounded, color: AppColors.danger),
          title: const Text('Réinitialisation complète',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
          subtitle: const Text(
              'Volontairement non automatisée — intervention manuelle requise',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFE9C873))),
          ),
      ],
    );
  }
}
