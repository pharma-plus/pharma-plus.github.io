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

/// Fournisseurs : gestion, historique des commandes, règlements.
class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      '/suppliers',
      query: {
        'limit': 100,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
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

  Future<void> _edit(Map<String, dynamic>? supplier) async {
    final locale = context.read<AuthStore>().locale;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SupplierForm(supplier: supplier),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('supplierCreated', locale))),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupplierDetail(
          supplierId: supplier['id'] as String, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('suppliers', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.local_shipping_outlined),
        label: Text(S.t('newSupplier', locale)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(child: Text(S.t('noSuppliers', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final s = _items[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    radius: BorderRadius.circular(16),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    onTap: () => _showDetail(s),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                              Icons.local_shipping,
                                              color: AppColors.primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('${s['name']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              Text(
                                                [s['city'], s['contact_name']]
                                                    .whereType<String>()
                                                    .where((v) => v.isNotEmpty)
                                                    .join(' · '),
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
                                            if (s['rating'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star,
                                                      size: 14,
                                                      color: AppColors.accent),
                                                  Text(' ${s['rating']}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ],
                                              ),
                                            Text(
                                              '${s['nb_orders']} ${S.t('nbOrders', locale)}',
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

class _SupplierForm extends StatefulWidget {
  final Map<String, dynamic>? supplier;

  const _SupplierForm({this.supplier});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  late final _name =
      TextEditingController(text: '${widget.supplier?['name'] ?? ''}');
  late final _contact =
      TextEditingController(text: '${widget.supplier?['contact_name'] ?? ''}');
  late final _phone =
      TextEditingController(text: '${widget.supplier?['phone'] ?? ''}');
  late final _whatsapp =
      TextEditingController(text: '${widget.supplier?['whatsapp'] ?? ''}');
  late final _email =
      TextEditingController(text: '${widget.supplier?['email'] ?? ''}');
  late final _address =
      TextEditingController(text: '${widget.supplier?['address'] ?? ''}');
  late final _city =
      TextEditingController(text: '${widget.supplier?['city'] ?? ''}');
  late final _paymentTerms =
      TextEditingController(text: '${widget.supplier?['payment_terms'] ?? ''}');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _contact,
      _phone,
      _whatsapp,
      _email,
      _address,
      _city,
      _paymentTerms
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'contact_name':
          _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'whatsapp': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'payment_terms':
          _paymentTerms.text.trim().isEmpty ? null : _paymentTerms.text.trim(),
    };
    final result = widget.supplier == null
        ? await ApiClient.instance.post('/suppliers', body: body)
        : await ApiClient.instance
            .put('/suppliers/${widget.supplier!['id']}', body: body);
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
                  widget.supplier == null
                      ? S.t('newSupplier', locale)
                      : '${widget.supplier!['name']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                  controller: _name,
                  decoration:
                      InputDecoration(labelText: '${S.t('name', locale)} *')),
              const SizedBox(height: 12),
              TextField(
                  controller: _contact,
                  decoration:
                      InputDecoration(labelText: S.t('contactName', locale))),
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
                  controller: _city,
                  decoration: InputDecoration(labelText: S.t('city', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _paymentTerms,
                  decoration:
                      InputDecoration(labelText: S.t('paymentTerms', locale))),
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

class _SupplierDetail extends StatefulWidget {
  final String supplierId;
  final VoidCallback onChanged;

  const _SupplierDetail({required this.supplierId, required this.onChanged});

  @override
  State<_SupplierDetail> createState() => _SupplierDetailState();
}

class _SupplierDetailState extends State<_SupplierDetail> {
  Map<String, dynamic>? _supplier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/suppliers/${widget.supplierId}');
    if (!mounted) return;
    if (result.success) setState(() => _supplier = result.data);
  }

  Future<void> _recordPayment() async {
    final locale = context.read<AuthStore>().locale;
    final amount = TextEditingController();
    final reference = TextEditingController();
    String method = 'cash';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.t('recordPayment', locale)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: S.t('paymentAmount', locale)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: InputDecoration(labelText: S.t('method', locale)),
                items: ['cash', 'bank', 'check', 'mobile']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => method = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reference,
                decoration:
                    InputDecoration(labelText: S.t('reference', locale)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('save', locale)),
            ),
          ],
        ),
      ),
    );
    if (saved != true || amount.text.trim().isEmpty) return;
    final result = await ApiClient.instance.post(
      '/suppliers/${widget.supplierId}/payments',
      body: {
        'amount': double.tryParse(amount.text) ?? 0,
        'method': method,
        'reference':
            reference.text.trim().isEmpty ? null : reference.text.trim(),
      },
    );
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('paymentRecorded', locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final s = _supplier;
    if (s == null) {
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
            Text('${s['name']}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${s['contact_name'] ?? ''} · ${s['phone'] ?? ''}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '${S.t('totalPurchases', locale)}: '
              '${Fmt.money(double.tryParse('${s['total_purchases'] ?? 0}') ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(S.t('purchaseOrders', locale),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(S.t('recordPayment', locale)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: (s['orders'] as List? ?? const []).isEmpty
                  ? Center(child: Text(S.t('noOrders', locale)))
                  : ListView(
                      children: [
                        for (final o in s['orders'] as List? ?? const [])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: StatusChip(
                                label: '${o['status']}',
                                color: statusColor('${o['status']}')),
                            title: Text('${o['number']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(Fmt.shortDate(
                                DateTime.tryParse('${o['order_date']}'))),
                            trailing: Text(Fmt.money(
                                double.tryParse('${o['total']}') ?? 0)),
                          ),
                        if ((s['payments'] as List? ?? const []).isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Divider(),
                          ),
                        for (final p in s['payments'] as List? ?? const [])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.payments_outlined,
                                color: AppColors.success),
                            title: Text('${p['method']}'),
                            subtitle: Text(Fmt.shortDate(
                                DateTime.tryParse('${p['payment_date']}'))),
                            trailing: Text(Fmt.money(
                                double.tryParse('${p['amount']}') ?? 0)),
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
