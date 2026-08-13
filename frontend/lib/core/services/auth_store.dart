import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Gestion centralisée de la session : jetons, utilisateur, base URL,
/// mode sombre et langue (persistés).
class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kAccess = 'pmg_access_token';
  static const _kRefresh = 'pmg_refresh_token';
  static const _kUser = 'pmg_user';
  static const _kTheme = 'pmg_theme_mode';
  static const _kLocale = 'pmg_locale';
  static const _kBaseUrl = 'pmg_base_url';

  String? _accessToken;
  String? _refreshToken;
  User? _user;
  bool _initialized = false;

  String _baseUrl = 'http://localhost:4000/api/v1';
  ThemeMode _themeMode = ThemeMode.system;
  String _locale = 'fr';

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  User? get user => _user;
  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get isInitialized => _initialized;

  String get baseUrl => _baseUrl;
  ThemeMode get themeMode => _themeMode;
  String get locale => _locale;

  /// Restaure la session persistée au démarrage.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_kTheme),
        orElse: () => ThemeMode.system,
      );
      _locale = prefs.getString(_kLocale) ?? 'fr';
      _baseUrl = prefs.getString(_kBaseUrl) ?? _baseUrl;

      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
      final userRaw = await _storage.read(key: _kUser);
      if (userRaw != null) {
        _user = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[AuthStore] init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, _baseUrl);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, locale);
    notifyListeners();
  }

  /// Enregistre la session après connexion / 2FA / refresh.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _user = user;
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
    notifyListeners();
  }

  /// Une seule tentative de rafraîchissement du jeton.
  Future<bool> tryRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
      await saveSession(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        user: User.fromJson(data['user'] as Map<String, dynamic>),
      );
      return true;
    } catch (e) {
      debugPrint('[AuthStore] refresh error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
    notifyListeners();
  }
}
