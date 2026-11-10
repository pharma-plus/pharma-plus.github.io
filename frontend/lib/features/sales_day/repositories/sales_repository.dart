/// ============================================================
/// VENTES DU JOUR — Repository du module (indépendant du POS)
/// ============================================================
/// Source de vérité : routes officielles de la passerelle PHARMA+
/// (authentification JWT + sessionActive + RBAC sales:view côté
/// passerelle) :
///   GET /sales/day?from=&to=&offsetMin=
///   GET /sales/day/transactions?from=&to=&page=&limit=&status=&search=
///
/// Aucune donnée inventée : ce que l'API n'expose pas est laissé
/// indisponible pour l'UI (« — », « Non disponible »).
/// Renouvellement proactif du JWT (best-effort, single-flight) avant le
/// 1er appel + 1 seul retry sur réseau indisponible — identique au
/// comportement éprouvé du module ventes précédent. Aucun retry sur
/// 401/403/4xx/5xx (pas de boucles).
/// ============================================================

import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';

class SalesTransactionQuery {
  final int page;
  final int limit;
  /// '' (toutes) | 'completed' | 'problems' (annulées/retours/en attente)
  final String status;
  final String search;

  const SalesTransactionQuery({
    this.page = 1,
    this.limit = 50,
    this.status = '',
    this.search = '',
  });
}

class SalesRepository {
  SalesRepository._();
  static final SalesRepository instance = SalesRepository._();

