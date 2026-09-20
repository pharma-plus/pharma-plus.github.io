import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/order_status.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';
import '../catalog/unknown_product_dialog.dart';

/// Achats : commandes fournisseurs et rÃ©ceptions de stock.
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
      ApiClient.instance.get('/purchases/orders',
          query: {'limit': 100}),
      ApiClient.instance.get('/purchases/receptions',
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
      _orders = ApiList.of(orders.data);
      _receptions = ApiList.of(receptions.data);
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

  Future<void> _scanProduct() async {
    final result = await BarcodeScannerSheet.show(
        context, title: 'Scanner produit pour rÃ©ception');
    if (result == null || !mounted) return;
    final code = result.lookupCode;
    if (code.isEmpty) return;
    final apiResult = await ApiClient.instance.get(
      '/catalog/medications/barcode/${Uri.encodeComponent(code)}',
    );
    if (!mounted) return;
    if (!apiResult.success || apiResult.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code inconnu : $code')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Produit trouvÃ© : ${apiResult.data['name']}')));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('purchases', locale)),
        actions: [
          IconButton(
              onPressed: _scanProduct,
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFE9C873))),
        ],
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
                        Text('${o['supplier_name']} Â· ${o['branch_name']}',
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
                        label: orderStatusLabel('${o['status']}'),
                        color: orderStatusColor('${o['status']}'),
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
                      Text('${r['number']} â†’ ${r['order_number']}',
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
      ApiClient.instance.get('/branches'),
      ApiClient.instance
          .get('/suppliers', query: {'limit': 200}),
      ApiClient.instance.get('/catalog/medications',
          query: {'limit': 200, 'status': 'available'}),
    ]);
    if (!mounted) return;
    setState(() {
      _branches = ApiList.of(results[0].data);
      _suppliers = ApiList.of(results[1].data);
      _medications = ApiList.of(results[2].data);
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
        .get('/purchases/orders/${widget.orderId}');
    if (!mounted) return;
    if (result.success) {
      final d = result.data;
      setState(() => _order = d is Map<String, dynamic> ? d : (d is Map ? Map<String, dynamic>.from(d) : null));
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
                    label: orderStatusLabel('${order['status']}'),
                    color: orderStatusColor('${order['status']}')),
              ],
            ),
            const SizedBox(height: 8),
            Text('${order['supplier_name']} Â· ${order['branch_name']}',
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
                      title: Text('${item['medication_name'] ?? 'â€”'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${Fmt.number(double.tryParse('${item['quantity_ordered']}') ?? 0)} u. Â· ${Fmt.money(double.tryParse('${item['unit_cost']}') ?? 0)}',
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
  // Produits SUPPLÃ‰MENTAIRES (non prÃ©vus dans la commande).
  final List<Map<String, dynamic>> _extras = [];
  final List<TextEditingController> _extraQty = [];
  final List<TextEditingController> _extraLot = [];
  final List<TextEditingController> _extraExpiry = [];
  // Anti-doublon de scan : un mÃªme code ignorÃ© < 1.2 s.
  String? _lastCode;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _saving = false;

  List<Map<String, dynamic>> get _items =>
      (widget.order['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : '$v';

  /// RESTE Ã  recevoir pour une ligne (commandÃ© âˆ’ dÃ©jÃ  reÃ§u).
  double _remaining(Map<String, dynamic> item) {
    final r = _num(item['quantity_ordered']) - _num(item['quantity_received']);
    return r <= 0 ? 0 : r;
  }

  TextEditingController _qtyCtrl(Map<String, dynamic> item) =>
      _qty.putIfAbsent('${item['id']}', () {
        final rem = _remaining(item);
        return TextEditingController(text: rem > 0 ? _fmt(rem) : '0');
      });

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// SCAN (mode simple) : un scan, retour immÃ©diat.
  Future<void> _scan() async {
    final result = await BarcodeScannerSheet.show(context,
        title: 'Scanner produit (rÃ©ception)');
    if (result == null || !mounted) return;
    await _processScan(result);
  }

  /// SCAN CONTINU : l'Ã©cran camÃ©ra reste ouvert, chaque lecture incrÃ©mente
  /// la ligne correspondante (rÃ©ception de 50 produits sans rouvrir le scan).
  Future<void> _scanContinuous() async {
    await BarcodeScannerSheet.showContinuous(context,
        title: 'Scan continu (rÃ©ception)',
        onScan: (result) => _processScan(result, continuous: true));
    if (!mounted) return;
    setState(() {}); // rafraÃ®chir l'UI aprÃ¨s fermeture du scan continu
  }

  /// Traitement d'une lecture : identifie le produit, incrÃ©mente la quantitÃ©
  /// reÃ§ue (jamais au-delÃ  du reste) et prÃ©-remplit lot/expiration GS1.
  Future<void> _processScan(ScanResult result, {bool continuous = false}) async {
    final code = result.lookupCode;
    if (code.isEmpty || !mounted) return;
    final now = DateTime.now();
    if (code == _lastCode &&
        now.difference(_lastScanAt).inMilliseconds < 1200) {
      if (!continuous) _toast('Scan identique ignorÃ© (protection anti-doublon)');
      return;
    }
    _lastCode = code;
    _lastScanAt = now;

    final lookup = await ApiClient.instance
        .get('/catalog/medications/barcode/${Uri.encodeComponent(code)}');
    if (!mounted) return;
    if (!lookup.success || lookup.data == null) {
      // PRODUIT NON TROUVÃ‰ : jamais de crÃ©ation automatique (anti-doublon).
      if (continuous) {
        _toast('Produit non reconnu ($code) â€” utilisez le scan simple '
            'pour le crÃ©er ou l\u2019associer.');
      } else {
        await _createUnknownProduct(code);
      }
      return;
    }
    final med = lookup.data;
    Map<String, dynamic>? match;
    for (final it in _items) {
      if ('${it['medication_id']}' == '${med['id']}') {
        match = it;
        break;
      }
    }
    if (match == null) {
      if (continuous) {
        _toast('${med['name']} : supplÃ©mentaire â€” utilisez le scan simple '
            'pour l\u2019ajouter Ã  la rÃ©ception.');
      } else {
        // Produit connu mais non prÃ©vu : PRODUIT SUPPLÃ‰MENTAIRE.
        await _proposeExtra(Map<String, dynamic>.from(med as Map));
      }
      return;
    }
    final item = match;
    final rem = _remaining(item);
    if (rem <= 0) {
      _toast('${med['name']} : dÃ©jÃ  entiÃ¨rement reÃ§u.');
      return;
    }
    final cur =
        double.tryParse(_qtyCtrl(item).text.replaceAll(',', '.')) ?? 0;
    if (cur >= rem) {
      _toast('${med['name']} : dÃ©jÃ  comptÃ© Ã  $cur pour un reste de $rem.');
      return;
    }
    setState(() {
      _qtyCtrl(item).text = _fmt((cur + 1).clamp(0, rem));
      // DonnÃ©es GS1 extraites (DataMatrix) : prÃ©-remplir lot / expiration.
      if (result.gs1.lot != null && result.gs1.lot!.isNotEmpty) {
        _lot.putIfAbsent('${item['id']}', () => TextEditingController())
            .text = result.gs1.lot!;
      }
      if (result.gs1.expiry != null && result.gs1.expiry!.isNotEmpty) {
        _expiry.putIfAbsent('${item['id']}', () => TextEditingController())
            .text = result.gs1.expiry!;
      }
    });
    _toast('${med['name']} â€” reÃ§u : ${_qtyCtrl(item).text} / $rem');
  }

  /// Ajout d'un produit supplÃ©mentaire (commandÃ© = reÃ§u d'office cÃ´tÃ© API).
  Future<void> _proposeExtra(Map<String, dynamic> med) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produit supplÃ©mentaire'),
        content: Text(
            '${med['name']} n\u2019est pas prÃ©vu dans cette commande. '
            'L\u2019ajouter Ã  la rÃ©ception ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajouter')),
        ],
      ),
    );
    if (add != true || !mounted) return;
    setState(() {
      _extras.add(Map<String, dynamic>.from(med));
      _extraQty.add(TextEditingController(text: '1'));
      _extraLot.add(TextEditingController());
      _extraExpiry.add(TextEditingController());
    });
  }

  /// Produit inconnu : module unifiÃ© (rechercher / associer / crÃ©er /
  /// annuler â€” jamais de doublon automatique). Si une fiche est crÃ©Ã©e ou
  /// associÃ©e, on la propose immÃ©diatement comme produit de rÃ©ception.
  Future<void> _createUnknownProduct(String code) async {
    final med = await showUnknownProductDialog(context, barcode: code);
    if (!mounted) return;
    if (med != null) {
      await _proposeExtra(Map<String, dynamic>.from(med));
    }
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty =
          double.tryParse(_qtyCtrl(item).text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) continue;
      payload.add({
        'medication_id': item['medication_id'],
        'quantity': qty,
        'lot_number': _lot['${item['id']}']?.text.trim() ?? '',
        'expiry_date': _expiry['${item['id']}']?.text,
      });
    }
    for (var i = 0; i < _extras.length; i++) {
      final q = double.tryParse(_extraQty[i].text.replaceAll(',', '.')) ?? 0;
      if (q <= 0) continue;
      payload.add({
        'medication_id': _extras[i]['id'],
        'quantity': q,
        'lot_number': _extraLot[i].text.trim(),
        'expiry_date': _extraExpiry[i].text,
        'cost_price': _num(_extras[i]['price_purchase']),
      });
    }
    if (payload.isEmpty) {
      _toast('Indiquez au moins une quantitÃ© reÃ§ue.');
      return;
    }
    final missingLot = payload.any((p) =>
        '${p['lot_number']}'.trim().isEmpty || p['expiry_date'] == null);
    if (missingLot) {
      _toast('NumÃ©ro de lot et date de pÃ©remption obligatoires.');
      return;
    }
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
              Row(children: [
                Expanded(
                  child: Text(
                      '${S.t('receive', locale)} â€” ${widget.order['number']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Scan continu (rÃ©ception)',
                  onPressed: _scanContinuous,
                  icon: const Icon(Icons.all_inclusive_rounded,
                      color: AppColors.pharmaGold),
                ),
                IconButton(
                  tooltip: 'Scanner produit',
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.pharmaGold),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                  'QuantitÃ© prÃ©-remplie = RESTE Ã  recevoir. Un scan incrÃ©mente '
                  'de 1. Aucun stock n\u2019est modifiÃ© avant la validation.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 12),
              for (final item in _items) _buildLine(item, locale),
              if (_extras.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('Produits supplÃ©mentaires',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (var i = 0; i < _extras.length; i++)
                  _buildExtraLine(i, locale),
              ],
              const SizedBox(height: 8),
              GradientButton(
                label: 'Valider la rÃ©ception',
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

  Widget _buildLine(Map<String, dynamic> item, String locale) {
    final ordered = _num(item['quantity_ordered']);
    final received = _num(item['quantity_received']);
    final rem = _remaining(item);
    final done = rem <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Opacity(
        opacity: done ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['medication_name']}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('CommandÃ© ${_fmt(ordered)} Â· DÃ©jÃ  reÃ§u ${_fmt(received)}'
                ' Â· Reste ${_fmt(rem)}',
                style:
                    const TextStyle(fontSize: 11.5, color: Colors.white54)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl(item),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: S.t('receiveQty', locale), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lot.putIfAbsent(
                      '${item['id']}', () => TextEditingController()),
                  decoration: InputDecoration(
                      labelText: S.t('lotNumber', locale), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _expiry.putIfAbsent(
                      '${item['id']}', () => TextEditingController()),
                  readOnly: true,
                  decoration: InputDecoration(
                      labelText: S.t('expiryDate', locale), isDense: true),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 180)),
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
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraLine(int i, String locale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('${_extras[i]['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                _extras.removeAt(i);
                _extraQty.removeAt(i);
                _extraLot.removeAt(i);
                _extraExpiry.removeAt(i);
              }),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _extraQty[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: S.t('receiveQty', locale), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _extraLot[i],
                decoration: InputDecoration(
                    labelText: S.t('lotNumber', locale), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _extraExpiry[i],
                readOnly: true,
                decoration: InputDecoration(
                    labelText: S.t('expiryDate', locale), isDense: true),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    _extraExpiry[i].text =
                        picked.toIso8601String().split('T').first;
                  }
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

