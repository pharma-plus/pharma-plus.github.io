// PMG-POS-REAL
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../pos/payment_models.dart';
import 'pos_category_grid.dart';

/// ============================================================
/// POINT DE VENTE (encart dashboard) — VRAI mini-POS :
/// · recherche catalogue RÉELLE via l'API (/catalog/medications)
/// · panier réel : ajout, quantités +/−, suppression de ligne
/// · remise (% ou MAD) et totaux via calculateSaleTotal()
/// · Vider · Suspendre / Reprendre (persisté localement)
/// · Paiement → ouvre le POS complet avec ce panier pré-rempli
/// ============================================================
/// 8 catégories POS — chacune avec SA miniature 3D peinte (voir
/// `pos_categories.dart` pour les glyphes partagés avec le POS complet).
class PosPanel extends StatefulWidget {
  final VoidCallback onCheckout;

  /// Ouvre le POS complet avec le panier courant pré-rempli et le montant
  /// reçu validé dans la feuille de paiement : l'encaissement se fait
  /// automatiquement avec CE montant réel (pas de seconde saisie).
  final void Function(
          List<Medication> items, double discount, bool isPercent, double received)?
      onPrefilled;
  final bool compact;
  const PosPanel(
      {super.key,
      required this.onCheckout,
      this.onPrefilled,
      this.compact = false});
  @override
  State<PosPanel> createState() => _PosPanelState();
}

class _PosPanelState extends State<PosPanel> {
  final _search = TextEditingController();
  final _discountCtrl = TextEditingController();
  final Map<String, Medication> _cart = {};
  final Map<String, int> _qty = {};
  final Map<String, Medication> _results = {};
  final Map<String, int> _heldQty = {};
  List<String> _heldIds = [];
  double _discount = 0;
  bool _discountPercent = true;
  bool _searching = false;
  Timer? _debounce;
  int _emptyReloads = 0;
  String _paymentMode = 'cash'; // cash | visa | mastercard
  double _received = 0;
  final _receivedCtrl = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  String? _customerId;

  static const _kHeldKey = 'pmg_pos_held_sales';

  /// Mots-clés de recherche réels par catégorie (filtre API du catalogue).
  static const Map<String, String> _catQueries = {
    'all': '',
    'antalgiques': 'ibuprof',
    'antibiotiques': 'amoxicill',
    'cardiologie': 'bisoprolol',
    'diabete': 'metformin',
    'vitamines': 'vitamine',
    'respiratoire': 'salbutamol',
    'digestif': 'omeprazole',
    'autres': '',
  };

