import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../shell/shell_nav.dart';
import 'stock_logic.dart';
import 'stock_movements_page.dart';

/// Module Stock — lignes de stock par lot (stock_balances ⋈ lots ⋈ medications).
/// Ordinateur : tableau professionnel (en-tête collant, colonnes largeurs
/// fixes, défilement horizontal/vertical). Téléphone : cartes compactes.
/// Les filtres (rupture, sous seuil, péremptions) reposent sur des données
/// RÉELLES : lots joint par lot_id, seuil reorder_level du médicament.
class StockPage extends StatefulWidget {
  /// Filtre initial : null | low | expiring | expired | rupture.
  final String? initialFilter;
  const StockPage({super.key, this.initialFilter});

  /// Filtre demandé à distance (dashboard) avant d'ouvrir l'onglet Stock.
  /// StockPage vit dans l'IndexedStack du shell : il écoute ce notifier
  /// pour appliquer le filtre puis recharger, sans reconstruire la page.
  static final ValueNotifier<String?> pendingFilter =
      ValueNotifier<String?>(null);

  /// Ouvre l'onglet Stock (shell) avec un filtre optionnel. `''` (ou
  /// null) = filtre « tout » : force une notification même si la valeur
  /// notifier est déjà nulle, pour réinitialiser le filtre courant.
  static void openWith({String? filter}) {
    pendingFilter.value = filter ?? '';
    ShellNav.index.value = 4;
  }

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  double _totalValue = 0;
  double _totalQty = 0;
  bool _canCreate = false;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _filter = normalizeStockFilter(widget.initialFilter);
    StockPage.pendingFilter.addListener(_onPendingFilter);
    _applyPendingFilter();
    _load();
  }

  /// Filtre poussé par le dashboard (KPI « Produits en stock », « Voir
  /// tout » des alertes) : appliqué et consommé (remis à null) pour ne
  /// pas re-filtrer à la prochaine visite de l'onglet.
  void _onPendingFilter() => _applyPendingFilter();

  void _applyPendingFilter() {
    final pending = StockPage.pendingFilter.value;
    if (pending == null) return;
    StockPage.pendingFilter.value = null;
    if (!mounted) return;
    final next = normalizeStockFilter(pending.isEmpty ? null : pending);
    if (next == _filter) return;
    setState(() => _filter = next);
    _load();
  }

  @override
  void dispose() {
    StockPage.pendingFilter.removeListener(_onPendingFilter);
    _search.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Trois sources réelles en parallèle : soldes (ledger), lots
    // (numéro + péremption) et médicaments (nom, seuil, prix, EAN).
    final results = await Future.wait([
      ApiClient.instance.get('/stock/balances', query: {'limit': 1000}),
      ApiClient.instance.get('/stock/lots', query: {
        'limit': 1000,
        'select': 'id,medication_id,lot_number,expiry_date',
        'order': 'expiry_date.asc',
      }),
      ApiClient.instance.get('/catalog/medications', query: {
        'limit': 1000,
        'select':
            'id,name,dosage,form,laboratory_name,price_sale,reorder_level,barcode_ean13',
      }),
    ]);
    if (!mounted) return;
    final balances = results[0];
    if (!balances.success) {
      setState(() {
        _loading = false;
        _error = balances.error?.readableMessage ?? balances.error?.message;
      });
      return;
    }
    final lotsById = <String, Map<String, dynamic>>{};
    for (final l in ApiList.of(results[1].data)) {
      final id = '${l['id']}';
      if (id.isNotEmpty && id != 'null') {
        lotsById[id] = Map<String, dynamic>.from(l);
      }
    }
    final medsById = <String, Map<String, dynamic>>{};
    for (final m in ApiList.of(results[2].data)) {
      final id = '${m['id']}';
      if (id.isNotEmpty && id != 'null') {
        medsById[id] = Map<String, dynamic>.from(m);
      }
    }

    final rows = <Map<String, dynamic>>[];
    double totalQty = 0;
    double totalValue = 0;
    final qtyByMed = <String, double>{};
    for (final b in ApiList.of(balances.data)) {
      final medId = '${b['medication_id']}';
      final lotId = '${b['lot_id']}';
      final med = medsById[medId];
      final lot =
          (lotId.isNotEmpty && lotId != 'null') ? lotsById[lotId] : null;
      final qty = _number(b['quantity']);
      final reserved = _number(b['reserved_quantity']);
      final available = qty - reserved;
      final price = _number(med?['price_sale']);
      final detailParts = [
        if ('${med?['dosage'] ?? ''}'.isNotEmpty) '${med?['dosage']}',
        if ('${med?['form'] ?? ''}'.isNotEmpty) '${med?['form']}',
        if ('${med?['laboratory_name'] ?? ''}'.isNotEmpty)
          '${med?['laboratory_name']}',
      ];
      rows.add({
        'medication_id': medId,
        'branch_id': b['branch_id'],
        'lot_id': (lotId.isNotEmpty && lotId != 'null') ? lotId : null,
        'quantity': qty,
        'reserved_quantity': reserved,
        'available': available,
        'medication_name': med?['name'] ?? '—',
        'med_detail': detailParts.join(' · '),
        'barcode_ean13': med?['barcode_ean13'],
        'reorder_level': _number(med?['reorder_level']),
        'price_sale': price,
        'lot_number': lot?['lot_number'],
        'expiry_date': lot?['expiry_date'],
      });
      if (available > 0) {
        qtyByMed[medId] = (qtyByMed[medId] ?? 0) + available;
        totalQty += available;
        totalValue += available * price;
      }
    }

    final auth = context.read<AuthStore>();
    setState(() {
      _items = rows;
      _totalQty = totalQty;
      _totalValue = totalValue;
      _canCreate = auth.isSuperAdmin ||
          auth.permissions.contains('stock:create') ||
          auth.permissions.contains('stock:edit');
      _canEdit = auth.isSuperAdmin || auth.permissions.contains('stock:edit');
      _loading = false;
    });
  }

  StockStatus _statusOf(Map<String, dynamic> row) => computeStockStatus(
        available: _number(row['available']),
        reorderLevel: _number(row['reorder_level']),
        expiry: DateTime.tryParse('${row['expiry_date'] ?? ''}'),
      );

  List<Map<String, dynamic>> get _filtered {
    final byStatus =
        filterStockRows<Map<String, dynamic>>(_items, _filter, _statusOf);
    final q = _search.text;
    if (q.trim().isEmpty) return byStatus;
    return byStatus.where((r) => stockRowMatchesQuery(r, q)).toList();
  }

  double _number(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _scanAndFind() async {
    final result = await BarcodeScannerSheet.show(context,
        title: 'Scanner produit pour stock');
    if (result == null || !mounted) return;
    final code = result.lookupCode;
    if (code.isEmpty) return;
    final apiResult = await ApiClient.instance.get(
      '/catalog/medications/barcode/${Uri.encodeComponent(code)}',
    );
    if (!mounted) return;
    if (!apiResult.success || apiResult.data == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Code inconnu : $code')));
      return;
    }
    final med = apiResult.data;
    final medMap =
        med is Map ? Map<String, dynamic>.from(med) : <String, dynamic>{};
    final matches =
        _items.where((i) => i['medication_id'] == medMap['id']).toList();
    if (matches.isEmpty) {
      if (!_canCreate) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${medMap['name'] ?? code} · aucun stock enregistré (permission requise pour ajuster)')));
        return;
      }
      await _adjustStock({
        'medication_id': medMap['id'],
        'branch_id': medMap['branch_id'] ?? '',
        'available': 0,
        'medication_name': medMap['name'] ?? code,
      });
      return;
    }
    if (matches.length == 1) {
      await _showStockActions(matches.first);
      return;
    }
    // Plusieurs lots : choix de la ligne exacte.
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Plusieurs lignes de stock — choisissez le lot',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final m in matches)
              ListTile(
                title: Text('${m['medication_name']}'),
                subtitle: Text(
                    'Lot ${m['lot_number'] ?? '—'} · ${Fmt.number(_number(m['available']))} u.'),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) await _showStockActions(chosen);
  }

  Future<void> _showStockActions(Map<String, dynamic> item) async {
    if (!_canCreate) return;
    final locale = context.read<AuthStore>().locale;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.primary),
              title: Text(S.t('adjustStock', locale)),
              onTap: () => Navigator.pop(context, 'adjust'),
            ),
            if (_canEdit)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text(S.t('writeOff', locale)),
                onTap: () => Navigator.pop(context, 'writeOff'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'adjust') {
      await _adjustStock(item);
    } else {
      await _writeOff(item);
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> item) async {
    final locale = context.read<AuthStore>().locale;
    final quantity =
        TextEditingController(text: _number(item['available']).toString());
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('adjustStock', locale)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) =>
                validateRequired(v, S.t('requiredField', locale)) ??
                validateNonNegativeNumber(v, S.t('invalidNumber', locale)),
            decoration: InputDecoration(labelText: S.t('newQuantity', locale)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (confirmed != true) return;
    final newQuantity =
        double.tryParse(quantity.text.trim().replaceAll(',', '.'));
    final branchId = item['branch_id'] as String?;
    final medicationId = item['medication_id'] as String?;
    if (newQuantity == null ||
        newQuantity < 0 ||
        branchId == null ||
        medicationId == null) {
      return;
    }
    final result = await ApiClient.instance.post('/stock/adjustments', body: {
      'branchId': branchId,
      'items': [
        {'medication_id': medicationId, 'new_quantity': newQuantity}
      ],
    });
    if (!mounted) return;
    if (result.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error?.readableMessage ??
              result.error?.message ??
              S.t('loadError', locale))));
    }
  }

  Future<void> _writeOff(Map<String, dynamic> item) async {
    final locale = context.read<AuthStore>().locale;
    final quantity = TextEditingController();
    final reason = TextEditingController();
    var expired = _statusOf(item) == StockStatus.expired;
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.t('writeOff', locale)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      validateRequired(v, S.t('requiredField', locale)) ??
                      validateNonNegativeNumber(
                          v, S.t('invalidNumber', locale)) ??
                      ((double.tryParse(v!.trim().replaceAll(',', '.')) ??
                                  -1) <=
                              0
                          ? S.t('mustBePositive', locale)
                          : null),
                  decoration: InputDecoration(
                      labelText: S.t('writeOffQuantity', locale)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(labelText: S.t('reason', locale)),
                ),
                CheckboxListTile(
                  value: expired,
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.t('expired', locale)),
                  onChanged: (value) =>
                      setState(() => expired = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, true);
                  }
                },
                child: Text(S.t('save', locale))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(quantity.text.trim().replaceAll(',', '.'));
    final branchId = item['branch_id'] as String?;
    final medicationId = item['medication_id'] as String?;
    if (amount == null ||
        amount <= 0 ||
        branchId == null ||
        medicationId == null) {
      return;
    }
    final result = await ApiClient.instance.post('/stock/write-off', body: {
      'branchId': branchId,
      'items': [
        {
          'medication_id': medicationId,
          'quantity': amount,
          'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
          'expired': expired,
        }
      ],
    });
    if (!mounted) return;
    if (result.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error?.readableMessage ??
              result.error?.message ??
              S.t('loadError', locale))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.pharmaText,
        elevation: 0,
        title: Text(S.t('stock', locale),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.pharmaText)),
        actions: [
          IconButton(
              tooltip: 'Historique des mouvements',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StockMovementsPage())),
              icon:
                  const Icon(Icons.history_rounded, color: Color(0xFFE9C873))),
          IconButton(
              tooltip: 'Scanner',
              onPressed: _scanAndFind,
              icon:
                  const Icon(Icons.qr_code_scanner, color: Color(0xFFE9C873))),
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.pharmaGold)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AppSearchField(
              controller: _search,
              hint: 'Rechercher produit, lot, code-barres…',
              showFilterButton: false,
              debounceDuration: Duration.zero,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (!_loading && _error == null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(children: [
                // Carte KPI 1 — Valeur du stock (icône pro, MAD).
                Expanded(
                  child: GlassCard(
                    radius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.sell_outlined,
                          size: 18, color: AppColors.pharmaGold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(S.t('stockValue', locale),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.pharmaMuted)),
                            Text('${Fmt.money(_totalValue)} MAD',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.pharmaText)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Carte KPI 2 — Quantité totale (icône distincte, unité).
                Expanded(
                  child: GlassCard(
                    radius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 18, color: AppColors.emerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(S.t('stockQtyTotal', locale),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.pharmaMuted)),
                            Text('${Fmt.number(_totalQty)} u.',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.pharmaText)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                    label: 'Tous',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                _FilterChip(
                    label: 'Ruptures',
                    selected: _filter == 'rupture',
                    color: AppColors.danger,
                    onTap: () => setState(() => _filter = 'rupture')),
                _FilterChip(
                    label: 'Périmé',
                    selected: _filter == 'expired',
                    color: AppColors.danger,
                    onTap: () => setState(() => _filter = 'expired')),
                _FilterChip(
                    label: 'Expire < 90j',
                    selected: _filter == 'expiring',
                    color: AppColors.warning,
                    onTap: () => setState(() => _filter = 'expiring')),
                _FilterChip(
                    label: S.t('lowStock', locale),
                    selected: _filter == 'low',
                    color: AppColors.info,
                    onTap: () => setState(() => _filter = 'low')),
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
                                label: Text(S.t('retry', locale)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(child: Text(S.t('noStock', locale)))
                        // Bascule cartes/tableau sur la largeur réellement
                        // disponible (LayoutBuilder — motifs CatalogPage /
                        // SuppliersPage), fiable en test comme en prod.
                        : LayoutBuilder(builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 600;
                            return RefreshIndicator(
                              onRefresh: _load,
                              child: narrow
                                  ? _buildMobileList(locale)
                                  : _buildStickyTable(),
                            );
                          }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLEAU PROFESSIONNEL (ordinateur / tablette paysage) :
  // en-tête collant (hors défilement vertical), colonnes à largeurs
  // fixes, médicament flexible, un seul défilement horizontal partagé
  // par l'en-tête et les lignes, fonds opaques.
  // ─────────────────────────────────────────────────────────────
  static const double _rowPad = 24; // padding horizontal 12 × 2
  static const double _fixedNonMed = 816;
  // detail160 + lot110 + expiry110 + qty90 + seuil80 + prix100
  // + statut110 + actions56

  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  Widget _buildStickyTable() {
    final rows = _filtered;
    // Fond de zone 100 % opaque (palette solide, aucun alpha) : le fond
    // d'application ne transparaît NI entre les lignes, NI sous la dernière
    // ligne, NI derrière les barres de défilement.
    final zoneBg = Theme.of(context).brightness == Brightness.dark
        ? _rowDarkA
        : Colors.white;
    return Container(
      key: const ValueKey('stock_table_zone'),
      color: zoneBg,
      child: LayoutBuilder(builder: (context, constraints) {
        final usable = constraints.maxWidth - _rowPad;
        const medMin = 200.0;
        final totalW = usable >= medMin + _fixedNonMed
            ? constraints.maxWidth
            : medMin + _fixedNonMed + _rowPad;
        final medW = totalW - _rowPad - _fixedNonMed;
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: Column(
                children: [
                  _tableHeader(medW: medW),
                  Expanded(
                    child: Scrollbar(
                      controller: _vScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _vScroll,
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++)
                              _tableRow(rows[i], i, medW: medW),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // Lignes alternées : couleurs SOLIDES (aucune transparence).
  static const Color _rowDarkA = AppColors.pharmaSurface; // #08231C
  static const Color _rowDarkB = AppColors.pharmaSurface2; // #0B2C23

  Color _rowStripe(int i) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return i.isOdd ? _rowDarkB : _rowDarkA;
    return i.isOdd ? const Color(0xFFF2F5F3) : Colors.white;
  }

  Widget _headerCell(double w, String label,
      {TextAlign align = TextAlign.left}) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            // Blanc crème sur vert pétrole : contraste ~13:1, lisible
            // même en défilement (liseré or conservé sur le fond d'en-tête).
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.pharmaText)),
      ),
    );
  }

  Widget _tableHeader({required double medW}) {
    // Fond d'en-tête SOLIDE (0xFF006B43) : opaque en toute situation.
    return Container(
      key: const ValueKey('stock_table_header'),
      height: 44,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _headerCell(medW, 'Médicament'),
          _headerCell(160, 'Détail'),
          _headerCell(110, 'Lot'),
          _headerCell(110, 'Péremption'),
          _headerCell(90, 'Quantité', align: TextAlign.right),
          _headerCell(80, 'Seuil', align: TextAlign.right),
          _headerCell(100, 'Prix', align: TextAlign.right),
          _headerCell(110, 'Statut'),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _cell(double w, Widget child, {TextAlign align = TextAlign.left}) {
    Widget inner = child;
    if (align != TextAlign.left) {
      inner = Align(
        alignment:
            align == TextAlign.right ? Alignment.centerRight : Alignment.center,
        child: child,
      );
    }
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: inner,
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> item, int i, {required double medW}) {
    final status = _statusOf(item);
    final available = _number(item['available']);
    // Ligne 100 % opaque (jamais Colors.transparent) : le fond d'application
    // reste invisible à travers les cellules, dans les deux thèmes.
    final stripe = _rowStripe(i);
    final divider = Theme.of(context).brightness == Brightness.dark
        ? AppColors.borderDark
        : AppColors.borderLight;
    const cellStyle = TextStyle(fontSize: 12.5);
    return Material(
      color: stripe,
      child: InkWell(
        onTap: _canCreate ? () => _showStockActions(item) : null,
        child: Container(
          height: 48,
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: divider))),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _cell(
                medW,
                Text('${item['medication_name'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
              _cell(
                160,
                Text('${item['med_detail'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle.copyWith(color: AppColors.pharmaMuted)),
              ),
              _cell(
                110,
                Text('${item['lot_number'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle),
              ),
              _cell(
                110,
                Text(
                  item['expiry_date'] == null
                      ? '—'
                      : Fmt.shortDate(
                          DateTime.tryParse('${item['expiry_date']}')),
                  style: cellStyle.copyWith(
                    color: status == StockStatus.expired
                        ? AppColors.danger
                        : status == StockStatus.expiring
                            ? AppColors.warning
                            : null,
                  ),
                ),
              ),
              _cell(
                90,
                Text(Fmt.number(available),
                    textAlign: TextAlign.right,
                    style: cellStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: available <= 0 ? AppColors.danger : null)),
                align: TextAlign.right,
              ),
              _cell(
                80,
                Text(
                  _number(item['reorder_level']) > 0
                      ? Fmt.number(_number(item['reorder_level']))
                      : '—',
                  textAlign: TextAlign.right,
                  style: cellStyle.copyWith(color: AppColors.pharmaMuted),
                ),
                align: TextAlign.right,
              ),
              _cell(
                100,
                Text('${Fmt.money(_number(item['price_sale']))} MAD',
                    textAlign: TextAlign.right,
                    style: cellStyle.copyWith(color: AppColors.pharmaGold)),
                align: TextAlign.right,
              ),
              _cell(110, _StatusChip(status: status)),
              SizedBox(
                width: 56,
                child: _canCreate
                    ? PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (a) {
                          if (a == 'adjust') {
                            _adjustStock(item);
                          } else if (a == 'writeOff' && _canEdit) {
                            _writeOff(item);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'adjust', child: Text('Ajuster le stock')),
                          if (_canEdit)
                            const PopupMenuItem(
                                value: 'writeOff',
                                child: Text('Écrire à zéro')),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARTES COMPACTES (téléphone / petit écran).
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileList(String locale) {
    final rows = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final item = rows[i];
        final status = _statusOf(item);
        final available = _number(item['available']);
        final lotInfo = '${item['lot_number'] ?? ''}';
        final detail = [
          if ('${item['med_detail'] ?? ''}'.isNotEmpty) '${item['med_detail']}',
          if (lotInfo.isNotEmpty && lotInfo != 'null') 'Lot: $lotInfo',
        ].join(' · ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: _canCreate ? () => _showStockActions(item) : null,
            child: Row(
              children: [
                _StatusDot(status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item['medication_name'] ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(detail.isEmpty ? '—' : detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      if (item['expiry_date'] != null)
                        Text(
                            '${S.t('expiryShort', locale)} ${Fmt.shortDate(DateTime.tryParse('${item['expiry_date']}'))}',
                            style: TextStyle(
                                fontSize: 12,
                                color: status == StockStatus.expired
                                    ? AppColors.danger
                                    : status == StockStatus.expiring
                                        ? AppColors.warning
                                        : Colors.grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: available <= 0
                            ? AppColors.danger.withValues(alpha: 0.15)
                            : AppColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${Fmt.number(available)} u.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: available <= 0
                              ? AppColors.danger
                              : AppColors.emerald,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Fmt.money(_number(item['price_sale']))} MAD',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pharmaGold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StockStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StockStatus.rupture => ('Rupture', AppColors.danger),
      StockStatus.expired => ('Périmé', AppColors.danger),
      StockStatus.expiring => ('Expire < 90j', AppColors.warning),
      StockStatus.low => ('Sous seuil', AppColors.info),
      StockStatus.ok => ('OK', AppColors.emerald),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final StockStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockStatus.rupture || StockStatus.expired => AppColors.danger,
      StockStatus.expiring => AppColors.warning,
      StockStatus.low => AppColors.info,
      StockStatus.ok => Colors.transparent,
    };
    return Container(
      width: 8,
      height: 44,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color ?? AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
