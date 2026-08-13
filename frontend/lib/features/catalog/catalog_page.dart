import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.parapharmacy = false});

  final bool parapharmacy;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1, String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/catalog/medications',
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        'is_parapharmacie': _paraMode,
        'page': page,
        'limit': 40,
      },
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      _items = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Medication.fromJson)
          .toList();
      _total = result.meta?['total'] as int? ?? 0;
      _page = page;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final created = await _showForm(null);
    if (created) _load(page: 1, query: _search.text);
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
    final aisleCtrl = TextEditingController(text: medication?.aisle ?? '');
    final shelfCtrl = TextEditingController(text: medication?.shelf ?? '');
    final levelCtrl = TextEditingController(text: medication?.level ?? '');
    final positionCtrl = TextEditingController(text: medication?.position ?? '');
    final locationIdCtrl = TextEditingController(text: medication?.locationId ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(medication == null ? 'Nouveau médicament' : medication.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom *')),
              const SizedBox(height: 10),
              TextField(
                  controller: dci,
                  decoration: const InputDecoration(labelText: 'DCI')),
              const SizedBox(height: 10),
              TextField(
                  controller: barcode,
                  decoration: const InputDecoration(labelText: 'EAN-13')),
TextField(
      controller: aisleCtrl,
      decoration: const InputDecoration(labelText: 'Rayon')),
              const SizedBox(height: 10),
              TextField(
                controller: shelfCtrl,
                decoration: const InputDecoration(labelText: 'Étagère')),
              const SizedBox(height: 10),
              TextField(
                controller: levelCtrl,
                decoration: const InputDecoration(labelText: 'Niveau')),
              const SizedBox(height: 10),
              TextField(
                controller: positionCtrl,
                decoration: const InputDecoration(labelText: 'Case')),
              const SizedBox(height: 10),
              TextField(
                controller: locationIdCtrl,
                decoration: const InputDecoration(labelText: 'ID Emplacement (optionnel)'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: sale,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Prix de vente (DH) *')),
              const SizedBox(height: 10),
              TextField(
                  controller: minStock,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Stock minimum')),
            ],
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
    );
    if (saved != true) return false;

    if (medication == null) {
      final result =
          await ApiClient.instance.post('/catalog/medications', body: {
        'name': name.text.trim(),
        'dci': dci.text.trim(),
        'barcode_ean13': barcode.text.trim(),
        'price_purchase': double.tryParse(purchase.text) ?? 0,
        'price_sale': double.tryParse(sale.text) ?? 0,
        'min_stock': double.tryParse(minStock.text) ?? 0,
        'aisle': aisleCtrl.text.trim(),
        'shelf': shelfCtrl.text.trim(),
        'level': levelCtrl.text.trim(),
        'position': positionCtrl.text.trim(),
        'location_id': locationIdCtrl.text.trim(),
        'is_parapharmacie': _paraMode,
      });
      if (mounted) _showResult(result.success, result.error?.message ?? 'Créé');
      return result.success;
    }
    final result = await ApiClient.instance
        .put('/catalog/medications/${medication.id}', body: {
      'name': name.text.trim(),
      'dci': dci.text.trim(),
      'barcode_ean13': barcode.text.trim(),
      'price_purchase': double.tryParse(purchase.text),
      'price_sale': double.tryParse(sale.text),
      'min_stock': double.tryParse(minStock.text),
      'aisle': aisleCtrl.text.trim(),
      'shelf': shelfCtrl.text.trim(),
      'level': levelCtrl.text.trim(),
      'position': positionCtrl.text.trim(),
      'location_id': locationIdCtrl.text.trim(),
    });
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
    return Scaffold(
      appBar: AppBar(
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: () =>
                            _load(page: _page, query: _search.text),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              if (_items.length >= _total) {
                                return const SizedBox(height: 16);
                              }
                              return Center(
                                child: TextButton(
                                  onPressed: () => _load(
                                      page: _page + 1, query: _search.text),
                                  child: Text(S.t('loadMore',
                                      context.read<AuthStore>().locale)),
                                ),
                              );
                            }
                            final medication = _items[index];
                            return _MedicationTile(
                              medication: medication,
                              onTap: () => _showDetail(medication),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(Medication medication) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _MedicationDetail(
            medication: medication,
            onEdit: () {
              Navigator.pop(context);
              _showForm(medication).then((changed) {
                if (changed) _load(page: _page, query: _search.text);
              });
            }),
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTap;
  const _MedicationTile({required this.medication, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final low = medication.stockQuantity != null && medication.isLowStock;
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  [medication.dci, medication.dosage, medication.form]
                      .whereType<String>()
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(medication.priceSale),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 2),
              if (medication.stockQuantity != null)
                Text(
                  low
                      ? 'Alerte !'
                      : 'Stock: ${Fmt.number(medication.stockQuantity!)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: low
                        ? AppColors.danger
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicationDetail extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  const _MedicationDetail({required this.medication, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : Colors.black54;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: muted)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600))
            ],
          ),
        );
    return SafeArea(
      child: Padding(
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
                  child: Text(medication.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            const SizedBox(height: 8),
            row('DCI', medication.dci ?? '—'),
            row('Dosage', medication.dosage ?? '—'),
            row("Prix d'achat", Fmt.money(medication.pricePurchase)),
            row('Prix de vente', Fmt.money(medication.priceSale)),
            row('TVA', '${Fmt.number(medication.tvaRate, decimals: 1)} %'),
            row('Stock minimum', Fmt.number(medication.minStock)),
            row('EAN-13', medication.barcodeEan13 ?? '—'),
            row('Ordonnance requise',
                medication.prescriptionRequired ? 'Oui' : 'Non'),
          ],
        ),
      ),
    );
  }
}