  static const _cats = <(String, String)>[
    ('Antalgiques', 'antalgiques'),
    ('Antibiotiques', 'antibiotiques'),
    ('Cardiologie', 'cardiologie'),
    ('Diabète', 'diabete'),
    ('Vitamines', 'vitamines'),
    ('Respiratoire', 'respiratoire'),
    ('Digestif', 'digestif'),
    ('Autres', 'autres'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHeld();
    _loadCustomers();
    _doSearch(_search.text.trim());
  }

  @override
  void dispose() {
    _search.dispose();
    _discountCtrl.dispose();
    _receivedCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  SaleTotals get _totals => calculateSaleTotalExcl(
        [
          for (final m in _cart.values)
            SaleLine(
                unitPrice: m.priceSale,
                quantity: (_qty[m.id] ?? 1).toDouble(),
                tvaRate: m.tvaRate / 100),
        ],
        discountValue: _discount,
        discountIsPercent: _discountPercent,
      );

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _doSearch('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(query));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searching = true);
    final r = await ApiClient.instance.get(
        '/catalog/medications',
        query: {'q': query.trim(), 'limit': 60});
    if (!mounted) return;
    if (!r.success) {
      debugPrint('[PosPanel] catalog load failed: ${r.error} base=${ApiClient.instance.baseUrl}');
    }
    final items =
        r.success ? ApiList.of(r.data) : <Map<String, dynamic>>[];
    setState(() {
      _results.clear();
      for (final it in items) {
        final m = Medication.fromJson(it);
        if (it['id'] != null &&
            (m.stockQuantity == null || m.stockQuantity! > 0)) {
          _results['${it['id']}'] = m;
        }
      }
      _searching = false;
    });
    if (query.trim().isEmpty && _results.isEmpty && r.success && mounted) {
      if (_emptyReloads >= 3) return;
      _emptyReloads++;
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && _results.isEmpty && !_searching) _doSearch('');
    } else if (_results.isNotEmpty) {
      _emptyReloads = 0;
    }
  }

  void _searchCategory(String kind) {
    final q = _catQueries[kind] ?? '';
    if (q.isNotEmpty &&
        _search.text.trim().toLowerCase() == q.trim().toLowerCase()) {
      _search.text = '';
      _doSearch('');
      return;
    }
    _search.text = q;
    _doSearch(q);
  }

  void _add(Medication m) {
    setState(() {
      _qty[m.id] = (_qty[m.id] ?? 0) + 1;
      _cart[m.id] = m;
      _results.clear();
      _search.clear();
    });
  }

  void _bump(String id, int delta) {
    final q = (_qty[id] ?? 1) + delta;
    setState(() {
      if (q <= 0) {
        _qty.remove(id);
        _cart.remove(id);
      } else {
        _qty[id] = q;
      }
    });
  }

  void _clearCart() => setState(() {
        _cart.clear();
        _qty.clear();
        _discount = 0;
        _discountCtrl.clear();
        _received = 0;
        _receivedCtrl.clear();
        _paymentMode = 'cash';
        _customerId = null;
      });

  Future<void> _scanBarcode() async {
    final result = await BarcodeScannerSheet.show(context, title: 'Scanner produit');
    if (result != null) await _addScanned(result);
  }

  /// SCAN CONTINU (panier Dashboard) : chaque lecture ajoute +1 au panier.
  Future<void> _scanContinuous() async {
    await BarcodeScannerSheet.showContinuous(context,
        title: 'Scan continu (panier)',
        onScan: (result) => _addScanned(result, continuous: true));
  }

  Future<void> _addScanned(ScanResult scanned, {bool continuous = false}) async {
    final code = scanned.lookupCode;
    if (code.isEmpty || !mounted) return;
    final apiResult = await ApiClient.instance.get(
      '/catalog/medications/barcode/${Uri.encodeComponent(code)}',
    );
    if (!mounted) return;
    if (!apiResult.success || apiResult.data == null) {
      if (!continuous) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Code inconnu : $code')));
      }
      return;
    }
    final med = apiResult.data;
    final medMap = med is Map ? Map<String, dynamic>.from(med) : <String, dynamic>{};
    final m = Medication.fromJson(medMap);
    setState(() {
      _qty[m.id] = (_qty[m.id] ?? 0) + 1;
      _cart[m.id] = m;
    });
  }

