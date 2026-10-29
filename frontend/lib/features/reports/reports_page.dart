import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/download_file.dart';
import '../../core/services/report_export.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stats_tile.dart';
import '../shell/shell_nav.dart';

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
      ApiClient.instance.get('/reports/financial', query: query),
      ApiClient.instance.get('/reports/sales', query: query),
      ApiClient.instance
          .get('/reports/products', query: {...query, 'limit': '10'}),
      ApiClient.instance.get('/reports/employees', query: query),
      ApiClient.instance.get('/reports/stock'),
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
      final fd = results[0].data;
      _financial = fd is Map<String, dynamic>
          ? fd
          : (fd is Map ? Map<String, dynamic>.from(fd) : null);
      _sales = ApiList.of(results[1].data);
      _products = ApiList.of(results[2].data);
      _employees = ApiList.of(results[3].data);
      final sd = results[4].data;
      _stock = sd is Map<String, dynamic>
          ? sd
          : (sd is Map ? Map<String, dynamic>.from(sd) : null);
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

  // ============================================================
  // EXPORTS — PDF · Excel (CSV) · Word (.doc)
  // ============================================================
  String get _periodLabel =>
      'Période : ${Fmt.shortDate(_from)} → ${Fmt.shortDate(_to)}';

  List<Map<String, dynamic>> _exportSections() {
    final fin = _financial ?? const <String, dynamic>{};
    final revenue = (fin['revenue'] is Map<String, dynamic>)
        ? fin['revenue'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final stock = _stock ?? const <String, dynamic>{};
    final value = (stock['value'] is Map<String, dynamic>)
        ? stock['value'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return [
      ReportExport.section('Synthèse financière', [
        'Indicateur',
        'Montant'
      ], [
        ['CA période', ReportExport.numStr(revenue['revenue'])],
        ['Dépenses', ReportExport.numStr(fin['expenses'])],
        ['Bénéfice net', ReportExport.numStr(fin['net_profit'])],
        ['Créances', ReportExport.numStr(fin['receivables'])],
        ['Dettes', ReportExport.numStr(fin['payables'])],
      ]),
      ReportExport.section('Instantané stock', [
        'Indicateur',
        'Valeur'
      ], [
        ['Valeur du stock', ReportExport.numStr(value['stock_value'])],
        ['Coût du stock', ReportExport.numStr(value['stock_cost'])],
        ['Nb produits', '${value['nb_products'] ?? 0}'],
        ['Stock faible', '${stock['low_stock'] ?? 0}'],
        ['Péremptions proches', '${stock['expiring'] ?? 0}'],
        ['Périmés', '${stock['expired'] ?? 0}'],
      ]),
      ReportExport.section(
          'Ventes',
          ['Période', 'Nb ventes', 'Total', 'Bénéfice'],
          _sales
              .map((s) => [
                    '${s['period'] ?? ''}',
                    '${s['nb_sales'] ?? 0}',
                    ReportExport.numStr(s['total']),
                    ReportExport.numStr(s['profit']),
                  ])
              .toList()),
      ReportExport.section(
          'Top produits',
          ['Produit', 'Catégorie', 'Qté vendue', 'CA'],
          _products
              .map((p) => [
                    '${p['name'] ?? ''}',
                    '${p['category_name'] ?? '—'}',
                    '${p['qty_sold'] ?? 0}',
                    ReportExport.numStr(p['revenue']),
                  ])
              .toList()),
      ReportExport.section(
          'Employés',
          ['Nom', 'Nb ventes', 'CA', 'Bénéfice'],
          _employees
              .map((e) => [
                    '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}',
                    '${e['nb_sales'] ?? 0}',
                    ReportExport.numStr(e['revenue']),
                    ReportExport.numStr(e['profit']),
                  ])
              .toList()),
    ];
  }

  Future<void> _export(String fmt) async {
    if (fmt != 'pdf' && !downloadSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Export ${fmt.toUpperCase()} indisponible sur cet appareil — utilisez le PDF ou PHARMA+ sur le web.',
        ),
        backgroundColor: const Color(0xFF6B7280),
      ));
      return;
    }
    final sections = _exportSections();
    try {
      switch (fmt) {
        case 'pdf':
          await ReportExport.exportPdf('Rapports', sections, _periodLabel);
          break;
        case 'csv':
          ReportExport.exportCsv('Rapports', sections);
          break;
        case 'doc':
          ReportExport.exportDoc('Rapports', sections, _periodLabel);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export ${fmt.toUpperCase()} impossible : $e'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    if (!mounted) return;
    final saved = lastSavedPath;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved != null && saved.isNotEmpty
          ? 'Export ${fmt.toUpperCase()} enregistré : $saved'
          : 'Export ${fmt.toUpperCase()} généré'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('reports', locale)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exporter',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (fmt) => _export(fmt),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Exporter en PDF')),
              PopupMenuItem(
                  value: 'csv', child: Text('Exporter en Excel (CSV)')),
              PopupMenuItem(
                  value: 'doc', child: Text('Exporter en Word (.doc)')),
            ],
          ),
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
        _financialCharts(fin, revenue, locale),
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

  Widget _financialCharts(
      Map<String, dynamic> fin, Map<String, dynamic> revenue, String locale) {
    final revenueValue = double.tryParse('${revenue['revenue'] ?? 0}') ?? 0;
    final expensesValue = double.tryParse('${fin['expenses'] ?? 0}') ?? 0;
    final netValue = double.tryParse('${fin['net_profit'] ?? 0}') ?? 0;
    final periods = _sales.take(6).toList();
    final profitValues = periods
        .map((s) => double.tryParse('${s['profit'] ?? 0}') ?? 0)
        .toList();
    return _sectionCard(
      locale,
      'Analyse financière',
      LayoutBuilder(builder: (context, constraints) {
        final bars = _ReportChartCard(
          title: 'Bénéfice par période',
          painter: _ReportBarsPainter(
            values: profitValues,
            labels: periods
                .map((s) => '${s['period'] ?? ''}'
                    .substring(0, '${s['period'] ?? ''}'.length.clamp(0, 7)))
                .toList(),
            color: AppColors.emerald,
          ),
        );
        final donut = _ReportChartCard(
          title: 'Répartition financière',
          painter: _ReportDonutPainter(
            values: [
              revenueValue < 0 ? 0 : revenueValue,
              expensesValue < 0 ? 0 : expensesValue
            ],
            labels: const ['CA', 'Dépenses'],
            colors: const [AppColors.chart, AppColors.warning],
          ),
        );
        final margin = revenueValue == 0 ? null : netValue / revenueValue * 100;
        final charts = constraints.maxWidth >= 700
            ? Row(children: [
                Expanded(child: bars),
                const SizedBox(width: 12),
                Expanded(child: donut),
              ])
            : Column(children: [bars, const SizedBox(height: 10), donut]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          charts,
          if (margin != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                  'Marge calculée sur le bénéfice net : ${margin.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ]);
      }),
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
              ? AppColors.brandGold.withValues(alpha: 0.30)
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

class _ReportChartCard extends StatelessWidget {
  final String title;
  final CustomPainter painter;

  const _ReportChartCard({required this.title, required this.painter});

  @override
  Widget build(BuildContext context) => Container(
        height: 170,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: .52),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Expanded(
              child: CustomPaint(
                  painter: painter, child: const SizedBox.expand())),
        ]),
      );
}

class _ReportBarsPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  const _ReportBarsPainter(
      {required this.values, required this.labels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final max = maxValue <= 0 ? 1.0 : maxValue;
    final slot = size.width / values.length;
    final base = size.height - 20;
    for (var i = 0; i < values.length; i++) {
      final h = (values[i] / max) * (size.height - 30);
      final rect =
          Rect.fromLTWH(i * slot + slot * .18, base - h, slot * .48, h);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  rect.left + 4, rect.top + 4, rect.width, rect.height),
              const Radius.circular(4)),
          Paint()..color = color.withValues(alpha: .20));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = color);
      final label = labels.length > i ? labels[i] : '';
      final text = TextPainter(
          text: TextSpan(
              text: label,
              style: const TextStyle(fontSize: 8, color: Colors.grey)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: slot);
      text.paint(canvas, Offset(i * slot + (slot - text.width) / 2, base + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ReportBarsPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _ReportDonutPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;

  const _ReportDonutPainter({
    required this.values,
    required this.labels,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    final center = Offset(size.width * .28, size.height / 2);
    final radius = size.height * .32;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = Colors.grey.withValues(alpha: .15);
    canvas.drawCircle(center, radius, base);
    if (total <= 0) return;
    var start = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.28318;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..color = colors[i]);
      start += sweep;
      final y = 25.0 + i * 25;
      canvas.drawCircle(
          Offset(size.width * .58, y + 5), 4, Paint()..color = colors[i]);
      TextPainter(
          text: TextSpan(
              text: '${labels[i]} ${values[i].toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: size.width * .38)
        ..paint(canvas, Offset(size.width * .58 + 8, y));
    }
  }

  @override
  bool shouldRepaint(covariant _ReportDonutPainter oldDelegate) =>
      oldDelegate.values != values;
}
