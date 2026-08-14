import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';

/// Portail réservé au Super Administrateur PHARMA+ :
/// statistiques globales, gestion des pharmacies, création, suspension.
class SuperAdminPortal extends StatefulWidget {
  const SuperAdminPortal({super.key});

  @override
  State<SuperAdminPortal> createState() => _SuperAdminPortalState();
}

class _SuperAdminPortalState extends State<SuperAdminPortal> {
  Map<String, dynamic>? _global;
  List<Map<String, dynamic>> _pharmacies = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _q;
  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active':
        return AppColors.success;
      case 'suspended':
        return AppColors.danger;
      case 'deleted':
        return Colors.grey;
      default:
        return AppColors.warning;
    }
  }

  String _licenseLabel(dynamic type, String locale) {
    switch ('$type') {
      case 'standard':
        return S.t('standard', locale);
      case 'professional':
        return S.t('professional', locale);
      case 'enterprise':
        return S.t('enterprise', locale);
      default:
        return S.t('trial', locale);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _pharmacies = [];
      _hasMore = true;
      setState(() => _loading = true);
    } else if (_loadingMore) {
      return;
    }
    setState(() => _loadingMore = !reset);
    final locale = context.read<AuthStore>().locale;
    final results = await Future.wait([
      if (reset)
        ApiClient.instance.get<Map<String, dynamic>>('/pharmacies/global-stats'),
      ApiClient.instance.get<Map<String, dynamic>>('/pharmacies',
          query: {
            'page': _page,
            'limit': _limit,
            if (_q != null && _q!.isNotEmpty) 'q': _q!,
          }),
    ]);

    if (!mounted) return;
    if (reset) _global = results[0].data;
    final listRes = results.last;
    if (!listRes.success) {
      setState(() {
        _error = listRes.error?.readableMessage ?? S.t('loadError', locale);
        _loading = false;
        _loadingMore = false;
      });
      return;
    }
    final items = (listRes.data?['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    _page++;
    if (items.length < _limit) _hasMore = false;
    setState(() {
      if (reset) {
        _pharmacies = items;
      } else {
        _pharmacies.addAll(items);
      }
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  Future<void> _create() async {
    final locale = context.read<AuthStore>().locale;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _PharmacyForm(),
    );
    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.t('pharmacyCreated', locale))));
        _load(reset: true);
      }
    }
  }

  void _openDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PharmacyDetail(pharmacy: p, onChanged: () => _load(reset: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(S.t('superAdminPortal', locale)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthStore>().signOut(),
            icon: const Icon(Icons.logout),
            label: Text(S.t('logout', locale)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_business_outlined),
        label: Text(S.t('newPharmacy', locale)),
      ),
      body: Column(
        children: [
          if (_global != null) _GlobalStats(global: _global!, locale: locale),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: S.t('searchPharmacy', locale),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) {
                _q = v.trim();
                _load(reset: true);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                    : _pharmacies.isEmpty
                        ? Center(child: Text(S.t('noPharmacies', locale)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: _pharmacies.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == _pharmacies.length) {
                                if (!_loadingMore) {
                                  Future.microtask(() => _load());
                                }
                                return const Center(
                                    child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ));
                              }
                              final p = _pharmacies[i];
                              final status = '${p['status']}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(14),
                                  onTap: () => _openDetail(p),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.goldGradient,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.local_pharmacy,
                                            color: Color(0xFF3E2A00)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${p['name']}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text('@${p['slug']} · ${p['city'] ?? ''}',
                                                style: const TextStyle(
                                                    fontSize: 12, color: Colors.grey)),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                StatusChip(
                                                    label: status == 'active'
                                                        ? S.t('pharmacyActive', locale)
                                                        : status == 'suspended'
                                                            ? S.t('suspended', locale)
                                                            : S.t('deleted', locale),
                                                    color: _statusColor(status)),
                                                StatusChip(
                                                    label: _licenseLabel(
                                                        p['license_type'], locale),
                                                    color: AppColors.info),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${p['nb_users'] ?? 0} ${S.t('nbUsers', locale)}',
                                              style: const TextStyle(fontSize: 12)),
                                          Text('${p['nb_branches'] ?? 0} ${S.t('nbBranches', locale)}',
                                              style: const TextStyle(fontSize: 12)),
                                          TextButton(
                                            onPressed: () => _openDetail(p),
                                            child: Text(S.t('manage', locale)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _GlobalStats extends StatelessWidget {
  final Map<String, dynamic> global;
  final String locale;
  const _GlobalStats({required this.global, required this.locale});

  @override
  Widget build(BuildContext context) {
    final ph = global['pharmacies'] as Map? ?? {};
    final tiles = [
      (S.t('totalPharmacies', locale), '${ph['total'] ?? 0}'),
      (S.t('active', locale), '${ph['active'] ?? 0}'),
      (S.t('totalUsers', locale), '${global['users'] ?? 0}'),
      (S.t('totalSales', locale), '${global['sales'] ?? 0}'),
      (S.t('totalRevenue', locale),
          '${(global['revenue'] ?? 0).toString()} MAD'),
      (S.t('licenseType', locale), '${global['activeLicenses'] ?? 0}'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tiles[i].$1,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(tiles[i].$2,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PharmacyForm extends StatefulWidget {
  const _PharmacyForm();
  @override
  State<_PharmacyForm> createState() => _PharmacyFormState();
}

class _PharmacyFormState extends State<_PharmacyForm> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _license = 'trial';
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _slug.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final result = await ApiClient.instance.post('/pharmacies', body: {
      'name': _name.text.trim(),
      'slug': _slug.text.trim().toLowerCase(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'admin_email': _email.text.trim(),
      'admin_password': _password.text.isNotEmpty ? _password.text : 'Admin123!',
      'license_type': _license,
    });
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? S.t('loadError', locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('newPharmacy', locale),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: S.t('name', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                decoration: InputDecoration(labelText: S.t('slug', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: InputDecoration(labelText: S.t('city', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: InputDecoration(labelText: S.t('phone', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: S.t('adminEmail', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: S.t('adminPassword', locale)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _license,
                decoration: InputDecoration(labelText: S.t('licenseType', locale)),
                items: ['trial', 'standard', 'professional', 'enterprise']
                    .map((l) => DropdownMenuItem(
                        value: l, child: Text(_licenseText(l, locale))))
                    .toList(),
                onChanged: (v) => setState(() => _license = v ?? 'trial'),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: S.t('createPharmacy', locale),
                icon: Icons.add_business_outlined,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _licenseText(String l, String locale) {
    switch (l) {
      case 'standard':
        return S.t('standard', locale);
      case 'professional':
        return S.t('professional', locale);
      case 'enterprise':
        return S.t('enterprise', locale);
      default:
        return S.t('trial', locale);
    }
  }
}

class _PharmacyDetail extends StatefulWidget {
  final Map<String, dynamic> pharmacy;
  final VoidCallback onChanged;
  const _PharmacyDetail({required this.pharmacy, required this.onChanged});

  @override
  State<_PharmacyDetail> createState() => _PharmacyDetailState();
}

class _PharmacyDetailState extends State<_PharmacyDetail> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/pharmacies/${widget.pharmacy['id']}/stats');
    if (!mounted) return;
    if (result.success) {
      setState(() => _stats = result.data);
    } else {
      setState(() => _error = result.error?.message);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active':
        return AppColors.success;
      case 'suspended':
        return AppColors.danger;
      case 'deleted':
        return Colors.grey;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _toggleStatus(String status) async {
    final locale = context.read<AuthStore>().locale;
    final result = await ApiClient.instance
        .post('/pharmacies/${widget.pharmacy['id']}/status', body: {'status': status});
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.t('statusUpdated', locale))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? S.t('loadError', locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final p = widget.pharmacy;
    final status = '${p['status']}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${p['name']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                StatusChip(
                    label: status == 'active'
                        ? S.t('pharmacyActive', locale)
                        : status == 'suspended'
                            ? S.t('suspended', locale)
                            : S.t('deleted', locale),
                    color: _statusColor(status)),
              ],
            ),
            const SizedBox(height: 6),
            Text('@${p['slug']} · ${p['city'] ?? ''} · ${p['phone'] ?? ''}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger))
            else if (_stats != null)
              Expanded(
                child: ListView(
                  children: [
                    _StatRow(S.t('nbUsers', locale), '${_stats!['users'] ?? 0}'),
                    _StatRow(S.t('nbBranches', locale), '${_stats!['branches'] ?? 0}'),
                    _StatRow(S.t('medications', locale), '${_stats!['medications'] ?? 0}'),
                    _StatRow(S.t('sales', locale), '${_stats!['sales']?['total'] ?? 0}'),
                    _StatRow(S.t('totalRevenue', locale),
                        '${(_stats!['revenue']?['total'] ?? 0)} MAD'),
                    _StatRow(S.t('licenseExpiry', locale),
                        '${_stats!['license']?['expiry_date'] ?? '—'}'),
                    const SizedBox(height: 16),
                    if (status == 'active')
                      GradientButton(
                        label: S.t('suspend', locale),
                        icon: Icons.block,
                        onPressed: () => _toggleStatus('suspended'),
                      )
                    else
                      GradientButton(
                        label: S.t('reactivate', locale),
                        icon: Icons.check_circle,
                        onPressed: () => _toggleStatus('active'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
