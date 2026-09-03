import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';

/// Comptabilité : caisse, journal et dépenses.
class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _register;
  bool _registerChecked = false;
  List<Map<String, dynamic>> _journal = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? get _branchId => context.read<AuthStore>().user?.branchId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiClient.instance.get<Map<String, dynamic>>('/accounting/journal',
          query: {'limit': 100}),
      ApiClient.instance.get<Map<String, dynamic>>('/accounting/expenses',
          query: {'limit': 100}),
    ]);
    if (!mounted) return;
    final journal = results[0];
    final expenses = results[1];
    await _loadRegister();
    if (!journal.success || !expenses.success) {
      setState(() {
        _loading = false;
        _error = (journal.error ?? expenses.error)?.message;
      });
      return;
    }
    setState(() {
      _journal = (journal.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _expenses = (expenses.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _loadRegister() async {
    final branchId = _branchId;
    if (branchId == null) return;
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/accounting/registers/$branchId/open');
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _register = result.data;
        _registerChecked = true;
      });
    } else {
      setState(() {
        _register = null;
        _registerChecked = true;
      });
    }
  }

  Future<void> _openRegister() async {
    final branchId = _branchId;
    final locale = context.read<AuthStore>().locale;
    if (branchId == null) return;
    final amount = TextEditingController();
    final opened = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('openRegister', locale)),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: S.t('openingBalance', locale)),
        ),
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
    if (opened != true) return;
    await ApiClient.instance.post('/accounting/registers', body: {
      'branchId': branchId,
      'openingBalance': double.tryParse(amount.text) ?? 0,
    });
    if (mounted) _loadRegister();
  }

  Future<void> _addMovement(String type) async {
    final locale = context.read<AuthStore>().locale;
    final registerId = _register?['id'] as String?;
    if (registerId == null) return;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '${S.t('addMovement', locale)} (${type == 'in' ? 'In' : 'Out'})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: S.t('paymentAmount', locale))),
            const SizedBox(height: 12),
            TextField(
                controller: reason,
                decoration: InputDecoration(labelText: S.t('reason', locale))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (ok != true || amount.text.trim().isEmpty) return;
    await ApiClient.instance
        .post('/accounting/registers/$registerId/movements', body: {
      'movementType': type,
      'amount': double.tryParse(amount.text) ?? 0,
      'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
    });
    if (mounted) _loadRegister();
  }

  Future<void> _closeRegister() async {
    final locale = context.read<AuthStore>().locale;
    final registerId = _register?['id'] as String?;
    if (registerId == null) return;
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('closeRegister', locale)),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: S.t('countedBalance', locale)),
        ),
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
    if (ok != true) return;
    await ApiClient.instance
        .post('/accounting/registers/$registerId/close', body: {
      'countedBalance': double.tryParse(amount.text) ?? 0,
    });
    if (mounted) _loadRegister();
  }

  Future<void> _addExpense() async {
    final locale = context.read<AuthStore>().locale;
    final categoriesResult = await ApiClient.instance
        .get<List<dynamic>>('/accounting/expense-categories');
    if (!mounted) return;
    final categories =
        categoriesResult.data?.whereType<Map<String, dynamic>>().toList() ?? [];
    final amount = TextEditingController();
    final description = TextEditingController();
    String? categoryId =
        categories.isEmpty ? null : categories.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.t('newExpense', locale)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: InputDecoration(
                      labelText: S.t('expenseCategory', locale)),
                  items: categories
                      .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text('${c['name']}')))
                      .toList(),
                  onChanged: (v) => setState(() => categoryId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: S.t('paymentAmount', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: description,
                  decoration: InputDecoration(
                      labelText: S.t('expenseDescription', locale))),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('save', locale))),
          ],
        ),
      ),
    );
    if (ok != true || amount.text.trim().isEmpty) return;
    await ApiClient.instance.post('/accounting/expenses', body: {
      'categoryId': categoryId,
      'amount': double.tryParse(amount.text) ?? 0,
      'description':
          description.text.trim().isEmpty ? null : description.text.trim(),
    });
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('accounting', locale)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: S.t('cashRegister', locale)),
            Tab(text: S.t('journal', locale)),
            Tab(text: S.t('expenses', locale)),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _RegisterTab(
                      register: _register,
                      checked: _registerChecked,
                      onOpen: _openRegister,
                      onAddIn: () => _addMovement('in'),
                      onAddOut: () => _addMovement('out'),
                      onClose: _closeRegister,
                    ),
                    _JournalTab(items: _journal),
                    _ExpensesTab(items: _expenses, onAdd: _addExpense),
                  ],
                ),
    );
  }
}

