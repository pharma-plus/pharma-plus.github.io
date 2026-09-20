import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/barcode_scanner.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../shell/shell_nav.dart';
import '../catalog/unknown_product_dialog.dart';

/// ============================================================
/// MODULE AUDIT PHARMA+ â€” accessible via MENU > Autres modules.
/// Onglet 1 â€” Audit STOCK : stock systÃ¨me vs stock physique,
///            Ã©cart + valeur de l'Ã©cart. AUCUNE correction auto :
///            le pharmacien valide explicitement (inventory:approve).
/// Onglet 2 â€” Audit CAISSE : attendu (paiements rÃ©els du jour)
///            vs comptÃ©, Ã©cart, historique. Aucune Ã©criture auto.
/// ============================================================
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('audit', locale)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Audit stock'), Tab(text: 'Audit caisse')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [
        StockAuditTab(),
        CashAuditTab(),
      ]),
    );
  }
}

/* ==================== AUDIT STOCK ==================== */

class StockAuditTab extends StatefulWidget {
  const StockAuditTab({super.key});

  @override
  State<StockAuditTab> createState() => _StockAuditTabState();
}

class _StockAuditTabState extends State<StockAuditTab> {
  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _openSession;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _lastScannedCode;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _openSession = null;
      _items = [];
    });
    final results = await Future.wait([
      ApiClient.instance.get('/branches'),
      ApiClient.instance.get('/inventory/sessions',
          query: {'limit': 20, 'status': 'open'}),
    ]);
    if (!mounted) return;
    if (!results[0].success || !results[1].success) {
      setState(() {
        _loading = false;
        _error = (results[0].error ?? results[1].error)?.message;
      });
      return;
    }
    final sessions = ApiList.of(results[1].data);
    setState(() {
      _branches = ApiList.of(results[0].data);
      _loading = false;
    });
    if (sessions.isNotEmpty) {
      await _open('${sessions.first['id']}');
    }
  }

  Future<void> _open(String sessionId) async {
    final r = await ApiClient.instance.get('/inventory/sessions/$sessionId');
    if (!mounted || !r.success) return;
    final d = r.data;
    setState(() {
      _openSession = d is Map<String, dynamic> ? d : null;
      _items = ApiList.of(d?['items']);
    });
  }

  Future<void> _startSession() async {
    if (_branches.isEmpty || _busy) return;
    final branchId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Succursale Ã  auditer'),
        children: [
          for (final b in _branches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, '${b['id']}'),
              child: Text('${b['name']}'),
            ),
        ],
      ),
    );
    if (branchId == null) return;
    setState(() => _busy = true);
    final r = await ApiClient.instance.post('/inventory/sessions',
        body: {'branchId': branchId});
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.success) {
      final locale = context.read<AuthStore>().locale;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? S.t('loadError', locale))));
      return;
    }
    await _load();
    await _open('${r.data?['id']}');
  }

  /// Scan rÃ©el (mode simple) : identifie le produit, incrÃ©mente sa quantitÃ© comptÃ©e.
  Future<void> _scan() async {
    final result = await BarcodeScannerSheet.show(context,
        title: 'Scanner produit (audit)');
    if (result == null || !mounted) return;
    await _processScan(result);
  }

  /// SCAN CONTINU : l'Ã©cran camÃ©ra reste ouvert, chaque lecture compte +1
  /// sur la ligne correspondante (inventaire de rayon entier sans interruption).
  Future<void> _scanContinuous() async {
    await BarcodeScannerSheet.showContinuous(context,
        title: 'Scan continu (audit)',
        onScan: (result) => _processScan(result, continuous: true));
    if (!mounted) return;
    await _open('${_openSession?['id']}'); // rafraÃ®chir les compteurs
  }

  /// Traitement d'une lecture de scan (mode simple ou continu).
  /// Anti-doublon : un mÃªme code ignorÃ© s'il est rescannÃ© < 1.2 s.
  Future<void> _processScan(ScanResult result, {bool continuous = false}) async {
    final code = result.lookupCode;
    if (code.isEmpty || !mounted) return;
    final now = DateTime.now();
    if (code == _lastScannedCode &&
        now.difference(_lastScanAt).inMilliseconds < 1200) {
      if (!continuous) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Scan identique ignorÃ© (protection anti-doublon)')));
      }
      return;
    }
    _lastScannedCode = code;
    _lastScanAt = now;

    // Recherche du produit dans la base PHARMA+ (base centrale unique).
    final lookup = await ApiClient.instance
        .get('/catalog/medications/barcode/${Uri.encodeComponent(code)}');
    if (!mounted) return;
    if (!lookup.success || lookup.data == null) {
      // Produit inconnu : JAMAIS de crÃ©ation automatique (anti-doublon).
      if (continuous) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Produit non reconnu ($code) â€” utilisez le scan simple '
                'pour le crÃ©er ou l\u2019associer.')));
      } else {
        await _showUnknownProductDialog(code);
      }
      return;
    }
    final med = lookup.data;
    final rows = _items
        .where((it) => '${it['medication_id']}' == '${med['id']}')
        .toList();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Produit trouvÃ© (${med['name']}) mais absent de la session d\'audit en cours.')));
      return;
    }
    final row = rows.first;
    final newQty = _num(row['counted_qty']) + 1;
    final r = await ApiClient.instance.post(
      '/inventory/sessions/${row['session_id']}/count',
      body: {'itemId': row['id'], 'countedQty': newQty},
    );
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${med['name']} â€” comptÃ© : $newQty')));
      // En mode continu, mise Ã  jour locale immÃ©diate (pas de reload complet).
      if (continuous) {
        setState(() => row['counted_qty'] = newQty);
      } else {
        await _open('${row['session_id']}');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? 'Erreur de comptage')));
    }
  }

  /// Produit NON TROUVÃ‰ : module unifiÃ© (rechercher / associer / crÃ©er /
  /// annuler â€” jamais de doublon automatique).
  Future<void> _showUnknownProductDialog(String code) async {
    final med = await showUnknownProductDialog(context, barcode: code);
    if (!mounted) return;
    if (med != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Â« ${med['name']} Â» ${med['barcode_ean13'] != null ? 'associÃ© au code ${med['barcode_ean13']}' : 'crÃ©Ã©'} â€” '
              'relancez le scan pour le compter.')));
    }
  }

  /// Validation du pharmacien : corrige les Ã©carts via de VRAIS mouvements.
  Future<void> _validate() async {
    final session = _openSession;
    if (session == null || _busy) return;
    final locale = context.read<AuthStore>().locale;
    final gaps = _items.where((it) => _num(it['gap']) != 0).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider la correction du stock ?'),
        content: Text(
            '$gaps Ã©cart(s) dÃ©tectÃ©(s). Des mouvements rÃ©els (entrÃ©e/sortie) '
            'seront enregistrÃ©s pour chaque Ã©cart. Le stock ne sera modifiÃ© '
            'qu\'aprÃ¨s cette validation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('confirm', locale))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final r = await ApiClient.instance
        .post('/inventory/sessions/${session['id']}/close', body: {});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Audit validÃ© â€” ${r.data?['corrections'] ?? 0} correction(s) enregistrÃ©e(s)')));
      setState(() {
        _openSession = null;
        _items = [];
      });
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? 'Erreur de validation')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(S.t('retry', locale))),
        ]),
      );
    }
    if (_openSession == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fact_check_outlined,
              size: 54, color: AppColors.pharmaGold),
          const SizedBox(height: 12),
          const Text('Aucun audit de stock en cours',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Comparez le stock systÃ¨me au stock physique.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5)),
          const SizedBox(height: 16),
          GradientButton(
              label: 'DÃ©marrer un inventaire',
              icon: Icons.play_arrow_rounded,
              loading: _busy,
              onPressed: _startSession),
        ]),
      );
    }
    final gaps = _items.where((it) => _num(it['gap']) != 0).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(children: [
          Expanded(
            child: Text(
              '${_openSession?['branch_name'] ?? ''} Â· '
              '${_items.length} produits Â· $gaps Ã©cart(s)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
              tooltip: 'Scan continu (audit)',
              onPressed: _scanContinuous,
              icon: const Icon(Icons.all_inclusive_rounded,
                  color: AppColors.pharmaGold)),
          IconButton(
              tooltip: 'Scanner produit',
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.pharmaGold)),
          IconButton(
              tooltip: S.t('refresh', locale),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Expanded(child: _buildList(locale)),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GradientButton(
            label: 'Valider la correction du stock',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _validate,
          ),
        ),
      ),
    ]);
  }

  Widget _buildList(String locale) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final it = _items[i];
        final sys = _num(it['system_qty']);
        final counted = _num(it['counted_qty']);
        final gap = counted - sys;
        final isInt = counted.truncateToDouble() == counted;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${it['medication_name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          'Lot ${it['lot_number'] ?? 'â€”'} Â· SystÃ¨me : ${Fmt.number(sys)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.55))),
                    ]),
              ),
              SizedBox(
                width: 86,
                child: TextFormField(
                  initialValue: Fmt.number(counted, decimals: isInt ? 0 : 2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      labelText: 'Physique', isDense: true),
                  onFieldSubmitted: (v) async {
                    final q = double.tryParse(v.replaceAll(',', '.'));
                    if (q == null) return;
                    final r = await ApiClient.instance.post(
                      '/inventory/sessions/${it['session_id']}/count',
                      body: {'itemId': it['id'], 'countedQty': q},
                    );
                    if (mounted && r.success) {
                      await _open('${it['session_id']}');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              _GapChip(gap: gap, gapValue: _num(it['gap_value'])),
            ]),
          ),
        );
      },
    );
  }
}

