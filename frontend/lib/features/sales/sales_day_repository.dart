import 'dart:convert';

import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';

/// ---------------------------------------------------------------------------
/// SALES DAY — Repository indépendant (PHASE Ventes du jour)
/// ---------------------------------------------------------------------------
/// Source unique de vérité pour l'écran Ventes du jour : ne dépend ni du POS
/// ni du dashboard. Utilise les routes réellement présentes en production :
///   GET /sales?limit=&page=&from=&to=  (JWT + sessionActive + RBAC sales:view)
///
/// Données honnêtes : la route ne renvoie que
///   id, total, created_at, status, branch_id  (status = 'completed' filtré)
/// Les champs indisponibles (paiements, remises, produits, lignes) ne sont
/// JAMAIS inventés : le repository expose des indicateurs `available` pour
/// que l'UI affiche « — » avec une note explicative.
/// ---------------------------------------------------------------------------

/// Erreur différenciée pour l'écran Ventes du jour.
enum SalesDayErrorKind {
  network,
  timeout,
  sessionExpired,
  forbidden,
  serverError,
  unknown,
}

class SalesDayError {
  final SalesDayErrorKind kind;
  final String message;
  final String technical;

  const SalesDayError({
    required this.kind,
    required this.message,
    required this.technical,
  });

  /// Message court adapté à la situation (jamais mensonger).
  String get userMessage {
    switch (kind) {
      case SalesDayErrorKind.network:
        return 'Connexion impossible — vérifiez votre connexion puis réessayez.';
      case SalesDayErrorKind.timeout:
        return 'Le serveur met trop de temps à répondre. Réessayez.';
      case SalesDayErrorKind.sessionExpired:
        return 'Session expirée — veuillez vous reconnecter.';
      case SalesDayErrorKind.forbidden:
        return 'Accès refusé : votre compte n\'a pas la permission ventes (sales:view).';
      case SalesDayErrorKind.serverError:
        return 'Erreur serveur — réessayez dans un instant.';
      case SalesDayErrorKind.unknown:
        return message;
    }
  }
}

/// Résultat de chargement d'une période donnée.
class SalesDayResult {
  final List<Map<String, dynamic>> rows;
  final int totalServer;
  final bool isComplete;
  final SalesDayError? error;

  const SalesDayResult({
    required this.rows,
    required this.totalServer,
    required this.isComplete,
    required this.error,
  });
}

/// Agrégats calculés UNIQUEMENT à partir des lignes réellement chargées.
class SalesDayAggregates {
  final double revenue;
  final int count;
  final double average;
  final int cancelledCount;
  final bool hasPaymentBreakdown;
  final double? paidAmount;
  final double? unpaidAmount;
  final int? partialCount;
  final double? totalDiscounts;
  final int? productsSold;
  final List<HourBucket> hourly;
  final int coverageLoaded;
  final int coverageTotal;

  const SalesDayAggregates({
    required this.revenue,
    required this.count,
    required this.average,
    required this.cancelledCount,
    required this.hasPaymentBreakdown,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.partialCount,
    required this.totalDiscounts,
    required this.productsSold,
    required this.hourly,
    required this.coverageLoaded,
    required this.coverageTotal,
  });
}

class HourBucket {
  final String label;
  final double revenue;
  final int count;

  const HourBucket({required this.label, required this.revenue, required this.count});
}

/// Repository indépendant de l'écran Ventes du jour.
class SalesDayRepository {
  SalesDayRepository._();
  static final SalesDayRepository instance = SalesDayRepository._();

  /// Charge une page de ventes pour [from] (inclus) → [to] (exclu).
  /// [fromIso]/[toIso] doivent déjà être en ISO avec décalage local.
  Future<SalesDayResult> _loadPageOnce({
    required String fromIso,
    required String toIso,
    required int page,
    required int limit,
  }) async {
    final result = await ApiClient.instance.get(
      '/sales',
      query: {'limit': limit, 'page': page, 'from': fromIso, 'to': toIso},
      timeout: const Duration(seconds: 20),
    );
    if (!result.success) {
      return const SalesDayResult(
        rows: [],
        totalServer: 0,
        isComplete: false,
        error: null,
      ).withError(_mapError(result));
    }
    final rows = ApiList.of(result.data);
    final total = ApiList.total(result.data, result.meta);
    return SalesDayResult(
      rows: rows,
      totalServer: total,
      isComplete: rows.length >= total,
      error: null,
    );
  }

