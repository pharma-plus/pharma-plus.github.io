import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/offline_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../../core/widgets/shared/app_data_table.dart';
import '../../core/widgets/shared/app_filter_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/utils/table_columns.dart';
import '../../core/widgets/shared.dart';
import '../shell/shell_nav.dart';

/// Catalogue centralisé — Référentiel unique pour POS, Stock, Achats, Ventes, IA
/// Gère médicaments, parapharmacie, vétérinaire, dispositifs médicaux
class ReferencePage extends StatefulWidget {
  const ReferencePage({super.key});

  @override
  State<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _activeTab = 'medicaments';
  
  // Filtres
  String? _filterForm;
  String? _filterLabo;
  String? _filterStatus;
  String? _filterPathologie;
  RangeValues? _priceRange;
  
  // Données de référence
  List<Map<String, dynamic>> _forms = [];
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _pathologies = [];
  int _indicationsTotal = 0;

  static const _tabs = [
    ('medicaments', Icons.medication_outlined, 'medicaments'),
    ('parapharmacie', Icons.spa_outlined, 'parapharmacy'),
    ('veterinaire', Icons.pets_outlined, 'veterinaire'),
    ('dispositifs', Icons.medical_services_outlined, 'dispositifs'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFacets();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFacets() async {
    final f = await ApiClient.instance.get('/catalog/medications/facets');
    if (!mounted || !f.success || f.data is! Map) return;
    final d = Map<String, dynamic>.from(f.data as Map);
    setState(() {
      _forms = (d['forms'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      _labs = (d['laboratories'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      _indicationsTotal = (d['indications_total'] as num?)?.toInt() ?? 0;
    });
    if (_indicationsTotal > 0) {
      final p = await ApiClient.instance.get('/catalog/medications/pathologies');
      if (mounted && p.success) {
        setState(() => _pathologies = ApiList.of(p.data));
      }
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(query: q));
  }

  Future<void> _load({String? query}) async {
    setState(() { _loading = true; _error = null; });
    final params = <String, dynamic>{
      'limit': 200,
      if (query != null && query.isNotEmpty) 'q': query,
      if (_activeTab == 'parapharmacie') 'is_parapharmacie': true,
      if (_activeTab == 'veterinaire') 'is_veterinaire': true,
      if (_activeTab == 'dispositifs') 'is_dispositif': true,
      if (_filterForm != null && _filterForm!.isNotEmpty) 'form': 'eq.$_filterForm',
      if (_filterLabo != null && _filterLabo!.isNotEmpty) 'laboratory_name': 'eq.$_filterLabo',
      if (_filterStatus != null && _filterStatus!.isNotEmpty) 'status': 'eq.$_filterStatus',
      if (_filterPathologie != null && _filterPathologie!.isNotEmpty) 'pathologie': _filterPathologie,
      if (_priceRange != null) 'price_sale': 'gte.${_priceRange!.start},lte.${_priceRange!.end}',
    };
    final r = await ApiClient.instance.get('/catalog/medications', query: params);
    if (!mounted) return;
    if (!r.success) {
      setState(() { _loading = false; _error = r.error?.message ?? 'Erreur'; });
      return;
    }
    setState(() {
      _items = ApiList.of(r.data);
      _loading = false;
    });
  }

  void _clearFilters() => setState(() {
    _filterForm = null; _filterLabo = null; _filterStatus = null; 
    _filterPathologie = null; _priceRange = null;
    _load(query: _search.text);
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('referenceCatalog', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: S.t('export', locale),
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: S.t('import', locale),
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: Column(children: [
        // Onglets types de produits
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            segments: [
              for (final (key, icon, label) in _tabs)
                ButtonSegment(
                  value: key,
                  icon: Icon(icon, size: 18),
                  label: Text(S.t(label, locale)),
                ),
            ],
            selected: {_activeTab},
            onSelectionChanged: (sel) => setState(() {
              _activeTab = sel.first;
              _load(query: _search.text);
            }),
          ),
        ),
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppSearchField(
            controller: _search,
            hint: S.t('search', locale),
            onChanged: _onSearchChanged,
            showFilterButton: true,
            onFilterPressed: _showFilterDialog,
          ),
        ),
        // Barre de filtres actifs
        if (_hasActiveFilters)
          _ActiveFilterBar(
            onClear: _clearFilters,
            locale: locale,
            form: _filterForm, labo: _filterLabo,
            status: _filterStatus, patho: _filterPathologie,
            priceRange: _priceRange,
          ),
        // Liste / Tableau
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _items.isEmpty
                      ? Center(child: Text(S.t('noProducts', locale)))
                      : LayoutBuilder(builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 980;
                          return RefreshIndicator(
                            onRefresh: () => _load(query: _search.text),
                            child: narrow
                                ? _buildMobileCards(locale)
                                : _buildDesktopTable(locale),
                          );
                        }),
        ),
      ]),
    );
  }

  bool get _hasActiveFilters =>
      _filterForm != null || _filterLabo != null || _filterStatus != null ||
      _filterPathologie != null || _priceRange != null;

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(query: q));
  }

