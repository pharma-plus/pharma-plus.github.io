// PHARMA+ — INVENTAIRE PHYSIQUE (phases 14-16).
// STOCK SYSTÈME + COMPTAGE PHYSIQUE : ÉCART = PHYSIQUE − SYSTÈME.
// Le comptage ne modifie PAS le stock système : seule la validation
// pharmacien (POST close) génère les mouvements de correction.
// Scan smartphone/tablette supporté (moteur ZXing / mobile_scanner).
library;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/services/api_client.dart';
import '../../core/widgets/barcode_scanner.dart' as scanner;
import '../../core/theme/colors.dart';
import '../shell/shell_nav.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _loading = true;
  List<dynamic> _sessions = [];
  Map<String, dynamic>? _detail;
  String? _error;

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
    final r = await ApiClient.instance.get('/inventory/sessions');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) {
        _sessions = (r.data is List) ? (r.data as List) : [];
      } else {
        _error = r.error?.readableMessage ?? 'Erreur de chargement';
      }
    });
  }

  Future<void> _newSession() async {
    // Choix de la succursale (l'inventaire est par succursale).
    final br = await ApiClient.instance.get('/branches');
    final branches = (br.success && br.data is List)
        ? (br.data as List).whereType<Map>().toList()
        : <Map>[];
    if (!mounted) return;
    String? branchId;
    if (branches.length == 1) {
      branchId = '${branches.first['id']}';
    } else if (branches.length > 1) {
      branchId = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          backgroundColor: AppColors.pharmaSurface,
          title: const Text('Succursale',
              style: TextStyle(color: Colors.white)),
          children: branches
              .map((b) => SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(context, '${b['id']}'),
                    child: Text('${b['name'] ?? b['code']}',
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
        ),
      );
    }
    if (branchId == null || branchId.isEmpty) return;
    final r = await ApiClient.instance.post('/inventory/sessions', body: {
      'branchId': branchId,
      'withItems': true,
    });
    if (!mounted) return;
    if (r.success) {
      final id = (r.data as Map)['id'] as String;
      await _openDetail(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? 'Échec'),
          backgroundColor: AppColors.danger));
    }
  }

  Future<void> _openDetail(String id) async {
    final r = await ApiClient.instance.get('/inventory/sessions/$id');
    if (!mounted) return;
    if (r.success && r.data is Map) {
      setState(() => _detail = Map<String, dynamic>.from(r.data as Map));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? 'Erreur'),
          backgroundColor: AppColors.danger));
    }
  }

  Future<void> _setCount(Map<String, dynamic> item, double qty) async {
    final sessionId = _detail!['id'] as String;
    final r = await ApiClient.instance
        .post('/inventory/sessions/$sessionId/count', body: {
      'itemId': item['id'],
      'countedQty': qty,
    });
    if (r.success && mounted) {
      setState(() {
        final items = (_detail!['items'] as List)
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : e)
            .toList();
        for (final it in items) {
          if (it is Map<String, dynamic> && it['id'] == item['id']) {
            it['counted_qty'] = qty;
            it['gap'] = qty - (it['system_qty'] as num? ?? 0);
          }
        }
        _detail = {..._detail!, 'items': items};
      });
    }
  }

  Future<void> _scanCount() async {
    final r = await scanner.BarcodeScannerSheet.show(
      context,
      title: 'Scanner un médicament à compter',
    );
    if (r == null || _detail == null) return;
    final code = r.lookupCode;
    final items = (_detail!['items'] as List)
        .whereType<Map>()
        .where((i) =>
            '${i['medications']?['barcode_ean13'] ?? ''}' == code)
        .toList();
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Produit non référencé dans cet inventaire : $code'),
          backgroundColor: AppColors.warning));
      return;
    }
    await _countDialog(Map<String, dynamic>.from(items.first));
  }

  Future<void> _countDialog(Map<String, dynamic> item) async {
    final name = (item['medication_name'] ??
            item['medications']?['name'] ??
            'Produit') as String;
    final systemQty = (item['system_qty'] as num?)?.toDouble() ?? 0;
    final counted = TextEditingController(
        text: '${(item['counted_qty'] as num?) ?? systemQty}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.pharmaSurface,
        title: Text(name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock système : $systemQty',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: counted,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Quantité physique'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    await _setCount(item, double.tryParse(counted.text) ?? 0);
  }

  Future<void> _validate() async {
    final sessionId = _detail!['id'] as String;
    final r = await ApiClient.instance
        .post('/inventory/sessions/$sessionId/close', body: {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r.success
          ? 'Inventaire validé · corrections : ${r.data?['corrections']}'
          : (r.error?.readableMessage ?? 'Échec de validation')),
      backgroundColor: r.success ? AppColors.success : AppColors.danger,
    ));
    if (r.success) {
      setState(() => _detail = null);
      await _load();
    }
  }

  Future<void> _exportPdf() async {
    final d = _detail!;
    final items = (d['items'] as List).whereType<Map>().toList();
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('INVENTAIRE PHYSIQUE — ${d['branch_name'] ?? ''}',
            style:
                const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('Session ${d['id']} · ${d['started_at']} · ${d['status']}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Médicament', 'Lot', 'Système', 'Physique', 'Écart'],
          data: items
              .map((i) => [
                    '${i['medication_name'] ?? ''}',
                    '${i['lot_number'] ?? '-'}',
                    '${i['system_qty'] ?? 0}',
                    '${i['counted_qty'] ?? 0}',
                    (((i['gap'] as num?) ?? 0) > 0)
                        ? '+${i['gap']}'
                        : '${i['gap'] ?? 0}',
                  ])
              .toList(),
          headerStyle:
              const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) return _buildDetail();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Inventaire physique'),
        actions: [
          IconButton(
              tooltip: 'Nouvelle session',
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Color(0xFFE9C873)),
              onPressed: _newSession),
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE9C873)))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white70)))
              : _sessions.isEmpty
                  ? const Center(
                      child: Text('Aucun inventaire. Démarrez une session.',
                          style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _sessions.length,
                      itemBuilder: (context, i) {
                        final s = _sessions[i] as Map;
                        return Card(
                          color: AppColors.pharmaSurface,
                          child: ListTile(
                            title: Text(
                                '${s['branches']?['name'] ?? ''} · ${s['status']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text('${s['started_at'] ?? ''}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFE9C873)),
                            onTap: () => _openDetail(s['id'] as String),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildDetail() {
    final items = (_detail!['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final open = _detail!['status'] == 'open';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _detail = null)),
        title: Text('Inventaire · ${_detail!['branch_name'] ?? ''}'),
        actions: [
          IconButton(
              tooltip: 'Scanner pour compter',
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: Color(0xFFE9C873)),
              onPressed: open ? _scanCount : null),
          IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: items.isEmpty ? null : _exportPdf),
          if (open)
            IconButton(
              tooltip: 'Valider les ajustements',
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF43D97C)),
              onPressed: _validate,
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('Aucun article (stock vide)',
                  style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                final gap = (it['gap'] as num?) ?? 0;
                final gapColor = gap == 0
                    ? Colors.white70
                    : gap > 0
                        ? const Color(0xFF43D97C)
                        : AppColors.danger;
                return Card(
                  color: AppColors.pharmaSurface,
                  child: ListTile(
                    title: Text('${it['medication_name'] ?? 'Produit'}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                        'Système : ${it['system_qty']} · Physique : ${it['counted_qty']}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    trailing: Text(
                      gap > 0 ? '+$gap' : '$gap',
                      style: TextStyle(
                          color: gapColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    onTap: open ? () => _countDialog(it) : null,
                  ),
                );
              },
            ),
    );
  }
}