class _GapChip extends StatelessWidget {
  final double gap;
  final double gapValue;
  const _GapChip({required this.gap, required this.gapValue});

  @override
  Widget build(BuildContext context) {
    final isInt = gap.truncateToDouble() == gap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          gap == 0
              ? 'Ã‰gal'
              : 'Ã‰cart ${gap > 0 ? '+' : ''}${Fmt.number(gap, decimals: isInt ? 0 : 2)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: gap == 0
                ? AppColors.success
                : (gap > 0 ? AppColors.warning : AppColors.danger),
          ),
        ),
        if (gap != 0)
          Text(Fmt.money(gapValue),
              style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      ],
    );
  }
}

/* ==================== AUDIT CAISSE ==================== */

class CashAuditTab extends StatefulWidget {
  const CashAuditTab({super.key});

  @override
  State<CashAuditTab> createState() => _CashAuditTabState();
}

class _CashAuditTabState extends State<CashAuditTab> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _expected;
  String? _branchId;
  final _counted = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiClient.instance.get('/branches'),
      ApiClient.instance.get('/inventory/cash-audits'),
      ApiClient.instance.get('/inventory/cash-expected'),
    ]);
    if (!mounted) return;
    final failures = results.where((r) => !r.success).toList();
    if (failures.isNotEmpty) {
      setState(() {
        _loading = false;
        _error = failures.first.error?.message;
      });
      return;
    }
    final branches = ApiList.of(results[0].data);
    setState(() {
      _branches = branches;
      _history = ApiList.of(results[1].data);
      _expected = results[2].data is Map
          ? Map<String, dynamic>.from(results[2].data as Map)
          : null;
      _branchId ??= branches.isNotEmpty ? '${branches.first['id']}' : null;
      _loading = false;
    });
  }

  double get _expectedCash => _num(_expected?['paymentsCash']);

  double get _countedValue =>
      double.tryParse(_counted.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (_branchId == null || _busy) return;
    final locale = context.read<AuthStore>().locale;
    setState(() => _busy = true);
    final r = await ApiClient.instance.post('/inventory/cash-audits', body: {
      'branchId': _branchId,
      'expectedCash': _expectedCash,
      'countedCash': _countedValue,
      'salesTotal': _num(_expected?['salesTotal']),
      'paymentsCash': _num(_expected?['paymentsCash']),
      'paymentsCard': _num(_expected?['paymentsCard']),
      'paymentsOther': _num(_expected?['paymentsOther']),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Audit caisse enregistrÃ© â€” Ã©cart : ${Fmt.money(_num(r.data?['difference']))} MAD')));
      _counted.clear();
      _notes.clear();
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.readableMessage ?? S.t('loadError', locale))));
    }
  }

  Widget _cashRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: Colors.white.withValues(alpha: bold ? 1 : 0.7))),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(S.t('retry', locale))),
        ]),
      );
    }
    final diff = _countedValue - _expectedCash;
    return _CashAuditView(
        locale: locale,
        branches: _branches,
        history: _history,
        expected: _expected,
        branchId: _branchId,
        counted: _counted,
        notes: _notes,
        busy: _busy,
        diff: diff,
        expectedCash: _expectedCash,
        cashRow: _cashRow,
        onBranch: (v) => setState(() => _branchId = v),
        onCounted: (_) => setState(() {}),
        onSave: _save);
  }
}

