/// ============================================================
/// VENTES DU JOUR — Contrôleur (état, chargements, filtres)
/// ============================================================
/// Chargement progressif : 1 requête analytique légère (/sales/day) +
/// 1 page de transactions à la fois (pagination serveur).
/// La comparaison avec la période précédente est best-effort et
/// n'altère jamais l'affichage principal.
/// Erreurs différenciées, jamais masquées ; aucune donnée inventée.
/// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models/sales_day_model.dart';
import '../repositories/sales_repository.dart';
import '../services/sales_analytics_service.dart';

/// Filtres de la liste des transactions.
class SalesTxFilter {
  static const String all = '';
  static const String completed = 'completed';
  static const String problems = 'problems';
}

class SalesDayController extends ChangeNotifier {
  final SalesRepository _repo = SalesRepository.instance;
  final int _txPageSize = 50;

  bool _disposed = false;

  // --- Période --------------------------------------------------------
  SalesPeriod period = SalesPeriod.today;
  DateTimeRange? custom;

  // --- Analyse --------------------------------------------------------
  bool loading = true;
  SalesDayFailure? error;
  SalesDayAnalytics? analytics;

  /// KPI de la période précédente (même durée) — null si indisponible.
  SalesDayKpis? previousKpis;

  // --- Transactions ---------------------------------------------------
  final List<SalesTransaction> txRows = [];
  int txTotal = 0;
  bool txLoading = false;
  bool txLoadingMore = false;
  String txStatus = SalesTxFilter.all;
  String _search = '';
  SalesDayFailure? txError;

  Timer? _searchDebounce;

  // --- Jeu complet pour agrégations et exports (hors pagination UI) ----
  List<SalesTransaction> fullRows = const <SalesTransaction>[];
  bool fullLoading = false;
  bool fullComplete = false;
  SalesDayFailure? fullError;
  String? _fullLoadedKey;
  Future<List<SalesTransaction>?>? _fullFuture;

  /// Le jeu complet est périmétré par la PÉRIODE SEULE : les filtres
  /// `txStatus` / `_search` appartiennent exclusivement au tableau de la
  /// vue générale et ne doivent pas restreindre employés/retours/exports.
  String get _fullKey =>
      '${range.start.toIso8601String()}|${range.end.toIso8601String()}';

  /// Libellé explicite du périmètre affiché dans l'UI et les exports.
  String get fullScopeLabel =>
      'Période ${periodLabelText} complète · aucun filtre de statut ni de recherche appliqué';

  SalesDateRange get range =>
      SalesAnalyticsService.rangeFor(period, custom: custom);

  String get periodLabelText =>
      SalesAnalyticsService.periodLabel(period, range);

  String get search => _search;

  bool get txHasMore => txRows.length < txTotal;

  /// Deltas par KPI (pct null = incomparable ; jamais de % inventé).
  SalesDelta get grossDelta => SalesAnalyticsService.delta(
      analytics?.kpis.grossRevenue ?? 0, previousKpis?.grossRevenue);
  SalesDelta get countDelta => SalesAnalyticsService.delta(
      (analytics?.kpis.salesCount ?? 0).toDouble(),
      previousKpis?.salesCount.toDouble());

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  // --------------------------------------------------------------------
  // Cycle de vie
  // --------------------------------------------------------------------
  Future<void> initialLoad() => reload();

  /// Changement de période → recharge tout.
  Future<void> setPeriod(SalesPeriod p, {DateTimeRange? customRange}) async {
    period = p;
    if (customRange != null) custom = customRange;
    await reload();
  }

  Future<void> setCustomRange(DateTimeRange r) =>
      setPeriod(SalesPeriod.custom, customRange: r);

  Future<void> reload() async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    loading = true;
    error = null;
    txError = null;
    analytics = null;
    previousKpis = null;
    txRows.clear();
    txTotal = 0;
    _fullLoadedKey = null;
    fullRows = const <SalesTransaction>[];
    fullComplete = false;
    fullError = null;
    _notify();
    final r = range;
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    // Analyse + page 1 des transactions : chargement principal.
    final (analyticsRes, analyticsErr) =
        await _repo.loadAnalytics(r, offsetMinutes: offsetMinutes);
    final (txRes, txErr) = await _repo.loadTransactions(
      r,
      SalesTransactionQuery(status: txStatus, search: _search),
      offsetMinutes: offsetMinutes,
    );

