import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/colors.dart';

/// PHARMA+ — Module unifié « PRODUIT NON RECONNU » (section 11).
/// Un seul moteur, réutilisé partout (réception, audit, POS, stock) :
///   1. RECHERCHER (anti-doublon) — 2. ASSOCIER (PUT) —
///   3. CRÉER (POST, catalogue central unique) — 4. ANNULER.
/// JAMAIS de création automatique de doublon.
/// Retour : la fiche produit créée/associée, ou `null` si annulé.

/// Codes valides pour stockage en base : EAN-8 → GTIN-14.
bool isValidProductCode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code);

Future<Map<String, dynamic>?> showUnknownProductDialog(
  BuildContext context, {
  required String barcode,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => UnknownProductDialog(barcode: barcode),
  );
}

class UnknownProductDialog extends StatefulWidget {
  final String barcode;
  const UnknownProductDialog({super.key, required this.barcode});

  @override
  State<UnknownProductDialog> createState() => _UnknownProductDialogState();
}

class _UnknownProductDialogState extends State<UnknownProductDialog> {
  _Mode _mode = _Mode.search;

  // ── Création ──
  final _name = TextEditingController();
  final _dci = TextEditingController();
  final _dosage = TextEditingController();
  final _form = TextEditingController();
  final _purchase = TextEditingController();
  final _sale = TextEditingController();
  final _tva = TextEditingController(text: '20');
  bool _parapharmacie = false;
  bool _saving = false;
  String? _error;

  // ── Recherche / association ──
  final _search = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false;
  String? _assocSavingId;

  @override
  void initState() {
    super.initState();
    _runSearch(); // recherche anti-doublon immédiate avec le code scanné
  }