  void _clearFilters() => setState(() {
    _filterForm = null; _filterLabo = null; _filterStatus = null; 
    _filterPathologie = null; _priceRange = null;
    _load(query: _search.text);
  });

  Widget _buildMobileCards(String locale) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final p = _items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _showDetail(p),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication, color: Color(0xFF3E2A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text([
                      p['dci'], p['dosage'], p['form'], p['laboratory_name']
                    ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (p['price_sale'] != null && (p['price_sale'] as num) > 0)
                      Text('${Fmt.money((p['price_sale'] as num).toDouble())} DH',
                          style: const TextStyle(
                              color: AppColors.pharmaGold,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                  ],
                ),
              ),
              _StatusChip(p['status']),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(String locale) {
    final cfg = TableColumnWidths;
    return AppDataTable<Map<String, dynamic>>(
      columns: TableColumns.medications(locale),
      data: _items,
      fixedHeader: true,
      config: const AppDataTableConfig(columnSpacing: 16),
      onRowTap: _showDetail,
    );
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(query: q));
  }

  void _clearFilters() => setState(() {
    _filterForm = null; _filterLabo = null; _filterStatus = null; 
    _filterPathologie = null; _priceRange = null;
    _load(query: _search.text);
  });

  void _showFilterDialog() {
    final locale = context.read<AuthStore>().locale;
    String? tmpForm = _filterForm;
    String? tmpLabo = _filterLabo;
    String? tmpStatus = _filterStatus;
    String? tmpPatho = _filterPathologie;
    RangeValues? tmpPrice = _priceRange;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(S.t('filters', locale)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _filterDropdown(ctx, S.t('form', locale), _forms, tmpForm,
                (v) => setState(() => tmpForm = v)),
            _filterDropdown(ctx, S.t('laboratory', locale), _labs, tmpLabo,
                (v) => setState(() => tmpLabo = v)),
            _filterDropdown(ctx, S.t('status', locale), [
              _Facet('Disponible', 'available'),
              _Facet('Rupture', 'out_of_stock'),
              _Facet('Retiré', 'retired'),
            ], tmpStatus, (v) => setState(() => tmpStatus = v)),
            if (_indicationsTotal > 0)
              _filterDropdown(ctx, S.t('pathology', locale), _pathologies, tmpPatho,
                  (v) => setState(() => tmpPatho = v))
            else
              ListTile(
                leading: const Icon(Icons.filter_alt_off, color: Colors.grey),
                title: Text(S.t('pathology', locale)),
                subtitle: Text(S.t('noPathologyData', locale)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.attach_money, color: AppColors.pharmaGold),
              title: Text(S.t('priceRange', locale)),
              subtitle: tmpPrice != null
                  ? Text('${tmpPrice!.start.round()} - ${tmpPrice!.end.round()} DH')
                  : Text(S.t('all', locale)),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => tmpPrice = null),
              ),
              onTap: () async {
                final range = await showRangeSliderDialog(
                  context: ctx,
                  min: 0,
                  max: 5000,
                  current: tmpPrice,
                );
                if (range != null) setState(() => tmpPrice = range);
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('cancel', locale))),
          FilledButton(
            onPressed: () {
              setState(() {
                _filterForm = tmpForm;
                _filterLabo = tmpLabo;
                _filterStatus = tmpStatus;
                _filterPathologie = tmpPatho;
                _priceRange = tmpPrice;
              });
              _load(query: _search.text);
              Navigator.pop(ctx);
            },
            child: Text(S.t('apply', locale)),
          ),
        ],
      )),
    );
  }

  Widget _filterDropdown(BuildContext ctx, String label, List<Map<String, dynamic>> options,
      String? value, ValueChanged<String?> onChanged) {
    final enabled = options.isNotEmpty;
    return DropdownButtonFormField<String>(
      initialValue: enabled ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(S.t('all', ctx.read<AuthStore>().locale))),
        for (final o in options.where((o) => o['label'].toString().isNotEmpty && o['value'].toString().isNotEmpty))
          DropdownMenuItem(
            value: o['value'].toString(),
            child: Text('${o['label']} (${o['total'] ?? 0})',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }

  Future<RangeValues?> showRangeSliderDialog({
    required BuildContext context,
    required double min,
    required double max,
    RangeValues? current,
  }) async {
    RangeValues? result = current;
    await showDialog<RangeValues>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: const Text('Fourchette de prix'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RangeSlider(
            values: result ?? RangeValues(min, max),
            min: min, max: max,
            divisions: 100,
            labels: RangeLabels(
              '${(result ?? RangeValues(min, max)).start.round()} DH',
              '${(result ?? RangeValues(min, max)).end.round()} DH',
            ),
            onChanged: (v) => setState(() => result = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, result), child: const Text('OK')),
        ],
      )),
    );
    return result;
  }

  void _exportCsv() {
    final csv = StringBuffer();
    // En-têtes
    csv.writeln('EAN-13,Nom,DCI,Dosage,Forme,Présentation,Labo,PPV,PH,PPC,Statut,Princeps/Gen');
    for (final p in _items) {
      csv.writeln([
        p['barcode_ean13'] ?? '',
        '"${(p['name'] ?? '').replaceAll('"', '""')}"',
        p['dci'] ?? '',
        p['dosage'] ?? '',
        p['form'] ?? '',
        p['presentation'] ?? '',
        p['laboratory_name'] ?? '',
        p['price_sale'] ?? '',
        p['ph'] ?? '',
        p['ppc'] ?? '',
        p['status'] ?? '',
        p['princeps_generique'] ?? '',
      ].join(','));
    }
    final bytes = utf8.encode(csv.toString());
    // Note: sur Web, utiliser html.Blob pour télécharger
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export CSV: ${_items.length} lignes')),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import contrôlé'),
        content: const Text('Sélectionnez un fichier CSV/Excel validé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Choisir fichier')),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p['name'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 12),
            _detailRow('EAN-13', p['barcode_ean13']),
            _detailRow('DCI', p['dci']),
            _detailRow('Dosage', p['dosage']),
            _detailRow('Forme', p['form']),
            _detailRow('Présentation', p['presentation']),
            _detailRow('Laboratoire', p['laboratory_name']),
            _detailRow('Classe thérapeutique', p['therapeutic_class']),
            _detailRow('Substance active', p['substance_active']),
            _detailRow('PPV', p['price_sale'] != null ? '${Fmt.money((p['price_sale'] as num).toDouble())} DH' : null),
            _detailRow('PH', p['ph'] != null ? '${Fmt.money((p['ph'] as num).toDouble())} DH' : null),
            _detailRow('PPC', p['ppc'] != null ? '${Fmt.money((p['ppc'] as num).toDouble())} DH' : null),
            _detailRow('Taux remboursement', p['reimbursement_rate'] != null ? '${p['reimbursement_rate']}%' : null),
            _detailRow('Princeps/Générique', p['princeps_generique']),
            _detailRow('Statut', p['status']),
            _detailRow('AMM', p['amm_number']),
            _detailRow('Code-barres', p['barcode_ean13']),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  final VoidCallback onClear;
  final String locale;
  final String? form, labo, status, patho;
  final RangeValues? priceRange;

  const _ActiveFilterBar({
    required this.onClear,
    required this.locale,
    this.form, this.labo, this.status, this.patho, this.priceRange,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (form != null) _FilterChip(label: 'Forme: $form', onRemoved: () {}),
      if (labo != null) _FilterChip(label: 'Labo: $labo', onRemoved: () {}),
      if (status != null) _FilterChip(label: 'Statut: $status', onRemoved: () {}),
      if (patho != null) _FilterChip(label: 'Pathologie: $patho', onRemoved: () {}),
      if (priceRange != null) _FilterChip(label: 'Prix: ${priceRange!.start.round()}-${priceRange!.end.round()} DH', onRemoved: () {}),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(child: Wrap(spacing: 8, children: chips)),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off, size: 16),
          label: Text(S.t('clearFilters', locale)),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemoved;
  const _FilterChip({required this.label, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onRemoved,
      deleteIcon: const Icon(Icons.close, size: 14),
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: const TextStyle(color: AppColors.pharmaGold),
      deleteIconColor: AppColors.pharmaGold,
    );
  }
}

class _Facet {
  final String label;
  final String value;
  final int total;
  const _Facet(this.label, [this.value = '', this.total = 0]);
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final s = status ?? 'unknown';
    Color color;
    String label;
    switch (s) {
      case 'available': color = AppColors.success; label = 'Disponible'; break;
      case 'out_of_stock': color = AppColors.danger; label = 'Rupture'; break;
      case 'retired': color = Colors.grey; label = 'Retiré'; break;
      default: color = Colors.grey; label = s;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}