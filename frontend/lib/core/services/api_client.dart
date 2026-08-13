import 'dart:convert';
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

  /// Envoie avec une seule tentative de renouvellement de session en cas de 401.
  Future<ApiResult<T>> _send<T>(Future<http.Response> Function() request,
      {bool retried = false}) async {
    try {
      final res = await request().timeout(timeout);
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
      return ApiResult._(
        false,
        null,
        null,
        ApiError(
            'NETWORK_ERROR',
            'Impossible de joindre le serveur. Vérifiez votre connexion.',
            const [],
            0),
        0,
      );
    }
  }
}