class _RegisterTab extends StatelessWidget {
  final Map<String, dynamic>? register;
  final bool checked;
  final VoidCallback onOpen;
  final VoidCallback onAddIn;
  final VoidCallback onAddOut;
  final VoidCallback onClose;

  const _RegisterTab({
    required this.register,
    required this.checked,
    required this.onOpen,
    required this.onAddIn,
    required this.onAddOut,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final r = register;
    if (!checked) return const SizedBox.shrink();
    if (r == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payments_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 8),
            Text(S.t('noOpenRegister', locale)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.lock_open),
              label: Text(S.t('openRegister', locale)),
            ),
          ],
        ),
      );
    }
    final totalIn = double.tryParse('${r['total_in'] ?? 0}') ?? 0;
    final totalOut = double.tryParse('${r['total_out'] ?? 0}') ?? 0;
    final expected = double.tryParse('${r['expected_balance'] ?? 0}') ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _RegStat(
                    label: S.t('openingBalance', locale),
                    value: Fmt.money(
                        double.tryParse('${r['opening_balance'] ?? 0}') ?? 0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RegStat(
                    label: S.t('expectedBalance', locale),
                    value: Fmt.money(expected)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RegStat(
                    label: S.t('difference', locale),
                    value: Fmt.money(
                        double.tryParse('${r['difference'] ?? 0}') ?? 0),
                    color: double.tryParse('${r['difference'] ?? 0}') == 0
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddIn,
                  icon: const Icon(Icons.add, color: AppColors.success),
                  label: Text('+ ${Fmt.money(totalIn)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddOut,
                  icon: const Icon(Icons.remove, color: AppColors.danger),
                  label: Text('− ${Fmt.money(totalOut)}'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.lock),
              label: Text(S.t('closeRegister', locale)),
            ),
          ),
        ),
        Expanded(
          child: (r['movements'] as List? ?? const []).isEmpty
              ? Center(child: Text(S.t('noResults', locale)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: (r['movements'] as List).length,
                  itemBuilder: (context, i) {
                    final m =
                        (r['movements'] as List)[i] as Map<String, dynamic>;
                    final isIn =
                        ['in', 'sale'].contains('${m['movement_type']}');
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isIn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIn ? AppColors.success : AppColors.danger,
                      ),
                      title:
                          Text('${m['movement_type']} · ${m['reason'] ?? '—'}'),
                      subtitle: Text(Fmt.dateTime(
                          DateTime.tryParse('${m['created_at']}'))),
                      trailing: Text(
                        '${isIn ? '+' : '−'} ${Fmt.money(double.tryParse('${m['amount']}') ?? 0)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isIn ? AppColors.success : AppColors.danger),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RegStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _RegStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGold.withValues(alpha: 0.30)
              : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _JournalTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _JournalTab({required this.items});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (items.isEmpty) return Center(child: Text(S.t('noJournal', locale)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final debit = double.tryParse('${e['debit_total'] ?? 0}') ?? 0;
        final credit = double.tryParse('${e['credit_total'] ?? 0}') ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.receipt_long, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e['entry_number']}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${e['description'] ?? ''} · ${e['journal_type']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.money(debit > 0 ? debit : credit),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(Fmt.shortDate(DateTime.tryParse('${e['entry_date']}')),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
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

class _ExpensesTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;

  const _ExpensesTab({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final total = items.fold<double>(
        0, (sum, e) => sum + (double.tryParse('${e['amount'] ?? 0}') ?? 0));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _RegStat(
                    label: S.t('expenses', locale), value: Fmt.money(total)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(S.t('newExpense', locale)),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(S.t('noExpenses', locale)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      dense: true,
                      leading: StatusChip(
                          label: '${e['category_name'] ?? '—'}',
                          color: AppColors.warning),
                      title: Text('${e['description'] ?? '—'}'),
                      subtitle: Text(Fmt.shortDate(
                          DateTime.tryParse('${e['expense_date']}'))),
                      trailing: Text(
                          Fmt.money(double.tryParse('${e['amount']}') ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
