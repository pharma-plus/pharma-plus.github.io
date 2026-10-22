// PHARMA+ — PRÉPARATION D'UNE COMMANDE FOURNISSEUR (BROUILLON).
// Depuis le plan de réapprovisionnement (/ai/reorder-plan) : la commande
// est créée en statut « draft » via POST /purchases/orders — elle n'est
// JAMAIS envoyée automatiquement au fournisseur. La validation/le envoi
// restent des actions séparées d'un utilisateur autorisé (purchases:*).
library;

import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';

class ReorderDraftDialog extends StatefulWidget {
  /// Lignes du plan de réappro (champs : medication_id, name,
  /// suggested_qty, unit_cost, supplier_name, priority).
  final List<Map<String, dynamic>> items;
  const ReorderDraftDialog({super.key, required this.items});

  /// Ouvre la préparation de commande brouillon (permission serveur
  /// purchases:create exigée à la création).
  static Future<bool?> show(BuildContext context,
      {required List<Map<String, dynamic>> items}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
          child: ReorderDraftDialog(items: items),
        ),
      ),
    );
  }

  @override
  State<ReorderDraftDialog> createState() => _ReorderDraftDialogState();
}

class _ReorderDraftDialogState extends State<ReorderDraftDialog> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _branches = [];
  String? _supplierId;
  String? _branchId;
  late final List<_DraftLine> _lines;
  bool _loadingMeta = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines = widget.items
        .where((e) => '${e['medication_id'] ?? ''}'.isNotEmpty)
        .map((e) => _DraftLine(
              medicationId: '${e['medication_id']}',
              name: '${e['name'] ?? '—'}',
              qty: (double.tryParse('${e['suggested_qty'] ?? 0}') ?? 0)
                  .clamp(1, 999999)
                  .toDouble(),
              unitCost: double.tryParse('${e['unit_cost'] ?? 0}') ?? 0,
              supplierNameHint: '${e['supplier_name'] ?? ''}',
            ))
        .toList();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final results = await Future.wait([
      ApiClient.instance
          .get('/suppliers', query: {'limit': 200, 'status': 'active'}),
      ApiClient.instance.get('/branches', query: {'limit': 50}),
    ]);
    if (!mounted) return;
    final suppliers = results[0];
    final branches = results[1];
    setState(() {
      _suppliers = suppliers.success
          ? ApiList.of(suppliers.data)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      _branches = branches.success
          ? ApiList.of(branches.data)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      if (_branches.length == 1) _branchId = '${_branches.first['id']}';
      // Fournisseur pré-sélectionné si toutes les lignes partagent le même.
      final names = _lines.map((l) => l.supplierNameHint).toSet();
      _loadingMeta = false;
      if (names.length == 1 &&
          names.first.isNotEmpty &&
          names.first != 'null') {
        final match = _suppliers.where(
            (s) => '${s['name']}'.toLowerCase() == names.first.toLowerCase());
        if (match.isNotEmpty) _supplierId = '${match.first['id']}';
      }
    });
  }

  double get _totalCost =>
      _lines.fold<double>(0, (sum, l) => sum + l.qty * l.unitCost);

  Future<void> _submit() async {
    final supplierId = _supplierId;
    final branchId = _branchId;
    if (supplierId == null || branchId == null) {
      setState(() => _error = 'Sélectionnez le fournisseur et la succursale.');
      return;
    }
    final validLines = _lines.where((l) => l.qty > 0).toList();
    if (validLines.isEmpty) {
      setState(() => _error = 'Aucune ligne avec une quantité valide.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await ApiClient.instance.post('/purchases/orders', body: {
      'branchId': branchId,
      'supplierId': supplierId,
      'notes': 'Préparé depuis le plan de réapprovisionnement (brouillon)',
      'items': [
        for (final l in validLines)
          {
            'medication_id': l.medicationId,
            'quantity': l.qty,
            'unit_cost': l.unitCost,
          }
      ],
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Commande brouillon créée — elle ne sera pas envoyée automatiquement.')));
    } else {
      setState(() =>
          _error = r.error?.readableMessage ?? r.error?.message ?? 'Échec');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_document,
                  color: AppColors.emerald, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Préparer une commande (brouillon)',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'La commande sera créée en BROUILLON dans Achats. '
            'Aucun envoi automatique au fournisseur : un utilisateur '
            'autorisé devra la valider et l\'envoyer manuellement.',
            style: TextStyle(fontSize: 12, color: AppColors.pharmaMuted),
          ),
          const SizedBox(height: 14),
          if (_loadingMeta)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ))
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _supplierId,
                    decoration: const InputDecoration(
                        labelText: 'Fournisseur', isDense: true),
                    items: [
                      for (final s in _suppliers)
                        DropdownMenuItem(
                            value: '${s['id']}', child: Text('${s['name']}')),
                    ],
                    onChanged:
                        _saving ? null : (v) => setState(() => _supplierId = v),
                  ),
                ),
                if (_branches.length > 1) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _branchId,
                      decoration: const InputDecoration(
                          labelText: 'Succursale', isDense: true),
                      items: [
                        for (final b in _branches)
                          DropdownMenuItem(
                              value: '${b['id']}',
                              child: Text('${b['name'] ?? b['code']}')),
                      ],
                      onChanged:
                          _saving ? null : (v) => setState(() => _branchId = v),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.goldBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lines.length,
                  itemBuilder: (context, i) {
                    final l = _lines[i];
                    return ListTile(
                      dense: true,
                      title: Text(l.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          'Coût unitaire : ${Fmt.money(l.unitCost)} MAD',
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: SizedBox(
                        width: 110,
                        child: TextFormField(
                          initialValue: '${l.qty.round()}',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                              labelText: 'Qté', isDense: true),
                          onChanged: (v) => setState(() {
                            l.qty = (double.tryParse(
                                        v.trim().replaceAll(',', '.')) ??
                                    0)
                                .clamp(0, 999999)
                                .toDouble();
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_lines.length} ligne(s) · Total : ${Fmt.money(_totalCost)} MAD',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_error != null)
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12)),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emerald),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Créer le brouillon (${validQtyLabel()})'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String validQtyLabel() {
    final n = _lines.where((l) => l.qty > 0).length;
    return '$n article${n > 1 ? 's' : ''}';
  }
}

class _DraftLine {
  final String medicationId;
  final String name;
  final String supplierNameHint;
  double qty;
  double unitCost;
  _DraftLine({
    required this.medicationId,
    required this.name,
    required this.qty,
    required this.unitCost,
    this.supplierNameHint = '',
  });
}
