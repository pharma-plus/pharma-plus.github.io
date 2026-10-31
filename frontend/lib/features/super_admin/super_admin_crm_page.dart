/// ============================================================
/// SUPER ADMIN — CRM Commercial & Gestion Société
/// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';

/// Portail Super Admin — CRM commercial, facturation, support
class SuperAdminCRMPage extends StatefulWidget {
  const SuperAdminCRMPage({super.key});

  @override
  State<SuperAdminCRMPage> createState() => _SuperAdminCRMPageState();
}

class _SuperAdminCRMPageState extends State<SuperAdminCRMPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _prospects = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _globalStats;
  bool _loading = true;
  String? _error;
  String _activeTab = 'pharmacies';
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  static const _tabs = [
    ('pharmacies', Icons.local_pharmacy_outlined, 'pharmacies'),
    ('prospects', Icons.people_outline, 'prospects'),
    ('invoices', Icons.receipt_long_outlined, 'invoices'),
    ('tickets', Icons.support_agent_outlined, 'tickets'),
    ('analytics', Icons.analytics_outlined, 'analytics'),
    ('roles', Icons.admin_panel_settings_outlined, 'roles'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      if (mounted) setState(() => _loading = true);
    } else if (_loadingMore) {
      return;
    }
    setState(() => _loadingMore = !reset);

    final locale = context.read<AuthStore>().locale;
    final results = await Future.wait([
      if (reset) ApiClient.instance.get('/superadmin/stats'),
      ApiClient.instance.get('/superadmin/${_activeTab}', query: {
        'page': _page,
        'limit': 20,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      }),
    ]);

    if (!mounted) return;
    if (reset) {
      final statsRes = results[0];
      if (statsRes.success) {
        final d = statsRes.data;
        setState(() {
          _globalStats = d is Map<String, dynamic> ? d : (d is Map ? Map<String, dynamic>.from(d) : null);
        });
      }
    }
    final listRes = results.last;
    if (!listRes.success) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = listRes.error?.readableMessage ?? S.t('loadError', locale);
        });
      }
      return;
    }
    final items = _parseList(listRes.data);
    if (mounted) {
      setState(() {
        if (reset) {
          switch (_activeTab) {
            case 'pharmacies':
              _pharmacies = items;
              break;
            case 'prospects':
              _prospects = items;
              break;
            case 'invoices':
              _invoices = items;
              break;
            case 'tickets':
              _tickets = items;
              break;
            case 'roles':
              // handled separately
              break;
          }
        } else {
          switch (_activeTab) {
            case 'pharmacies':
              _pharmacies.addAll(items);
              break;
            case 'prospects':
              _prospects.addAll(items);
              break;
            case 'invoices':
              _invoices.addAll(items);
              break;
            case 'tickets':
              _tickets.addAll(items);
              break;
          }
        }
        _page++;
        if (items.length < 20) _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _load(reset: true);
  });

  bool get _hasActiveFilters => _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('superAdminCRM', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: AppColors.pharmaGold),
            onPressed: () => setState(() => _activeTab = 'analytics'),
            tooltip: S.t('analytics', locale),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(children: [
        // Onglets
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            segments: [
              for (final (key, icon, label) in _tabs)
                ButtonSegment(
                  value: key,
                  icon: Icon(icon, size: 18),
                  label: Text(S.t(label, locale)),
                ),
            ],
            selected: {_activeTab},
            onSelectionChanged: (sel) => setState(() {
              _activeTab = sel.first;
              _load(reset: true);
            }),
          ),
        ),
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppSearchField(
            controller: _search,
            hint: S.t('search', locale),
            showFilterButton: false,
            debounceDuration: Duration.zero,
            onChanged: _onSearchChanged,
          ),
        ),
        // Filtres actifs
        if (_hasActiveFilters)
          _ActiveFilterBar(onClear: _clearFilters, locale: locale),
        // Liste
        Expanded(
          child: _loading && _activeTab != 'analytics'
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _getCurrentList().isEmpty
                      ? _EmptyState(onAdd: _showCreateDialog, locale: locale, activeTab: _activeTab)
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: _activeTab == 'analytics'
                              ? _buildAnalytics(locale)
                              : _buildListView(locale),
                        ),
        ),
      ]),
      floatingActionButton: _activeTab != 'analytics' && _activeTab != 'roles'
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: Text(S.t('create', locale)),
            )
          : null,
    );
  }

  List<Map<String, dynamic>> _getCurrentList() {
    switch (_activeTab) {
      case 'pharmacies':
        return _pharmacies;
      case 'prospects':
        return _prospects;
      case 'invoices':
        return _invoices;
      case 'tickets':
        return _tickets;
      case 'roles':
        return [];
      default:
        return [];
    }
  }

  Widget _buildListView(String locale) {
    final items = _getCurrentList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      itemCount: items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          if (!_loadingMore) Future.microtask(() => _load());
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final item = items[i];
        return _buildItemCard(item, locale);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String locale) {
    switch (_activeTab) {
      case 'pharmacies':
        return _PharmacyCard(item: item, locale: locale, onTap: () => _showDetail(item));
      case 'prospects':
        return _ProspectCard(item: item, locale: locale, onTap: () => _showDetail(item));
      case 'invoices':
        return _InvoiceCard(item: item, locale: locale);
      case 'tickets':
        return _TicketCard(item: item, locale: locale);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAnalytics(String locale) {
    final stats = _globalStats ?? {};
    final ph = stats['pharmacies'] as Map? ?? {};
    final tiles = [
      (S.t('totalPharmacies', locale), '${ph['total'] ?? 0}'),
      (S.t('active', locale), '${ph['active'] ?? 0}'),
      (S.t('totalUsers', locale), '${stats['users'] ?? 0}'),
      (S.t('totalSales', locale), '${stats['sales'] ?? 0}'),
      (S.t('totalRevenue', locale), '${(stats['revenue'] ?? 0).toString()} MAD'),
      (S.t('licenseType', locale), '${stats['activeLicenses'] ?? 0}'),
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
              Text(tiles[i].$1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(tiles[i].$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: switch (_activeTab) {
            'pharmacies' => _PharmacyForm(onSaved: () => _load(reset: true)),
            'prospects' => _ProspectForm(onSaved: () => _load(reset: true)),
            'invoices' => _InvoiceForm(onSaved: () => _load(reset: true)),
            'tickets' => _TicketForm(onSaved: () => _load(reset: true)),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(item: item, activeTab: _activeTab, onChanged: () => _load(reset: true)),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  final VoidCallback onClear;
  final String locale;
  const _ActiveFilterBar({required this.onClear, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(child: Wrap(spacing: 8, children: [
          // Filtres actifs affichés ici
        ])),
        TextButton.icon(onPressed: onClear, icon: const Icon(Icons.filter_alt_off, size: 16), label: Text(S.t('clearFilters', locale))),
      ]),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String locale;
  final VoidCallback onTap;
  const _PharmacyCard({required this.item, required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_pharmacy, color: Color(0xFF3E2A00))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text('@${item['slug']} · ${item['city'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              StatusChip(label: status == 'active' ? S.t('pharmacyActive', locale) : status == 'suspended' ? S.t('suspended', locale) : S.t('deleted', locale), color: status == 'active' ? AppColors.success : status == 'suspended' ? AppColors.danger : Colors.grey),
              StatusChip(label: item['license_type']?.toString().capitalize() ?? S.t('trial', locale), color: AppColors.info),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${item['nb_users'] ?? 0} ${S.t('nbUsers', locale)}', style: const TextStyle(fontSize: 12)),
            Text('${item['nb_branches'] ?? 0} ${S.t('nbBranches', locale)}', style: const TextStyle(fontSize: 12)),
            TextButton(onPressed: onTap, child: Text(S.t('manage', locale))),
          ]),
        ]),
      ),
    );
  }
}

class _ProspectCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String locale;
  final VoidCallback onTap;
  const _ProspectCard({required this.item, required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(padding: const EdgeInsets.all(14), onTap: onTap, child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_outline, color: AppColors.info)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${item['company'] ?? ''} · ${item['email'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusChip(label: item['status']?.toString().capitalize() ?? 'Nouveau', color: AppColors.info),
          const SizedBox(height: 4),
          Text('${item['estimated_value'] != null ? '${item['estimated_value']} MAD' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ])
    )
  );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String locale;
  const _InvoiceCard({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(radius: BorderRadius.circular(16), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          const Icon(Icons.receipt_long, color: AppColors.pharmaGold, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${item['pharmacy_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusChip(label: '${item['status']}', color: item['status'] == 'paid' ? AppColors.success : item['status'] == 'pending' ? AppColors.warning : AppColors.danger),
            Text(Fmt.money(double.tryParse('${item['amount'] ?? 0}') ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.pharmaGold)),
          ]),
        ])
    )
  );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String locale;
  const _TicketCard({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(radius: BorderRadius.circular(16), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), onTap: () {},
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.support_agent, color: AppColors.info)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['subject']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${item['pharmacy_name'] ?? ''} · ${item['created_at'] != null ? DateTime.tryParse('${item['created_at']}')?.toString().substring(0, 10) : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          StatusChip(label: item['status']?.toString().capitalize() ?? 'Open', color: item['status'] == 'resolved' ? AppColors.success : item['status'] == 'in_progress' ? AppColors.warning : AppColors.danger),
        ])
    )
  );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final String locale;
  final String activeTab;
  const _EmptyState({required this.onAdd, required this.locale, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    String emptyTitle = 'no${activeTab.capitalize()}';
    String emptySubtitle = 'addFirst${activeTab.capitalize()}';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(S.t(emptyTitle, locale),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(S.t(emptySubtitle, locale),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          GradientButton(label: S.t('create', locale), icon: Icons.add, onPressed: onAdd),
        ]),
      ),
    );
  }
}