  Future<void> _loadHeld() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString(_kHeldKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _heldIds = list.map((e) => '${e['id']}').toList();
        for (final e in list) {
          final items = e['items'] as List? ?? const [];
          _heldQty['${e['id']}'] = items.fold<int>(
              0, (s, it) => s + (((it as Map)['qty'] as num?)?.toInt() ?? 0));
        }
      });
    } catch (_) {}
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

  Future<void> _hold() async {
    if (_cart.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing =
        jsonDecode(prefs.getString(_kHeldKey) ?? '[]') as List? ?? [];
    final id = 'H${DateTime.now().millisecondsSinceEpoch}';
    existing.add({
      'id': id,
      'savedAt': DateTime.now().toIso8601String(),
      'discount': _discount,
      'isPercent': _discountPercent,
      'items': [
        for (final m in _cart.values)
          {
            'id': m.id,
            'name': m.name,
            'price_sale': m.priceSale,
            'qty': _qty[m.id] ?? 1,
          }
      ],
    });
    await prefs.setString(_kHeldKey, jsonEncode(existing));
    if (!mounted) return;
    _clearCart();
    setState(() => _heldIds.add(id));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente suspendue — reprenez-la ici.')));
  }

  Future<void> _resume(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing =
        jsonDecode(prefs.getString(_kHeldKey) ?? '[]') as List? ?? [];
    Map<String, dynamic>? held;
    for (final e in existing.whereType<Map<String, dynamic>>()) {
      if ('${e['id']}' == id) {
        held = Map<String, dynamic>.from(e);
        break;
      }
    }
    if (held == null) return;
    final Map<String, dynamic> h = held;
    final items = (h['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    setState(() {
      for (final it in items) {
        final m = Medication(
          id: '${it['id']}',
          name: '${it['name']}',
          priceSale: (it['price_sale'] as num?)?.toDouble() ?? 0,
        );
        _cart[m.id] = m;
        _qty[m.id] = (it['qty'] as num?)?.toInt() ?? 1;
      }
      _discount = (h['discount'] as num?)?.toDouble() ?? 0;
      _discountCtrl.text = _discount == 0 ? '' : '$_discount';
      _heldIds.remove(id);
      _heldQty.remove(id);
    });
    await prefs.setString(
        _kHeldKey,
        jsonEncode(existing
            .whereType<Map<String, dynamic>>()
            .where((e) => '${e['id']}' != id)
            .toList()));
  }

  String _fmt(double v) => Fmt.money(v);

  void _pay() {
    if (_cart.isEmpty) {
      widget.onCheckout();
      return;
    }
    PaymentResult pay;
    if (_paymentMode == 'cash') {
      if (!_cashSufficient) return;
      pay = PaymentResult.cash(
          amount: _totals.total, received: _received, change: _change);
    } else if (_paymentMode == 'visa') {
      pay = PaymentResult.card(amount: _totals.total, cardType: 'visa');
    } else {
      pay = PaymentResult.card(amount: _totals.total, cardType: 'mastercard');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pay.method == 'card'
          ? 'Vente enregistrée · Carte ${pay.cardType ?? ''}'
          : _change > 0
              ? 'Vente enregistrée · Monnaie : ${Fmt.money(_change)} MAD'
              : 'Vente enregistrée')),
    );
    _clearCart();
  }

  bool get _cashSufficient => _received >= _totals.total || _paymentMode != 'cash';
  double get _change => (_received > _totals.total) ? _received - _totals.total : 0;

  void _setReceived(String v) =>
      setState(() => _received = double.tryParse(v.replaceAll(',', '.')) ?? 0);

  void _quickReceived(double v) {
    final next = v == _totals.total ? v : _received + v;
    _receivedCtrl.text =
        next == next.roundToDouble() ? next.round().toString() : next.toStringAsFixed(2);
    setState(() => _received = next);
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    return _PanelShell(
      title: 'POINT DE VENTE',
      icon: Icons.point_of_sale_rounded,
      iconColor: AppColors.emerald,
      trailing: InkWell(
        onTap: widget.onCheckout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFC9A24B).withValues(alpha: 0.5)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFE9C873)),
            SizedBox(width: 5),
            Text('POS complet',
                style: TextStyle(
                    color: Color(0xFFE9C873),
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── 1) RECHERCHE ──
        Container(
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFC9A24B).withValues(alpha: 0.4))),
          child: Row(children: [
            const SizedBox(width: 8),
            Icon(Icons.search_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.45)),
            const SizedBox(width: 5),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Rechercher…',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF), fontSize: 11)),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5)),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        // ── 2) SCANNER (simple + continu) ──
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: _scanBarcode,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A4A32), Color(0xFF0E2A1C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFC9A24B).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: Color(0xFFE9C873), size: 15),
                    SizedBox(width: 6),
                    Text('Scanner un produit',
                        style: TextStyle(
                            color: Color(0xFFE9C873),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _scanContinuous,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A4A32), Color(0xFF0E2A1C)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFC9A24B).withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.all_inclusive_rounded,
                    color: Color(0xFFE9C873), size: 15),
                SizedBox(width: 4),
                Text('Continu',
                    style: TextStyle(
                        color: Color(0xFFE9C873),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        // ── 3) CATÉGORIES 3D ──
        LayoutBuilder(builder: (context, cons) {
          const gap = 6.0;
          const tileH = 48.0;
          final cellW = (cons.maxWidth - 3 * gap) / 4;
          final active = _search.text.trim().toLowerCase();
          return SizedBox(
            height: tileH * 2 + gap,
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: cellW / tileH,
              children: [
                for (final (name, kind) in _cats)
                  _CatChip(
                      name: name,
                      selected: active.isNotEmpty &&
                          active ==
                              (_catQueries[kind] ?? '').trim().toLowerCase(),
                      onTap: () => _searchCategory(kind)),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        // ── 4) TABLEAU UNIQUE (header + panier + catalogue) ──
        const _RowHeader(),
        const SizedBox(height: 4),
        Expanded(
          child: _cart.isEmpty && _results.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_heldIds.isNotEmpty)
                      for (final id in _heldIds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _PanelButton(
                              label: 'Reprendre (${_heldQty[id] ?? 0} art.)',
                              icon: Icons.unarchive_rounded,
                              color: const Color(0xFF2A7A5A),
                              onTap: () => _resume(id)),
                        ),
                    Text('Recherchez un médicament',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10)),
                  ]))
              : ListView(
                  shrinkWrap: false,
                  children: [
                    for (final m in _cart.values)
                      _CartRow(
                        name: m.name,
                        qty: _qty[m.id] ?? 1,
                        lineTotal: m.priceSale * (_qty[m.id] ?? 1),
                        onMinus: () => _bump(m.id, -1),
                        onPlus: () => _bump(m.id, 1),
                        onDelete: () => _bump(m.id, -(_qty[m.id] ?? 1)),
                      ),
                    if (_results.isNotEmpty)
                      for (final m in _results.values)
                        InkWell(
                          onTap: () => _add(m),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            child: Row(children: [
                              const Icon(Icons.add_circle_outline_rounded,
                                  size: 13, color: AppColors.emeraldLight),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                    '${m.name}${m.dosage != null ? ' · ${m.dosage}' : ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                              ),
                              Text(_fmt(m.priceSale),
                                  style: const TextStyle(
                                      color: Color(0xFFE9C873), fontSize: 10.5, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        // ── 5) CLIENT COMPTOIR ──
        if (_cart.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC9A24B).withValues(alpha: 0.3))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _customerId,
                dropdownColor: const Color(0xFF1A2E23),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.5)),
                hint: Row(children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 16, color: Color(0xFFE9C873)),
                  const SizedBox(width: 8),
                  Text('Client comptoir',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
                selectedItemBuilder: (ctx) => [
                  for (final c in _customers)
                    Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: Color(0xFFE9C873)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${c['name'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                ],
                items: [
                  for (final c in _customers)
                    DropdownMenuItem(
                      value: '${c['id']}',
                      child: Text('${c['name'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                    ),
                ],
                onChanged: (v) => setState(() => _customerId = v),
              ),
            ),
          ),
        // ── 6) REMISE + TVA ──
        if (_cart.isNotEmpty)
          Row(children: [
            SizedBox(
              width: 80,
              height: 30,
              child: TextField(
                controller: _discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => setState(
                    () => _discount = double.tryParse(v.replaceAll(',', '.')) ?? 0),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    hintText: 'Remise',
                    hintStyle:
                        const TextStyle(color: Color(0x55FFFFFF), fontSize: 10)),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _discountPercent = !_discountPercent),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                    color: _discountPercent
                        ? const Color(0xFF17523A)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: const Color(0xFF2A7A5A).withValues(alpha: 0.6))),
                child: Center(
                    child: Text(_discountPercent ? '%' : 'MAD',
                        style: const TextStyle(
                            color: Color(0xFF7BEBA4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900))),
              ),
            ),
            const Spacer(),
            Text('TVA ${_fmt(t.tva)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9.5)),
          ]),
        if (_cart.isNotEmpty)
          const SizedBox(height: 4),
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF0E2A1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2E7A50).withValues(alpha: 0.55))),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (t.discount > 0)
                    Text('-${_fmt(t.discount)}',
                        style: const TextStyle(
                            color: Color(0xFFB3372F),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  const Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                  Text(_fmt(t.total),
                      style: const TextStyle(
                          color: Color(0xFF7BEBA4),
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ]),
          ),
        // ── 7) PAIEMENT (montant reçu — espèces uniquement) ──
        if (_cart.isNotEmpty && _paymentMode == 'cash') ...[
          const SizedBox(height: 6),
          TextField(
            controller: _receivedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
            onChanged: _setReceived,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 18),
              fillColor: Colors.white.withValues(alpha: 0.04),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.goldBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.goldBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.pharmaGold)),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            _QuickPayBtn(label: '+20', onTap: () => _quickReceived(20)),
            const SizedBox(width: 4),
            _QuickPayBtn(label: '+50', onTap: () => _quickReceived(50)),
            const SizedBox(width: 4),
            _QuickPayBtn(label: '+100', onTap: () => _quickReceived(100)),
            const SizedBox(width: 4),
            _QuickPayBtn(label: 'Exact', onTap: () {
              _receivedCtrl.text = _totals.total == _totals.total.roundToDouble()
                  ? _totals.total.round().toString()
                  : _totals.total.toStringAsFixed(2);
              setState(() => _received = _totals.total);
            }),
          ]),
          if (_received > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _cashSufficient
                      ? AppColors.emerald.withValues(alpha: 0.1)
                      : AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _cashSufficient ? AppColors.emerald : AppColors.danger)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_cashSufficient ? 'MONNAIE' : 'RESTE A PAYER',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _cashSufficient
                                ? AppColors.emerald
                                : AppColors.danger)),
                    Text(
                        '${Fmt.money(_cashSufficient ? _change : _totals.total - _received)} MAD',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _cashSufficient
                                ? AppColors.emerald
                                : AppColors.danger)),
                  ]),
            ),
          ],
        ],
        // ── 8) MODE DE PAIEMENT (3 boutons avec logos) ──
        if (_cart.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PaymentModeBtn(
                  selected: _paymentMode == 'cash',
                  selectedColor: AppColors.emerald,
                  onTap: () => setState(() => _paymentMode = 'cash'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_rounded,
                          size: 16,
                          color: _paymentMode == 'cash'
                              ? AppColors.emerald
                              : Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 5),
                      Text('Especes',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _paymentMode == 'cash'
                                  ? AppColors.emerald
                                  : Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _PaymentModeBtn(
                  selected: _paymentMode == 'visa',
                  selectedColor: const Color(0xFF1A1F71),
                  onTap: () => setState(() => _paymentMode = 'visa'),
                  child: Container(
                    width: 42,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F71),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: const Text('VISA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                  child: _PaymentModeBtn(
                  selected: _paymentMode == 'mastercard',
                  selectedColor: const Color(0xFFD4760A),
                  onTap: () => setState(() => _paymentMode = 'mastercard'),
                  child: SizedBox(
                    width: 44,
                    height: 28,
                    child: CustomPaint(
                      painter: _MastercardPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        // ── 9) 3 BOUTONS — Vider / Suspendre / Payer ──
        Row(children: [
          Expanded(
              child: _PanelButton(
                  label: 'Vider',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFB3372F),
                  onTap: _clearCart)),
          const SizedBox(width: 6),
          Expanded(
              child: _PanelButton(
                  label: 'Suspendre',
                  icon: Icons.pause_circle_outline_rounded,
                  color: const Color(0xFFB98A1F),
                  onTap: _hold)),
          const SizedBox(width: 6),
          Expanded(
              child: _PayButton(
                  label: 'Payer',
                  onTap: _pay)),
        ]),
      ]),
    );
  }
}

/// Coquille des panneaux latéraux (identique au style du dashboard).
class _PanelShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;
  const _PanelShell({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dividerDark),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6)),
          ),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 10),
        Expanded(child: child),
      ]),
    );
  }
}

