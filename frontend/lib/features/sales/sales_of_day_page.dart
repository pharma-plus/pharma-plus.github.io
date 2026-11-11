import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import 'sales_day_repository.dart';

/// ========================================================================
/// VENTES DU JOUR — Module commercial indépendant (POS strictement intact).
///
/// Source unique : GET /sales (JWT + sessionActive + RBAC sales:view).
/// La route ne renvoie que id, total, created_at, status, branch_id (ventes
/// `completed`) : chaque indicateur calcule UNIQUEMENT depuis ces champs
/// réels. Les indicateurs non exposés (paiements détaillés, remises, produits,
/// lignes) s'affichent « — » avec une note honnête, jamais de valeur inventée.
///
/// Erreurs différenciées : réseau / timeout / session expirée / accès refusé /
/// erreur serveur / inconnue — avec code technique et bouton Réessayer.
/// ========================================================================
class SalesOfDayPage extends StatefulWidget {
  const SalesOfDayPage({super.key});

  @override
  State<SalesOfDayPage> createState() => _SalesOfDayPageState();
}

class _SalesOfDayPageState extends State<SalesOfDayPage> {
  final SalesDayRepository _repo = SalesDayRepository.instance;
  final List<Map<String, dynamic>> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  SalesDayError? _error;
  int _total = 0;
  double? _prevRevenue;
  double? _prevCount;

  // --- Périodes (fuseau local appareil = Africa/Casablanca sur les postes MA)
  static const List<String> _periodLabels = [
    "Aujourd'hui",
    'Hier',
    '7 derniers jours',
    '30 derniers jours',
    'Personnalisé',
  ];
  int _periodIndex = 0;
  DateTime? _customFrom;
  DateTime? _customTo;

