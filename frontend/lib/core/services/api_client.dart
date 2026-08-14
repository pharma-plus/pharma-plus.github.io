import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_store.dart';

/// Résultat d'API normalisé par le backend.
class ApiResult<T> {
  final bool success;
  final T? data;
  final Map<String, dynamic>? meta;
  final ApiError? error;
  final int statusCode;

  ApiResult._(this.success, this.data, this.meta, this.error, this.statusCode);

  factory ApiResult.fromResponse(http.Response res) {
    final decoded = _safeDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = decoded?['data'];
      final meta = decoded?['meta'];
      return ApiResult._(
        true,
        data as T?,
        meta == null ? null : Map<String, dynamic>.from(meta as Map),
        null,
        res.statusCode,
      );
    }
    final err = decoded?['error'];
    return ApiResult._(
      false,
      null,
      null,
      ApiError.fromMap(
        err == null ? {} : Map<String, dynamic>.from(err as Map),
        res.statusCode,
      ),
      res.statusCode,
    );
  }
}

class ApiError {
  final String code;
  final String message;
  final List<Map<String, dynamic>> details;
  final int statusCode;

  ApiError(this.code, this.message, this.details, this.statusCode);

  factory ApiError.fromMap(Map<String, dynamic> map, int statusCode) =>
      ApiError(
        map['code']?.toString() ?? 'INTERNAL_ERROR',
        map['message']?.toString() ?? 'Erreur inconnue',
        (map['details'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        statusCode,
      );

  String get readableMessage {
    if (details.isNotEmpty) {
      return details.map((d) => '• ${d['message']}').join('\n');
    }
    return message;
  }

  @override
  String toString() => '$code ($statusCode): $message';
}

Map<String, dynamic>? _safeDecode(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  } catch (_) {
    return {'data': null};
  }
}

/// Bonto (hébergement gratuit) endort le conteneur à l'inactivité. Au
/// réveil, il renvoie une page HTML « Starting container » (statut 200)
/// au lieu du JSON attendu. On la détecte pour attendre et réessayer.
bool _isWakePage(String body) {
  final t = body.trim().toLowerCase();
  if (t.startsWith('<!doctype') || t.startsWith('<html')) {
    return t.contains('waking up') ||
        t.contains('starting container') ||
        t.contains('starting pharma') ||
        t.contains('bonto');
  }
  return false;
}

/// Client HTTP central : injecte le jeton, gère le renouvellement de session
/// et la file hors-ligne.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final AuthStore _auth = AuthStore.instance;
  http.Client? _client;

  static const Duration timeout = Duration(seconds: 25);

  String? get baseUrl => _auth.baseUrl;

  http.Client get _http => _client ??= http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl ?? 'http://localhost:4000/api/v1';
    final uri = Uri.parse('$base$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = _auth.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<ApiResult<T>> get<T>(String path,
      {Map<String, dynamic>? query}) async {
    return _send(() => _http.get(_uri(path, query), headers: _headers()));
  }

  Future<ApiResult<T>> post<T>(String path,
      {Object? body, bool auth = true}) async {
    return _send(
      () => _http.post(
        _uri(path),
        headers: _headers(auth: auth),
        body: body is String ? body : jsonEncode(body ?? {}),
      ),
    );
  }

  Future<ApiResult<T>> put<T>(String path, {Object? body}) async {
    return _send(
      () => _http.put(_uri(path),
          headers: _headers(), body: jsonEncode(body ?? {})),
    );
  }

  Future<ApiResult<T>> delete<T>(String path) async {
    return _send(() => _http.delete(_uri(path), headers: _headers()));
  }

  /// Envoie la requête. Gère :
  ///  - le réveil du conteneur Bonto (page HTML « Starting ») en réessayant
  ///    jusqu'à ce que le JSON soit servi ;
  ///  - le renouvellement de session unique en cas de 401 ;
  ///  - les erreurs réseau / timeout.
  Future<ApiResult<T>> _send<T>(Future<http.Response> Function() request,
      {bool retried = false}) async {
    const maxWakeRetries = 10;
    const wakeDelay = Duration(seconds: 4);
    for (int attempt = 0; attempt <= maxWakeRetries; attempt++) {
      try {
        final res = await request().timeout(timeout);

        // Conteneur en cours de démarrage : on attend et on réessaie.
        if (_isWakePage(res.body)) {
          if (attempt < maxWakeRetries) {
            await Future.delayed(wakeDelay);
            continue;
          }
          return ApiResult._(
            false,
            null,
            null,
            ApiError(
              'SERVER_STARTING',
              'Le serveur démarre, veuillez patienter quelques secondes puis réessayer.',
              const [],
              0,
            ),
            0,
          );
        }

        if (res.statusCode == 401 && !retried) {
          final renewed = await _auth.tryRefresh();
          if (renewed) {
            return _send(request, retried: true);
          }
          _auth.signOut();
        }
        return ApiResult<T>.fromResponse(res);
      } on ApiResult<T> {
        rethrow;
      } catch (e) {
        final isTimeout = e is TimeoutException;
        final code = isTimeout ? 'TIMEOUT' : 'NETWORK_ERROR';
        final label = isTimeout
            ? 'Délai d’attente dépassé (le serveur ne répond pas).'
            : 'Connexion au serveur impossible.';
        return ApiResult._(
          false,
          null,
          null,
          ApiError(
            code,
            '$label\nCause technique : ${e.toString()}',
            const [],
            0,
          ),
          0,
        );
      }
    }
    return ApiResult._(
      false,
      null,
      null,
      ApiError('SERVER_STARTING',
          'Le serveur démarre, veuillez patienter puis réessayer.', const [], 0),
      0,
    );
  }
}
