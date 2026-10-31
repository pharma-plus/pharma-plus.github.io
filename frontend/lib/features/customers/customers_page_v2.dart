import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';
import 'organisms.dart';

/// Fichier clients enrichi : création, édition, historique + gestion des organismes (AMO, CNOPS, CNSS, mutuelles, assurances).
class CustomersPageV2 extends StatefulWidget {
  const CustomersPageV2({super.key});

  @override
  State<CustomersPageV2> createState() => _CustomersPageV2State();
}

class _CustomersPageV2State extends State<CustomersPageV2> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _creditOnly = false;
  String? _organismFilter; // Filtre par type d'organisme

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = <String, dynamic>{
      'limit': 100,
      if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      if (_creditOnly) 'hasCredit': true,
      if (_organismFilter != null && _organismFilter!.isNotEmpty) 'organism_type': _organismFilter,
    };
    final result = await ApiClient.instance.get(
      '/customers',
      query: query,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      _items = ApiList.of(result.data);
      _loading = false;
    });
  }

  void _debouncedLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(Map<String, dynamic>? customer) async {
    final locale = context.read<AuthStore>().locale;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: CustomerFormV2(customer: customer),
        ),
      ),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(customer == null
              ? S.t('customerCreated', locale)
              : S.t('customerUpdated', locale))),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerDetailV2(
          customerId: customer['id'] as String,
          onEdit: () {
            Navigator.pop(context);
            _edit(customer);
          }),
    );
  }

  void _clearFilters() => setState(() {
    _creditOnly = false;
    _organismFilter = null;
    _load();
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('customers', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt),
        label: Text(S.t('newCustomer', locale)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AppSearchField(
              controller: _search,
              hint: S.t('search', locale),
              showFilterButton: true,
              debounceDuration: Duration.zero,
              onChanged: (_) => _debouncedLoad(),
              onFilterPressed: _showFilterDialog,
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(S.t('hasCredit', locale)),
                selected: _creditOnly,
                onSelected: (v) => setState(() {
                  _creditOnly = v;
                  _load();
                }),
              ),
              const SizedBox(width: 8),
              _OrganismFilterChip(
                selected: _organismFilter,
                onChanged: (v) => setState(() {
                  _organismFilter = v;
                  _load();
                }),
                locale: locale,
              ),
              if (_creditOnly || _organismFilter != null)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: Text(S.t('clearFilters', locale)),
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(child: Text(S.t('noCustomers', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final c = _items[i];
                                final credit = double.tryParse(
                                        '${c['credit_balance'] ?? 0}') ??
                                    0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    radius: BorderRadius.circular(16),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    onTap: () => _showDetail(c),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: const BoxDecoration(
                                            gradient: AppColors.goldGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${c['name']}'.isNotEmpty
                                                  ? '${c['name']}'[0]
                                                      .toUpperCase()
                                                  : '?',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF3E2A00)),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('${c['name']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              Text(
                                                _buildCustomerSubtitle(c),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _CustomerOrganismChips(
                                            affiliations: _parseAffiliations(c)),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (credit > 0)
                                              StatusChip(
                                                  label: Fmt.money(credit),
                                                  color: AppColors.danger)
                                            else
                                              StatusChip(
                                                  label: S.t('active', locale),
                                                  color: AppColors.success),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${S.t('totalSpent', locale)}: '
                                              '${Fmt.money(double.tryParse('${c['total_spent'] ?? 0}') ?? 0)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey),
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
                        ),
        ],
      ),
    );
  }

  String _buildCustomerSubtitle(Map<String, dynamic> c) {
    final parts = <String>[
      if (c['phone']?.toString().isNotEmpty ?? false) c['phone'].toString(),
      if (c['email']?.toString().isNotEmpty ?? false) c['email'].toString(),
    ];
    // Ajouter le type d'organisme principal si disponible
    final aff = _parseAffiliations(c);
    if (aff.isNotEmpty) {
      parts.add(aff.first.organismType.label);
    }
    return parts.join(' · ');
  }

  List<ClientAffiliation> _parseAffiliations(Map<String, dynamic> c) {
    final affs = c['affiliations'] as List?;
    if (affs == null) return [];
    return affs
        .whereType<Map<String, dynamic>>()
        .map(ClientAffiliation.fromJson)
        .toList();
  }

  void _showFilterDialog() {
    final locale = context.read<AuthStore>().locale;
    String? tmpOrganism = _organismFilter;
    bool tmpCredit = _creditOnly;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(S.t('filters', locale)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ChoiceChip(
            label: Text(S.t('hasCredit', locale)),
            selected: tmpCredit,
            onSelected: (v) => setState(() => tmpCredit = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: tmpOrganism,
            isExpanded: true,
            decoration: InputDecoration(labelText: S.t('organismType', locale)),
            items: [
              DropdownMenuItem(value: null, child: Text(S.t('all', locale))),
              for (final o in OrganismType.values)
                DropdownMenuItem(
                  value: o.code,
                  child: Row(children: [
                    Icon(o.icon, size: 18, color: AppColors.pharmaGold),
                    const SizedBox(width: 8),
                    Text(o.label),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => tmpOrganism = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('cancel', locale))),
          FilledButton(
            onPressed: () {
              setState(() {
                _creditOnly = tmpCredit;
                _organismFilter = tmpOrganism;
              });
              _load();
              Navigator.pop(ctx);
            },
            child: Text(S.t('apply', locale)),
          ),
        ],
      )),
    );
  }
}

class _OrganismFilterChip extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String locale;

  const _OrganismFilterChip({
    required this.selected,
    required this.onChanged,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: onChanged,
      tooltip: S.t('organismType', locale),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: null, child: Row(children: [
          const Icon(Icons.clear, size: 18),
          const SizedBox(width: 8),
          Text(S.t('all', locale)),
        ])),
        for (final o in OrganismType.values)
          PopupMenuItem(
            value: o.code,
            child: Row(children: [
              Icon(o.icon, size: 18, color: AppColors.pharmaGold),
              const SizedBox(width: 8),
              Text(o.label),
            ]),
          ),
      ],
      child: InputChip(
        label: Text(selected == null
            ? S.t('organismType', locale)
            : OrganismType.fromCode(selected!).label),
        avatar: selected == null
            ? null
            : Icon(OrganismType.fromCode(selected!).icon, size: 16),
        onPressed: () {},
        deleteIcon: selected == null ? null : const Icon(Icons.close, size: 16),
        onDeleted: () => onChanged(null),
      ),
    );
  }
}