  @override
  void dispose() {
    for (final c in [_name, _dci, _dosage, _form, _purchase, _sale, _tva, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  /// RECHERCHER — anti-doublon par code, nom, dosage, forme (API catalogue).
  Future<void> _runSearch() async {
    final q = _search.text.trim().isEmpty ? widget.barcode : _search.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final r = await ApiClient.instance
        .get('/catalog/medications?q=${Uri.encodeComponent(q)}&limit=20');
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = (r.success ? (r.data as List? ?? const []) : const []);
    });
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  /// ASSOCIER — attache le code scanné à un produit existant (PUT complet).
  Future<void> _associate(Map<String, dynamic> med) async {
    if (!isValidProductCode(widget.barcode)) {
      setState(() => _error =
          'Code non numérique (${widget.barcode}) — impossible à associer '
          'comme code-barres. Créez une référence ou annulez.');
      return;
    }
    final id = '${med['id']}';
    setState(() => _assocSavingId = id);
    final r = await ApiClient.instance.get('/catalog/medications/$id');
    if (!mounted) return;
    if (!r.success || r.data == null) {
      setState(() => _assocSavingId = null);
      return;
    }
    final full = Map<String, dynamic>.from(r.data as Map);
    final body = <String, dynamic>{
      'name': full['name'],
      'dci': full['dci'],
      'generic_name': full['generic_name'],
      'dosage': full['dosage'],
      'form': full['form'],
      'presentation': full['presentation'],
      'photo_url': full['photo_url'],
      'leaflet_url': full['leaflet_url'],
      'barcode_ean13': widget.barcode,
      'category_id': full['category_id'],
      'family_id': full['family_id'],
      'laboratory_id': full['laboratory_id'],
      'price_purchase': _num(full['price_purchase']),
      'price_sale': _num(full['price_sale']),
      'tva_rate': _num(full['tva_rate']),
      'prescription_required': full['prescription_required'] ?? false,
      'storage_conditions': full['storage_conditions'],
      'reorder_level': _num(full['reorder_level']),
      'min_stock': _num(full['min_stock']),
      'shelf_location': full['shelf_location'],
      'status': full['status'] ?? 'available',
      'is_public': full['is_public'] ?? false,
      'is_parapharmacie': full['is_parapharmacie'] ?? false,
    };
    final up =
        await ApiClient.instance.put('/catalog/medications/$id', body: body);
    if (!mounted) return;
    setState(() => _assocSavingId = null);
    if (up.success && up.data != null) {
      Navigator.of(context).pop(Map<String, dynamic>.from(up.data as Map));
    } else {
      setState(() => _error =
          up.error?.readableMessage ?? 'Erreur lors de l\u2019association.');
    }
  }

  /// CRÉER — nouvelle référence dans le catalogue central (POST).
  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'dci': _dci.text.trim().isEmpty ? null : _dci.text.trim(),
      'dosage': _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      'form': _form.text.trim().isEmpty ? null : _form.text.trim(),
      if (isValidProductCode(widget.barcode)) 'barcode_ean13': widget.barcode,
      'price_purchase':
          double.tryParse(_purchase.text.replaceAll(',', '.')) ?? 0,
      'price_sale': double.tryParse(_sale.text.replaceAll(',', '.')) ?? 0,
      'tva_rate': double.tryParse(_tva.text.replaceAll(',', '.')) ?? 20,
      'is_parapharmacie': _parapharmacie,
    };
    final r = await ApiClient.instance.post('/catalog/medications', body: body);
    if (!mounted) return;
    if (r.success && r.data != null) {
      Navigator.of(context).pop(Map<String, dynamic>.from(r.data as Map));
    } else {
      setState(() {
        _saving = false;
        _error = r.error?.readableMessage ?? 'Erreur de création';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.help_outline_rounded, color: AppColors.pharmaGold),
        SizedBox(width: 8),
        Expanded(child: Text('Produit non reconnu')),
      ]),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code scanné : ${widget.barcode}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text(
                  'Ce code n\u2019est associé à aucun produit. Rechercher, '
                  'associer ou créer — jamais de doublon automatique.',
                  style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 12),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                      value: _Mode.search,
                      icon: Icon(Icons.search_rounded, size: 18),
                      label: Text('Rechercher')),
                  ButtonSegment(
                      value: _Mode.create,
                      icon: Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: Text('Créer')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              ..._buildSearchMode(),
              if (_mode == _Mode.create) ..._buildCreateMode(),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        if (_mode == _Mode.create)
          FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'Création…' : 'Créer la référence')),
      ],
    );
  }

  List<Widget> _buildSearchMode() {
    if (_mode != _Mode.search) return const [];
    return [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
                labelText: 'Nom, dosage, forme ou code-barres'),
            onSubmitted: (_) => _runSearch(),
          ),
        ),
        IconButton(
          onPressed: _searching ? null : _runSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      ]),
      const SizedBox(height: 8),
      if (_searching) const Center(child: CircularProgressIndicator()),
      if (!_searching)
        ..._results.map<Widget>((m) => Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                title: Text('${m['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(
                    '${m['dosage'] ?? '—'} · ${m['form'] ?? '—'} · '
                    '${m['laboratory_name'] ?? 'Labo non renseigné'}\n'
                    'Code actuel : ${m['barcode_ean13'] ?? 'aucun'}',
                    style: const TextStyle(fontSize: 11.5)),
                isThreeLine: true,
                trailing: _assocSavingId == '${m['id']}'
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link_rounded,
                        color: AppColors.pharmaGold),
                onTap: _assocSavingId == null
                    ? () => _associate(Map<String, dynamic>.from(m as Map))
                    : null,
              ),
            )),
      if (!_searching && _results.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
              'Aucun produit existant ne correspond. Utilisez « Créer » '
              'pour une nouvelle référence.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
    ];
  }

  List<Widget> _buildCreateMode() {
    return [
      TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom du produit *')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
              controller: _dci,
              decoration: const InputDecoration(labelText: 'DCI')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
              controller: _dosage,
              decoration:
                  const InputDecoration(labelText: 'Dosage (ex. 500 mg)')),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(
          controller: _form,
          decoration: const InputDecoration(
              labelText: 'Forme (comprimé, sirop…)')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
              controller: _purchase,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix achat')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
              controller: _sale,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix vente *')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
              controller: _tva,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'TVA (%)')),
        ),
      ]),
      const SizedBox(height: 10),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Parapharmacie', style: TextStyle(fontSize: 13)),
        value: _parapharmacie,
        onChanged: (v) => setState(() => _parapharmacie = v ?? false),
      ),
      if (!isValidProductCode(widget.barcode))
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
              '⚠ Code non numérique : il ne sera pas enregistré comme '
              'code-barres.',
              style: TextStyle(fontSize: 11, color: Colors.orange)),
        ),
    ];
  }
}

enum _Mode { search, create }
