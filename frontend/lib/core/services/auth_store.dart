import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'offline_store.dart';
import '../../features/shell/shell_nav.dart';

/// Gestion centralisée de la session : jetons, utilisateur, base URL,
/// mode sombre et langue (persistés).
class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Stockage des jetons : sur le Web, `flutter_secure_storage` repose sur
  /// `dart:html`/`package:js` (incompatible Wasm, persistance fragile).
  /// Repli non-destructif : `SharedPreferences` (localStorage) sur Web,
  /// stockage sécurisé natif sur mobile/desktop. Aucune API modifiée.
  static Future<String?> _tokenRead(String key) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      } catch (_) {
        return null;
      }
    }
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  static Future<void> _tokenWrite(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  static Future<void> _tokenDelete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }
  static const _kAccess = 'pmg_access_token';
  static const _kRefresh = 'pmg_refresh_token';
  static const _kUser = 'pmg_user';
  static const _kTheme = 'pmg_theme_mode';
  static const _kLocale = 'pmg_locale';
  static const _kBaseUrl = 'pmg_base_url';

  /// Temps avant verrouillage automatique (en minutes).
  static const int _defaultInactivityMinutes = 15;
  int _inactivityMinutes = _defaultInactivityMinutes;
  Timer? _inactivityTimer;

  /// Durée d'inactivité avant verrouillage (en minutes).
  /// 0 = désactivé.
  int get inactivityMinutes => _inactivityMinutes;

  set inactivityMinutes(int value) {
    if (value < 0) value = 0;
    if (value == _inactivityMinutes) return;
    _inactivityMinutes = value;
    if (_inactivityMinutes > 0) {
      resetInactivityTimer();
      _startInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
    notifyListeners();
  }

  /// Indique si le minuteur d'inactivité est actif.
  bool get isInactivityTimerActive => _inactivityTimer != null;

  /// Dernière activité détectée (timestamp).
  DateTime? _lastActivity;

  String? _accessToken;
  String? _refreshToken;
  User? _user;
  bool _initialized = false;
  bool _initError = false;
  bool _forcedLogin = false;

  /// Permissions utilisateur (déjà présentes via enrichProfile)
  Set<String> get permissions => _user?.permissions ?? {};
  bool get isSuperAdmin => _user?.isSuperAdmin ?? false;

  /// Filtres d'accès par rôle (additifs, aucune suppression destructive)
  bool get canViewStock => isSuperAdmin || permissions.contains('stock:view');
  bool get canViewSales => isSuperAdmin || permissions.contains('sales:view');
  bool get canViewCustomers => isSuperAdmin || permissions.contains('customers:view');
  bool get canViewCatalog => isSuperAdmin || permissions.contains('catalog:view');
  bool get canViewSettings => isSuperAdmin || permissions.contains('settings:view');
  bool get canViewEmployees => isSuperAdmin || permissions.contains('employees:view');
  bool get canViewUsers => isSuperAdmin || permissions.contains('users:view');
  bool get canViewReports => isSuperAdmin || permissions.contains('reports:view');

  /// URL par défaut : si l'app web est servie depuis localhost / 127.0.0.1
  /// (développement local), on cible le backend local (port 4000) ;
  /// sinon on utilise l'API distante (Supabase / Bonto).
  static String get _defaultBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isLocal =
          host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '::1';
      if (isLocal) return 'http://127.0.0.1:4000/api/v1';
    }
    return 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';
  }

  String _baseUrl = _defaultBaseUrl;
  ThemeMode _themeMode = ThemeMode.system;
  String _locale = 'fr';

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  User? get user => _user;
  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get isInitialized => _initialized;
  bool get initError => _initError;

  String get baseUrl => _baseUrl;
  ThemeMode get themeMode => _themeMode;
  String get locale => _locale;

  /// Restaure la session persistée au démarrage.
  /// Garde-fou : toute l'initialisation est bornée à 12 s maximum.
  Future<void> init() async {
    try {
      debugPrint('[PHARMA+] AuthStore.init() debute');
      await _doInit().timeout(const Duration(seconds: 12));
      debugPrint(
          '[PHARMA+] AuthStore._doInit() termine, isAuthenticated=$isAuthenticated');
    } catch (e) {
      debugPrint('[AuthStore] init error: $e');
      final isMissingPlugin = e is MissingPluginException;
      if (!_forcedLogin && !isMissingPlugin) _initError = true;
    } finally {
      debugPrint('[PHARMA+] AuthStore.init() finally, _initialized=$_initialized, _forcedLogin=$_forcedLogin');
      if (!_forcedLogin) {
        _initialized = true;
        notifyListeners();
      } else if (_accessToken != null && _user != null) {
        // Course 8 s / 12 s : le splash a forcé l'affichage du Login pendant
        // que _doInit restaurait la session. Sans ce notify, l'utilisateur
        // restait bloqué sur Login avec un jeton valide. On bascule maintenant.
        notifyListeners();
      }
    }
  }

  Future<void> _doInit() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    _locale = prefs.getString(_kLocale) ?? 'fr';
    final storedUrl = prefs.getString(_kBaseUrl);
    if (storedUrl != null && storedUrl.isNotEmpty) {
      // L'URL choisie dans les paramètres (⚙) est respectée, y compris
      // une URL locale (http://127.0.0.1:4000/api/v1) en développement.
      _baseUrl = storedUrl;
    }

    _accessToken = await _tokenRead(_kAccess);
    _refreshToken = await _tokenRead(_kRefresh);
    final userRaw = await _tokenRead(_kUser);
    if (userRaw != null) {
      _user = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
    }
  }

  /// Réessaie l'initialisation après une erreur.
  Future<void> retryInit() async {
    _initError = false;
    _initialized = false;
    notifyListeners();
    await init();
  }

  /// Passe outre une erreur d'initialisation sans session : sûr car on
  /// n'est pas authentifié → on va vers la page de connexion.
  void continueToLogin() {
    if (_initialized) return;
    _forcedLogin = true;
    _initError = false;
    _initialized = true;
    notifyListeners();
  }

  /// Forcé par le Splash si l'init ne termine jamais : garantit qu'on
  /// n'affiche jamais un chargement infini (→ page de connexion).
  void forceProceedToLogin() {
    if (_initialized) return;
    _forcedLogin = true;
    _initError = false;
    _initialized = true;
    notifyListeners();
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
    final previousPharmacyId = _user?.pharmacyId;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _user = user;
    _locked = false;
    _manualLock = false;
    await _tokenWrite(_kAccess, accessToken);
    await _tokenWrite(_kRefresh, refreshToken);
    await _tokenWrite(_kUser, jsonEncode(user.toJson()));
    // Changement de pharmacie (poste partagé) : purge le cache catalogue pour
    // qu'aucun produit de l'ancienne pharmacie ne soit visible hors-ligne.
    if (previousPharmacyId != null &&
        previousPharmacyId != user.pharmacyId) {
      try {
        await OfflineStore.instance.clearCatalog();
      } catch (_) {}
    }
    // Au login, démarrer le minuteur d'inactivité.
    // FIX : _lastActivity doit être initialisé SINON la condition
    // `_lastActivity != null` dans le timer échoue toujours →
    // verrouillage automatique JAMAIS déclenché.
    _lastActivity = DateTime.now();
    _startInactivityTimer();
    notifyListeners();
  }

  /// Démarre le minuteur de verrouillage inactivité.
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_lastActivity != null &&
          DateTime.now().difference(_lastActivity!).inMinutes >= _inactivityMinutes) {
        lockSession();
      }
    });
  }

  bool _locked = false;
  bool _manualLock = false;

  /// Vrai quand l'application est verrouillée (écran PIN affiché).
  bool get isLocked => _locked;

  /// Vrai si le verrouillage a été demandé par l'utilisateur (bouton)
  /// et non par l'inactivité (seul ce dernier interdit l'annulation).
  bool get isManualLock => _manualLock;

  /// Verrouille l'application. L'état LOCAL est posé AVANT tout appel
  /// réseau : une panne de connexion ne doit jamais laisser l'écran
  /// utilisable. L'appel API trace l'événement en audit (best-effort,
  /// borné par un timeout pour ne pas figer l'interface).
  Future<void> lockSession({bool manual = false}) async {
    if (_locked) return;
    _manualLock = manual;
    _locked = true;
    _lastActivity = null; // évite un re-verrouillage en boucle
    notifyListeners();
    if (_accessToken == null) return;
    try {
      await ApiClient.instance
          .post('/auth/lock')
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[AuthStore] lock audit error: $e');
    }
  }

  /// Déverrouille après validation du PIN (appelé par LockScreen).
  void unlock() {
    if (!_locked) return;
    _locked = false;
    _manualLock = false;
    resetInactivityTimer();
    notifyListeners();
  }

  /// Le serveur a refusé une requête car la session est verrouillée (423) :
  /// c'est le cas si l'application a redémarré alors que la session était
  /// verrouillée côté serveur. Pose l'état LOCAL pour afficher l'écran PIN
  /// (sans re-appeler /auth/lock, la session l'est déjà). L'utilisateur
  /// déverrouille ensuite par PIN → /auth/pin/verify → le serveur retire
  /// locked_at.
  void serverLocked() {
    if (_locked) return;
    _manualLock = false;
    _locked = true;
    _lastActivity = null;
    notifyListeners();
  }

  /// Réinitialise le minuteur d'inactivité (appelé à chaque interaction utilisateur).
  void resetInactivityTimer() {
    _lastActivity = DateTime.now();
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
    _locked = false;
    _manualLock = false;
    // Arrêter le minuteur d'inactivité
    _inactivityTimer?.cancel();
    ShellNav.index.value = 0;
    // Purge le cache catalogue local : aucune donnée produit ne doit survivre
    // au logout sur un poste partagé (prévention de fuite hors-ligne).
    try {
      await OfflineStore.instance.clearCatalog();
    } catch (_) {}
    await _tokenDelete(_kAccess);
    await _tokenDelete(_kRefresh);
    await _tokenDelete(_kUser);
    notifyListeners();
  }
}