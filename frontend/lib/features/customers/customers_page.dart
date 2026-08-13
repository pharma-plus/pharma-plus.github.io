import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';

/// Fichier clients : création, édition, historique (ventes / factures).
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _creditOnly = false;

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
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customers',
      query: {
        'limit': 100,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        if (_creditOnly) 'hasCredit': true,
      },
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
      _items = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic>? customer) async {
    final locale = context.read<AuthStore>().locale;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerForm(customer: customer),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(customer == null
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
      builder: (_) => _CustomerDetail(
          customerId: customer['id'] as String,
          onEdit: () {
            Navigator.pop(context);
            _edit(customer);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
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
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
              ),
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
                                                '${c['phone'] ?? ''}'.isNotEmpty
                                                    ? '${c['phone']}'
                                                    : '${c['email'] ?? ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
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
}

class _CustomerForm extends StatefulWidget {
  final Map<String, dynamic>? customer;

  const _CustomerForm({this.customer});

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  late final _name =
      TextEditingController(text: '${widget.customer?['name'] ?? ''}');
  late final _phone =
      TextEditingController(text: '${widget.customer?['phone'] ?? ''}');
  late final _whatsapp =
      TextEditingController(text: '${widget.customer?['whatsapp'] ?? ''}');
  late final _email =
      TextEditingController(text: '${widget.customer?['email'] ?? ''}');
  late final _address =
      TextEditingController(text: '${widget.customer?['address'] ?? ''}');
  late final _credit =
      TextEditingController(text: '${widget.customer?['credit_limit'] ?? 0}');
  late final _notes =
      TextEditingController(text: '${widget.customer?['notes'] ?? ''}');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _address.dispose();
    _credit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'whatsapp': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'credit_limit': double.tryParse(_credit.text) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    final result = widget.customer == null
        ? await ApiClient.instance.post('/customers', body: body)
        : await ApiClient.instance
            .put('/customers/${widget.customer!['id']}', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.customer == null
                      ? S.t('newCustomer', locale)
                      : '${widget.customer!['name']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                  controller: _name,
                  decoration:
                      InputDecoration(labelText: '${S.t('name', locale)} *')),
              const SizedBox(height: 12),
              TextField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: S.t('phone', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _whatsapp,
                  decoration:
                      InputDecoration(labelText: S.t('whatsapp', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _email,
                  decoration: InputDecoration(labelText: S.t('email', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _address,
                  decoration:
                      InputDecoration(labelText: S.t('address', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _credit,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: S.t('creditLimit', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: S.t('notes', locale))),
              const SizedBox(height: 20),
              GradientButton(
                label: S.t('save', locale),
                icon: Icons.check,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetail extends StatefulWidget {
  final String customerId;
  final VoidCallback onEdit;

  const _CustomerDetail({required this.customerId, required this.onEdit});

  @override
  State<_CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<_CustomerDetail> {
  Map<String, dynamic>? _customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/customers/${widget.customerId}');
    if (!mounted) return;
    if (result.success) setState(() => _customer = result.data);
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
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${c['name']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            row(S.t('phone', locale), '${c['phone'] ?? '—'}'),
            row(S.t('whatsapp', locale), '${c['whatsapp'] ?? '—'}'),
            row(S.t('email', locale), '${c['email'] ?? '—'}'),
            row(S.t('address', locale), '${c['address'] ?? '—'}'),
            row(
                S.t('loyaltyPoints', locale),
                Fmt.number(
                    double.tryParse('${c['loyalty_points'] ?? 0}') ?? 0)),
            row(S.t('creditLimit', locale),
                Fmt.money(double.tryParse('${c['credit_limit'] ?? 0}') ?? 0)),
            row(S.t('creditBalance', locale),
                Fmt.money(double.tryParse('${c['credit_balance'] ?? 0}') ?? 0)),
            const Divider(height: 24),
            Text(S.t('salesReport', locale),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Expanded(
              child: (c['sales'] as List? ?? const []).isEmpty
                  ? Center(child: Text(S.t('noResults', locale)))
                  : ListView(
                      children: [
                        for (final s in c['sales'] as List? ?? const [])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('${s['number']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(Fmt.shortDate(
                                DateTime.tryParse('${s['created_at']}'))),
                            trailing: Text(Fmt.money(
                                double.tryParse('${s['total']}') ?? 0)),
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
