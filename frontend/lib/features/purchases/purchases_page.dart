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

/// Achats : commandes fournisseurs et réceptions de stock.
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _receptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiClient.instance.get<Map<String, dynamic>>('/purchases/orders',
          query: {'limit': 100}),
      ApiClient.instance.get<Map<String, dynamic>>('/purchases/receptions',
          query: {'limit': 100}),
    ]);
    if (!mounted) return;
    final orders = results[0];
    final receptions = results[1];
    if (!orders.success || !receptions.success) {
      setState(() {
        _loading = false;
        _error = (orders.error ?? receptions.error)?.message;
      });
      return;
    }
    setState(() {
      _orders = (orders.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _receptions = (receptions.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _createOrder() async {
    final locale = context.read<AuthStore>().locale;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _OrderForm(),
    );
    if (created == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('orderCreated', locale))),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _OrderDetail(orderId: order['id'] as String, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('purchases', locale)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: S.t('purchaseOrders', locale)),
            Tab(text: S.t('receptions', locale)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createOrder,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(S.t('newOrder', locale)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _OrderList(items: _orders, onTap: _showDetail),
                    _ReceptionList(items: _receptions),
                  ],
                ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _OrderList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (items.isEmpty) {
      return Center(child: Text(S.t('noOrders', locale)));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final o = items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              radius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => onTap(o),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: Color(0xFF3E2A00)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${o['number']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${o['supplier_name']} · ${o['branch_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white60
                                    : Colors.black54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(
                        label: '${o['status']}',
                        color: statusColor('${o['status']}'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          Fmt.money(double.tryParse('${o['total'] ?? 0}') ?? 0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReceptionList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _ReceptionList({required this.items});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (items.isEmpty) return Center(child: Text(S.t('noReceptions', locale)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.inventory_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['number']} → ${r['order_number']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${r['supplier_name']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(Fmt.shortDate(DateTime.tryParse('${r['received_at']}'))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderForm extends StatefulWidget {
  const _OrderForm();

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  final _expected = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _medications = [];
  String? _branchId;
  String? _supplierId;
  final List<_OrderLine> _lines = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get<List<dynamic>>('/branches'),
      ApiClient.instance
          .get<Map<String, dynamic>>('/suppliers', query: {'limit': 200}),
      ApiClient.instance.get<Map<String, dynamic>>('/catalog/medications',
          query: {'limit': 200, 'status': 'available'}),
    ]);
    if (!mounted) return;
    setState(() {
      _branches = (results[0].data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _suppliers =
          ((results[1].data as Map<String, dynamic>?)?['items'] as List? ??
                  const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      _medications =
          ((results[2].data as Map<String, dynamic>?)?['items'] as List? ??
                  const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      _loading = false;
    });
  }

  void _addLine() {
    setState(() => _lines.add(_OrderLine()));
  }

  Future<void> _save() async {
    if (_branchId == null || _supplierId == null) return;
    if (_lines.isEmpty || _lines.any((l) => l.medicationId == null)) return;
    setState(() => _saving = true);
    final result = await ApiClient.instance.post(
      '/purchases/orders',
      body: {
        'branchId': _branchId,
        'supplierId': _supplierId,
        'expectedDate': _expected.text.isEmpty ? null : _expected.text,
        'notes': _notes.text.isEmpty ? null : _notes.text,
        'items': _lines
            .map((l) => {
                  'medication_id': l.medicationId,
                  'quantity': l.quantity,
                  'unit_cost': l.unitCost,
                  'tva_rate': l.tvaRate,
                  'discount': l.discount,
                })
            .toList(),
      },
    );
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
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t('newOrder', locale),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _supplierId,
                      decoration: InputDecoration(
                          labelText: S.t('chooseSupplier', locale)),
                      items: _suppliers
                          .map((s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text('${s['name']}')))
                          .toList(),
                      onChanged: (v) => setState(() => _supplierId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _branchId,
                      decoration: InputDecoration(
                          labelText: S.t('chooseBranch', locale)),
                      items: _branches
                          .map((b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text('${b['name']}')))
                          .toList(),
                      onChanged: (v) => setState(() => _branchId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expected,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: S.t('expectedDate', locale),
                        suffixIcon: const Icon(Icons.event),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          _expected.text =
                              picked.toIso8601String().split('T').first;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: S.t('notes', locale)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(S.t('itemsRequired', locale),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add),
                          label: Text(S.t('addItem', locale)),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _lines.length; i++)
                      _LineEditor(
                        key: ValueKey(i),
                        medications: _medications,
                        line: _lines[i],
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _lines.removeAt(i)),
                      ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: S.t('create', locale),
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

class _OrderLine {
  String? medicationId;
  double quantity = 1;
  double unitCost = 0;
  double tvaRate = 20;
  double discount = 0;
}

class _LineEditor extends StatelessWidget {
  final List<Map<String, dynamic>> medications;
  final _OrderLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _LineEditor({
    super.key,
    required this.medications,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: line.medicationId,
                  decoration: InputDecoration(
                      labelText: S.t('selectMedication', locale)),
                  isExpanded: true,
                  items: medications
                      .map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text('${m['name']}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    line.medicationId = v;
                    final med = medications.firstWhere((m) => m['id'] == v);
                    line.unitCost =
                        double.tryParse('${med['price_purchase'] ?? 0}') ?? 0;
                    line.tvaRate =
                        double.tryParse('${med['tva_rate'] ?? 20}') ?? 20;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: AppColors.danger)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${line.quantity}',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: S.t('quantityOrdered', locale)),
                  onChanged: (v) => line.quantity = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '${line.unitCost}',
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: S.t('unitCost', locale)),
                  onChanged: (v) => line.unitCost = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '${line.discount}',
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: S.t('discount', locale)),
                  onChanged: (v) => line.discount = double.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderDetail extends StatefulWidget {
  final String orderId;
  final VoidCallback onChanged;

  const _OrderDetail({required this.orderId, required this.onChanged});

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  Map<String, dynamic>? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/purchases/orders/${widget.orderId}');
    if (!mounted) return;
    if (result.success) {
      setState(() => _order = result.data);
    } else {
      setState(() => _error = result.error?.message);
    }
  }

  Future<void> _setStatus(String status) async {
    final result = await ApiClient.instance.post(
      '/purchases/orders/${widget.orderId}/status',
      body: {'status': status},
    );
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _receive() async {
    final order = _order;
    if (order == null) return;
    final locale = context.read<AuthStore>().locale;
    final received = await showDialog<bool>(
      context: context,
      builder: (_) => _ReceiveForm(order: order, onChanged: _load),
    );
    if (received == true && mounted) {
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('received', locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (_error != null) {
      return SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!),
      ));
    }
    final order = _order;
    if (order == null) {
      return const SafeArea(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    final canReceive = ['draft', 'sent', 'confirmed', 'partial']
        .contains('${order['status']}');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${order['number']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                StatusChip(
                    label: order['status'].toString(),
                    color: statusColor('${order['status']}')),
              ],
            ),
            const SizedBox(height: 8),
            Text('${order['supplier_name']} · ${order['branch_name']}',
                style: const TextStyle(color: Colors.grey)),
            Text(Fmt.shortDate(DateTime.tryParse('${order['order_date']}')),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final item in order['items'] as List? ?? const [])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.medication,
                          color: AppColors.primary),
                      title: Text('${item['medication_name'] ?? '—'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${Fmt.number(double.tryParse('${item['quantity_ordered']}') ?? 0)} u. · ${Fmt.money(double.tryParse('${item['unit_cost']}') ?? 0)}',
                      ),
                      trailing: Text(
                        '${Fmt.number(double.tryParse('${item['quantity_received']}') ?? 0)}/'
                        '${Fmt.number(double.tryParse('${item['quantity_ordered']}') ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.t('total', locale),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(Fmt.money(double.tryParse('${order['total']}') ?? 0),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (canReceive)
                    GradientButton(
                      label: S.t('receive', locale),
                      icon: Icons.inventory,
                      onPressed: _receive,
                    ),
                  const SizedBox(height: 8),
                  if (['draft', 'sent', 'confirmed']
                      .contains('${order['status']}'))
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _setStatus('cancelled'),
                            child: Text(S.t('cancelled', locale),
                                style:
                                    const TextStyle(color: AppColors.danger)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _setStatus(
                                '${order['status']}' == 'draft'
                                    ? 'sent'
                                    : 'confirmed'),
                            child: Text(S.t('statusUpdated', locale)),
                          ),
                        ),
                      ],
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

class _ReceiveForm extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onChanged;

  const _ReceiveForm({required this.order, required this.onChanged});

  @override
  State<_ReceiveForm> createState() => _ReceiveFormState();
}

class _ReceiveFormState extends State<_ReceiveForm> {
  final Map<String, TextEditingController> _qty = {};
  final Map<String, TextEditingController> _lot = {};
  final Map<String, TextEditingController> _expiry = {};
  bool _saving = false;

  List<Map<String, dynamic>> get _items =>
      (widget.order['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = double.tryParse(_qty['${item['id']}']?.text ?? '') ?? 0;
      if (qty <= 0) continue;
      payload.add({
        'medication_id': item['medication_id'],
        'quantity': qty,
        'lot_number': _lot['${item['id']}']?.text.trim() ?? '',
        'expiry_date': _expiry['${item['id']}']?.text,
      });
    }
    if (payload.isEmpty) return;
    setState(() => _saving = true);
    final result = await ApiClient.instance.post(
      '/purchases/orders/${widget.order['id']}/receive',
      body: {
        'branchId': widget.order['branch_id'],
        'items': payload,
      },
    );
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
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
              Text('${S.t('receive', locale)} — ${widget.order['number']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item['medication_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qty.putIfAbsent(
                                  '${item['id']}',
                                  () => TextEditingController(
                                      text: '${item['quantity_ordered']}')),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: S.t('receiveQty', locale),
                                  isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lot.putIfAbsent('${item['id']}',
                                  () => TextEditingController()),
                              decoration: InputDecoration(
                                  labelText: S.t('lotNumber', locale),
                                  isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _expiry.putIfAbsent('${item['id']}',
                                  () => TextEditingController()),
                              readOnly: true,
                              decoration: InputDecoration(
                                  labelText: S.t('expiryDate', locale),
                                  isDense: true),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now()
                                      .add(const Duration(days: 180)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (picked != null) {
                                  _expiry['${item['id']}']!.text =
                                      picked.toIso8601String().split('T').first;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              GradientButton(
                label: S.t('confirm', locale),
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
