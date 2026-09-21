import 'package:flutter/material.dart';

import '../../core/services/ocr_service.dart';
import '../../core/theme/colors.dart';

/// PHARMA+ — Ordonnance : lecture OCR + correspondance catalogue (sections
/// 13–15). OCR Tesseract.js 100 % local au navigateur (section 17) :
/// rien n'est envoyé au backend ni à un service tiers. Le texte extrait est
/// affiché, MODIFIABLE, et les correspondances catalogue ne sont ajoutées
/// QUE si le pharmacien les confirme (section 15 — jamais automatique).

String _normalize(String s) {
  return s
      .toUpperCase()
      .replaceAll(RegExp(r'[ÀÁÂÄ]'), 'A')
      .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
      .replaceAll(RegExp(r'[ÎÏ]'), 'I')
      .replaceAll(RegExp(r'[ÔÖ]'), 'O')
      .replaceAll(RegExp(r'[ÙÛÜ]'), 'U')
      .replaceAll(RegExp(r'[Ç]'), 'C');
}

Set<String> _significantTokens(String name) {
  return _normalize(name)
      .split(RegExp(r'[^A-Z0-9]+'))
      .where((t) => t.length >= 4 && int.tryParse(t) == null)
      .toSet();
}

/// Score de correspondance nom ↔ texte OCR (0.0 → 1.0).
double matchScore(Map<String, dynamic> med, Set<String> ocrTokens) {
  final tokens = _significantTokens('${med['name']}');
  if (tokens.isEmpty || ocrTokens.isEmpty) return 0;
  var found = 0;
  for (final t in tokens) {
    if (ocrTokens.contains(t)) found++;
  }
  return found / tokens.length;
}

/// Ouvre le flux OCR complet. Retourne les médicaments CHOISIS par le
/// pharmacien (jamais automatiques), ou null si annulé/échec.
Future<List<Map<String, dynamic>>?> openPrescriptionOcr(
  BuildContext context, {
  required List<Map<String, dynamic>> medications,
}) {
  return showDialog<List<Map<String, dynamic>>>(
    context: context,
    builder: (_) => _OcrDialog(medications: medications),
  );
}

class _OcrDialog extends StatefulWidget {
  final List<Map<String, dynamic>> medications;
  const _OcrDialog({required this.medications});

  @override
  State<_OcrDialog> createState() => _OcrDialogState();
}

class _OcrDialogState extends State<_OcrDialog> {
  bool _working = true;
  String? _error;
  String _text = '';
  double _confidence = 0;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final r = await captureAndRecognize();
    if (!mounted) return;
    if (r == null || r.text.isEmpty) {
      setState(() {
        _working = false;
        _error = r == null
            ? 'OCR indisponible sur cet appareil ou lecture impossible.'
            : 'Aucun texte lisible détecté — saisissez manuellement.';
      });
      return;
    }
    setState(() {
      _working = false;
      _text = r.text;
      _confidence = r.confidence;
    });
  }

  String get _confidenceLabel {
    if (_confidence >= 85) return 'Élevée';
    if (_confidence >= 60) return 'Moyenne — vérifiez';
    return '⚠ Faible — vérification nécessaire';
  }

  List<MapEntry<Map<String, dynamic>, double>> get _suggestions {
    final ocrTokens = _normalize(_text)
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((t) => t.length >= 4)
        .toSet();
    final matches = <MapEntry<Map<String, dynamic>, double>>[];
    for (final med in widget.medications) {
      final score = matchScore(med, ocrTokens);
      if (score >= 0.6) matches.add(MapEntry(med, score));
    }
    matches.sort((a, b) => b.value.compareTo(a.value));
    return matches.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.document_scanner_outlined, color: AppColors.pharmaGold),
        SizedBox(width: 8),
        Expanded(child: Text('Lecture OCR de l\u2019ordonnance')),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: _working
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Lecture du document (OCR local)…',
                        style: TextStyle(fontSize: 12.5)),
                  ]),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Confiance OCR : ',
                          style: TextStyle(fontSize: 12.5)),
                      Text(_confidenceLabel,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _confidence >= 85
                                  ? AppColors.success
                                  : _confidence >= 60
                                      ? AppColors.warning
                                      : AppColors.danger)),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: TextEditingController(text: _text),
                      maxLines: 6,
                      onChanged: (v) => _text = v,
                      decoration: const InputDecoration(
                        labelText: 'Texte extrait — CORRIGEZ-LE si nécessaire',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                        'Correspondances dans le catalogue '
                        '(cochez ce que vous confirmez) :',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ..._suggestions.map<Widget>((e) {
                      final med = e.key;
                      final score = e.value;
                      final id = '${med['id']}';
                      final high = score >= 0.85;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selectedIds.contains(id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        }),
                        title: Text('${med['name']}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${med['dosage'] ?? '—'} · ${med['form'] ?? '—'} · '
                            'correspondance ${high ? 'élevée' : 'moyenne'} '
                            '(${(score * 100).round()} %)'
                            '${high ? '' : ' — ⚠ vérification nécessaire'}',
                            style: const TextStyle(fontSize: 11.5)),
                      );
                    }),
                    if (_suggestions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            'Aucune correspondance sûre dans le catalogue. '
                            'Corrigez le texte ou ajoutez les médicaments '
                            'manuellement.',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        if (!_working)
          FilledButton.icon(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.of(context).pop(widget.medications
                    .where((m) => _selectedIds.contains('${m['id']}'))
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label:
                Text('Ajouter ${_selectedIds.length} ligne(s) au formulaire'),
          ),
      ],
    );
  }
}
