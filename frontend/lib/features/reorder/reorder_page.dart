/// ============================================================
/// RÉAPPROVISIONNEMENT INTELLIGENT — Moteur IA déterministe
/// Basé sur les algorithmes du backend (ai_reorder_plan, ai_insights)
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/supplier_integration.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/shared/app_data_table.dart';
import '../../core/widgets/shared/app_search_field.dart';
import '../../core/utils/table_columns.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/status_chip.dart';

/// Page de réapprovisionnement intelligent
class ReorderPage extends StatefulWidget {
  const ReorderPage({super.key});

  @override
  State<ReorderPage> createState() => _ReorderPageState();
}

class _ReorderPageState extends State<ReorderPage> {
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _insights;
  bool _loading = true;
  String? _error;
  String _activeTab = 'plan';
  
  // Filtres
  String? _filterSupplier;
  String? _filterPriority;
  RangeValues? _costRange;
  
  static const _tabs = [
    ('plan', Icons.local_shipping_outlined, 'reorderPlan'),
    ('insights', Icons.lightbulb_outline, 'insights'),
    ('history', Icons.history_outlined, 'reorderHistory'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      ApiClient.instance.get('/ai/reorder-plan'),
      ApiClient.instance.get('/ai/insights'),
    ]);
    if (!mounted) return;
    final planRes = results[0];
    final insightsRes = results[1];
    setState(() {
      if (!planRes.success) {
        _error = planRes.error?.readableMessage ?? 'Erreur';
      } else {
        final pd = planRes.data;
        _plan = pd is Map ? Map<String, dynamic>.from(pd) : null;
      }
      if (insightsRes.success) {
        final id = insightsRes.data;
        _insights = id is Map ? Map<String, dynamic>.from(id) : null;
      }
      _loading = false;
      _activeTab ??= 'plan';
    });
  }

  void _showFilterDialog() {
    // ... dialogue de filtres
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('reorderPlan', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.pharmaGold),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.pharmaGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(children: [
                  // Onglets
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: SegmentedButton<String>(
                      segments: [
                        for (final (key, icon, label) in _tabs)
                          ButtonSegment(
                            value: key,
                            icon: Icon(icon, size: 18),
                            label: Text(S.t(label, locale)),
                          ),
                      ],
                      selected: {_activeTab},
                      onSelectionChanged: (sel) => setState(() => _activeTab = sel.first),
                    ),
                  ),
                  // Résumé global
                  if (_plan != null) _buildSummary(locale),
                  // Liste / Tableau
                  Expanded(
                    child: _activeTab == 'plan' 
                        ? _buildPlanTable(locale)
                        : _activeTab == 'insights'
                            ? _buildInsights(locale)
                            : _buildHistory(locale),
                  ),
                ]),
    );
  }

  Widget _buildSummary(String locale) {
    if (_plan == null) return const SizedBox.shrink();
    final items = _plan!['items'] as List? ?? [];
    final totalCost = double.tryParse('${_plan!['total_estimated_cost'] ?? 0}') ?? 0;
    final totalQty = double.tryParse('${_plan!['total_suggested_qty'] ?? 0}') ?? 0;
    final bySupplier = _plan!['by_supplier'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: _KpiTile(S.t('productsToOrder', locale), items.length.toString(),
                Icons.local_shipping_outlined, AppColors.emerald)),
            const SizedBox(width: 8),
            Expanded(child: _KpiTile(S.t('totalEstCost', locale), Fmt.money(totalCost),
                Icons.attach_money_outlined, AppColors.pharmaGold)),
            const SizedBox(width: 8),
            Expanded(child: _KpiTile(S.t('suppliers', locale), bySupplier.length.toString(),
                Icons.local_shipping_outlined, AppColors.info)),
          ]),
          if (bySupplier.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(S.t('bySupplier', locale),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in bySupplier)
                _SupplierCostChip(
                  name: s['supplier_name']?.toString() ?? '—',
                  count: s['items_count']?.toString() ?? '0',
                  qty: s['total_qty']?.toString() ?? '0',
                  cost: Fmt.money(double.tryParse('${s['total_cost'] ?? 0}') ?? 0),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTable(String locale) {
    final items = (_plan?['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (items.isEmpty) {
      return Center(child: Text(S.t('noData', locale)));
    }

    // Appliquer filtres
    var filtered = items;
    if (_filterSupplier != null && _filterSupplier!.isNotEmpty) {
      filtered = filtered.where((i) => i['supplier_name'] == _filterSupplier).toList();
    }
    if (_filterPriority != null && _filterPriority!.isNotEmpty) {
      filtered = filtered.where((i) => i['priority'] == _filterPriority).toList();
    }
    if (_costRange != null) {
      final estCost = (i) => double.tryParse('${i['estimated_cost'] ?? 0}') ?? 0;
      filtered = filtered.where((i) => 
          estCost(i) >= _costRange!.start && estCost(i) <= _costRange!.end).toList();
    }

    if (filtered.isEmpty) {
      return Center(child: Text(S.t('noDataFiltered', locale)));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: AppDataTable<Map<String, dynamic>>(
        columns: [
          TableColumnWidths.column(
            key: 'name', label: S.t('product', locale), type: TableColumnType.name),
          TableColumnWidths.column(
            key: 'supplier_name', label: S.t('supplier', locale), type: TableColumnType.description),
          TableColumnWidths.column(
            key: 'priority', label: S.t('priority', locale), type: TableColumnType.status,
            cellBuilder: (ctx, item, idx) => _PriorityChip(item['priority']?.toString() ?? '')),
          TableColumnWidths.column(
            key: 'suggested_qty', label: S.t('suggestedQty', locale), type: TableColumnType.quantity,
            numeric: true),
          TableColumnWidths.column(
            key: 'stock', label: S.t('stock', locale), type: TableColumnType.quantity,
            numeric: true),
          TableColumnWidths.column(
            key: 'days_of_cover', label: S.t('daysCover', locale), type: TableColumnType.code,
            numeric: true, alignment: TextAlign.center),
          TableColumnWidths.column(
            key: 'estimated_cost', label: S.t('estimatedCost', locale), type: TableColumnType.money,
            numeric: true, cellBuilder: (ctx, item, idx) {
              final c = double.tryParse('${item['estimated_cost'] ?? 0}') ?? 0;
              return Text(Fmt.money(c), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.pharmaGold));
            }),
          TableColumnWidths.column(
            key: 'actions', label: S.t('actions', locale), type: TableColumnType.actionsWide,
            cellBuilder: (ctx, item, idx) => _ActionButtons(item: item)),
        ],
        data: filtered,
        fixedHeader: true,
        config: const AppDataTableConfig(columnSpacing: 16),
        onRowTap: (item) => _showDetail(item),
      );
    );
  }

  Widget _buildInsights(String locale) {
    if (_insights == null) return Center(child: Text(S.t('noData', locale)));
    // Afficher les insights (ruptures, surstock, ventes lentes, etc.)
    return Center(child: Text('Insights - à implémenter'));
  }

  Widget _buildHistory(String locale) {
    return Center(child: Text('Historique réappro - à implémenter'));
  }

  void _showDetail(Map<String, dynamic> item) {
    // ... dialogue de détail
  }

  void _showFilterDialog() {
    // ... dialogue de filtres
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SupplierCostChip extends StatelessWidget {
  final String name;
  final String count;
  final String qty;
  final String cost;

  const _SupplierCostChip({
    required this.name, required this.count, required this.qty, required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('$count art. · $qty u. · $cost', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip(this.priority);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (priority) {
      case 'rupture': color = AppColors.danger; label = 'Rupture'; break;
      case 'critique': color = AppColors.warning; label = 'Critique'; break;
      case 'haute': color = AppColors.pharmaGold; label = 'Haute'; break;
      default: color = AppColors.success; label = 'Normale';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActionButtons({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: 'Détail', icon: const Icon(Icons.visibility, size: 18), onPressed: () {}),
      IconButton(tooltip: 'Modifier qté', icon: const Icon(Icons.edit, size: 18), onPressed: () {}),
      IconButton(tooltip: 'Ignorer', icon: const Icon(Icons.skip_next, size: 18), onPressed: () {}),
    ]);
  }
}

class _SupplierCostChip extends StatelessWidget {
  // ... déjà défini dans ReorderPage
}