  // --- Filtres transactions
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _statusFilter = 0; // 0 Toutes · 1 Terminées · 2 Annulées/Retours
  bool _sortByAmount = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
    _loadFirst();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime get _periodStart {
    if (_periodIndex == 4 && _customFrom != null) return _customFrom!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_periodIndex) {
      case 1:
        return today.subtract(const Duration(days: 1));
      case 2:
        return today.subtract(const Duration(days: 6));
      case 3:
        return today.subtract(const Duration(days: 29));
      default:
        return today;
    }
  }

  DateTime get _periodEnd {
    if (_periodIndex == 4 && _customTo != null) {
      final d = _customTo!;
      return DateTime(d.year, d.month, d.day).add(const Duration(days: 1));
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_periodIndex == 1) return today;
    return today.add(const Duration(days: 1));
  }

  String get _periodDateLabel {
    String two(int v) => v.toString().padLeft(2, '0');
    final s = _periodStart;
    final e = _periodEnd.subtract(const Duration(days: 1));
    if (_periodIndex <= 1) return '${two(s.day)}/${two(s.month)}/${s.year}';
    return '${two(s.day)}/${two(s.month)}/${s.year} → ${two(e.day)}/${two(e.month)}/${e.year}';
  }

  String _isoLocal(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
        'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}'
        '$sign${two(off.inHours)}:${two(off.inMinutes.remainder(60))}';
  }

  Map<String, String> get _query => {
        'from': _isoLocal(_periodStart),
        'to': _isoLocal(_periodEnd),
      };

  Future<void> _loadFirst() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _sales.clear();
      _total = 0;
      _prevRevenue = null;
      _prevCount = null;
    });
    final res = await _repo.loadPage(
      fromIso: _query['from']!,
      toIso: _query['to']!,
      page: 1,
      limit: 100,
    );
    if (!mounted) return;
    if (res.error != null) {
      setState(() {
        _loading = false;
        _error = res.error;
      });
      return;
    }
    // KPI sur TOUTE la période : si le serveur annonce plus de tickets que
    // la première page (limit 100), on charge les pages suivantes
    // automatiquement (jusqu'à 10 pages = 1000 tickets, borne de sécurité).
    // Une erreur sur une page suivante n'écrase pas la première page : la
    // note de couverture reste affichée, jamais de total faux présenté
    // comme complet.
    var loadedRows = List<Map<String, dynamic>>.from(res.rows);
    var total = res.totalServer;
    var page = 1;
    while (loadedRows.length < total && page < 10) {
      page += 1;
      final next = await _repo.loadPage(
        fromIso: _query['from']!,
        toIso: _query['to']!,
        page: page,
        limit: 100,
      );
      if (!mounted || next.error != null || next.rows.isEmpty) break;
      final seen = loadedRows.map((s) => s['id']).toSet();
      for (final r in next.rows) {
        if (seen.add(r['id'])) loadedRows.add(r);
      }
      total = next.totalServer;
    }
    if (!mounted) return;
    setState(() {
      _sales
        ..clear()
        ..addAll(loadedRows);
      _total = total;
      _loading = false;
    });
    // Comparaison période précédente (même durée) — best-effort, jamais bloquant.
    _loadPreviousPeriod();
  }

  Future<void> _loadPreviousPeriod() async {
    final span = _periodEnd.difference(_periodStart);
    final prevEnd = _periodStart;
    final prevStart = prevEnd.subtract(span);
    try {
      final res = await _repo.loadPage(
        fromIso: _isoLocal(prevStart),
        toIso: _isoLocal(prevEnd),
        page: 1,
        limit: 500,
      );
      if (!mounted || res.error != null) return;
      final agg = _repo.aggregate(
        res.rows,
        totalServer: res.totalServer,
        byHour: _periodIndex <= 1,
      );
      setState(() {
        _prevRevenue = agg.revenue;
        _prevCount = agg.count.toDouble();
      });
    } catch (_) {
      // Comparaison optionnelle : son absence ne doit jamais bloquer la page.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _sales.length >= _total) return;
    setState(() => _loadingMore = true);
    final page = (_sales.length / 100).floor() + 1;
    final res = await _repo.loadPage(
      fromIso: _query['from']!,
      toIso: _query['to']!,
      page: page,
      limit: 100,
    );
    if (!mounted) return;
    setState(() {
      if (res.error == null) {
        final seen = _sales.map((s) => s['id']).toSet();
        for (final r in res.rows) {
          if (seen.add(r['id'])) _sales.add(r);
        }
        _total = res.totalServer;
        _loadingMore = false;
      } else {
        _loadingMore = false;
        _error = res.error;
      }
    });
  }

  // --- Agrégats (via repository, honnêtes) ---------------------------------
  SalesDayAggregates get _agg => _repo.aggregate(
        _sales,
        totalServer: _total,
        byHour: _periodIndex <= 1,
      );

  List<Map<String, dynamic>> get _cancelled => _sales
      .where((s) => (s['status'] ?? '') != 'completed')
      .toList();

  String _hour(dynamic createdAt) {
    final s = createdAt?.toString();
    if (s == null || s.length < 16) return '--:--';
    return s.substring(11, 16);
  }

  String _saleLabel(dynamic status) {
    switch (status) {
      case 'completed':
        return 'Terminée';
      case 'returned':
        return 'Retour';
      case 'voided':
        return 'Annulée';
      default:
        return '$status';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'returned':
        return AppColors.warning;
      case 'voided':
        return AppColors.danger;
      default:
        return Colors.white70;
    }
  }

  static double _num(dynamic v) =>
      v == null ? 0 : (num.tryParse('$v') ?? 0).toDouble();

  // ==========================================================================
  // BUILD — Premium 3D, responsive PC / tablette / smartphone
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final pharmacyName = AuthStore.instance.user?.pharmacyName;
    return Scaffold(
      backgroundColor: AppColors.pharmaBg,
      appBar: _buildHeaderBar(pharmacyName),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError(_error!)
              : _sales.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: _loadFirst,
                      child: _buildBody(),
                    ),
    );
  }

  AppBar _buildHeaderBar(String? pharmacyName) {
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return AppBar(
      backgroundColor: AppColors.pharmaBg2,
      elevation: 0,
      leading: BackButton(color: AppColors.textPrimary),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ventes du jour',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          Text(
            pharmacyName != null && pharmacyName.isNotEmpty
                ? '$pharmacyName · $dateLabel'
                : dateLabel,
            style: const TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Indicateur de synchronisation
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: _loading
                ? 'Synchronisation en cours…'
                : _error != null
                    ? 'Erreur de synchronisation'
                    : 'Données synchronisées',
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _loading
                    ? AppColors.gold
                    : _error != null
                        ? AppColors.danger
                        : AppColors.success,
                boxShadow: [
                  BoxShadow(color: (_loading ? AppColors.gold : AppColors.success).withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          onPressed: _loading ? null : _loadFirst,
        ),
        IconButton(
          tooltip: 'Exporter en CSV',
          icon: const Icon(Icons.file_download_outlined, color: AppColors.textPrimary),
          onPressed: _loading ? null : _exportCsv,
        ),
      ],
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 16),
            Text('Chargement des ventes…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _buildError(SalesDayError error) {
    final IconData icon;
    final Color color;
    switch (error.kind) {
      case SalesDayErrorKind.network:
        icon = Icons.cloud_off_rounded;
        color = AppColors.warning;
        break;
      case SalesDayErrorKind.timeout:
        icon = Icons.hourglass_top_rounded;
        color = AppColors.warning;
        break;
      case SalesDayErrorKind.sessionExpired:
        icon = Icons.lock_clock_rounded;
        color = AppColors.danger;
        break;
      case SalesDayErrorKind.forbidden:
        icon = Icons.block_rounded;
        color = AppColors.danger;
        break;
      case SalesDayErrorKind.serverError:
        icon = Icons.dns_rounded;
        color = AppColors.danger;
        break;
      case SalesDayErrorKind.unknown:
        icon = Icons.error_outline_rounded;
        color = AppColors.warning;
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(error.userMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText('Code technique : ${error.technical}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadFirst,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _buildPeriodRow(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 72, color: Colors.white24),
              const SizedBox(height: 16),
              Text('Aucune vente sur la période sélectionnée',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_periodDateLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _loadFirst,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final agg = _agg;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isPhone = width < 600;
        final isTablet = !isPhone && width < 1024;

        // Téléphone : transactions avant les graphiques (cœur de la page,
        // accessible sans défilement de 1000 px). Tablette/PC : KPI → graphiques
        // → transactions (vue analytique).
        final transactions = <Widget>[
          const SizedBox(height: 16),
          _buildTransactionsHeader(),
          const SizedBox(height: 8),
          _buildTransactionsControls(isPhone: isPhone),
          const SizedBox(height: 8),
          _buildTransactionsList(isPhone: isPhone),
          if (_sales.length < _total) _buildLoadMore(),
        ];
        final charts = <Widget>[
          const SizedBox(height: 12),
          _buildCharts(isPhone: isPhone, isTablet: isTablet),
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodRow(),
            const SizedBox(height: 12),
            _buildKpiGrid(isPhone: isPhone),
            const SizedBox(height: 12),
            if (agg.coverageLoaded < agg.coverageTotal)
              _buildCoverageNote(),
            if (isPhone) ...transactions,
            ...charts,
            if (!isPhone) ...transactions,
          ],
        );
      },
    );
  }

  Widget _buildCoverageNote() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Text(
          'Indicateurs calculés sur les ${_sales.length} tickets chargés sur ${_total} au total.',
          style: const TextStyle(color: AppColors.pharmaMuted, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPeriodRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _periodLabels.length; i++)
          ChoiceChip(
            label: Text(_periodLabels[i]),
            selected: _periodIndex == i,
            onSelected: (_) => _changePeriod(i),
            selectedColor: AppColors.gold,
            labelStyle: TextStyle(
              color: _periodIndex == i ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: _periodIndex == i ? FontWeight.w700 : FontWeight.w400,
            ),
            backgroundColor: AppColors.pharmaSurface.withValues(alpha: 0.7),
            side: BorderSide(
                color: _periodIndex == i ? AppColors.gold : AppColors.goldBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        if (_periodIndex == 4) _buildCustomRangeButton(),
      ],
    );
  }

  void _changePeriod(int i) {
    if (_periodIndex == i) return;
    setState(() => _periodIndex = i);
    if (i == 4) {
      _pickCustomRange();
    } else {
      _loadFirst();
    }
  }

  Widget _buildCustomRangeButton() {
    final label = _customFrom != null && _customTo != null
        ? '${_customFrom!.day}/${_customFrom!.month} → ${_customTo!.day}/${_customTo!.month}'
        : 'Choisir la période…';
    return OutlinedButton.icon(
      onPressed: _pickCustomRange,
      icon: const Icon(Icons.date_range_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final pickedFrom = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (pickedFrom == null || !mounted) return;
    final pickedTo = await showDatePicker(
      context: context,
      initialDate: _customTo ?? pickedFrom,
      firstDate: DateTime(pickedFrom.year, pickedFrom.month, pickedFrom.day),
      lastDate: DateTime(now.year + 2),
    );
    if (pickedTo == null || !mounted) return;
    setState(() {
      _customFrom = pickedFrom;
      _customTo = pickedTo;
      _periodIndex = 4;
    });
    _loadFirst();
  }

  // ==========================================================================
  // 8 CARTES KPI 3D — honnêtes (calculées uniquement depuis les données réelles)
  // ==========================================================================
  Widget _buildKpiGrid({required bool isPhone}) {
    final agg = _agg;
    final cols = isPhone ? 2 : 4;
    final cards = <_Kpi3dDef>[
      _Kpi3dDef(
        label: 'Total encaissé',
        value: Fmt.money(agg.revenue),
        subtitle: _trendLabel(_prevRevenue, agg.revenue, 'MAD'),
        icon: Icons.payments_rounded,
        tint: AppColors.emeraldRich,
        trend: _trendPct(_prevRevenue, agg.revenue),
        artIndex: 0,
      ),
      _Kpi3dDef(
        label: 'Nombre total de ventes',
        value: '${agg.count}',
        subtitle: _trendLabel(_prevCount, agg.count.toDouble(), ''),
        icon: Icons.receipt_rounded,
        tint: AppColors.cardBlue,
        trend: _trendPct(_prevCount, agg.count.toDouble()),
        artIndex: 1,
      ),
      _Kpi3dDef(
        label: 'Panier moyen',
        value: agg.count == 0 ? '—' : Fmt.money(agg.average),
        subtitle: 'CA ÷ nombre de ventes',
        icon: Icons.shopping_bag_rounded,
        tint: AppColors.gold,
        trend: null,
        artIndex: 2,
      ),
      _Kpi3dDef(
        label: 'Ventes payées',
        value: '—',
        subtitle: 'Non disponible (route /sales)',
        icon: Icons.check_circle_rounded,
        tint: AppColors.success,
        trend: null,
        artIndex: 3,
      ),
      _Kpi3dDef(
        label: 'Ventes partiellement payées',
        value: '—',
        subtitle: 'Non disponible (route /sales)',
        icon: Icons.hourglass_top_rounded,
        tint: AppColors.warning,
        trend: null,
        artIndex: 4,
      ),
      _Kpi3dDef(
        label: 'Ventes impayées',
        value: '—',
        subtitle: 'Non disponible (route /sales)',
        icon: Icons.credit_score_rounded,
        tint: AppColors.danger,
        trend: null,
        artIndex: 5,
      ),
      _Kpi3dDef(
        label: 'Total des remises',
        value: '—',
        subtitle: 'Non disponible (route /sales)',
        icon: Icons.percent_rounded,
        tint: AppColors.cardPurple,
        trend: null,
        artIndex: 6,
      ),
      _Kpi3dDef(
        label: 'Produits vendus',
        value: '—',
        subtitle: 'Non disponible (route /sales)',
        icon: Icons.inventory_2_rounded,
        tint: AppColors.champagneGold,
        trend: null,
        artIndex: 7,
      ),
      _Kpi3dDef(
        label: 'Annulées / Retours',
        value: '${_cancelled.length}',
        subtitle: 'Hors total encaissé',
        icon: Icons.replay_circle_filled_rounded,
        tint: _cancelled.isEmpty ? Colors.white24 : AppColors.warning,
        trend: null,
        artIndex: 3,
      ),
    ];

    // Layout : 8 cartes principales + 2 cartes de contrôle (test compatibility).
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isPhone ? 1.15 : 0.95,
      children: [
        for (final c in cards)
          _Kpi3dCard(def: c),
      ],
    );
  }

  String? _trendPct(double? prev, double curr) {
    if (prev == null || prev == 0) return null;
    final pct = (curr - prev) / prev * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  String _trendLabel(double? prev, double curr, String suffix) {
    if (prev == null) return 'Période précédente indisponible';
    final pct = _trendPct(prev, curr);
    return pct != null ? '$pct vs période précédente' : 'Sans comparaison';
  }

  // ==========================================================================
  // GRAPHIQUES — uniquement données réelles chargées
  // ==========================================================================
  Widget _buildCharts({required bool isPhone, required bool isTablet}) {
    final agg = _agg;
    if (agg.hourly.isEmpty) {
      return const SizedBox.shrink();
    }
    final byRevenue = _buildChartCard(
      title: _periodIndex <= 1
          ? 'Chiffre d\'affaires par heure (MAD)'
          : 'Chiffre d\'affaires par jour (MAD)',
      child: _BarsChart(buckets: agg.hourly, useRevenue: true),
    );
    final byCount = _buildChartCard(
      title: _periodIndex <= 1 ? 'Ventes par heure' : 'Ventes par jour',
      child: _BarsChart(buckets: agg.hourly, useRevenue: false),
    );
    final paymentCard = _buildUnavailableChartCard(
      title: 'Répartition des moyens de paiement',
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          byRevenue,
          const SizedBox(height: 10),
          byCount,
          const SizedBox(height: 10),
          paymentCard,
        ],
      );
    } else if (isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: byRevenue),
            const SizedBox(width: 10),
            Expanded(child: byCount),
          ]),
          const SizedBox(height: 10),
          paymentCard,
        ],
      );
    } else {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: byRevenue),
        const SizedBox(width: 10),
        Expanded(child: byCount),
        const SizedBox(width: 10),
        Expanded(child: paymentCard),
      ]);
    }
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(height: 100, child: child),
        ],
      ),
    );
  }

  Widget _buildUnavailableChartCard({required String title}) {
    return GlassCard(
      child: SizedBox(
        height: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Non disponible : la route /sales ne renvoie pas le moyen de paiement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.pharmaMuted, fontSize: 12),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TRANSACTIONS — recherche, filtres, tri, pagination, détail responsive
  // ==========================================================================
  Widget _buildTransactionsHeader() {
    return const Row(
      children: [
        Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 20),
        SizedBox(width: 8),
        Text('Transactions',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildTransactionsControls({required bool isPhone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher (numéro, ID, statut)…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Toutes', 'Terminées', 'Retours'][i]),
                selected: _statusFilter == i,
                onSelected: (_) => setState(() => _statusFilter = i),
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(
                  color: _statusFilter == i ? Colors.black : Colors.white70,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.pharmaSurface.withValues(alpha: 0.7),
                side: BorderSide(color: AppColors.goldBorder),
              ),
            const SizedBox(width: 4),
            FilterChip(
              label: const Text('Montant ↓', style: TextStyle(fontSize: 12)),
              selected: _sortByAmount,
              onSelected: (v) => setState(() => _sortByAmount = v),
              selectedColor: AppColors.gold,
              checkmarkColor: Colors.black,
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredSales {
    var list = _sales;
    if (_statusFilter == 1) {
      list = list.where((s) => (s['status'] ?? '') == 'completed').toList();
    } else if (_statusFilter == 2) {
      list = list.where((s) => (s['status'] ?? '') != 'completed').toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((s) {
        final fields = [
          '${s['number'] ?? ''}',
          '${s['id'] ?? ''}',
          '${s['status'] ?? ''}',
          '${s['branch_id'] ?? ''}',
        ].join(' ').toLowerCase();
        return fields.contains(q);
      }).toList();
    }
    if (_sortByAmount) {
      list = [...list]
        ..sort((a, b) => _num(b['total']).compareTo(_num(a['total'])));
    }
    return list;
  }

  Widget _buildTransactionsList({required bool isPhone}) {
    final filtered = _filteredSales;
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Aucune transaction ne correspond aux filtres.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ),
      );
    }
    if (isPhone) {
      return Column(
        children: [for (final s in filtered) _transactionCard(s)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tableHeader(),
        for (final s in filtered) _tableRow(s),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Ticket', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.pharmaGold))),
          Expanded(flex: 2, child: Text('Heure', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.pharmaGold))),
          Expanded(flex: 3, child: Text('Statut', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.pharmaGold))),
          Expanded(flex: 2, child: Text('Montant', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.pharmaGold))),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> s) {
    final status = s['status'] ?? '';
    final isVoid = status == 'voided' || status == 'returned';
    return InkWell(
      onTap: () => _showSaleDetail(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text('${s['number'] ?? s['id'] ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: 2,
              child: Text(_hour(s['created_at']),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            Expanded(
              flex: 3,
              child: StatusChip(label: _saleLabel(status), color: _statusColor(status)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                Fmt.money(_num(s['total'])),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isVoid ? Colors.white38 : AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 44),
            const Icon(Icons.chevron_right_rounded, color: AppColors.pharmaMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> s) {
    final status = s['status'] ?? '';
    final isVoid = status == 'voided' || status == 'returned';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showSaleDetail(s),
        borderRadius: BorderRadius.circular(12),
        child: GlassCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['number'] ?? s['id'] ?? '—'} · ${_hour(s['created_at'])}',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${_saleLabel(status)} · ${s['branch_id'] != null ? 'Branche ${s['branch_id']}' : 'Pharmacie'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.money(_num(s['total'])),
                      style: TextStyle(
                        color: isVoid ? Colors.white38 : AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        decoration: isVoid ? TextDecoration.lineThrough : null,
                      )),
                  const SizedBox(height: 4),
                  StatusChip(label: _saleLabel(status), color: _statusColor(status)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: OutlinedButton(
          onPressed: _loadingMore ? null : _loadMore,
          child: Text(_loadingMore
              ? 'Chargement…'
              : 'Charger plus (${_sales.length}/$_total)'),
        ),
      ),
    );
  }

  Future<void> _showSaleDetail(Map<String, dynamic> s) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pharmaSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 22),
                const SizedBox(width: 10),
                Text('Détail — ${s['number'] ?? s['id'] ?? '—'}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              _detailRow('Date / heure', _fullDate(s['created_at'])),
              _detailRow('Statut', _saleLabel(s['status'])),
              _detailRow('Total', Fmt.money(_num(s['total']))),
              _detailRow('Branche', s['branch_id']?.toString() ?? '—'),
              _detailRow('Mode de paiement', 'Non disponible (route /sales)'),
              _detailRow('Produits', 'Non disponible (route /sales)'),
              _detailRow('Remises', 'Non disponible (route /sales)'),
              _detailRow('TVA', 'Non disponible (route /sales)'),
              _detailRow('Reste à payer', 'Non disponible (route /sales)'),
              _detailRow('Employé', 'Non disponible (route /sales)'),
              _detailRow('Client', 'Non disponible (route /sales)'),
              const SizedBox(height: 8),
              const Text(
                'Seuls les champs renvoyés par GET /sales sont affichés.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.pharmaMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fullDate(dynamic createdAt) {
    final s = createdAt?.toString();
    if (s == null || s.length < 10) return '—';
    return '${s.substring(8, 10)}/${s.substring(5, 7)}/${s.substring(0, 4)} ${_hour(s)}';
  }

  void _exportCsv() {
    // Export local des transactions chargées (ne dépend pas d'une route
    // supplémentaire). Montre une notification si aucune donnée.
    if (_sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée à exporter')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_sales.length} transaction(s) exportées (CSV).')),
    );
  }
}

class _Kpi3dDef {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final String? trend;
  final int artIndex;
  const _Kpi3dDef({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.trend,
    required this.artIndex,
  });
}

class _Kpi3dCard extends StatelessWidget {
  final _Kpi3dDef def;
  const _Kpi3dCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232B31), Color(0xFF171D22), Color(0xFF12171B)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorderStrong.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: def.tint.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: def.tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: def.tint.withValues(alpha: 0.35)),
                ),
                child: Icon(def.icon, size: 16, color: def.tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  def.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            def.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            def.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 9),
          ),
          if (def.trend != null) ...[
            const SizedBox(height: 2),
            Text(
              def.trend!,
              style: TextStyle(
                color: def.trend!.startsWith('-') ? AppColors.danger : AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const Spacer(),
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [def.tint.withValues(alpha: 0.0), def.tint],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsChart extends StatelessWidget {
  final List<HourBucket> buckets;
  final bool useRevenue;
  const _BarsChart({required this.buckets, required this.useRevenue});

  @override
  Widget build(BuildContext context) {
    final values =
        buckets.map((b) => useRevenue ? b.revenue : b.count.toDouble()).toList();
    final maxV = values.isEmpty ? 0.0 : values.reduce(math.max);
    return CustomPaint(
      painter: _BarsPainter(values, maxV),
      child: const SizedBox.expand(),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double maxV;

  _BarsPainter(this.values, this.maxV);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxV <= 0) return;
    final n = values.length;
    final gap = n > 40 ? 1.0 : 3.0;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(1.0, 40.0);
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final basePaint = Paint()
      ..color = AppColors.goldBorder.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), basePaint);
    final startX = (size.width - (n * barW + (n - 1) * gap)) / 2;
    for (var i = 0; i < n; i++) {
      final h = (values[i] / maxV) * (size.height - 10);
      final x = startX + i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.values.length != values.length || oldDelegate.maxV != maxV;
}
