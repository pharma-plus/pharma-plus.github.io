import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/colors.dart';
import '../catalog/catalog_page.dart';
import '../returns/returns_page.dart';
import '../shell/shell_nav.dart';

/// Type d'une ligne de résultat de la recherche globale.
class GlobalSearchHit {
  final String group;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback open;
  const GlobalSearchHit({
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.open,
  });
}

/// Barre de recherche GLOBALE du dashboard :
/// médicaments · référence / code-barres · fournisseurs · clients ·
/// stock · commandes (n°) · BL / réceptions · ventes & retours · employés.
class GlobalSearchField extends StatefulWidget {
  final VoidCallback onScan;
  const GlobalSearchField({super.key, required this.onScan});

  @override
  State<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends State<GlobalSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layer = LayerLink();
  Timer? _debounce;
  List<GlobalSearchHit> _hits = [];
  bool _loading = false;
  bool _open = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _hits = [];
        _open = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _open = true;
    });
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(q));
  }

  Future<void> _search(String q) async {
    final ql = q.toLowerCase();
    final api = ApiClient.instance;
    final results = await Future.wait([
      api.get('/catalog/medications', query: {'q': q, 'limit': 6}),
      api.get('/suppliers', query: {'q': q, 'limit': 5}),
      api.get('/customers', query: {'q': q, 'limit': 5}),
      api.get('/stock/balances', query: {'q': q, 'limit': 5}),
      api.get('/sales', query: {'q': q, 'limit': 5}),
      api.get('/employees', query: {'q': q, 'limit': 4}),
      api.get('/purchases/orders', query: {'limit': 40}),
      api.get('/purchases/receptions', query: {'limit': 40}),
    ]);
    if (!mounted || _ctrl.text.trim() != q) return;

    List<dynamic> rows(dynamic r) {
      if (r.success != true || r.data == null) return const [];
      final d = r.data;
      if (d is List) return d;
      if (d is Map && d['items'] is List) return d['items'] as List;
      if (d is Map && d['rows'] is List) return d['rows'] as List;
      if (d is Map && d['data'] is List) return d['data'] as List;
      return const [];
    }

    String s(dynamic v) => v == null ? '' : '$v';
    bool match(String v) => v.toLowerCase().contains(ql);
    final hits = <GlobalSearchHit>[];

    for (final m in rows(results[0])) {
      if (m is! Map) continue;
      final name = s(m['name']);
      final bar = s(m['barcode_ean13']);
      if (name.isEmpty && bar.isEmpty) continue;
      hits.add(GlobalSearchHit(
        group: 'Médicament',
        title: name.isEmpty ? bar : name,
        subtitle: [bar, s(m['dosage']), s(m['form'])]
            .where((x) => x.isNotEmpty)
            .join(' · '),
        icon: Icons.medication_rounded,
        open: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => CatalogPage(initialQuery: q)),
        ),
      ));
    }
    for (final m in rows(results[1])) {
      if (m is! Map) continue;
      final name = s(m['name']);
      if (name.isEmpty) continue;
      hits.add(GlobalSearchHit(
        group: 'Fournisseur',
        title: name,
        subtitle: [s(m['city']), s(m['type'])].where((x) => x.isNotEmpty).join(' · '),
        icon: Icons.local_shipping_rounded,
        open: () => ShellNav.index.value = 5,
      ));
    }
    for (final m in rows(results[2])) {
      if (m is! Map) continue;
      final name = s(m['name']).isNotEmpty
          ? s(m['name'])
          : '${s(m['first_name'])} ${s(m['last_name'])}'.trim();
      final phone = s(m['phone']);
      if (name.isEmpty) continue;
      hits.add(GlobalSearchHit(
        group: 'Client',
        title: name,
        subtitle: phone,
        icon: Icons.person_rounded,
        open: () => ShellNav.index.value = 7,
      ));
    }
    for (final m in rows(results[3])) {
      if (m is! Map) continue;
      final name = s(m['name']);
      if (name.isEmpty && !match(s(m['barcode_ean13']))) continue;
      hits.add(GlobalSearchHit(
        group: 'Stock',
        title: name.isEmpty ? s(m['barcode_ean13']) : name,
        subtitle: 'Dispo ${s(m['available'])} · seuil ${s(m['reorder_level'])}',
        icon: Icons.inventory_2_rounded,
        open: () => ShellNav.index.value = 4,
      ));
    }
    for (final m in rows(results[4])) {
      if (m is! Map) continue;
      final num_ = s(m['number']);
      final cust = s(m['customer_name']);
      if (num_.isEmpty && cust.isEmpty) continue;
      hits.add(GlobalSearchHit(
        group: 'Vente / retour',
        title: num_.isEmpty ? cust : num_,
        subtitle: cust,
        icon: Icons.receipt_long_rounded,
        open: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const ReturnsPage()),
        ),
      ));
    }
    for (final m in rows(results[5])) {
      if (m is! Map) continue;
      final name =
          '${s(m['first_name'])} ${s(m['last_name'])}'.trim();
      if (name.isEmpty) continue;
      hits.add(GlobalSearchHit(
        group: 'Employé',
        title: name,
        subtitle: s(m['email']),
        icon: Icons.badge_rounded,
        open: () => ShellNav.index.value = 8,
      ));
    }
    // Commandes + BL : filtre client (pas de param q côté API).
    for (final m in rows(results[6])) {
      if (m is! Map) continue;
      final number = s(m['number']);
      final sup = s(m['supplier_name']);
      if (!match(number) && !match(sup)) continue;
      hits.add(GlobalSearchHit(
        group: 'Commande',
        title: number.isEmpty ? sup : number,
        subtitle: sup,
        icon: Icons.fact_check_rounded,
        open: () => ShellNav.index.value = 6,
      ));
    }
    for (final m in rows(results[7])) {
      if (m is! Map) continue;
      final number = s(m['number']);
      final order = s(m['order_number']);
      final sup = s(m['supplier_name']);
      if (!match(number) && !match(order) && !match(sup)) continue;
      hits.add(GlobalSearchHit(
        group: 'BL / réception',
        title: number.isEmpty ? order : number,
        subtitle: [order, sup].where((x) => x.isNotEmpty).join(' · '),
        icon: Icons.assignment_turned_in_rounded,
        open: () => ShellNav.index.value = 6,
      ));
    }

    if (!mounted) return;
    setState(() {
      _hits = hits.take(12).toList();
      _loading = false;
      _open = true;
    });
  }

  void _select(GlobalSearchHit hit) {
    setState(() {
      _open = false;
      _ctrl.clear();
    });
    _focus.unfocus();
    hit.open();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A201A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(children: [
              const Icon(Icons.search,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    final q = _ctrl.text.trim();
                    if (q.isEmpty) return;
                    setState(() => _open = false);
                    _focus.unfocus();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (_) => CatalogPage(initialQuery: q)),
                    );
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  cursorColor: AppColors.goldBorder,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText:
                        'Médicament, client, fournisseur, n° commande, BL, référence…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13.5),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: AppColors.goldBorder),
                  ),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onScan,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            const Color(0xFFC9A24B).withValues(alpha: 0.6)),
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      size: 17, color: Color(0xFFD9B45C)),
                ),
              ),
            ]),
          ),
          if (_open && (_hits.isNotEmpty || _loading))
            CompositedTransformFollower(
              link: _layer,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF0C1F19),
                child: Container(
                  width: 420,
                  constraints: const BoxConstraints(maxHeight: 340),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: _hits.isEmpty && !_loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Aucun résultat',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: _hits.length,
                          itemBuilder: (_, i) {
                            final h = _hits[i];
                            return InkWell(
                              onTap: () => _select(h),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(children: [
                                  Icon(h.icon,
                                      size: 18,
                                      color: const Color(0xFFD9B45C)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(h.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        if (h.subtitle.isNotEmpty)
                                          Text(h.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(h.group,
                                        style: const TextStyle(
                                            color: Color(0xFF9BB8A8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