// Forms
class _PharmacyForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _PharmacyForm({required this.onSaved});
  @override State<_PharmacyForm> createState() => _PharmacyFormState();
}

class _PharmacyFormState extends State<_PharmacyForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _city = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _licenseType = 'trial';
  bool _saving = false;

  @override void dispose() { _name.dispose(); _slug.dispose(); _city.dispose(); _email.dispose(); _phone.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final body = {
      'name': _name.text.trim(),
      'slug': _slug.text.trim().toLowerCase(),
      'city': _city.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'license_type': _licenseType,
    };
    final result = await ApiClient.instance.post('/superadmin/pharmacies', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      widget.onSaved();
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
          Text(S.t('newPharmacy', locale), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(controller: _name, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('name', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _slug, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('slug', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _city, decoration: InputDecoration(labelText: S.t('city', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _email, decoration: InputDecoration(labelText: S.t('email', locale)), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, decoration: InputDecoration(labelText: S.t('phone', locale)), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: InputDecoration(labelText: S.t('address', locale)), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _licenseType,
            decoration: InputDecoration(labelText: S.t('licenseType', locale)),
            items: ['trial', 'standard', 'professional', 'enterprise'].map((e) => DropdownMenuItem(value: e, child: Text(S.t(e, locale)))).toList(),
            onChanged: (v) => setState(() => _licenseType = v!),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: Text(S.t('cancel', locale)))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.check, loading: _saving, onPressed: _save)),
          ]),
        ])))));
  }
}

