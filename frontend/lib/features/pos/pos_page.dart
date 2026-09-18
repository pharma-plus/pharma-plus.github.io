import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/services/offline_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../shell/shell_nav.dart';
import '../dashboard/pos_category_grid.dart';
import 'pos_categories.dart';
import 'pos_models.dart';
import 'payment_models.dart';

class PosPage extends StatefulWidget {
  final List<Medication>? initialItems;
  final double initialDiscount;
  final bool initialDiscountIsPercent;
  final double? initialReceived;
  const PosPage({
    super.key,
    this.initialItems,
    this.initialDiscount = 0,
    this.initialDiscountIsPercent = true,
    this.initialReceived,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final Cart _cart = Cart();
  final _search = TextEditingController();
  final _receivedCtrl = TextEditingController();
  List<Medication> _results = [];
  bool _searching = false;
  bool _checkout = false;
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  List<Map<String, dynamic>> _customers = [];
  String? _customerId;

  // ── Remise ──
  bool _discountIsPercent = true;

  // ── Mode de paiement intégré ──
  String _paymentMode = 'cash'; // cash | visa | mastercard
  double _received = 0;

  // ── Catégories ──
  List<Medication> _catalog = [];
  String? _activeCategoryId;

  static const _catQueries = <String, String>{
    'antalgiques': 'ibuprof',
    'antibiotiques': 'amoxicill',
    'cardiologie': 'bisoprolol',
    'diabete': 'metformin',
    'vitamines': 'vitamine',
    'respiratoire': 'salbutamol',
    'digestif': 'omeprazole',
    'autres': '',
  };

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadCustomers();
    _searchMedications('');
    final items = widget.initialItems;
    if (items != null && items.isNotEmpty) {
      for (final m in items) _cart.add(m);
      if (widget.initialDiscount > 0) {
        _cart.globalDiscountPercent = widget.initialDiscountIsPercent
            ? widget.initialDiscount
            : _cart.subtotal > 0
                ? (widget.initialDiscount / _cart.subtotal) * 100
                : 0;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  // ──────────────── DATA ────────────────

  Future<void> _loadBranches() async {
    final r = await ApiClient.instance.get('/branches');
    if (!mounted) return;
    if (r.success) {
      final list = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final auth = context.read<AuthStore>();
      setState(() {
        _branches = list;
        _branchId =
            auth.user?.branchId ?? (list.isNotEmpty ? '${list[0]['id']}' : null);
      });
      if (widget.initialReceived != null &&
          _cart.lines.isNotEmpty &&
          _branchId != null &&
          !_checkout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_checkout) {
            _checkoutFlow(PaymentResult.cash(
              amount: _cart.total,
              received: widget.initialReceived!,
              change: calculateChange(
                  received: widget.initialReceived!, total: _cart.total),
            ));
          }
        });
      }
    }
  }

  Future<void> _loadCustomers() async {
    final r = await ApiClient.instance.get('/customers', query: {'limit': 200});
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _customers = (r.data as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    }
  }

  String _branchName() {
    final b = _branches.where((e) => '${e['id']}' == _branchId).firstOrNull;
    final name = b?['name'];
    return (name != null && '$name'.trim().isNotEmpty) ? '$name' : 'PHARMA+';
  }

  // ──────────────── SEARCH + FILTER ────────────────

  Future<void> _searchMedications(String query) async {
    setState(() => _searching = true);
    final q = query.trim();
    final Map<String, dynamic> params = {'limit': 60};
    if (q.isNotEmpty) params['q'] = q;
    final result = await ApiClient.instance.get('/catalog/medications', query: params);
    if (!mounted) return;
    final rows =
        result.success ? ApiList.of(result.data) : <Map<String, dynamic>>[];
    _catalog = rows
        .map(Medication.fromJson)
        .where((m) => m.stockQuantity == null || m.stockQuantity! > 0)
        .toList();
    _applyFilter();
    if (mounted) setState(() => _searching = false);
    if (query.trim().isEmpty && _catalog.isEmpty && result.success) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      if (_catalog.isEmpty && !_searching) _searchMedications('');
    }
  }