/// En-tête de la table panier.
class _RowHeader extends StatelessWidget {
  const _RowHeader();
  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6);
    return Row(children: [
      Expanded(child: Text('PRODUIT', style: style)),
      SizedBox(
          width: 86,
          child: Text('QTE', textAlign: TextAlign.center, style: style)),
      SizedBox(
          width: 68,
          child: Text('TOTAL', textAlign: TextAlign.right, style: style)),
      const SizedBox(width: 20),
    ]);
  }
}

/// Tuile de catégorie 3D pour le mini-POS.
class _CatChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip(
      {required this.name, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PosCategoryTile(label: name, selected: selected, onTap: onTap);
  }
}

/// Bouton d'action du panneau.
class _PanelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PanelButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Bouton Payer avec gradient vert (identique au GradientButton du POS complet).
class _PayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0E8C4F), Color(0xFF086B3D)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A7A5A).withValues(alpha: 0.6))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.payments_outlined, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Bouton de mode de paiement avec logo custom.
class _PaymentModeBtn extends StatelessWidget {
  final Widget child;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  const _PaymentModeBtn({
    required this.child,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? selectedColor
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.6 : 0.8),
        ),
        child: child,
      ),
    );
  }
}

class _QuickPayBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickPayBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70)),
        ),
      ),
    );
  }
}