class _ProspectForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _ProspectForm({required this.onSaved});
  @override State<_ProspectForm> createState() => _ProspectFormState();
}

class _ProspectFormState extends State<_ProspectForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _estimatedValue = TextEditingController();
  bool _saving = false;

  @override void dispose() { _name.dispose(); _company.dispose(); _email.dispose(); _phone.dispose(); _estimatedValue.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final body = {
      'name': _name.text.trim(),
      'company': _company.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'estimated_value': double.tryParse(_estimatedValue.text.trim()) ?? 0,
    };
    final result = await ApiClient.instance.post('/superadmin/prospects', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      widget.onSaved();
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
          Text(S.t('newProspect', locale), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(controller: _name, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('name', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _company, decoration: InputDecoration(labelText: S.t('company', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _email, decoration: InputDecoration(labelText: S.t('email', locale)), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, decoration: InputDecoration(labelText: S.t('phone', locale)), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextFormField(controller: _estimatedValue, decoration: InputDecoration(labelText: S.t('estimatedValue', locale)), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: Text(S.t('cancel', locale)))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.check, loading: _saving, onPressed: _save)),
          ]),
        ])))));
  }
}

class _InvoiceForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _InvoiceForm({required this.onSaved});
  @override State<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<_InvoiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _pharmacyId = TextEditingController();
  final _amount = TextEditingController();
  String _status = 'pending';
  bool _saving = false;

  @override void dispose() { _number.dispose(); _pharmacyId.dispose(); _amount.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final body = {
      'number': _number.text.trim(),
      'pharmacy_id': _pharmacyId.text.trim(),
      'amount': double.tryParse(_amount.text.trim()) ?? 0,
      'status': _status,
    };
    final result = await ApiClient.instance.post('/superadmin/invoices', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      widget.onSaved();
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
          Text(S.t('newInvoice', locale), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(controller: _number, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('number', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _pharmacyId, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('pharmacyId', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('amount', locale)), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: InputDecoration(labelText: S.t('status', locale)),
            items: ['pending', 'paid', 'overdue', 'cancelled'].map((e) => DropdownMenuItem(value: e, child: Text(e.capitalize()))).toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: Text(S.t('cancel', locale)))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.check, loading: _saving, onPressed: _save)),
          ]),
        ])))));
  }
}

