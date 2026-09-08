// PMG-POS-REAL
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';

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

  /// Ouvre le POS complet avec le panier courant pré-rempli : le
  /// paiement et l'enregistrement de la vente se font dans le vrai POS.
  final void Function(List<Medication> items, double discount, bool isPercent)?
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

  static const _kHeldKey = 'pmg_pos_held_sales';

  /// Mots-clés de recherche réels par catégorie (filtre API du catalogue).
  static const Map<String, String> _catQueries = {
    'all': '',
    'meds': '',
    'vitamins': 'vitamine',
    'care': 'sirop',
    'baby': 'bébé',
    'firstAid': 'antiseptique',
    'beauty': 'crème',
    'accessories': 'compresses',
  };

  static const _cats = <(String, String)>[
    ('Tout', 'all'),
    ('Médica.', 'meds'),
    ('Vitami.', 'vitamins'),
    ('Santé', 'care'),
    ('Bébé', 'baby'),
    ('Secours', 'firstAid'),
    ('Beauté', 'beauty'),
    ('Divers', 'accessories'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHeld();
  }

  @override
  void dispose() {
    _search.dispose();
    _discountCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---- Totaux : service centralisé, aucun calcul local dupliqué ----
  // Convention HT + TVA ajoutée = même moteur que le POS complet.
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

  // ---- Recherche catalogue (API réelle, debouncée) ----
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(query));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searching = true);
    final r = await ApiClient.instance.get<Map<String, dynamic>>(
        '/catalog/medications',
        query: {'q': query.trim(), 'limit': 8});
    if (!mounted) return;
    final items = r.success ? (r.data?['items'] as List? ?? const []) : const [];
    setState(() {
      _results.clear();
      for (final it in items.whereType<Map<String, dynamic>>()) {
        if (it['id'] != null) _results['${it['id']}'] = Medication.fromJson(it);
      }
      _searching = false;
    });
  }

  void _searchCategory(String kind) {
    final q = _catQueries[kind] ?? '';
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
      });

  // ---- Ventes suspendues : persistance locale réelle ----
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
    } catch (_) {
      // Contenu local illisible : ignoré proprement.
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
    // Capture non nulle pour utilisation à l'intérieur de setState
    // (la promotion de type ne traverse pas les closures Dart).
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
        // ---- Recherche produit RÉELLE + scan ----
        Container(
          height: 42,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFC9A24B).withValues(alpha: 0.4))),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.search_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Rechercher un médicament…',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF), fontSize: 12)),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(
              tooltip: 'Scanner',
              onPressed: widget.onCheckout,
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  size: 19, color: Color(0xFFE9C873)),
            ),
          ]),
        ),
        // ---- Résultats de recherche (API réelle) ----
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
                color: const Color(0xFF0C1F16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dividerDark)),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final m in _results.values)
                  InkWell(
                    onTap: () => _add(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(children: [
                        const Icon(Icons.medication_rounded,
                            size: 15, color: AppColors.emeraldLight),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${m.name}${m.dosage != null ? ' · ${m.dosage}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11.5)),
                        ),
                        Text(_fmt(m.priceSale),
                            style: const TextStyle(
                                color: Color(0xFFE9C873),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // ---- Catégories : filtres de recherche RÉELS ----
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final (name, kind) in _cats)
            _CatChip(
                name: name,
                icon: _catIcon(kind),
                onTap: () => _searchCategory(kind)),
        ]),
        const SizedBox(height: 8),
        // ---- En-tête table ----
        const _RowHeader(),
        const SizedBox(height: 6),
        // ---- Panier réel / ventes suspendues ----
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_heldIds.isNotEmpty)
                    for (final id in _heldIds)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PanelButton(
                            label: 'Reprendre (${_heldQty[id] ?? 0} art.)',
                            icon: Icons.unarchive_rounded,
                            color: const Color(0xFF2A7A5A),
                            onTap: () => _resume(id)),
                      ),
                  Text('Recherchez un médicament pour commencer',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11)),
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
                  ],
                ),
        ),
        const SizedBox(height: 8),
        // ---- Remise RÉELLE (% ou montant) ----
        Row(children: [
          SizedBox(
            width: 92,
            height: 34,
            child: TextField(
              controller: _discountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(
                  () => _discount = double.tryParse(v.replaceAll(',', '.')) ?? 0),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1))),
                  hintText: 'Remise',
                  hintStyle:
                      const TextStyle(color: Color(0x55FFFFFF), fontSize: 11)),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _discountPercent = !_discountPercent),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: _discountPercent
                      ? const Color(0xFF17523A)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: const Color(0xFF2A7A5A).withValues(alpha: 0.6))),
              child: Center(
                  child: Text(_discountPercent ? '%' : 'MAD',
                      style: const TextStyle(
                          color: Color(0xFF7BEBA4),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900))),
            ),
          ),
          const Spacer(),
          Text('TVA incl. ${_fmt(t.tva)}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10.5)),
        ]),
        const SizedBox(height: 8),
        // ---- Totaux RÉELS (service centralisé) ----
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF0E2A1C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF2E7A50).withValues(alpha: 0.55))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MoneyRow('Sous-total', _fmt(t.subtotal)),
                if (t.discount > 0) _MoneyRow('Remise', '- ${_fmt(t.discount)}'),
                const SizedBox(height: 4),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                      Text(_fmt(t.total),
                          style: const TextStyle(
                              color: Color(0xFF7BEBA4),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ]),
              ]),
        ),
        const SizedBox(height: 10),
        // ---- Vider / Suspendre / Paiement : actions RÉELLES ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(
                child: _PanelButton(
                    label: 'Vider',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFB3372F),
                    onTap: _clearCart)),
            const SizedBox(width: 8),
            Expanded(
                child: _PanelButton(
                    label: 'Suspendre',
                    icon: Icons.pause_circle_outline_rounded,
                    color: const Color(0xFFB98A1F),
                    onTap: _hold)),
            const SizedBox(width: 8),
            Expanded(
                child: _PanelButton(
                    label: 'Paiement',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF0E8C4F),
                    onTap: _cart.isEmpty
                        ? widget.onCheckout
                        : () => widget.onPrefilled?.call(
                            _cart.values.toList(),
                            _discount,
                            _discountPercent))),
          ]),
        ),
      ]),
    );
  }

  IconData _catIcon(String kind) => switch (kind) {
        'all' => Icons.apps_rounded,
        'meds' => Icons.medication_rounded,
        'vitamins' => Icons.eco_rounded,
        'care' => Icons.healing_rounded,
        'baby' => Icons.child_care_rounded,
        'firstAid' => Icons.local_hospital_rounded,
        'beauty' => Icons.face_retouching_natural_rounded,
        _ => Icons.medical_services_rounded,
      };
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
          child: Text('QTÉ', textAlign: TextAlign.center, style: style)),
      SizedBox(
          width: 68,
          child: Text('TOTAL', textAlign: TextAlign.right, style: style)),
      const SizedBox(width: 20),
    ]);
  }
}

/// Puce de catégorie (filtre de recherche réel).
class _CatChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  const _CatChip({required this.name, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(children: [
          Container(
            width: 34,
            height: 30,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
            child: Icon(icon, size: 17, color: AppColors.emeraldLight),
          ),
          const SizedBox(height: 3),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
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

/// Ligne monétaire des totaux.
class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  const _MoneyRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