class _CustomerOrganismChips extends StatelessWidget {
  final List<ClientAffiliation> affiliations;

  const _CustomerOrganismChips({required this.affiliations});

  @override
  Widget build(BuildContext context) {
    if (affiliations.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: affiliations.map((a) {
        final isExpired = a.isExpired;
        final isExpiring = a.isExpiringSoon;
        Color chipColor;
        if (isExpired) chipColor = Colors.red;
        else if (isExpiring) chipColor = Colors.orange;
        else chipColor = AppColors.success;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chipColor, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(a.organismType.icon, size: 12, color: chipColor),
            const SizedBox(width: 4),
            Text(
              a.organismName.isNotEmpty ? a.organismName : a.organismType.label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: chipColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (a.isExpiringSoon || a.isExpired) ...[
              const SizedBox(width: 4),
              Icon(
                a.isExpired ? Icons.warning : Icons.schedule,
                size: 12,
                color: chipColor,
              ),
            ],
          ]),
        );
      }).toList(),
    );
  }
}

class _CustomerDetailV2 extends StatefulWidget {
  final String customerId;
  final VoidCallback onEdit;

  const _CustomerDetailV2({required this.customerId, required this.onEdit});

  @override
  State<_CustomerDetailV2> createState() => _CustomerDetailV2State();
}