class _TicketForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _TicketForm({required this.onSaved});
  @override State<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<_TicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _pharmacyId = TextEditingController();
  String _priority = 'medium';
  bool _saving = false;

  @override void dispose() { _subject.dispose(); _description.dispose(); _pharmacyId.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final locale = context.read<AuthStore>().locale;
    final body = {
      'subject': _subject.text.trim(),
      'description': _description.text.trim(),
      'pharmacy_id': _pharmacyId.text.trim(),
      'priority': _priority,
    };
    final result = await ApiClient.instance.post('/superadmin/tickets', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      widget.onSaved();
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
          Text(S.t('newTicket', locale), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(controller: _subject, validator: (v) => v?.isEmpty == true ? S.t('requiredField', locale) : null, decoration: InputDecoration(labelText: S.t('subject', locale))),
          const SizedBox(height: 12),
          TextFormField(controller: _description, decoration: InputDecoration(labelText: S.t('description', locale)), maxLines: 4),
          const SizedBox(height: 12),
          TextFormField(controller: _pharmacyId, decoration: InputDecoration(labelText: S.t('pharmacyId', locale))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: InputDecoration(labelText: S.t('priority', locale)),
            items: ['low', 'medium', 'high', 'urgent'].map((e) => DropdownMenuItem(value: e, child: Text(e.capitalize()))).toList(),
            onChanged: (v) => setState(() => _priority = v!),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: Text(S.t('cancel', locale)))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: S.t('save', locale), icon: Icons.check, loading: _saving, onPressed: _save)),
          ]),
        ])))));
  }
}

class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final String activeTab;
  final VoidCallback onChanged;
  const _DetailSheet({required this.item, required this.activeTab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(item['name']?.toString() ?? item['subject']?.toString() ?? item['number']?.toString() ?? 'Détail', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                ...item.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
                    Expanded(child: Text('${e.value}', style: const TextStyle(fontSize: 14))),
                  ]),
                )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}