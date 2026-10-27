// PHARMA+ — HISTORIQUE DES MOUVEMENTS DE STOCK.
// Source : table ledger `stock_movements` (GET /stock/movements),
// enrichie par jointure PostgREST (medications, users).
// Lecture seule : aucun ajustement depuis cet écran (le parcours
// officiel reste Ajuster/Écrire à zéro du module Stock).
library;

import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../shell/shell_nav.dart';
import 'stock_logic.dart';

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _typeFilter = 'all';

  static const Map<String, String> _typeLabels = {
    'all': 'Tous les types',
    'purchase_receipt': 'Réceptions achat',
    'sale': 'Ventes',
    'sale_return': 'Retours vente',
    'inventory_in': 'Inventaire +',
    'inventory_out': 'Inventaire −',
    'adjustment': 'Ajustements',
    'transfer_in': 'Entrées transfert',
    'transfer_out': 'Sorties transfert',
    'reservation': 'Réservations',
    'release': 'Libérations',
    'expiry_loss': 'Pertes péremption',
    'write_off': 'Écritures à zéro',
  };

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
    final r = await ApiClient.instance.get('/stock/movements', query: {
      'limit': 200,
      'select': '*,medications(name),users(name)',
      'order': 'created_at.desc',
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) {
        _rows = ApiList.of(r.data)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _error = r.error?.readableMessage ?? r.error?.message;
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _rows;
    if (_typeFilter != 'all') {
      list = list.where((m) => m['movement_type'] == _typeFilter).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) {
        final name = '${m['medications']?['name'] ?? ''}'.toLowerCase();
        final notes = '${m['notes'] ?? ''}'.toLowerCase();
        final type = '${m['movement_type'] ?? ''}'.toLowerCase();
        return name.contains(q) || notes.contains(q) || type.contains(q);
      }).toList();
    }
    return list;
  }

  String _fmtDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '—';
    final date = Fmt.shortDate(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : Colors.black54;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Mouvements de stock',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.pharmaText)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.pharmaGold)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.pharmaText),
              decoration: const InputDecoration(
                hintText: 'Rechercher produit, motif…',
                prefixIcon: Icon(Icons.search, color: AppColors.pharmaMuted),
                hintStyle: TextStyle(color: AppColors.pharmaMuted),
                fillColor: AppColors.pharmaSurface2,
                filled: true,
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.goldBorder)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.goldBorder)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.pharmaGold)),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in _typeLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _typeFilter == e.key,
                      onSelected: (_) => setState(() => _typeFilter = e.key),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _typeFilter == e.key ? Colors.white : null,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('Aucun mouvement',
                                style: TextStyle(color: Colors.white70)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final m = _filtered[i];
                                final qty =
                                    (m['quantity'] as num?)?.toDouble() ?? 0;
                                final type = '${m['movement_type'] ?? ''}';
                                final medName =
                                    '${m['medications']?['name'] ?? '—'}';
                                final userName = '${m['users']?['name'] ?? ''}';
                                final notes = '${m['notes'] ?? ''}';
                                final ref = '${m['reference_type'] ?? ''}';
                                final qtyColor = qty >= 0
                                    ? AppColors.emerald
                                    : AppColors.danger;
                                return Card(
                                  color: isDark
                                      ? AppColors.pharmaSurface
                                      : Colors.white,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(medName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5)),
                                        ),
                                        Text(
                                          qty >= 0 ? '+$qty' : '$qty',
                                          style: TextStyle(
                                              color: qtyColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${movementTypeLabel(type)}'
                                      '${notes.isNotEmpty ? ' · $notes' : ''}'
                                      '${ref.isNotEmpty && ref != 'null' ? ' · $ref' : ''}'
                                      '${userName.isNotEmpty ? ' · $userName' : ''}'
                                      ' · ${_fmtDate('${m['created_at']}')}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11.5, color: muted),
                                    ),
                                    trailing: Icon(
                                      qty >= 0
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      size: 16,
                                      color: qtyColor,
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
