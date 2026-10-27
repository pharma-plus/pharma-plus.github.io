// PMG-POS-REAL
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../pos/payment_models.dart';
import '../pos/pos_models.dart';
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

  /// Transfère le panier encaissé au POS complet : celui-ci enregistre
  /// réellement la vente (stock, paiement, ticket) avec CE paiement,
  /// sans seconde saisie.
  final void Function(List<CartLine> lines, double discount, bool isPercent,
      PaymentResult payment, String? customerId)? onPrefilled;
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
  final Map<String, double> _stock = {};
  final Map<String, int> _heldQty = {};
  List<String> _heldIds = [];
  bool _resuming = false;
  bool _holding = false;
  double _discount = 0;
  bool _discountPercent = true;
  bool _searching = false;
  Timer? _debounce;
  int _emptyReloads = 0;
  String _paymentMode = 'cash'; // cash | visa | mastercard
  double _received = 0;
  final _receivedCtrl = TextEditingController();
  bool _checkout = false; // anti double-clic pendant POST /sales

  // Isolation des rebuilds : le champ « montant reçu » notifie uniquement
  // le bloc monnaie au lieu de reconstruire tout le panneau à chaque frappe.
  final ValueNotifier<double> _receivedVN = ValueNotifier<double>(0);
  List<Map<String, dynamic>> _customers = [];
  String? _customerId;
  String? _branchId; // fallback via /branches si AuthStore n'a pas de branch

  static const _kHeldKey = 'pmg_pos_held_sales';

  // Dernier utilisateur connu : permet de détecter un changement de
  // caissier (caisse partagée) et de suspendre le panier en cours.
  String? _lastUserId;

  /// Facettes réelles du catalogue : formes les plus fréquentes (API
  /// /catalog/medications/facets), plus de mots-clés en dur.
  List<Map<String, dynamic>> _facetForms = [];
  String? _activeForm;

  static const _kAllLabel = 'Tout';

  @override
  void initState() {
    super.initState();
    _lastUserId = AuthStore.instance.user?.id;
    AuthStore.instance.addListener(_onAuthChanged);
    _loadHeld();
    _loadCustomers();
    _loadFacets();
    _loadBranchId();
    _doSearch(_search.text.trim());
  }

  /// Changement d'utilisateur détecté (changement de caissier) :
  /// le panier en cours est suspendu POUR l'employé précédent puis la
  /// liste des ventes suspendues est rechargée pour le nouvel employé.
  void _onAuthChanged() {
    final uid = AuthStore.instance.user?.id;
    if (uid == _lastUserId) return;
    final prev = _lastUserId;
    _lastUserId = uid;
    if (_cart.isEmpty && _heldIds.isEmpty) return;
    if (_cart.isNotEmpty && prev != null) {
      _hold(asUserId: prev).whenComplete(_loadHeld);
    } else {
      _loadHeld();
    }
  }

  /// Résout le branchId : AuthStore d'abord, sinon première branche de l'API
  /// (même logique que PosPage._loadBranches).
  Future<void> _loadBranchId() async {
    final fromAuth = AuthStore.instance.user?.branchId;
    if (fromAuth != null && fromAuth.isNotEmpty) {
      _branchId = fromAuth;
      return;
    }
    final r = await ApiClient.instance.get('/branches');
    if (!mounted || !r.success) return;
    final list = (r.data as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (list.isNotEmpty) {
      setState(() => _branchId = '${list[0]['id']}');
    }
  }

  Future<void> _loadFacets() async {
    final r = await ApiClient.instance.get('/catalog/medications/facets');
    if (!mounted || !r.success || r.data is! Map) return;
    final d = Map<String, dynamic>.from(r.data as Map);
    setState(() {
      _facetForms = (d['forms'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .take(7)
          .toList();
    });
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_onAuthChanged);
    _search.dispose();
    _discountCtrl.dispose();
    _receivedCtrl.dispose();
    _debounce?.cancel();
    _receivedVN.dispose();
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
    final params = <String, dynamic>{'q': query.trim(), 'limit': 60};
    if (_activeForm != null && _activeForm!.isNotEmpty) {
      params['form'] = 'eq.$_activeForm';
    }
    final r = await ApiClient.instance
        .get('/catalog/medications', query: params);
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
    _loadStockForResults();
  }

  /// Charge le stock réel (stock_balances) pour les ids affichés.
  /// /catalog/medications ne retourne PAS stock_quantity (colonne absente
  /// de la table medications) : sans cet appel, _stock reste vide et tout
  /// ajout affichait « Stock non vérifiable » (bug PC dashboard).
  Future<void> _loadStockForResults() async {
    final ids =
        _results.keys.where((id) => !_stock.containsKey(id)).toList();
    if (ids.isEmpty) return;
    try {
      final r = await ApiClient.instance
          .get('/catalog/medications/stock', query: {'ids': ids.take(100).join(',')});
      if (!mounted || !r.success || r.data is! List) return;
      setState(() {
        for (final e in r.data as List) {
          if (e is Map) {
            _stock['${e['medication_id']}'] =
                (e['quantity'] as num?)?.toDouble() ?? 0;
          }
        }
      });
    } catch (_) {}
  }

  void _toggleForm(String form) {
    setState(() {
      _activeForm = _activeForm == form ? null : form;
    });
    _doSearch(_search.text.trim());
  }

  Future<void> _add(Medication m) async {
    // Vérifier le stock (map _stock) avant ajout — repli par produit si absent
    if (!_stock.containsKey(m.id)) {
      try {
        final r = await ApiClient.instance
            .get('/catalog/medications/stock', query: {'ids': m.id});
        if (r.success && r.data is List) {
          for (final e in r.data as List) {
            if (e is Map) {
              _stock['${e['medication_id']}'] =
                  (e['quantity'] as num?)?.toDouble() ?? 0;
            }
          }
        }
      } catch (_) {}
    }
    final stock = _stock[m.id];
    if (stock == null) {
      _showStockUnknownDialog();
      return;
    }
    if (stock <= 0) {
      _showStockZeroDialog();
      return;
    }
    final inCart = _qty[m.id] ?? 0;
    if (inCart + 1 > stock) {
      _showStockInsufficientDialog(m.name, stock - inCart);
      return;
    }
    setState(() {
      _qty[m.id] = (_qty[m.id] ?? 0) + 1;
      _cart[m.id] = m;
      _results.clear();
      _search.clear();
    });
  }

  void _showStockZeroDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produit indisponible'),
        content: const Text(
          'Ce médicament figure dans le catalogue, mais il n\'est actuellement pas disponible en stock dans votre pharmacie. '
          'Il ne peut pas être ajouté au panier. Enregistrez une réception de stock avant de procéder à la vente.\n\n'
          'Stock disponible : 0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showStockUnknownDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stock non vérifiable'),
        content: const Text(
          'Disponibilité du stock impossible à vérifier. Veuillez vérifier le stock avant de continuer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showStockInsufficientDialog(String name, double available) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stock insuffisant'),
        content: Text(
          'Quantité disponible pour « $name » : ${available.round()}. '
          'Vous ne pouvez pas ajouter plus que la quantité en stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _bump(String id, int delta) {
    // Vérifier le stock si on augmente la quantité
    if (delta > 0) {
      final m = _cart[id];
      final stock = _stock[id];
      if (stock != null) {
        final current = _qty[id] ?? 0;
        if (current + delta > stock) {
          _showStockInsufficientDialog(m!.name, stock - current);
          return;
        }
      }
    }
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

  void _clearCart() {
    setState(() {
      _cart.clear();
      _qty.clear();
      _discount = 0;
      _discountCtrl.clear();
      _received = 0;
      _receivedCtrl.clear();
      _paymentMode = 'cash';
      _customerId = null;
    });
    _receivedVN.value = 0;
  }

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
      final uid = AuthStore.instance.user?.id;
      // Verrou multi-employés : chaque employé ne voit QUE ses propres
      // ventes suspendues (aucun panier transféré à un collègue).
      final list = (jsonDecode(raw) as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((e) {
            final owner = e['userId'];
            return owner == null || owner == uid; // entrées héritées: visibles
          })
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

  Future<void> _hold({String? asUserId}) async {
    if (_cart.isEmpty || _holding) return; // anti double-clic
    _holding = true;
    try {
    final prefs = await SharedPreferences.getInstance();
    final existing =
        jsonDecode(prefs.getString(_kHeldKey) ?? '[]') as List? ?? [];
    final id = 'H${DateTime.now().millisecondsSinceEpoch}';
    existing.add({
      'id': id,
      // Portée multi-employés : la vente suspendue est propriété de
      // l'employé qui l'a créée (pas de transfert de panier).
      'userId': asUserId ?? AuthStore.instance.user?.id,
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
  } finally {
    _holding = false;
  }
  }

  /// Supprime définitivement une vente suspendue (annulation autorisée).
  Future<void> _dropHeld(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHeldKey) ?? '[]';
    await prefs.setString(
        _kHeldKey,
        jsonEncode((jsonDecode(raw) as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((e) => '${e['id']}' != id)
            .toList()));
    if (!mounted) return;
    setState(() {
      _heldIds.remove(id);
      _heldQty.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente suspendue supprimée')));
  }

  Future<void> _resume(String id) async {
    if (_resuming) return; // anti double-clic / reprises rapprochées
    _resuming = true;
    try {
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
    // Un employé ne peut reprendre qu'une vente qu'il a suspendue lui-même.
    final owner = h['userId'];
    if (owner != null && owner != AuthStore.instance.user?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vente suspendue par un autre employé.')));
      }
      await _loadHeld();
      return;
    }
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
    // Revérifiation du stock après reprise : la suspension peut dater,
    // un produit peut être épuisé depuis. Message explicite, sans blocage —
    // la validation finale revérifie côté serveur.
    await _verifyHeldStock(items);
    await prefs.setString(
        _kHeldKey,
        jsonEncode(existing
            .whereType<Map<String, dynamic>>()
            .where((e) => '${e['id']}' != id)
            .toList()));
  } finally {
    _resuming = false;
  }
  }

  /// Revérifie le stock (lots réels) des produits d'une vente reprise.
  Future<void> _verifyHeldStock(List<Map<String, dynamic>> items) async {
    try {
      final r = await ApiClient.instance.get('/catalog/medications/stock',
          query: {'ids': items.map((e) => '${e['id']}').join(',')});
      if (!r.success || r.data is! List) return;
      final avail = <String, double>{};
      for (final e in r.data as List) {
        if (e is Map) {
          avail['${e['medication_id']}'] =
              (e['quantity'] as num?)?.toDouble() ?? 0;
        }
      }
      final problems = <String>[];
      for (final it in items) {
        final want = (it['qty'] as num?)?.toDouble() ?? 1;
        final have = avail['${it['id']}'];
        final name = '${it['name'] ?? it['id']}';
        if (have == null || have <= 0) {
          problems.add('$name : indisponible');
        } else if (want > have) {
          problems.add(
              '$name : ${want.toStringAsFixed(0)} demandés, ${have.toStringAsFixed(0)} en stock');
        }
      }
      if (problems.isEmpty || !mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock à corriger'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Vente reprise, mais ces produits ne sont plus disponibles en quantité suffisante :'),
                const SizedBox(height: 8),
                for (final p in problems)
                  Text('• $p',
                      style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 8),
                const Text('Ajustez les quantités avant le paiement.'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Corriger le panier')),
          ],
        ),
      );
    } catch (_) {}
  }

  String _fmt(double v) => Fmt.money(v);

  void _pay() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panier vide — ajoutez un produit avant de payer.')),
      );
      return;
    }
    if (_checkout) return; // anti double-clic
    PaymentResult pay;
    if (_paymentMode == 'cash') {
      if (!_cashSufficient) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Montant reçu insuffisant — reste ${_fmt(_totals.total - _received)} MAD à payer')),
        );
        return;
      }
      pay = PaymentResult.cash(
          amount: _totals.total, received: _received, change: _change);
    } else if (_paymentMode == 'visa') {
      pay = PaymentResult.card(amount: _totals.total, cardType: 'visa');
    } else {
      pay = PaymentResult.card(amount: _totals.total, cardType: 'mastercard');
    }
    _executeSale(pay);
  }

  /// Exécute la vente directement via POST /sales (sans naviguer vers PosPage).
  Future<void> _executeSale(PaymentResult pay) async {
    final branchId = _branchId ?? AuthStore.instance.user?.branchId;
    if (branchId == null || branchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun point de vente assigné — rechargez la page.')),
        );
      }
      return;
    }
    setState(() => _checkout = true);
    // Feedback IMMEDIAT : le bouton ne doit jamais sembler « mort ».
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Enregistrement de la vente…')),
    );
    try {
      // nextInt(max) exige 0 < max < 2^32. Sur Web (dart2js), `1 << 32`
      // vaut 0 (décalage 32 bits) → RangeError. On fixe 2^31-1, valide partout.
      final clientSaleId =
          '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(0x7fffffff)}'
              .hashCode
              .toString();
      final saleBody = <String, dynamic>{
        'branchId': branchId,
        'saleType': 'pos',
        'clientSaleId': clientSaleId,
        'items': [
          for (final m in _cart.values)
            {
              'medication_id': m.id,
              'quantity': (_qty[m.id] ?? 1).toDouble(),
              'unit_price': m.priceSale,
            }
        ],
        if (_discount > 0)
          _discountPercent ? 'discount_percent' : 'discount_amount': _discount,
        if (_customerId != null) 'customerId': _customerId,
        'payments': [pay.toPayload()],
      };
      final result = await ApiClient.instance.post('/sales',
          body: saleBody, timeout: const Duration(seconds: 60));
      if (!mounted) return;
      if (result.success) {
        final saleNumber = (result.data is Map)
            ? '${(result.data as Map)['number'] ?? ''}'
            : '';
        final msg = (pay.method == 'card'
                ? 'Vente enregistrée · Carte ${pay.cardType ?? ''}'
                : (pay.change != null && pay.change! > 0)
                    ? 'Vente enregistrée · Monnaie : ${Fmt.money(pay.change!)} MAD'
                    : 'Vente enregistrée · ${Fmt.money(pay.amount)} MAD') +
            (saleNumber.isNotEmpty ? ' · $saleNumber' : '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 6), content: Text(msg)));
        // Impression ticket (même service que le POS complet).
        final receiptLines = [
          for (final m in _cart.values)
            CartLineLike(
              name: m.name,
              quantity: (_qty[m.id] ?? 1).toDouble(),
              unitPrice: m.priceSale,
              tvaRate: m.tvaRate,
            ),
        ];
        ReceiptPdf.printSaleReceipt(
          lines: receiptLines,
          pharmacyName: 'PHARMA+',
          locale: AuthStore.instance.locale,
          globalDiscountPercent: _discountPercent ? _discount : 0,
          globalDiscountAmount: _discountPercent ? 0 : _discount,
          amountReceived: pay.received ?? pay.amount,
          change: pay.change ?? 0,
        );
        _clearCart();
      } else {
        // DIALOG PERSISTANT : l'erreur de vente doit être LUE.
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Vente non enregistrée'),
            content: Text(result.error?.readableMessage ??
                'Erreur serveur (code ${result.statusCode}).'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK — réessayer')),
            ],
          ),
        );
      }
    } catch (e) {
      // EXCEPTION VISIBLE EN DIALOG (jamais masquée).
      debugPrint('[PosPanel] _executeSale exception: $e');
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur de vente'),
            content: Text('$e'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkout = false);
    }
  }

  bool get _cashSufficient => _received >= _totals.total || _paymentMode != 'cash';
  double get _change => (_received > _totals.total) ? _received - _totals.total : 0;

  void _setReceived(String v) {
    _received = double.tryParse(v.replaceAll(',', '.')) ?? 0;
    // Notifie uniquement le bloc monnaie (ValueListenableBuilder) au lieu
    // de setState() qui reconstruirait tout le panneau à chaque frappe.
    _receivedVN.value = _received;
  }

  void _quickReceived(double v) {
    final next = v == _totals.total ? v : _received + v;
    _receivedCtrl.text =
        next == next.roundToDouble() ? next.round().toString() : next.toStringAsFixed(2);
    _received = next;
    _receivedVN.value = next;
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
          final cards = <(String, String?)>[
            (_kAllLabel, null),
            for (final f in _facetForms) ('${f['value']}', '${f['value']}'),
          ];
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
                for (final (name, form) in cards)
                  _CatChip(
                      name: name,
                      selected: form == null
                          ? _activeForm == null
                          : _activeForm == form,
                      onTap: () {
                        if (form == null) {
                          setState(() => _activeForm = null);
                          _doSearch(_search.text.trim());
                        } else {
                          _toggleForm(form);
                        }
                      }),
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
                          child: Row(children: [
                            Expanded(
                              child: _PanelButton(
                                  label: 'Reprendre (${_heldQty[id] ?? 0} art.)',
                                  icon: Icons.unarchive_rounded,
                                  color: const Color(0xFF2A7A5A),
                                  onTap: () => _resume(id)),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Supprimer la vente suspendue',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.danger),
                              onPressed: () => _dropHeld(id),
                            ),
                          ]),
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
                                    '${m.name}${m.dosage != null ? ' · ${m.dosage}' : ''}${m.laboratoryName != null && m.laboratoryName!.isNotEmpty ? ' · ${m.laboratoryName}' : ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                              ),
                              Text(_fmt(m.priceSale),
                                  style: const TextStyle(
                                      color: Color(0xFFE9C873), fontSize: 10.5, fontWeight: FontWeight.w800)),
                              /* Marge droite de 20 px : place le prix sous la
                                 colonne TOTAL de l'en-tête (audit Phase 5). */
                              const SizedBox(width: 20),
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
              _received = _totals.total;
              _receivedVN.value = _totals.total;
            }),
          ]),
          // Bannière monnaie / reste : reconstruite seule via le notifier.
          ValueListenableBuilder<double>(
            valueListenable: _receivedVN,
            builder: (context, rv, _) {
              if (rv <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _cashSufficient
                          ? AppColors.emerald.withValues(alpha: 0.1)
                          : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              _cashSufficient ? AppColors.emerald : AppColors.danger)),
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
              );
            },
          ),
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
                  label: _checkout ? 'Enregistrement…' : 'Payer',
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
    /* Aligné au pixel sur les lignes (_CartRow) : même padding horizontal
       (9) et même largeur de colonne TOTAL (62 + 20 de marge droite).
       Avant : en-tête sans padding et TOTAL sur 68 → décalage de 6 px
       entre l'en-tête et le corps (audit Phase 5). */
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(children: [
        Expanded(child: Text('PRODUIT', style: style)),
        SizedBox(
            width: 86,
            child: Text('QTE', textAlign: TextAlign.center, style: style)),
        SizedBox(
            width: 62,
            child: Text('TOTAL', textAlign: TextAlign.right, style: style)),
        const SizedBox(width: 20),
      ]),
    );
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
