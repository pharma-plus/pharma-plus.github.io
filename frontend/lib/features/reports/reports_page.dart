import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
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
    final profitLabels = profitValues.map((v) => Fmt.money(v)).toList();

    return _sectionCard(
      locale,
      'Analyse financière 3D',
      LayoutBuilder(builder: (context, constraints) {
        final bars = _ReportChartCard(
          title: 'Bénéfice par période (3D)',
          painter: _BenefitBars3DPainter(
            values: profitValues,
            labels: periods
                .map((s) => '${s['period'] ?? ''}'
                    .substring(0, '${s['period'] ?? ''}'.length.clamp(0, 7)))
                .toList(),
            valueLabels: profitLabels,
            color: AppColors.emerald,
          ),
        );
        final donut = _ReportChartCard(
          title: 'Répartition CA / Dépenses (3D)',
          painter: _BenefitDonut3DPainter(
            values: [
              revenueValue < 0 ? 0 : revenueValue,
              expensesValue < 0 ? 0 : expensesValue,
            ],
            labels: const ['CA', 'Dépenses'],
            colors: const [AppColors.chart, AppColors.warning],
          ),
        );
        final margin = revenueValue == 0 ? null : netValue / revenueValue * 100;
        final trendArrow = _TrendArrowPainter(
          isPositive: netValue >= 0,
          size: 32,
          color: netValue >= 0 ? AppColors.success : AppColors.danger,
        );

        final charts = constraints.maxWidth >= 700
            ? Row(children: [
                Expanded(child: bars),
                const SizedBox(width: 12),
                Expanded(child: donut),
              ])
            : Column(children: [bars, const SizedBox(height: 10), donut]);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          charts,
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (netValue >= 0 ? AppColors.success : AppColors.danger).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (netValue >= 0 ? AppColors.success : AppColors.danger).withValues(alpha: .4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CustomPaint(size: const Size(40, 40), painter: trendArrow),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    netValue >= 0 ? 'Bénéfice net positif' : 'Perte nette',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: netValue >= 0 ? AppColors.success : AppColors.danger),
                  ),
                  Text(
                    'Marge nette : ${margin?.toStringAsFixed(1) ?? 'N/A'}% | ${Fmt.money(netValue)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: .8),
                      fontWeight: FontWeight.w600),
                  ),
                ]),
              ]),
            ),
          ]),
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

/// ============================================================
/// PAINTERS 3D POUR PAGE BÉNÉFICE — cohérents avec le dashboard
/// ============================================================

/// Barres 3D extrudées : face avant + face latérale + face supérieure
class _BenefitBars3DPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<String> valueLabels;
  final Color color;

  const _BenefitBars3DPainter({
    required this.values,
    required this.labels,
    required this.valueLabels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final max = maxValue <= 0 ? 1.0 : maxValue;
    final depth = math.min(10.0, size.width * .035);
    final base = size.height - 24;
    final slot = size.width / values.length;

    for (var i = 0; i < values.length; i++) {
      final h = ((values[i] / max) * (size.height - 50)).clamp(8.0, 999.0);
      final left = i * slot + slot * .18;
      final width = slot * .5;
      final top = base - h;

      final side = Color.lerp(color, Colors.black, .42)!;
      final topFace = Color.lerp(color, Colors.white, .30)!;

      // Ombre flottante
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 5, top + 6, width, h),
          const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: .14));

      // Face latérale (droite, perspective)
      final sidePath = Path()
        ..moveTo(left + width, top)
        ..lineTo(left + width + depth, top - depth)
        ..lineTo(left + width + depth, base - depth)
        ..lineTo(left + width, base)
        ..close();
      canvas.drawPath(sidePath, Paint()..color = side);

      // Face supérieure
      final topPath = Path()
        ..moveTo(left, top)
        ..lineTo(left + depth, top - depth)
        ..lineTo(left + width + depth, top - depth)
        ..lineTo(left + width, top)
        ..close();
      canvas.drawPath(topPath, Paint()..color = topFace);

      // Face avant avec dégradé
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, h),
          const Radius.circular(4)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(left, top),
            Offset(left + width, top + h),
            [color, color.withValues(alpha: .65)]));

      // Valeur au-dessus (taille adaptative)
      var fs = 12.0;
      TextPainter vp;
      do {
        vp = TextPainter(
          text: TextSpan(
            text: valueLabels[i],
            style: TextStyle(
              color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: slot * .95);
        if (vp.width <= slot * .95) break;
        fs -= 1;
      } while (fs > 8);
      vp.paint(canvas,
        Offset(i * slot + (slot - vp.width) / 2, math.max(0, top - depth - vp.height - 2)));

      // Label en bas
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.grey, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot);
      tp.paint(canvas, Offset(i * slot + (slot - tp.width) / 2, base + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BenefitBars3DPainter old) =>
      old.values != values;
}

/// Donut 3D avec épaisseur (couches empilées) + légende valeurs en gras
class _BenefitDonut3DPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;

  const _BenefitDonut3DPainter({
    required this.values,
    required this.labels,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    final cx = size.width * .26;
    final cy = size.height * .44;
    final radius = size.height * .36;

    for (var l = 7; l >= 0; l--) {
      canvas.save();
      canvas.translate(cx, cy + l * 1.6);
      canvas.scale(1, .58);
      final circle = Rect.fromCircle(center: Offset.zero, radius: radius);

      canvas.drawArc(
        circle,
        0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = Colors.white.withValues(alpha: .06 - l * .006));

      if (total > 0) {
        var start = -1.5708;
        for (var i = 0; i < values.length; i++) {
          final sweep = (values[i] / total * math.pi * 2) - .05;
          if (sweep <= 0) { start += values[i] / total * math.pi * 2; continue; }
          canvas.drawArc(circle, start, sweep, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 14
              ..color = Color.lerp(colors[i], Colors.black, (l / 7) * .55)!);
          start += sweep + .05;
        }
      }
      canvas.restore();
    }

    // Légende : label 11px + valeur GRAS 13px
    for (var i = 0; i < labels.length; i++) {
      final y = 16.0 + i * 28;
      canvas.drawCircle(Offset(size.width * .55, y + 8), 5, Paint()..color = colors[i]);
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: '${labels[i]} ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          TextSpan(text: '${values[i].round()}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * .42);
      tp.paint(canvas, Offset(size.width * .55 + 11, y));
    }
  }

  @override
  bool shouldRepaint(covariant _BenefitDonut3DPainter old) =>
      old.values != values;
}

/// Flèche de tendance 3D (montante/descendante)
class _TrendArrowPainter extends CustomPainter {
  final bool isPositive;
  final double size;
  final Color color;

  const _TrendArrowPainter({
    required this.isPositive,
    this.size = 28,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = this.size;

    final path = Path();
    if (isPositive) {
      path.moveTo(cx, cy + s * 0.45);
      path.lineTo(cx, cy - s * 0.35);
      path.moveTo(cx - s * 0.25, cy - s * 0.1);
      path.lineTo(cx, cy - s * 0.35);
      path.lineTo(cx + s * 0.25, cy - s * 0.1);
    } else {
      path.moveTo(cx, cy - s * 0.45);
      path.lineTo(cx, cy + s * 0.35);
      path.moveTo(cx - s * 0.25, cy + s * 0.1);
      path.lineTo(cx, cy + s * 0.35);
      path.lineTo(cx + s * 0.25, cy + s * 0.1);
    }

    canvas.drawPath(path.shift(const Offset(1, 1)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: .25));

    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendArrowPainter old) =>
      old.isPositive != isPositive;
}
