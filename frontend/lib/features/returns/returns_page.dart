import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../shell/shell_nav.dart';

/// ============================================================
/// RETOURS PHARMA+ — enregistrement de retours produits.
/// · Recherche d'une vente RÉELLE (GET /sales).
/// · Demande de retour : quantités ≤ quantités vendues, motif,
///   type (remboursement / échange / avoir) → POST /sales/returns.
/// · Le mouvement de stock (sale_return) et l'utilisateur + la date
///   sont enregistrés par l'API existante ; accès gated par la
///   permission `sales:create` (validation pharmacien).
/// ============================================================
class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
  List<Map<String, dynamic>> _sales = [];
  bool _loading = true;
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
    final r = await ApiClient.instance.get('/sales', query: {
      'limit': 30,
      'status': 'completed',
      if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.success) {
        _error = r.error?.message;
      } else {
        _sales = ApiList.of(r.data);
      }
    });
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  void _openReturn(Map<String, dynamic> sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReturnForm(sale: sale),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final user = context.watch<AuthStore>().user;
    final canReturn = user?.hasPermission('sales:create') ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Retours'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'N° de vente ou client…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh), onPressed: _load),
            ),
          ),
        ),
        if (!canReturn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GlassCard(
              radius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                    'Consultation seule : l\u2019enregistrement d\u2019un retour '
                    'nécessite la permission du pharmacien (sales:create).',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        Expanded(child: _buildList(locale, canReturn)),
      ]),
    );
  }

  Widget _buildList(String locale, bool canReturn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: Text(S.t('retry', locale))),
        ]),
      );
    }
    if (_sales.isEmpty) {
      return Center(
          child: Text('Aucune vente trouvée',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55))));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _sales.length,
      itemBuilder: (context, i) {
        final s = _sales[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            onTap: canReturn ? () => _openReturn(s) : null,
            radius: BorderRadius.circular(14),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                  '${s['number'] ?? s['id']} · ${Fmt.money(_num(s['total']))}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${s['customer_name'] ?? 'Client comptoir'} · '
                  '${Fmt.shortDate(DateTime.tryParse('${s['sale_date']}'))}'),
              trailing: canReturn
                  ? const Icon(Icons.keyboard_return,
                      color: AppColors.pharmaGold)
                  : const Icon(Icons.lock_outline,
                      size: 18, color: Colors.white38),
            ),
          ),
        );
      },
    );
  }
}

class _ReturnForm extends StatefulWidget {
  final Map<String, dynamic> sale;
  const _ReturnForm({required this.sale});

  @override
  State<_ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends State<_ReturnForm> {
  List<Map<String, dynamic>> _items = [];
  final Map<String, TextEditingController> _qty = {};
  final _reason = TextEditingController();
  String _returnType = 'refund';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    final r = await ApiClient.instance.get('/sales/${widget.sale['id']}');
    if (!mounted) return;
    if (!r.success) {
      setState(() {
        _loading = false;
        _error = r.error?.message;
      });
      return;
    }
    final d = r.data;
    setState(() {
      _items = ApiList.of(d?['items']);
      _loading = false;
    });
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;

  Future<void> _submit() async {
    if (_saving) return;
    final locale = context.read<AuthStore>().locale;
    final payload = <Map<String, dynamic>>[];
    for (final it in _items) {
      final q = double.tryParse(_qty['${it['id']}']?.text ?? '') ?? 0;
      if (q <= 0) continue;
      payload.add({'medication_id': it['medication_id'], 'quantity': q});
    }
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Indiquez au moins une quantité à retourner')));
      return;
    }
    setState(() => _saving = true);
    final r = await ApiClient.instance.post('/sales/returns', body: {
      'saleId': widget.sale['id'],
      'branchId': widget.sale['branch_id'],
      'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      'returnType': _returnType,
      'items': payload,
    });
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Retour enregistré — mouvement de stock créé')));
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error?.readableMessage ?? S.t('loadError', locale))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_loading)
              const CircularProgressIndicator()
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.white70))
            else
              ..._items.map((it) {
                final sold = _num(it['quantity']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: Text('${it['medication_name'] ?? it['name'] ?? '—'}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('vendu ${Fmt.number(sold)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _qty.putIfAbsent(
                            '${it['id']}', () => TextEditingController()),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                            labelText: 'Retour', isDense: true),
                      ),
                    ),
                  ]),
                );
              }),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _returnType,
              decoration: const InputDecoration(labelText: 'Type de retour'),
              items: const [
                DropdownMenuItem(value: 'refund', child: Text('Remboursement')),
                DropdownMenuItem(value: 'exchange', child: Text('Échange')),
                DropdownMenuItem(value: 'credit', child: Text('Avoir')),
              ],
              onChanged: (v) => setState(() => _returnType = v ?? 'refund'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              decoration:
                  const InputDecoration(labelText: 'Motif (optionnel)'),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: S.t('confirm', locale),
              icon: Icons.keyboard_return,
              loading: _saving,
              onPressed: _submit,
            ),
          ]),
        ),
      ),
    );
  }
}