  /// Vrai si le jeton d'accès JWT est absent de forme valide, expiré ou
  /// recommandé dans moins de [within] (défaut 60 s). Ne vérifie PAS la
  /// signature : il sert uniquement à décider d'un renouvellement proactif
  /// avant le premier appel, pour ne pas dépendre d'un 401 que la
  /// passerelle peut renvoyer sans CORS (bloqué par le navigateur).
  static bool isTokenExpiringSoon(String? token, {Duration within = const Duration(seconds: 60), DateTime? now}) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      final exp = decoded['exp'];
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);
      final reference = now ?? DateTime.now().toUtc();
      return expiry.isBefore(reference.add(within));
    } catch (_) {
      return false;
    }
  }

  Future<SalesDayResult> loadPage({
    required String fromIso,
    required String toIso,
    required int page,
    required int limit,
  }) async {
    // Renouvellement proactif UNIQUEMENT pour ce module : si le JWT est
    // expiré ou sur le point d'expirer, on le renouvelle avant le premier
    // appel (tryRefresh est single-flight). Sans cela, une passerelle qui
    // rejette le JWT expiré sans CORS bloque la lecture du 401 et le
    // client ne peut jamais renouveler (NETWORK_ERROR persistant).
    // Best-effort : un échec ici ne bloque pas l'appel (erreur affichée).
    try {
      final token = AuthStore.instance.accessToken;
      if (token != null && AuthStore.instance.refreshToken != null && isTokenExpiringSoon(token)) {
        await AuthStore.instance.tryRefresh();
      }
    } catch (_) {
      // Ignore : l'appel ci-dessous affichera l'erreur éventuelle.
    }
    var res = await _loadPageOnce(fromIso: fromIso, toIso: toIso, page: page, limit: limit);
    // Sur NETWORK_ERROR seulement : on retente UNE fois après un court délai.
    // Aucun retry sur 401/403/500 pour éviter les boucles de session/RBAC.
    if (res.error != null && res.error!.kind == SalesDayErrorKind.network) {
      await Future.delayed(const Duration(milliseconds: 800));
      res = await _loadPageOnce(fromIso: fromIso, toIso: toIso, page: page, limit: limit);
    }
    return res;
  }

  SalesDayError _mapError(ApiResult<dynamic> result) {
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
    if (status == 401 || status == 423 || code == 'SESSION_EXPIRED' || code == 'UNAUTHORIZED' || code == 'SESSION_LOCKED') {
      return SalesDayError(
        kind: SalesDayErrorKind.sessionExpired,
        message: e?.message ?? 'Session expirée',
        technical: tech,
      );
    }
    if (status == 403 || code == 'FORBIDDEN') {
      return SalesDayError(
        kind: SalesDayErrorKind.forbidden,
        message: e?.message ?? 'Accès refusé',
        technical: tech,
      );
    }
    if (status >= 500) {
      return SalesDayError(
        kind: SalesDayErrorKind.serverError,
        message: e?.message ?? 'Erreur serveur',
        technical: tech,
      );
    }
    if (code == 'TIMEOUT') {
      return SalesDayError(
        kind: SalesDayErrorKind.timeout,
        message: 'Délai d\u2019attente dépassé',
        technical: tech,
      );
    }
    if (code == 'NETWORK_ERROR' || status == 0) {
      return SalesDayError(
        kind: SalesDayErrorKind.network,
        message: e?.message ?? 'Connexion impossible',
        technical: tech,
      );
    }
    return SalesDayError(
      kind: SalesDayErrorKind.unknown,
      message: e?.message ?? 'Erreur inconnue',
      technical: tech,
    );
  }

  static double _amount(dynamic v) =>
      v == null ? 0 : (num.tryParse('$v') ?? 0).toDouble();

  /// Agrégats honnêtes : ne calcule que ce que la route fournit réellement.
  SalesDayAggregates aggregate(
    List<Map<String, dynamic>> rows, {
    required int totalServer,
    required bool byHour,
  }) {
    final completed = rows.where((s) => (s['status'] ?? '') == 'completed').toList();
    final revenue = completed.fold(0.0, (sum, s) => sum + _amount(s['total']));
    final count = completed.length;
    final average = count == 0 ? 0.0 : revenue / count;

    // La route /sales ne renvoie NI paiements, NI remises, NI lignes :
    // les indicateurs correspondants restent indisponibles (jamais inventés).
    const hasPayment = false;

    final buckets = <String, HourBucket>{};
    for (final s in completed) {
      final ts = s['created_at']?.toString() ?? '';
      if (ts.length < 13) continue;
      final key = byHour ? ts.substring(11, 13) : ts.substring(5, 10);
      final prev = buckets[key];
      buckets[key] = HourBucket(
        label: byHour ? '${key}h' : key,
        revenue: (prev?.revenue ?? 0) + _amount(s['total']),
        count: (prev?.count ?? 0) + 1,
      );
    }
    final sorted = buckets.values.toList()..sort((a, b) => a.label.compareTo(b.label));

    return SalesDayAggregates(
      revenue: revenue,
      count: count,
      average: average,
      cancelledCount: rows.length - count,
      hasPaymentBreakdown: hasPayment,
      paidAmount: null,
      unpaidAmount: null,
      partialCount: null,
      totalDiscounts: null,
      productsSold: null,
      hourly: sorted,
      coverageLoaded: rows.length,
      coverageTotal: totalServer,
    );
  }
}

/// Extension privée pour construire un résultat d'erreur.
extension _SalesDayResultX on SalesDayResult {
  SalesDayResult withError(SalesDayError error) => SalesDayResult(
        rows: rows,
        totalServer: totalServer,
        isComplete: isComplete,
        error: error,
      );
}
