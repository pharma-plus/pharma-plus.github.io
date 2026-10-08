import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/models/zone.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../floor_plan/pharmacy_plan_page.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../shell/shell_nav.dart';

/// Une option de filtre (facette reelle renvoyee par l'API).
class _Facet {
  final String label;
  final String value;
  final int total;
  const _Facet(this.label, [this.value = '', this.total = 0]);
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.parapharmacy = false, this.initialQuery});

  final bool parapharmacy;

  /// Pré-remplit la recherche (ex. produit cliqué depuis le Plan 3D).
  final String? initialQuery;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _search = TextEditingController();
  List<Medication> _items = [];
  bool _loading = true;
  int _total = 0;
  int _page = 1;
  String? _error;
  late bool _paraMode = widget.parapharmacy;

  // Facettes reelles (alimentees par /catalog/medications/facets).
  List<_Facet> _labs = [];
  List<_Facet> _forms = [];
  List<_Facet> _dosages = [];
  List<_Facet> _statuses = [];
  int _indicationsTotal = 0;
  List<String> _stockIds = [];
  final Map<String, double> _stock = {};

  // Filtres actifs.
  String? _fLab;
  String? _fForm;
  String? _fDosage;
  String? _fStatus;
  String? _fAvail; // en_stock | hors_stock
  String? _fPrice; // tranche id ("0-50")

  static const Map<String, List<num?>> _priceRanges = {
    '0-50': [0, 50],
    '50-100': [50, 100],
    '100-200': [100, 200],
    '200-500': [200, 500],
    '500+': [500, null],
  };

  bool get _hasFilters => _fLab != null || _fForm != null || _fDosage != null ||
      _fStatus != null || _fAvail != null || _fPrice != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) _search.text = q;
    _loadFacets();
    _load(query: q);
  }

  /// Facettes reelles : labos / formes / dosages / statuts + ids en stock +
  /// nombre d'indications (0 => filtre pathologie signale "non disponible").
  Future<void> _loadFacets() async {
    final f = await ApiClient.instance.get('/catalog/medications/facets');
    final s = await ApiClient.instance.get('/catalog/medications/stock-ids');
    if (!mounted) return;
    if (f.success && f.data is Map) {
      final d = f.data as Map;
      List<_Facet> parse(List? raw) => (raw ?? [])
          .map((e) => _Facet('${e['label'] ?? ''}', '${e['value'] ?? e['label'] ?? ''}',
              (e['total'] as num?)?.toInt() ?? 0))
          .toList();
      setState(() {
        _labs = parse(d['laboratories'] as List?);
        _forms = parse(d['forms'] as List?);
        _dosages = parse(d['dosages'] as List?);
        _statuses = parse(d['statuses'] as List?);
        _indicationsTotal = (d['indications_total'] as num?)?.toInt() ?? 0;
      });
    }
    if (s.success && s.data is List) {
      setState(() => _stockIds = (s.data as List).map((e) => '$e').toList());
    }
  }

  Map<String, dynamic> _buildQuery(int page, String? query) {
    final q = <String, dynamic>{
      if (query != null && query.isNotEmpty) 'q': query,
      'is_parapharmacie': _paraMode,
      'page': page,
      'limit': 100,
      if (_fLab != null) 'laboratory_name': 'eq.$_fLab',
      if (_fForm != null) 'form': 'eq.$_fForm',
      if (_fDosage != null) 'dosage': 'eq.$_fDosage',
      if (_fStatus != null) 'status': 'eq.$_fStatus',
    };
    // Tranche de prix (PostgREST and= pour cumuler min+max).
    final range = _fPrice != null ? _priceRanges[_fPrice] : null;
    if (range != null) {
      final min = range[0];
      final max = range[1];
      if (max == null) {
        q['price_sale'] = 'gte.$min';
      } else {
        q['and'] = '(price_sale.gte.$min,price_sale.lte.$max)';
      }
    }
    // Disponibilite : liste courte des ids reels avec stock > 0.
    if (_fAvail != null && _stockIds.isNotEmpty && _stockIds.length <= 300) {
      final ids = _stockIds.join(',');
      q['id'] = _fAvail == 'en_stock' ? 'in.($ids)' : 'not.in.($ids)';
    }
    return q;
  }

  Future<void> _load({int page = 1, String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var result = await ApiClient.instance.get(
      '/catalog/medications',
      query: _buildQuery(page, query),
    );
    // Backend edge function incomplet : si la route /catalog/medications
    // n'est pas déployée (PGRST125), on retombe sur la table brute
    // /medications pour au moins afficher le catalogue existant.
    if (!result.success && result.error?.code == 'PGRST125') {
      result = await ApiClient.instance.get(
        '/medications',
        query: {'limit': 100, 'is_parapharmacie': _paraMode},
      );
    }
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      final incoming =
          ApiList.of(result.data).map(Medication.fromJson).toList();
      // "Charger plus" : cumuler les pages au lieu de remplacer la liste.
      _items = page > 1 ? [..._items, ...incoming] : incoming;
      _total = ApiList.total(result.data, result.meta);
      _page = page;
      _loading = false;
    });
    _loadStockForPage();
  }

  /// Stock reel par lot pour les ids de la page affichee.
  Future<void> _loadStockForPage() async {
    final ids = _items.map((m) => m.id).where((id) => !_stock.containsKey(id)).toList();
    if (ids.isEmpty) return;
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
  }

  void _resetFilters() {
    setState(() {
      _fLab = null;
      _fForm = null;
      _fDosage = null;
      _fStatus = null;
      _fAvail = null;
      _fPrice = null;
    });
    _load(page: 1, query: _search.text);
  }

  Future<void> _create() async {
    final created = await _showForm(null);
    if (created) _load(page: 1, query: _search.text);
  }

  String _notProvided(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Non renseigné' : v;

  /// Fiche complete : GET /catalog/medications/{id}/details
  /// (medicament + labo + stock + provenance source + reference).
  void _showDetail(Medication medication) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _MedicationDetail(
          medication: medication,
          stock: _stock[medication.id],
          onEdit: () {
            Navigator.pop(context);
            _showForm(medication).then((changed) {
              if (changed) _load(page: _page, query: _search.text);
            });
          },
        ),
      ),
    );
  }

  Future<bool> _showForm(Medication? medication) async {
    final name = TextEditingController(text: medication?.name ?? '');
    final dci = TextEditingController(text: medication?.dci ?? '');
    final barcode = TextEditingController(text: medication?.barcodeEan13 ?? '');
    final purchase = TextEditingController(
        text: medication != null ? '${medication.pricePurchase}' : '');
    final sale = TextEditingController(
        text: medication != null ? '${medication.priceSale}' : '');
    final minStock = TextEditingController(
        text: medication != null ? '${medication.minStock}' : '');
    final dosage = TextEditingController(text: medication?.dosage ?? '');
    final form = TextEditingController(text: medication?.form ?? '');
    final presentation =
        TextEditingController(text: medication?.presentation ?? '');
    final laboratory =
        TextEditingController(text: medication?.laboratoryName ?? '');
    final therapeuticClass =
        TextEditingController(text: medication?.therapeuticClass ?? '');
    final substance = TextEditingController(text: medication?.substanceActive ?? '');
    final composition = TextEditingController(text: medication?.composition ?? '');
    final phCtrl = TextEditingController(
        text: medication?.ph != null ? '${medication!.ph}' : '');
    final ppcCtrl = TextEditingController(
        text: medication?.ppc != null ? '${medication!.ppc}' : '');
    // TVA : taux du produit, sinon défaut Paramètres → Fiscalité
    // (medicament / parapharmacie) selon le mode actif.
    double tvaRate = medication?.tvaRate ?? 0;
    if (tvaRate <= 0) {
      final pharmacy = await ApiClient.instance.get('/pharmacies/me');
      final settings = (pharmacy.data is Map)
          ? ((pharmacy.data as Map)['settings'] as Map?)
          : null;
      final tva = settings?['tva'] as Map?;
      tvaRate = (tva?[_paraMode ? 'parapharmacie' : 'medication'] as num?)?.toDouble() ??
          (_paraMode ? 20 : 16);
    }
    final tva = TextEditingController(text: '$tvaRate');
    String? selectedZone = medication?.shelfLocation;
    if (!mounted) return false;
    final locale = context.read<AuthStore>().locale;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(medication == null ? 'Nouveau médicament' : medication.name),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const                   _FormSection('Identité'),
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nom *')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: dci,
                      decoration: const InputDecoration(labelText: 'DCI')),
                  const SizedBox(height: 10),
                  // Code-barres + lecteur intégré (bouton scanner pro).
                  TextField(
                      controller: barcode,
                      decoration: InputDecoration(
                        labelText: 'Code-barres (EAN-13)',
                        suffixIcon: IconButton(
                          tooltip: 'Scanner le code-barres',
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.emeraldLight,
                          ),
                          onPressed: () async {
                            final r = await BarcodeScannerSheet.show(
                              context,
                              title: 'Scanner le code-barres du médicament',
                            );
                            if (r != null) {
                              barcode.text = r.lookupCode;
                            }
                          },
                        ),
                      )),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedZone,
                    decoration:
                        InputDecoration(labelText: S.t('zone', locale)),
                    items: kPlanZones
                        .map((z) => DropdownMenuItem(
                              value: z.id,
                              child: Text(S.t(z.labelKey, locale)),
                            ))
                        .toList(),
                    onChanged: (v) => selectedZone = v,
                  ),
                  const                   _FormSection('Caractéristiques'),
                  TextField(
                      controller: dosage,
                      decoration: const InputDecoration(labelText: 'Dosage')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: form,
                      decoration: const InputDecoration(labelText: 'Forme')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: presentation,
                      decoration:
                          const InputDecoration(labelText: 'Présentation')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: substance,
                      decoration: const InputDecoration(
                          labelText: 'Substance active')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: composition,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Composition')),
                  const                   _FormSection('Laboratoire'),
                  // Combo searchable : suggestions des labs reels existants ;
                  // un nom nouveau est cree via l'API (anti-doublon local).
                  _SearchableField(
                    controller: laboratory,
                    label: 'Laboratoire / Fabricant',
                    hint: 'Rechercher ou saisisser un laboratoire…',
                    options: _labs.map((l) => l.label).toList(),
                  ),
                  const                   _FormSection('Prix'),
                  Row(children: [
                    Expanded(
                      child: TextField(
                          controller: sale,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'PPV — Prix de vente (DH) *')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: purchase,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'PFHT — Prix achat (DH)')),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                          controller: phCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'PH (DH)')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: ppcCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'PPC (DH)')),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                          controller: tva,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'TVA (%)',
                              helperText: 'Défaut : Paramètres')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: minStock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Stock minimum')),
                    ),
                  ]),
                  const                   _FormSection('Thérapeutique'),
                  TextField(
                      controller: therapeuticClass,
                      decoration: const InputDecoration(
                          labelText: 'Classe thérapeutique')),
                  const SizedBox(height: 6),
                  Text(
                    'Pathologie / Indication : Non renseignée (aucune source fiable disponible)',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', context.read<AuthStore>().locale))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('save', context.read<AuthStore>().locale))),
          ],
        ),
      ),
    );
    if (saved != true) return false;

    // Laboratoire : anti-doublon (casse-insensible) sur les labs reels.
    var labId = medication?.laboratoryId;
    final labText = laboratory.text.trim();
    if (labText.isNotEmpty) {
      final match = _labs.firstWhere(
          (l) => l.label.toLowerCase() == labText.toLowerCase(),
          orElse: () => const _Facet(''));
      if (match.label.isNotEmpty) {
        laboratory.text = match.label; // nom canonique existant
      } else if (medication?.laboratoryName != labText) {
        // Nouveau laboratoire : creation via API (permission catalog:create).
        final lab = await ApiClient.instance
            .post('/catalog/laboratories', body: {'name': labText});
        if (lab.success && lab.data is Map) {
          labId = '${(lab.data as Map)['id']}';
        } else if (lab.error?.code == '409' || (lab.error?.message ?? '')
            .toLowerCase()
            .contains('existe')) {
          // Doublon cote serveur : on garde le nom, sans FK.
          labId = null;
        }
      }
    }

    final payload = <String, dynamic>{
      'name': name.text.trim(),
      'dci': dci.text.trim(),
      'barcode_ean13': barcode.text.trim(),
      'price_purchase': double.tryParse(purchase.text) ?? 0,
      'price_sale': double.tryParse(sale.text) ?? 0,
      'ph': phCtrl.text.trim().isEmpty ? null : double.tryParse(phCtrl.text),
      'ppc': ppcCtrl.text.trim().isEmpty ? null : double.tryParse(ppcCtrl.text),
      'min_stock': double.tryParse(minStock.text) ?? 0,
      'shelf_location': selectedZone,
      'dosage': dosage.text.trim().isEmpty ? null : dosage.text.trim(),
      'form': form.text.trim().isEmpty ? null : form.text.trim(),
      'presentation':
          presentation.text.trim().isEmpty ? null : presentation.text.trim(),
      'substance_active':
          substance.text.trim().isEmpty ? null : substance.text.trim(),
      'composition': composition.text.trim().isEmpty ? null : composition.text.trim(),
      'laboratory_name': labText.isEmpty ? null : laboratory.text.trim(),
      if (labId != null) 'laboratory_id': labId,
      'therapeutic_class': therapeuticClass.text.trim().isEmpty
          ? null
          : therapeuticClass.text.trim(),
      'tva_rate': double.tryParse(tva.text) ?? 20,
    };
    if (medication == null) {
      payload['is_parapharmacie'] = _paraMode;
      final result =
          await ApiClient.instance.post('/catalog/medications', body: payload);
      if (mounted) _showResult(result.success, result.error?.message ?? 'Créé');
      return result.success;
    }
    final result = await ApiClient.instance
        .put('/catalog/medications/${medication.id}', body: payload);
    if (mounted) {
      _showResult(result.success, result.error?.message ?? 'Enregistré');
    }
    return result.success;
  }

  void _showResult(bool ok, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: ok ? AppColors.success : AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(
            _paraMode ? S.t('parapharmacy', locale) : S.t('catalog', locale)),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.medication_outlined, size: 18),
                  label: Text(S.t('catalog', locale)),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.spa_outlined, size: 18),
                  label: Text(S.t('parapharmacy', locale)),
                ),
              ],
              selected: {_paraMode},
              onSelectionChanged: (selection) {
                setState(() => _paraMode = selection.first);
                _load(page: 1, query: _search.text);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (q) => _load(query: q),
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          // -------- Filtres combinables (ComboBox + reset) --------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _filterDropdown(
                  label: 'Laboratoire',
                  value: _fLab,
                  enabled: _labs.isNotEmpty,
                  options: _labs,
                  onChanged: (v) {
                    setState(() => _fLab = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                _filterDropdown(
                  label: 'Forme',
                  value: _fForm,
                  enabled: _forms.isNotEmpty,
                  options: _forms,
                  onChanged: (v) {
                    setState(() => _fForm = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                _filterDropdown(
                  label: 'Dosage',
                  value: _fDosage,
                  enabled: _dosages.isNotEmpty,
                  options: _dosages,
                  onChanged: (v) {
                    setState(() => _fDosage = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                _filterDropdown(
                  label: 'Statut',
                  value: _fStatus,
                  enabled: _statuses.isNotEmpty,
                  options: _statuses,
                  onChanged: (v) {
                    setState(() => _fStatus = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                _filterDropdown(
                  label: 'Prix (DH)',
                  value: _fPrice,
                  enabled: true,
                  options: _priceRanges.entries
                      .map((e) => _Facet(
                          e.key.endsWith('+')
                              ? '${e.key} DH'
                              : '${e.key.replaceAll('-', ' - ')} DH',
                          e.key))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _fPrice = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                _filterDropdown(
                  label: 'Disponibilité',
                  value: _fAvail,
                  enabled: true,
                  options: const [
                    _Facet('En stock', 'en_stock'),
                    _Facet('Sans stock suivi', 'hors_stock'),
                  ],
                  onChanged: (v) {
                    setState(() => _fAvail = v);
                    _load(page: 1, query: _search.text);
                  },
                ),
                // Pathologie / indication : signale honnetement (aucune
                // donnee reelle en base, jamais de carte promettant du vide).
                Tooltip(
                  message: _indicationsTotal > 0
                      ? '$_indicationsTotal indications'
                      : 'Aucune indication fournie par la source — données non disponibles',
                  child: FilterChip(
                    label: Text(_indicationsTotal > 0
                        ? 'Pathologie ($_indicationsTotal)'
                        : 'Pathologie : données non disponibles'),
                    selected: false,
                    onSelected: _indicationsTotal > 0
                        ? (_) {}
                        : null,
                    avatar: Icon(
                      _indicationsTotal > 0
                          ? Icons.filter_alt
                          : Icons.filter_alt_off_outlined,
                      size: 16,
                    ),
                  ),
                ),
                if (_hasFilters)
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Réinitialiser les filtres'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('Aucun produit'))
                        : RefreshIndicator(
                            onRefresh: () =>
                                _load(page: 1, query: _search.text),
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              child: Column(
                                children: [
                                  GlassCard(
                                    radius: BorderRadius.circular(16),
                                    padding: EdgeInsets.zero,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            minWidth: 1150),
                                        child: _buildTable(isDark, locale),
                                      ),
                                    ),
                                  ),
                                  if (_items.length < _total)
                                    Center(
                                      child: TextButton(
                                        onPressed: () => _load(
                                            page: _page + 1,
                                            query: _search.text),
                                        child: Text(S.t('loadMore', locale)),
                                      ),
                                    ),
                                  if (_items.length >= _total && _items.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        '${Fmt.number(_total)} produits',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required bool enabled,
    required List<_Facet> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: enabled ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: const Icon(Icons.arrow_drop_down, size: 18),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(enabled ? 'Tous' : '—',
                style: const TextStyle(fontSize: 13)),
          ),
          for (final o in options.where((o) => o.label.isNotEmpty && o.value.isNotEmpty))
            DropdownMenuItem<String>(
              value: o.value.isEmpty ? null : o.value,
              enabled: o.value.isNotEmpty,
              child: Text(
                o.total > 0 ? '${o.label} (${o.total})' : o.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  DataTable _buildTable(bool isDark, String locale) {
    const headerStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold);
    const cellStyle = TextStyle(fontSize: 12.5);
    final muted = isDark ? Colors.white60 : Colors.black54;

    DataRow row(Medication m) {
      final qty = _stock[m.id];
      final statusLabel = m.status == 'available'
          ? 'Disponible'
          : (m.status == 'archived' ? 'Archivé' : m.status);
      final statusColor = m.status == 'available'
          ? AppColors.success
          : AppColors.warning;
      return DataRow(
        onSelectChanged: (_) => _showDetail(m),
        cells: [
          DataCell(Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
          DataCell(Text(_notProvided(m.dci), style: cellStyle.copyWith(color: muted))),
          DataCell(Text(_notProvided(m.dosage), style: cellStyle)),
          DataCell(Text(_notProvided(m.form), style: cellStyle)),
          DataCell(Text(_notProvided(m.presentation), style: cellStyle)),
          DataCell(Text(_notProvided(m.laboratoryName), style: cellStyle)),
          DataCell(Text(
              m.priceSale > 0 ? Fmt.money(m.priceSale) : 'Non renseigné',
              style: cellStyle.copyWith(fontWeight: FontWeight.w700))),
          DataCell(Text(m.ph != null && m.ph! > 0 ? Fmt.money(m.ph!) : '—',
              style: cellStyle)),
          DataCell(Text(m.ppc != null && m.ppc! > 0 ? Fmt.money(m.ppc!) : '—',
              style: cellStyle)),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          )),
          DataCell(Text(
            qty == null
                ? 'Non suivi'
                : (qty > 0
                    ? '${Fmt.number(qty)} (en stock)'
                    : '0 (sans stock)'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: qty == null
                    ? muted
                    : (qty > 0 ? AppColors.success : AppColors.danger)),
          )),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Fiche détaillée',
                icon: const Icon(Icons.visibility_outlined, size: 18),
                onPressed: () => _showDetail(m),
              ),
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _showForm(m).then((changed) {
                  if (changed) _load(page: _page, query: _search.text);
                }),
              ),
            ],
          )),
        ],
      );
    }

    return DataTable(
      headingRowColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.9)),
      headingTextStyle: headerStyle,
      dataTextStyle: cellStyle,
      columnSpacing: 16,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Médicament', style: headerStyle)),
        DataColumn(label: Text('DCI', style: headerStyle)),
        DataColumn(label: Text('Dosage', style: headerStyle)),
        DataColumn(label: Text('Forme', style: headerStyle)),
        DataColumn(label: Text('Présentation', style: headerStyle)),
        DataColumn(label: Text('Laboratoire', style: headerStyle)),
        DataColumn(label: Text('PPV', style: headerStyle)),
        DataColumn(label: Text('PH', style: headerStyle)),
        DataColumn(label: Text('PPC', style: headerStyle)),
        DataColumn(label: Text('Statut', style: headerStyle)),
        DataColumn(label: Text('Stock / dispo', style: headerStyle)),
        DataColumn(label: Text('Actions', style: headerStyle)),
      ],
      rows: _items.map(row).toList(),
    );
  }
}

/// Section de titre dans le formulaire d'ajout/modification.
class _FormSection extends StatelessWidget {
  final String title;
  const _FormSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: 0.4),
          ),
          const SizedBox(width: 8),
          const Expanded(
              child: Divider(
                  color: AppColors.goldBorder, height: 1, thickness: 1)),
        ],
      ),
    );
  }
}