/// Ligne du panier : nom · contrôles quantité · total ligne · suppression.
class _CartRow extends StatelessWidget {
  final String name;
  final int qty;
  final double lineTotal;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;
  const _CartRow({
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
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(children: [
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          width: 86,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InkWell(
                onTap: onMinus,
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 15, color: Color(0xFF7BEBA4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text('$qty',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            InkWell(
                onTap: onPlus,
                child: const Icon(Icons.add_circle_outline_rounded,
                    size: 15, color: Color(0xFF7BEBA4))),
          ]),
        ),
        SizedBox(
          width: 62,
          child: Text(Fmt.money(lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Color(0xFFE9C873),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        InkWell(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFFB3372F))),
      ]),
    );
  }
}

/// Peintre pour le logo Mastercard (deux cercles se chevauchant).
class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final r = s.height * 0.38;
    // Ombre portée
    c.drawCircle(
        Offset(cx - r * 0.55, cy), r + 1,
        Paint()..color = const Color(0x30000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(
        Offset(cx + r * 0.55, cy), r + 1,
        Paint()..color = const Color(0x30000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Cercle gauche (rouge)
    c.drawCircle(Offset(cx - r * 0.55, cy), r,
        Paint()..shader = ui.Gradient.radial(
            Offset(cx - r * 0.55 - 3, cy - 3), r,
            [const Color(0xFFFF4D4D), const Color(0xFFEB001B)]));
    // Cercle droit (orange)
    c.drawCircle(Offset(cx + r * 0.55, cy), r,
        Paint()..shader = ui.Gradient.radial(
            Offset(cx + r * 0.55 - 3, cy - 3), r,
            [const Color(0xFFFFC733), const Color(0xFFF79E1B)]));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
