import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _syncing = false;

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
          decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:4000/api/v1'),
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
                  current: auth.themeMode,
                ),
                _RadioTheme(
                  label: S.t('light', locale),
                  mode: ThemeMode.light,
                  current: auth.themeMode,
                ),
                _RadioTheme(
                  label: S.t('dark', locale),
                  mode: ThemeMode.dark,
                  current: auth.themeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  onTap: _syncNow,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.dns_outlined, color: AppColors.primary),
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
            label: Text(S.t('logout', locale),
                style: const TextStyle(color: AppColors.danger)),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'PHARMA MAROC GOLD ENTERPRISE v2.0.0',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
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