  void _applyFilter() {
    final cat = _activeCategoryId;
    if (cat == null || cat == 'autres') {
      setState(() => _results = List.of(_catalog));
    } else {
      final q = cat.toLowerCase();
      setState(() {
        _results = _catalog
            .where((m) =>
                (m.categoryName?.toLowerCase().contains(q) ?? false) ||
                (m.categoryId?.toLowerCase() == q))
            .toList();
      });
    }
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerSheet.show(context, title: 'Scanner produit');
    if (code == null || code.code.trim().isEmpty) return;
    final result = await ApiClient.instance.get(
      '/catalog/medications/barcode/${Uri.encodeComponent(code.code.trim())}',
    );
    if (!mounted) return;
    final medication = result.data;
    if (!result.success || medication == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('unknownBarcode', context.read<AuthStore>().locale))),
      );
      return;
    }
    setState(() {
      final medMap = medication is Map ? Map<String, dynamic>.from(medication) : <String, dynamic>{};
      _cart.add(Medication.fromJson(medMap));
    });
  }

  // ──────────────── PAYMENT + CHECKOUT ────────────────

  bool get _cashSufficient => _received >= _cart.total || _paymentMode != 'cash';
  double get _change => (_received > _cart.total) ? _received - _cart.total : 0;
  double get _due => (_received < _cart.total) ? _cart.total - _received : 0;

  void _setReceived(String v) =>
      setState(() => _received = double.tryParse(v.replaceAll(',', '.')) ?? 0);

  void _quickReceived(double v) {
    final next = v == _cart.total ? v : _received + v;
    _receivedCtrl.text =
        next == next.roundToDouble() ? next.round().toString() : next.toStringAsFixed(2);
    setState(() => _received = next);
  }

  Future<void> _confirmPayment() async {
    if (_cart.isEmpty || _checkout) return;
    final auth = context.read<AuthStore>();
    if (_branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('selectBranch', auth.locale))),
      );
      return;
    }
    PaymentResult pay;
    if (_paymentMode == 'cash') {
      if (!_cashSufficient) return;
      pay = PaymentResult.cash(
          amount: _cart.total, received: _received, change: _change);
    } else if (_paymentMode == 'visa') {
      pay = PaymentResult.card(amount: _cart.total, cardType: 'visa');
    } else {
      pay = PaymentResult.card(amount: _cart.total, cardType: 'mastercard');
    }
    await _checkoutFlow(pay);
  }

  Future<void> _checkoutFlow([PaymentResult? payment]) async {
    if (_cart.isEmpty || _checkout) return;
    final auth = context.read<AuthStore>();
    if (_branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('selectBranch', auth.locale))),
      );
      return;
    }
    setState(() => _checkout = true);
    try {
      final pay = payment ??
          PaymentResult.cash(
              amount: _cart.total, received: _cart.total, change: 0);
      final result = await ApiClient.instance.post('/sales', body: {
        'branchId': _branchId,
        'saleType': 'pos',
        'items': _cart.lines.map((l) => l.toPayload()).toList(),
        if (_cart.globalDiscountPercent > 0)
          'discount_percent': _cart.globalDiscountPercent,
        if (_cart.globalDiscountFixed > 0)
          'discount_amount': _cart.globalDiscountFixed,
        if (_customerId != null) 'customerId': _customerId,
        'payments': [pay.toPayload()],
      });
      if (result.success) {
        final change = pay.change ??
            calculateChange(received: pay.amount, total: _cart.total);
        final lines = _cart.lines
            .map((l) => CartLineLike(
                  name: l.medication.name,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  tvaRate: l.tvaRate,
                ))
            .toList();
        final gdp = _cart.globalDiscountPercent;
        final pharmacyName = _branchName();
        _cart.clear();
        _received = 0;
        _receivedCtrl.clear();
        _paymentMode = 'cash';
        if (mounted) {
          final msg = pay.method == 'card'
              ? '${S.t('saleSuccess', auth.locale)} · Carte ${pay.cardType ?? ''}'
              : change > 0
                  ? '${S.t('saleSuccess', auth.locale)} · Monnaie : ${Fmt.money(change)} MAD'
                  : S.t('saleSuccess', auth.locale);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
          ReceiptPdf.printSaleReceipt(
            lines: lines,
            pharmacyName: pharmacyName,
            locale: auth.locale,
            globalDiscountPercent: gdp,
            amountReceived: pay.received ?? pay.amount,
            change: change,
          );
        }
      } else if (result.error?.code == 'NETWORK_ERROR') {
        await OfflineStore.instance.savePendingSale(
          'sale-${DateTime.now().millisecondsSinceEpoch}',
          {
            'branchId': _branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
            'payments': [pay.toPayload()],
          },
        );
        await OfflineStore.instance.enqueue(
            method: 'POST',
            path: '/sales',
            body: {
              'branchId': _branchId,
              'items': _cart.lines.map((l) => l.toPayload()).toList(),
            });
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.t('offline', auth.locale))));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.error?.readableMessage ?? 'Erreur')));
        }
      }
    } finally {
      if (mounted) setState(() => _checkout = false);
    }
  }

  // ──────────────── BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('pos', locale)),
        actions: [
          if (_branches.isNotEmpty)
            DropdownButton<String>(
              value: _branchId,
              hint: Text(S.t('branch', locale)),
              underline: const SizedBox.shrink(),
              items: _branches
                  .map((b) => DropdownMenuItem(
                      value: '${b['id']}',
                      child: Text('${b['name'] ?? b['code']}')))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ── EN-TÊTE ──
            // (AppBar already handles this)

            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ── PC/Mac : deux colonnes ──
                    if (constraints.maxWidth > 768) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── GAUCHE : Cartes (catégories + produits) ──
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSearchRow(locale),
                                const SizedBox(height: 8),
                                _buildCategoriesGrid(locale, aspectRatio: 3.5),
                                const SizedBox(height: 10),
                                _buildResultsTable(locale),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // ── DROITE : POS (client, remise, totaux, paiement, actions) ──
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildClientRow(locale),
                                const SizedBox(height: 8),
                                _buildDiscountRow(locale),
                                const SizedBox(height: 8),
                                _buildTotals(locale),
                                const SizedBox(height: 10),
                                _buildPaymentMode(locale),
                                const SizedBox(height: 8),
                                if (_paymentMode == 'cash' && !_cart.isEmpty)
                                  _buildCashReceived(locale),
                                if (_paymentMode == 'cash' && !_cart.isEmpty)
                                  const SizedBox(height: 12),
                                const Spacer(),
                                _buildActions(locale),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    // ── Mobile/Tablet : une seule colonne ──
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchRow(locale),
                        const SizedBox(height: 8),
                        _buildCategoriesGrid(locale),
                        const SizedBox(height: 10),
                        _buildResultsTable(locale),
                        const SizedBox(height: 10),
                        _buildClientRow(locale),
                        const SizedBox(height: 8),
                        _buildDiscountRow(locale),
                        const SizedBox(height: 8),
                        _buildTotals(locale),
                        const SizedBox(height: 10),
                        _buildPaymentMode(locale),
                        const SizedBox(height: 8),
                        if (_paymentMode == 'cash' && !_cart.isEmpty)
                          _buildCashReceived(locale),
                        if (_paymentMode == 'cash' && !_cart.isEmpty)
                          const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 2 : RECHERCHE + SCANNER (sous la barre)
  // ══════════════════════════════════════════
  Widget _buildSearchRow(String locale) {
    return Column(
      children: [
        // ── Barre de recherche pleine largeur ──
        TextField(
          controller: _search,
          onChanged: _searchMedications,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: S.t('search', locale),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.pharmaMuted, size: 20),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            fillColor: AppColors.pharmaSurface,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.goldBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.goldBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.pharmaGold)),
          ),
        ),
        const SizedBox(height: 8),
        // ── Scanner sous la barre ──
        SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: _scan,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A4A32), Color(0xFF0E2A1C)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      color: Color(0xFFE9C873), size: 20),
                  SizedBox(width: 8),
                  Text('Scanner un produit',
                      style: TextStyle(
                          color: Color(0xFFE9C873),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 3 : CATÉGORIES 3D (PosCategoryTile glyphs)
  // ══════════════════════════════════════════
  Widget _buildCategoriesGrid(String locale, {double aspectRatio = 1.0}) {
    final cats = PosCategoriesGrid.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.t('categories', locale),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.pharmaMuted),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: aspectRatio,
          ),
          itemCount: cats.length,
          itemBuilder: (context, index) {
            final c = cats[index];
            final active = _activeCategoryId == c.id;
            return PosCategoryTile(
              label: c.label,
              selected: active,
              onTap: () {
                setState(() {
                  _activeCategoryId = active ? null : c.id;
                  if (c.id == 'autres') _activeCategoryId = null;
                });
                _search.text = _catQueries[c.id] ?? '';
                _searchMedications(_catQueries[c.id] ?? '');
              },
            );
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 4 : TABLEAU PRODUIT / QTÉ / TOTAL
  // ══════════════════════════════════════════
  Widget _buildResultsTable(String locale) {
    final t = _totals;
    if (_cart.isEmpty && _results.isEmpty && !_searching) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: Text('Recherchez ou scannez un produit pour commencer',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.pharmaGold.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('PRODUIT',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pharmaGold,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 2,
                    child: Text('QTÉ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pharmaGold,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 2,
                    child: Text('TOTAL',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pharmaGold,
                            letterSpacing: 0.5))),
                SizedBox(width: 28),
              ],
            ),
          ),
          // ── Cart lines ──
          if (_cart.isEmpty && _searching)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.emerald)),
            )
          else if (_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Panier vide — ajoutez un produit',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ),
            )
          else
            ...List.generate(_cart.lines.length, (i) {
              final line = _cart.lines[i];
              return _ProductRow(
                name: line.medication.name,
                qty: line.quantity.round(),
                lineTotal: line.total,
                onMinus: () {
                  setState(() {
                    if (line.quantity > 1) {
                      line.quantity -= 1;
                    } else {
                      _cart.removeLine(line.medication.id);
                    }
                  });
                },
                onPlus: () => setState(() => line.quantity += 1),
                onDelete: () => setState(
                    () => _cart.removeLine(line.medication.id)),
              );
            }),
          // ── Search results to add ──
          if (_results.isNotEmpty && _cart.isEmpty)
            ...List.generate(_results.length, (i) {
              final m = _results[i];
              return InkWell(
                onTap: () => setState(() => _cart.add(m)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.add_circle_outline,
                          size: 18, color: AppColors.emerald),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 5 : CLIENT
  // ══════════════════════════════════════════
  Widget _buildClientRow(String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded,
              size: 20, color: AppColors.pharmaGold),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _customerId,
                isExpanded: true,
                dropdownColor: AppColors.menu,
                iconEnabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Client comptoir',
                        style: TextStyle(fontSize: 13)),
                  ),
                  ..._customers.map((c) => DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text(
                          '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
                              .trim(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                ],
                onChanged: (v) => setState(() => _customerId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 6 : REMISE
  // ══════════════════════════════════════════
  Widget _buildDiscountRow(String locale) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            onChanged: (v) {
              final d = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              setState(() {
                _cart.globalDiscountPercent = _discountIsPercent ? d : 0;
                if (!_discountIsPercent) _cart.globalDiscountFixed = d;
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: S.t('discount', locale),
              prefixIcon:
                  const Icon(Icons.local_offer_outlined, size: 16),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              fillColor: AppColors.pharmaSurface,
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _DiscountToggle(
          isPercent: _discountIsPercent,
          onChanged: (v) => setState(() => _discountIsPercent = v),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 7+8 : SOUS-TOTAL / TOTAL
  // ══════════════════════════════════════════
  Widget _buildTotals(String locale) {
    final t = _totals;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _TotalLine(label: S.t('subtotal', locale), value: t.subtotal),
          if (t.discount > 0)
            _TotalLine(
                label:
                    '${S.t('discount', locale)} (${_discountIsPercent ? "${_cart.globalDiscountPercent.toStringAsFixed(0)}%" : Fmt.money(_cart.globalDiscountFixed)})',
                value: -t.discount,
                color: AppColors.danger),
          _TotalLine(label: S.t('tva', locale), value: t.tva),
          const Divider(height: 12, color: AppColors.goldBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text('${Fmt.money(t.total)} MAD',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.pharmaGold)),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 9 : MODE DE PAIEMENT
  // ══════════════════════════════════════════
  Widget _buildPaymentMode(String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MODE DE PAIEMENT',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.pharmaMuted,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
                child: _PaymentChip(
              icon: Icons.payments_rounded,
              label: 'Espèces',
              selected: _paymentMode == 'cash',
              onTap: () => setState(() => _paymentMode = 'cash'),
            )),
            const SizedBox(width: 6),
            Expanded(
                child: _PaymentChip(
              icon: Icons.credit_card,
              label: 'Visa',
              selected: _paymentMode == 'visa',
              onTap: () => setState(() => _paymentMode = 'visa'),
              logo: _buildVisaLogo(),
            )),
            const SizedBox(width: 6),
            Expanded(
                child: _PaymentChip(
              icon: Icons.credit_card,
              label: 'Mastercard',
              selected: _paymentMode == 'mastercard',
              onTap: () => setState(() => _paymentMode = 'mastercard'),
              logo: _buildMastercardLogo(),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildVisaLogo() {
    return Container(
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text('VISA',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildMastercardLogo() {
    return SizedBox(
      width: 40,
      height: 24,
      child: CustomPaint(painter: _MastercardLogoPainter()),
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 10 : MONTANT REÇU / MONNAIE
  // ══════════════════════════════════════════
  Widget _buildCashReceived(String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('MONTANT REÇU (MAD)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.pharmaMuted,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextField(
          controller: _receivedCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
          ],
          onChanged: _setReceived,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            hintText: '0,00',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 22),
            fillColor: AppColors.pharmaSurface,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _cashSufficient
                        ? AppColors.emerald
                        : AppColors.danger)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _cashSufficient
                        ? AppColors.emerald
                        : AppColors.danger)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.pharmaGold)),
            suffixIcon: _received > 0
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.white54),
                    onPressed: () {
                      _receivedCtrl.clear();
                      setState(() => _received = 0);
                    })
                : null,
          ),
        ),
        const SizedBox(height: 8),
        // Quick amounts
        Row(
          children: [
            _QuickBtn(label: '+20', onTap: () => _quickReceived(20)),
            const SizedBox(width: 4),
            _QuickBtn(label: '+50', onTap: () => _quickReceived(50)),
            const SizedBox(width: 4),
            _QuickBtn(label: '+100', onTap: () => _quickReceived(100)),
            const SizedBox(width: 4),
            _QuickBtn(label: '+200', onTap: () => _quickReceived(200)),
            const SizedBox(width: 4),
            _QuickBtn(
                label: 'Exact',
                onTap: () {
                  _receivedCtrl.text = _cart.total == _cart.total.roundToDouble()
                      ? _cart.total.round().toString()
                      : Fmt.money(_cart.total);
                  setState(() => _received = _cart.total);
                }),
          ],
        ),
        const SizedBox(height: 10),
        // Change / Due
        if (_received > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cashSufficient
                  ? AppColors.emerald.withValues(alpha: 0.12)
                  : AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _cashSufficient ? AppColors.emerald : AppColors.danger),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    _cashSufficient ? 'MONNAIE / RENDU' : 'RESTE À PAYER',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _cashSufficient
                            ? AppColors.emerald
                            : AppColors.danger)),
                Text(
                    '${_cashSufficient ? Fmt.money(_change) : Fmt.money(_due)} MAD',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _cashSufficient
                            ? AppColors.emerald
                            : AppColors.danger)),
              ],
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  SECTION 11 : ACTIONS
  // ══════════════════════════════════════════
  Widget _buildActions(String locale) {
    final t = _totals;
    final canPay = !_cart.isEmpty &&
        !_checkout &&
        (_paymentMode != 'cash' || _cashSufficient);
    return Row(
      children: [
        Expanded(
          child: _PosButton(
            label: 'Vider',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFB3372F),
            enabled: !_cart.isEmpty,
            onTap: () {
              if (_cart.isEmpty) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Vider le panier ?'),
                  content:
                      const Text('Tous les produits seront supprimés.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler')),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _cart.clear();
                            _received = 0;
                            _receivedCtrl.clear();
                          });
                        },
                        child: const Text('Vider',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PosButton(
            label: 'Suspendre',
            icon: Icons.pause_circle_outline_rounded,
            color: const Color(0xFFB98A1F),
            enabled: !_cart.isEmpty,
            onTap: () {
              if (_cart.isEmpty) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Vente suspendue — reprenez-la ici.')),
              );
              setState(() => _cart.clear());
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PayButton(
            label: canPay
                ? 'Payer ${Fmt.money(t.total)} MAD'
                : _paymentMode == 'cash' && _received > 0 && !_cashSufficient
                    ? 'Montant insuffisant'
                    : 'Payer',
            enabled: canPay,
            onTap: canPay ? () => _confirmPayment() : null,
          ),
        ),
      ],
    );
  }

  // ── Totaux ──
  SaleTotals get _totals => calculateSaleTotalExcl(
        [
          for (final l in _cart.lines)
            SaleLine(
                unitPrice: l.unitPrice,
                quantity: l.quantity,
                tvaRate: l.tvaRate),
        ],
        discountValue: _discountIsPercent
            ? _cart.globalDiscountPercent
            : _cart.globalDiscountFixed,
        discountIsPercent: _discountIsPercent,
      );
}

// ════════════════════════════════════════
//  WIDGETS PRIVÉS
// ════════════════════════════════════════

class _ProductRow extends StatelessWidget {
  final String name;
  final int qty;
  final double lineTotal;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;
  const _ProductRow({
    required this.name,
    required this.qty,
    required this.lineTotal,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          // Product name
          Expanded(
            flex: 4,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          // Qty controls
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyBtn(icon: Icons.remove, onTap: onMinus),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$qty',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
                _QtyBtn(icon: Icons.add, onTap: onPlus),
              ],
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text(Fmt.money(lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.pharmaGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          // Delete
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child:
                  Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: AppColors.emerald),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _TotalLine({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500)),
          Text('${value < 0 ? '-' : ''}${Fmt.money(value.abs())} MAD',
              style: TextStyle(
                  fontSize: 12,
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? logo;
  const _PaymentChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.logo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withValues(alpha: 0.15)
              : AppColors.pharmaSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.goldBorder,
            width: selected ? 1.6 : 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null) ...[
              logo!,
              const SizedBox(height: 6),
            ] else ...[
              Icon(icon,
                  size: 20,
                  color: selected
                      ? AppColors.emerald
                      : Colors.white.withValues(alpha: 0.6)),
              const SizedBox(height: 6),
            ],
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.emerald
                        : Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _DiscountToggle extends StatelessWidget {
  final bool isPercent;
  final ValueChanged<bool> onChanged;
  const _DiscountToggle({required this.isPercent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          _ToggleBtn(
              label: '%',
              selected: isPercent,
              onTap: () => onChanged(true)),
          _ToggleBtn(
              label: 'MAD',
              selected: !isPercent,
              onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.white54)),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.pharmaSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.4)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pharmaGold)),
        ),
      ),
    );
  }
}

class _PosButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  const _PosButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: enabled ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: enabled
                    ? color
                    : Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.25))),
          ],
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _PayButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF0E8C4F), Color(0xFF086B3D)])
              : null,
          color: enabled ? null : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? const Color(0xFF2A7A5A).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined,
                size: 15,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25))),
          ],
        ),
      ),
    );
  }
}

class _MastercardLogoPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final r = s.height * 0.38;
    c.drawCircle(
        Offset(cx - r * 0.55, cy), r + 1,
        Paint()..color = const Color(0x30000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(
        Offset(cx + r * 0.55, cy), r + 1,
        Paint()..color = const Color(0x30000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(Offset(cx - r * 0.55, cy), r,
        Paint()..shader = ui.Gradient.radial(
            Offset(cx - r * 0.55 - 3, cy - 3), r,
            [const Color(0xFFFF4D4D), const Color(0xFFEB001B)]));
    c.drawCircle(Offset(cx + r * 0.55, cy), r,
        Paint()..shader = ui.Gradient.radial(
            Offset(cx + r * 0.55 - 3, cy - 3), r,
            [const Color(0xFFFFC733), const Color(0xFFF79E1B)]));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