  /// Vrai si le jeton est absent de forme valide, expiré ou sur le point
  /// d'expirer (durée [within]) — renouvellement préventif uniquement.
  static bool isTokenExpiringSoon(
    String? token, {
    Duration within = const Duration(seconds: 60),
    DateTime? now,
  }) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      final exp = decoded['exp'];
      if (exp is! num) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);
      final reference = now ?? DateTime.now().toUtc();
      return expiry.isBefore(reference.add(within));
    } catch (_) {
      return false;
    }
  }

  /// Devise inutile si le JWT est encore valide : best-effort, jamais
  /// bloquant (une erreur ici n'altère pas la requête suivante).
  Future<void> _ensureFreshToken() async {
    try {
      final token = AuthStore.instance.accessToken;
      final hasRefresh = AuthStore.instance.refreshToken != null;
      if (token != null && hasRefresh && isTokenExpiringSoon(token)) {
        await AuthStore.instance.tryRefresh();
      }
    } catch (_) {
      // ignore : si le refresh échoue, la requête présentera l'erreur.
    }
  }

  Future<ApiResult<dynamic>> _getOnce(
    String path,
    Map<String, String> query,
  ) =>
      ApiClient.instance.get(path, query: query, timeout: const Duration(seconds: 25));

  Future<ApiResult<dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    await _ensureFreshToken();
    var res = await _getOnce(path, query);
    if (!res.success &&
        res.statusCode <= 0 &&
        (res.error?.code == 'NETWORK_ERROR' || res.error?.code == 'TIMEOUT')) {
      await Future.delayed(const Duration(milliseconds: 800));
      res = await _getOnce(path, query);
    }
    return res;
  }

  // ------------------------------------------------------------------
  // KPIs + graphiques
  // ------------------------------------------------------------------
  Future<(SalesDayAnalytics?, SalesDayFailure?)> loadAnalytics(
    SalesDateRange range, {
    required int offsetMinutes,
  }) async {
    final res = await _get('/sales/day', {
      'from': isoLocal(range.start),
      'to': isoLocal(range.end),
      'offsetMin': '$offsetMinutes',
    });
    if (!res.success) return (null, _mapError(res));
    // ApiClient expose déjà le champ `data` du corps (déballé).
    // Réponse incomplète (data absent ou non objet) → KPIs à zéro,
    // jamais d'erreur bloquante : l'affiche reste honnête (« — »).
    final data = res.data;
    if (data is! Map || data.isEmpty) {
      return (
        const SalesDayAnalytics(
          kpis: SalesDayKpis(
            grossRevenue: 0,
            netRevenue: 0,
            taxTotal: 0,
            discountsTotal: 0,
            salesCount: 0,
            averageBasket: 0,
            cancelledCount: 0,
            returnedCount: 0,
            paidAmount: 0,
            outstandingAmount: 0,
            refundedAmount: null,
            costTotal: 0,
            totalRows: 0,
          ),
          hourly: const [],
          payments: const [],
          topProducts: const [],
        ),
        null,
      );
    }
    return (
      SalesDayAnalytics.fromJson(Map<String, dynamic>.from(data)),
      null,
    );
  }

  // ------------------------------------------------------------------
  // Transactions paginées + filtres
  // ------------------------------------------------------------------
  Future<(SalesTransactionsPage?, SalesDayFailure?)> loadTransactions(
    SalesDateRange range,
    SalesTransactionQuery q, {
    required int offsetMinutes,
  }) async {
    final query = <String, String>{
      'from': isoLocal(range.start),
      'to': isoLocal(range.end),
      'page': '${q.page}',
      'limit': '${q.limit}',
      'offsetMin': '$offsetMinutes',
    };
    if (q.status.isNotEmpty) query['status'] = q.status;
    if (q.search.trim().isNotEmpty) query['search'] = q.search.trim();
    final res = await _get('/sales/day/transactions', query);
    if (!res.success) return (null, _mapError(res));
    // ApiClient expose déjà data (liste) et meta du corps.
    final List<Map<String, dynamic>> rows = (res.data is List ? res.data as List : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final meta = res.meta is Map ? Map<String, dynamic>.from(res.meta as Map) : const<Map, dynamic>{};
    final page = meta['page'] is num ? (meta['page'] as num).toInt() : q.page;
    final limit = meta['limit'] is num ? (meta['limit'] as num).toInt() : q.limit;
    final total =
        meta['total'] is num ? (meta['total'] as num).toInt() : rows.length;
    return (
      SalesTransactionsPage(
        rows: rows.map(SalesTransaction.fromJson).toList(),
        totalServer: total,
        page: page,
        limit: limit,
      ),
      null,
    );
  }

  SalesDayFailure _mapError(ApiResult<dynamic> result) {
    final e = result.error;
    final code = e?.code ?? 'UNKNOWN';
    final status = result.statusCode;
    String detail = '';
    if (e != null && e.details.isNotEmpty) {
      final d = e.details.first['diagnostic'];
      if (d is String) detail = ' | $d';
    }
    String rawMsg = e?.message ?? '';
    if (rawMsg.length > 220) rawMsg = rawMsg.substring(0, 220);
    final cleanMsg = rawMsg.replaceAll('\n', ' | ').replaceAll('\r', ' ');
    final tech = status > 0
        ? '$code HTTP $status$detail'
        : '$code$detail | cause=$cleanMsg';
    if (status == 400 || code == 'VALIDATION' || code == 'BAD_REQUEST') {
      return SalesDayFailure(
        kind: SalesDayErrorKind.validation,
        message: e?.message ?? 'Requête invalide',
        technical: tech,
      );
    }
    if (status == 401 ||
        status == 423 ||
        code == 'SESSION_EXPIRED' ||
        code == 'UNAUTHORIZED' ||
        code == 'SESSION_LOCKED') {
      return SalesDayFailure(
        kind: SalesDayErrorKind.sessionExpired,
        message: e?.message ?? 'Session expirée',
        technical: tech,
      );
    }
    if (status == 403 || code == 'FORBIDDEN') {
      return SalesDayFailure(
        kind: SalesDayErrorKind.forbidden,
        message: e?.message ?? 'Accès refusé',
        technical: tech,
      );
    }
    if (status >= 500) {
      return SalesDayFailure(
        kind: SalesDayErrorKind.serverError,
        message: e?.message ?? 'Erreur serveur',
        technical: tech,
      );
    }
    if (code == 'TIMEOUT') {
      return SalesDayFailure(
        kind: SalesDayErrorKind.timeout,
        message: 'Délai d\u2019attente dépassé',
        technical: tech,
      );
    }
    if (code == 'NETWORK_ERROR' || status == 0) {
      return SalesDayFailure(
        kind: SalesDayErrorKind.network,
        message: e?.message ?? 'Connexion impossible',
        technical: tech,
      );
    }
    return SalesDayFailure(
      kind: SalesDayErrorKind.unknown,
      message: e?.message ?? 'Erreur inconnue',
      technical: tech,
    );
  }
}