    if (analyticsRes != null) {
      analytics = analyticsRes;
      error = null;
    } else {
      error = analyticsErr;
    }
    if (txRes != null) {
      txRows
        ..clear()
        ..addAll(txRes.rows);
      txTotal = txRes.totalServer;
      txError = null;
    } else if (txErr != null) {
      txError = txErr;
    }
    loading = false;
    _notify();

    // Comparaison précédente : finalisée après le premier rendu, jamais
    // bloquante.
    unawaited(_loadPrevious(r, offsetMinutes));
  }

  /// Période précédente (même durée) — BEST-EFFORT, silencieux en erreur.
  Future<void> _loadPrevious(SalesDateRange r, int offsetMinutes) async {
    try {
      final prev = SalesAnalyticsService.previousOf(r);
      final (a, _) =
          await _repo.loadAnalytics(prev, offsetMinutes: offsetMinutes);
      if (a != null && !_disposed) {
        previousKpis = a.kpis;
        _notify();
      }
    } catch (_) {
      // comparaison optionnelle : son erreur reste silencieuse
    }
  }

  // --------------------------------------------------------------------
  // Transactions (pagination + filtres)
  // --------------------------------------------------------------------
  Future<void> loadMore() async {
    if (txLoadingMore || loading || !txHasMore) return;
    txLoadingMore = true;
    _notify();
    final r = range;
    final page = (txRows.length / _txPageSize).floor() + 1;
    final (res, err) = await _repo.loadTransactions(
      r,
      SalesTransactionQuery(
        page: page,
        limit: _txPageSize,
        status: txStatus,
        search: _search,
      ),
      offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    txLoadingMore = false;
    if (err != null) {
      // Une erreur de continuation n'écrase pas l'affichage existant.
      txError = err;
      _notify();
      return;
    }
    if (res != null) {
      final seen = txRows.map((t) => t.id).toSet();
      for (final row in res.rows) {
        if (seen.add(row.id)) txRows.add(row);
      }
      txTotal = res.totalServer;
      txError = null;
    }
    _notify();
  }

  /// Recharge la liste seule (filtre statut / recherche).
  Future<void> _refreshTxOnly() async {
    if (loading) return;
    final r = range;
    txLoading = true;
    _notify();
    final (res, err) = await _repo.loadTransactions(
      r,
      SalesTransactionQuery(
        limit: _txPageSize,
        status: txStatus,
        search: _search,
      ),
      offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    txLoading = false;
    if (res != null) {
      txRows
        ..clear()
        ..addAll(res.rows);
      txTotal = res.totalServer;
      txError = null;
    } else if (err != null) {
      txError = err;
    }
    _notify();
  }

  Future<void> setStatus(String status) async {
    if (txStatus == status) return;
    txStatus = status;
    await _refreshTxOnly();
  }

  void setSearch(String value) {
    _search = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_refreshTxOnly()),
    );
  }

  // --------------------------------------------------------------------
  // Transactions complètes (une seule fois par combinaison période/filtres)
  // --------------------------------------------------------------------
  /// Retourne toutes les transactions de la période, SANS filtre de statut
  /// ni de recherche (pagination serveur parcourue intégralement), pour les
  /// agrégations et les exports. « fullComplete = false » signale une
  /// troncature : l'appelant doit refuser l'export plutôt que de produire
  /// un document incomplet.
  Future<List<SalesTransaction>?> ensureFullTransactions() {
    final key = _fullKey;
    if (_fullLoadedKey == key && fullError == null) {
      return Future.value(fullRows);
    }
    final pending = _fullFuture;
    if (pending != null) return pending;
    final future = _loadFullTransactions(key);
    _fullFuture = future;
    return future;
  }

  Future<List<SalesTransaction>?> _loadFullTransactions(String key) async {
    fullLoading = true;
    fullError = null;
    _notify();
    try {
      final (rows, err, complete) = await _repo.loadAllTransactions(
        range,
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        // Périmètre explicite et indépendant des filtres du tableau.
        status: SalesTxFilter.all,
        search: '',
      );
      fullRows = rows ?? const <SalesTransaction>[];
      fullComplete = complete;
      fullError = err;
      if (err == null) _fullLoadedKey = key;
      return rows;
    } finally {
      fullLoading = false;
      _fullFuture = null;
      _notify();
    }
  }

  /// Note de couverture honnête (vide = tout est inclus).
  String get coverageNote {
    final a = analytics;
    if (a == null) return '';
    final others = a.kpis.totalRows - a.kpis.salesCount;
    if (others == 0) return '';
    return 'KPI de montant limités aux ventes terminées · '
        '$others ligne(s) annulée(s)/retour/en attente exclue(s) des montants.';
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
