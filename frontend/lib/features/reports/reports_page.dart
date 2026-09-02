import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stats_tile.dart';

/// Rapports : vue financière, ventes, produits, stock et employés.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _financial;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _stock;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    final query = {'from': _iso(_from), 'to': _iso(_to)};
    final results = await Future.wait([
      ApiClient.instance
          .get<Map<String, dynamic>>('/reports/financial', query: query),
      ApiClient.instance.get<List<dynamic>>('/reports/sales', query: query),
      ApiClient.instance.get<List<dynamic>>('/reports/products',
          query: {...query, 'limit': '10'}),
      ApiClient.instance.get<List<dynamic>>('/reports/employees', query: query),
      ApiClient.instance.get<Map<String, dynamic>>('/reports/stock'),
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
    setState(() {
      _financial = results[0].data as Map<String, dynamic>?;
      _sales = (results[1].data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _products = (results[2].data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _employees = (results[3].data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _stock = results[4].data as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('reports', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: S.t('fromDate', locale),
                        border: const OutlineInputBorder(),
                      ),
                      child: Text(Fmt.shortDate(_from)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: S.t('toDate', locale),
                        border: const OutlineInputBorder(),
                      ),
                      child: Text(Fmt.shortDate(_to)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _load,
                  icon: const Icon(Icons.filter_alt),
                  tooltip: S.t('apply', locale),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _body(locale),
          ),
        ],
      ),
    );
  }

  Widget _body(String locale) {
    final fin = _financial ?? const <String, dynamic>{};
    final revenue = (fin['revenue'] is Map<String, dynamic>)
        ? fin['revenue'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final stock = _stock ?? const <String, dynamic>{};
    final value = (stock['value'] is Map<String, dynamic>)
        ? stock['value'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        SizedBox(
          height: 128,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(
                width: 160,
                child: StatsTile(
                    label: S.t('revenue', locale),
                    value: double.tryParse('${revenue['revenue'] ?? 0}') ?? 0,
                    icon: Icons.payments_outlined,
                    money: true),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: StatsTile(
                    label: S.t('expenses', locale),
                    value: double.tryParse('${fin['expenses'] ?? 0}') ?? 0,
                    icon: Icons.money_off,
                    money: true),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: StatsTile(
                    label: S.t('netProfit', locale),
                    value: double.tryParse('${fin['net_profit'] ?? 0}') ?? 0,
                    icon: Icons.trending_up,
                    money: true),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: StatsTile(
                    label: S.t('receivables', locale),
                    value: double.tryParse('${fin['receivables'] ?? 0}') ?? 0,
                    icon: Icons.account_balance_wallet_outlined,
                    money: true),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: StatsTile(
                    label: S.t('payables', locale),
                    value: double.tryParse('${fin['payables'] ?? 0}') ?? 0,
                    icon: Icons.request_quote_outlined,
                    money: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          locale,
          S.t('stockSnapshot', locale),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip(
                  S.t('stockValue', locale),
                  Fmt.money(
                      double.tryParse('${value['stock_value'] ?? 0}') ?? 0)),
              _chip(
                  S.t('stockCost', locale),
                  Fmt.money(
                      double.tryParse('${value['stock_cost'] ?? 0}') ?? 0)),
              _chip(S.t('nbProducts', locale), '${value['nb_products'] ?? 0}'),
              _chip(S.t('lowStock', locale), '${stock['low_stock'] ?? 0}'),
              _chip(S.t('expiring', locale), '${stock['expiring'] ?? 0}'),
              _chip(S.t('expired', locale), '${stock['expired'] ?? 0}'),
            ],
          ),
        ),
        _sectionCard(
          locale,
          S.t('salesReport', locale),
          _sales.isEmpty
              ? _empty(locale)
              : Column(
                  children: _sales
                      .map((s) => ListTile(
                            dense: true,
                            title: Text(Fmt.shortDate(
                                DateTime.tryParse('${s['period']}'))),
                            trailing: Text(
                                Fmt.money(
                                    double.tryParse('${s['total']}') ?? 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(
                                '${s['nb_sales']} ${S.t('nbSales', locale)} · ${Fmt.money(double.tryParse('${s['profit']}') ?? 0)} ${S.t('profit', locale)}'),
                          ))
                      .toList(),
                ),
        ),
        _sectionCard(
          locale,
          S.t('topProducts', locale),
          _products.isEmpty
              ? _empty(locale)
              : Column(
                  children: _products
                      .map((p) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${p['name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          '${p['category_name'] ?? '—'} · ${Fmt.money(double.tryParse('${p['avg_price']}') ?? 0)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${p['qty_sold']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        Fmt.money(double.tryParse(
                                                '${p['revenue']}') ??
                                            0),
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
        _sectionCard(
          locale,
          S.t('employeePerformance', locale),
          _employees.isEmpty
              ? _empty(locale)
              : Column(
                  children: _employees
                      .map((e) => ListTile(
                            dense: true,
                            title: Text('${e['first_name']} ${e['last_name']}'),
                            trailing: Text(
                                Fmt.money(
                                    double.tryParse('${e['revenue']}') ?? 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(
                                '${e['nb_sales']} ${S.t('nbSales', locale)} · ${Fmt.money(double.tryParse('${e['profit']}') ?? 0)} ${S.t('profit', locale)}'),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.dividerDark
              : Colors.white,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _sectionCard(String locale, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: BorderRadius.circular(18),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _empty(String locale) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(S.t('noResults', locale))),
      );
}