/// Champ avec suggestions (combo searchable) : tap => panneau de recherche.
class _SearchableField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> options;
  const _SearchableField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            suffixIcon: IconButton(
              tooltip: 'Choisir dans les laboratoires existants',
              icon: const Icon(Icons.search, size: 18),
              onPressed: () => _openPicker(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final filter = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final q = filter.text.trim().toLowerCase();
                final list = q.isEmpty
                    ? options
                    : options.where((o) => o.toLowerCase().contains(q)).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: filter,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un laboratoire…',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: list.isEmpty
                          ? const Center(child: Text('Aucun laboratoire'))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, i) => ListTile(
                                dense: true,
                                title: Text(list[i]),
                                onTap: () => Navigator.pop(context, list[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (selected != null) controller.text = selected;
  }
}

class _MedicationDetail extends StatefulWidget {
  final Medication medication;
  final double? stock;
  final VoidCallback onEdit;
  const _MedicationDetail(
      {required this.medication, this.stock, required this.onEdit});

  @override
  State<_MedicationDetail> createState() => _MedicationDetailState();
}

class _MedicationDetailState extends State<_MedicationDetail> {
  Map<String, dynamic>? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final r = await ApiClient.instance
        .get('/catalog/medications/${widget.medication.id}/details');
    if (!mounted) return;
    setState(() {
      if (r.success && r.data is Map) _details = Map<String, dynamic>.from(r.data as Map);
      _loading = false;
    });
  }

  String _np(dynamic v) {
    if (v == null) return 'Non renseigné';
    final s = '$v'.trim();
    return s.isEmpty || s == '0.0' || s == '0' ? 'Non renseigné' : s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : Colors.black54;
    final locale = context.read<AuthStore>().locale;
    final m = widget.medication;
    final med = _details?['medication'] as Map<String, dynamic>?;
    final lab = _details?['laboratory'] as Map<String, dynamic>?;
    final prov = _details?['provenance'] as Map<String, dynamic>?;
    final ref = _details?['reference'] as Map<String, dynamic>?;
    final stockQty = _details != null
        ? ((_details!['stock'] as Map?)?['quantity'] as num?)?.toDouble()
        : widget.stock;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 165,
                child: Text(label, style: TextStyle(color: muted)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(children: [
            const Icon(Icons.circle, size: 6, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold)),
          ]),
        );

    final dci = med?['dci'] ?? m.dci ?? (ref?['dci'] as String?);
    final substance = med?['substance_active'] ?? ref?['substance_active'];
    final dosage = med?['dosage'] ?? m.dosage;
    final form = med?['form'] ?? m.form;
    final pres = med?['presentation'] ?? m.presentation;
    final labName = med?['laboratory_name'] ?? lab?['name'] ?? m.laboratoryName;
    final tva = med?['tva_rate'] ?? m.tvaRate;
    final classe = med?['therapeutic_class'] ?? m.therapeuticClass;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.medication,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _details == null && _loading
                  ? 'Chargement…'
                  : (_details == null
                      ? 'Détails indisponibles'
                      : ''),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            section('Identité'),
            row('Nom commercial', m.name),
            row('DCI', _np(dci)),
            row('Code-barres (EAN-13)', _np(med?['barcode_ean13'] ?? m.barcodeEan13)),
            row('QR / DataMatrix', _np(med?['qr_code'])),
            section('Caractéristiques'),
            row('Dosage', _np(dosage)),
            row('Forme', _np(form)),
            row('Présentation', _np(pres)),
            row('Substance active', _np(substance)),
            row('Composition', _np(med?['composition'])),
            section('Laboratoire'),
            row('Laboratoire', _np(labName)),
            section('Prix'),
            row('PPV', m.priceSale > 0 ? Fmt.money(m.priceSale) : 'Non renseigné'),
            row('PH', (ref?['ph'] != null) ? Fmt.money(double.parse('${ref!['ph']}')) : 'Non renseigné'),
            row('PPC', (med?['ppc'] != null) ? Fmt.money(double.parse('${med!['ppc']}')) : ((ref?['ppc'] != null) ? Fmt.money(double.parse('${ref!['ppc']}')) : 'Non renseigné')),
            row('PFHT (achat)', m.pricePurchase > 0 ? Fmt.money(m.pricePurchase) : 'Non renseigné'),
            row('TVA', '${_np(tva)} %'),
            section('Thérapeutique'),
            row('Classe thérapeutique', _np(classe)),
            row('Pathologie', 'Non renseignée'),
            row('Indication', 'Non renseignée'),
            section('Stock'),
            row('Quantité',
                stockQty == null ? 'Non suivi' : Fmt.number(stockQty)),
            row('Disponibilité', stockQty == null
                ? 'Non renseignée'
                : (stockQty > 0 ? 'En stock' : 'Sans stock')),
            row('Stock minimum', _np(med?['min_stock'] ?? m.minStock)),
            row('Emplacement', _np(med?['shelf_location'] ?? m.shelfLocation)),
            section('Source'),
            row('Source', _np(prov?['source'])),
            row('URL source',
                prov?['source_url'] == null ? 'Non renseignée' : '${prov!['source_url']}'),
            row('Date source', _np(prov?['date_source'])),
            row('Date import', _np(prov?['date_import'])),
            if (ref != null) ...[
              row('N° AMM', _np(ref['amm_number'])),
              row('Code produit', _np(ref['code_produit'])),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.view_in_ar),
                label: Text(S.t('viewInPlan', locale)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PharmacyPlanPage(focusZoneId: m.zone),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