class _CustomerDetailV2State extends State<_CustomerDetailV2> {
  Map<String, dynamic>? _customer;
  List<ClientAffiliation> _affiliations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance.get('/customers/${widget.customerId}');
    if (!mounted) return;
    if (result.success) {
      final d = result.data;
      final c = d is Map<String, dynamic>
          ? d
          : (d is Map ? Map<String, dynamic>.from(d) : null);
      if (c != null) {
        setState(() {
          _customer = c;
          final affs = c['affiliations'] as List?;
          _affiliations = (affs ?? [])
              .whereType<Map<String, dynamic>>()
              .map(ClientAffiliation.fromJson)
              .toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final c = _customer;
    if (c == null) {
      return const SafeArea(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('${c!['name']}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              _InfoChip(label: S.t('phone', locale), value: c['phone'] ?? '—'),
              _InfoChip(label: S.t('email', locale), value: c['email'] ?? '—'),
              _InfoChip(label: S.t('creditLimit', locale), value: Fmt.money(double.tryParse('${c['credit_limit'] ?? 0}') ?? 0)),
            ]),
            const SizedBox(height: 12),
            // Affiliations / Organismes
            if (_affiliations.isNotEmpty) ...[
              Text(S.t('organisms', locale),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _affiliations.map((a) => _AffiliationChip(affiliation: a)).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(),
            _DetailRow(label: S.t('name', locale), value: c['name'] ?? '—'),
            _DetailRow(label: S.t('phone', locale), value: c['phone'] ?? '—'),
            _DetailRow(label: S.t('email', locale), value: c['email'] ?? '—'),
            _DetailRow(label: S.t('address', locale), value: c['address'] ?? '—'),
            _DetailRow(label: S.t('creditLimit', locale), value: Fmt.money(double.tryParse('${c['credit_limit'] ?? 0}') ?? 0)),
            _DetailRow(label: S.t('totalSpent', locale), value: Fmt.money(double.tryParse('${c['total_spent'] ?? 0}') ?? 0)),
            _DetailRow(label: S.t('creditBalance', locale), value: Fmt.money(double.tryParse('${c['credit_balance'] ?? 0}') ?? 0)),
            _DetailRow(label: S.t('notes', locale), value: c['notes'] ?? '—'),
          ],
        ),
      ),
    );
  }
}

class _AffiliationChip extends StatelessWidget {
  final ClientAffiliation affiliation;

  const _AffiliationChip({required this.affiliation});

  @override
  Widget build(BuildContext context) {
    final isExpired = affiliation.isExpired;
    final isExpiring = affiliation.isExpiringSoon;
    Color color;
    if (isExpired) color = Colors.red;
    else if (isExpiring) color = Colors.orange;
    else color = AppColors.success;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(affiliation.organismType.icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(affiliation.organismName.isNotEmpty
                ? affiliation.organismName
                : affiliation.organismType.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          ),
          if (affiliation.isExpired || affiliation.isExpiringSoon)
            Icon(
                affiliation.isExpired ? Icons.warning_amber_rounded : Icons.schedule,
                size: 16,
                color: color),
        ]),
        const SizedBox(height: 6),
        _AffRow(S.t('affiliationNumber', context.read<AuthStore>().locale), affiliation.affiliationNumber),
        if (affiliation.contractNumber != null)
          _AffRow(S.t('contractNumber', context.read<AuthStore>().locale), affiliation.contractNumber!),
        if (affiliation.validityStart != null || affiliation.validityEnd != null)
          _AffRow(S.t('validityPeriod', context.read<AuthStore>().locale),
              '${affiliation.validityStart != null ? DateFormat('dd/MM/yyyy').format(affiliation.validityStart!) : '—'} → ${affiliation.validityEnd != null ? DateFormat('dd/MM/yyyy').format(affiliation.validityEnd!) : '—'}'),
        if (affiliation.coverageRate != null)
          _AffRow(S.t('coverageRate', context.read<AuthStore>().locale), '${affiliation.coverageRate}%'),
        if (affiliation.annualCeiling != null)
          _AffRow(S.t('annualCeiling', context.read<AuthStore>().locale), Fmt.money(affiliation.annualCeiling!)),
        if (affiliation.notes != null && affiliation.notes!.isNotEmpty)
          _AffRow(S.t('notes', context.read<AuthStore>().locale), affiliation.notes!),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: affiliation.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: affiliation.statusColor, width: 1),
            ),
            child: Text(affiliation.statusLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: affiliation.statusColor)),
          ),
        ]),
      ]),
    );
  }
}

class _AffRow extends StatelessWidget {
  final String label;
  final String value;

  const _AffRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.pharmaSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dividerDark)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}