/* ==================== VUE CAISSE ==================== */

class _CashAuditView extends StatelessWidget {
  final String locale;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? expected;
  final String? branchId;
  final TextEditingController counted;
  final TextEditingController notes;
  final bool busy;
  final double diff;
  final double expectedCash;
  final Widget Function(String, String, {bool bold}) cashRow;
  final ValueChanged<String?> onBranch;
  final ValueChanged<String> onCounted;
  final VoidCallback onSave;

  const _CashAuditView({
    required this.locale,
    required this.branches,
    required this.history,
    required this.expected,
    required this.branchId,
    required this.counted,
    required this.notes,
    required this.busy,
    required this.diff,
    required this.expectedCash,
    required this.cashRow,
    required this.onBranch,
    required this.onCounted,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            radius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ContrÃ´le de caisse du jour',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      'Attendu calculÃ© sur les VRAIS paiements enregistrÃ©s '
                      '(aucune Ã©criture financiÃ¨re modifiÃ©e).',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.55))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: const InputDecoration(labelText: 'Succursale'),
                    items: branches
                        .map((b) => DropdownMenuItem(
                            value: '${b['id']}', child: Text('${b['name']}')))
                        .toList(),
                    onChanged: onBranch,
                  ),
                  const SizedBox(height: 10),
                  cashRow('Ventes systÃ¨me',
                      Fmt.money(double.tryParse('${expected?['salesTotal']}') ?? 0)),
                  cashRow('Paiements espÃ¨ces',
                      Fmt.money(double.tryParse('${expected?['paymentsCash']}') ?? 0)),
                  cashRow('Paiements carte',
                      Fmt.money(double.tryParse('${expected?['paymentsCard']}') ?? 0)),
                  cashRow('Autres paiements',
                      Fmt.money(double.tryParse('${expected?['paymentsOther']}') ?? 0)),
                  cashRow('CAISSE SYSTÃˆME (attendu espÃ¨ces)',
                      Fmt.money(expectedCash),
                      bold: true),
                  const SizedBox(height: 10),
                  TextField(
                    controller: counted,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Montant rÃ©ellement comptÃ© (MAD)'),
                    onChanged: onCounted,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ã‰CART',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '${diff >= 0 ? '+' : ''}${Fmt.money(diff)} MAD',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: diff == 0
                                ? AppColors.success
                                : (diff > 0
                                    ? AppColors.warning
                                    : AppColors.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optionnel)'),
                  ),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: 'Enregistrer l\u2019audit caisse',
                    icon: Icons.save_rounded,
                    loading: busy,
                    onPressed: counted.text.trim().isEmpty ? null : onSave,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HistoryList(history: history),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Historique des audits caisse',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Text('Aucun audit enregistrÃ©',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5)))),
          )
        else
          ...history.map((h) {
            final d = double.tryParse('${h['difference']}') ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                radius: BorderRadius.circular(14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${h['branch_name'] ?? ''} Â· ${Fmt.shortDate(DateTime.tryParse('${h['audit_date']}'))}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      'Attendu : ${Fmt.money(double.tryParse('${h['expected_cash']}') ?? 0)} Â· '
                      'ComptÃ© : ${Fmt.money(double.tryParse('${h['counted_cash']}') ?? 0)}'
                      '${'${h['user_name'] ?? ''}'.isNotEmpty ? ' Â· ${h['user_name']}' : ''}'),
                  trailing: Text('${d >= 0 ? '+' : ''}${Fmt.money(d)} MAD',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: d == 0
                              ? AppColors.success
                              : (d > 0
                                  ? AppColors.warning
                                  : AppColors.danger))),
                ),
              ),
            );
          }),
      ],
    );
  }
}

