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
  static const _kLocalMode = 'pmg_local_mode';

  /// URL par défaut de l'application (API distante).
  static String get _defaultBaseUrl =>
      'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

  /// URL du backend local (mode local PHARMA+).
  static const _localBaseUrl = 'http://127.0.0.1:4001/api/v1';

  /// Mode local optionnel revendiqué par le client (persisté en SharedPreferences).
  bool _localMode = false;

  /// Indique si l'application fonctionne en mode local (backend 127.0.0.1:4001).
  bool get isLocalMode => _localMode;

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

  /// Single-flight : un seul renouvellement de jeton a la fois. Les
  /// requetes concurrentes qui arrivent avec un token expire partagent
  /// le meme resultat, evitant la rotation multiple du refresh token
  /// (cause racine des boucles 401 / "JWT invalide ou expire").
  static Future<bool>? _refreshing;

  /// Empêche plusieurs signOut concurrents (plusieurs POST /auth/logout
  /// en parallel sur des requêtes 401 simultanées).
  bool _signingOut = false;

  /// Vrai dès que la lecture des jetons persistés a eu lieu dans `_doInit`.
  /// Le splash sonde ce drapeau pour ne JAMAIS forcer un passage à la
  /// connexion pendant la restauration d'une session stockée : forcer
  /// maintenant rendrait un espace (Client ou Super Admin) à partir d'un
  /// profil à moitié initialisé — cause du "double dashboard" (flash
  /// Super Admin puis retour Client) au rafraîchissement de page.
  bool _restoreTokensLoaded = false;

  /// Permissions utilisateur (déjà présentes via enrichProfile)
  Set<String> get permissions => _user?.permissions ?? {};
  bool get isSuperAdmin => _user?.isSuperAdmin ?? false;

  /// Filtres d'accès par rôle (additifs, aucune suppression destructive)
  bool get canViewStock => isSuperAdmin || permissions.contains('stock:view');
  bool get canViewSales => isSuperAdmin || permissions.contains('sales:view');
  bool get canViewCustomers =>
      isSuperAdmin || permissions.contains('customers:view');
  bool get canViewCatalog =>
      isSuperAdmin || permissions.contains('catalog:view');
  bool get canViewSettings =>
      isSuperAdmin || permissions.contains('settings:view');
  bool get canViewEmployees =>
      isSuperAdmin || permissions.contains('employees:view');
  bool get canViewUsers => isSuperAdmin || permissions.contains('users:view');
  bool get canViewReports =>
      isSuperAdmin || permissions.contains('reports:view');

  /// Visibilité d'un module par l'utilisateur connecté.
  /// `visibleModules == null` → tous les modules visibles (défaut).
  /// `visibleModules == []` → aucun module visible.
  /// Sinon → seul les modules listés sont visibles.
  bool canSeeModule(String key) {
    // SÉCURITÉ : le module 'superadmin_crm' est réservé au Super Admin.
    // Un `visibleModules == null` (non renseigné côté serveur) ne doit
    // JAMAIS ouvrir les fonctions d'administration d'envergure — sinon
    // un simple client voit le portail Super Admin apparaître dans son
    // menu puis est renvoyé au Dashboard Client (page qui disparaît).
    if (key == 'superadmin_crm') return isSuperAdmin;
    if (isSuperAdmin) return true;
    final modules = _user?.visibleModules;
    if (modules == null) return true;
    return modules.contains(key);
  }

  /// Bascule entre mode local et mode distant.
  /// En mode local, l'URL du backend est http://127.0.0.1:4001/api/v1.
  Future<void> setLocalMode(bool enabled) async {
    _localMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalMode, enabled);
    _baseUrl = enabled ? _localBaseUrl : _defaultBaseUrl;
    _baseSource = enabled ? 'local' : 'default';
    notifyListeners();
  }

  String _baseUrl = _defaultBaseUrl;

  /// Source de l'URL effective après `_doInit` : `default` (URL distante
  /// par défaut), `stored` (valeur persistée `pmg_base_url`), ou `local`
  /// (mode local forcé). Diagnostic non sensible, sans jeton.
  String _baseSource = 'default';
  String get baseSource => _baseSource;

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
  /// Un verrou interne empêche les appels concurrents à `init()`.
  static Future<void>? _initializing;

  Future<void> init() async {
    if (_initialized) return;
    if (_initializing != null) {
      // Un appel à init() est déjà en cours : on attend sa fin.
      return _initializing!;
    }
    _initializing = _runInit();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _runInit() async {
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
      debugPrint(
          '[PHARMA+] AuthStore.init() finally, _initialized=$_initialized, _forcedLogin=$_forcedLogin');
      // Toujours marquer l'initialisation comme terminée pour débloquer
      // RootGate (sortie du splash vers la page de connexion ou d'erreur).
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _doInit() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    _locale = prefs.getString(_kLocale) ?? 'fr';
    _localMode = prefs.getBool(_kLocalMode) ?? false;
    final storedUrl = prefs.getString(_kBaseUrl);
    if (_localMode) {
      _baseUrl = _localBaseUrl;
      _baseSource = 'local';
    } else if (storedUrl != null && storedUrl.isNotEmpty) {
      // L'URL choisie dans les paramètres (⚙) est respectée, y compris
      // une URL locale (http://127.0.0.1:4000/api/v1) en développement.
      // Normalisation : aucun '/' final (évite //sales côté ApiClient).
      _baseUrl = storedUrl.trim();
      while (_baseUrl.endsWith('/')) {
        _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
      }
      _baseSource = 'stored';
    } else {
      _baseUrl = _defaultBaseUrl;
      _baseSource = 'default';
    }

    _accessToken = await _tokenRead(_kAccess);
    _refreshToken = await _tokenRead(_kRefresh);
    final userRaw = await _tokenRead(_kUser);
    // Les jetons sont connus : le splash peut désormais décider s'il y a
    // quelque chose à restaurer (cf. splashProbe).
    _restoreTokensLoaded = true;
    if (userRaw != null) {
      // Restauration : toute valeur admin stockée localement est
      // rétrogradée en « inconnu ». Seule une réponse serveur authentifiée
      // contenant explicitement is_super_admin peut autoriser le CRM
      // (un ancien `true` local ne constitue jamais une autorisation).
      _user = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>)
          .withoutAdminConfirmation();

      // Rafraîchir le profil utilisateur depuis le serveur pour détecter
      // les changements de rôle (ex: is_super_admin activé en base).
      if (_accessToken != null) {
        User? serverUser;
        try {
          final userResult = await ApiClient.instance.getCurrentUser();
          if (userResult.success && userResult.data != null) {
            serverUser = userResult.data! as User;
          }
        } catch (e) {
          debugPrint(
              '[AuthStore] Impossible de rafraîchir le profil utilisateur: $e');
          // Erreur réseau : le profil local reste utilisé pour l'affichage,
          // sans confirmation admin (dégradation gracieuse, jamais un
          // privilège accordé depuis une valeur locale).
        }
        final User merged = _user!.applyServerConfirmation(serverUser);
        if (!identical(merged, _user)) {
          // Profil serveur complet (champ admin explicite, true OU false)
          // : on adopte la valeur confirmée et on la persiste.
          _user = merged;
          await _tokenWrite(_kUser, jsonEncode(merged.toJson()));
          notifyListeners();
        } else if (serverUser == null ||
            serverUser.isSuperAdminFlag == null) {
          // Réponse absente ou contrat incomplet : le profil local est
          // conservé pour l'affichage mais SANS confirmation admin. On ne
          // réécrit PAS le stockage (aucune destruction inutile de données,
          // aucun faux false enregistré comme valeur serveur confirmée).
          debugPrint(
              '[AuthStore] /auth/me contrat incomplet : statut admin non confirmé, accès CRM refusé jusqu\'à confirmation serveur');
        }
      }
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

  /// Sondé périodiquement par l'écran de démarrage (`_SplashScreen`) :
  /// débloque la page de connexion UNIQUEMENT quand il n'y a strictement
  /// rien à restaurer. Si une session stockée existe, RootGate restera
  /// sur le splash jusqu'à ce que `_doInit` se termine (bornée à 12 s) :
  /// l'espace (Client ou Super Admin) n'est rendu qu'avec un profil
  /// complet et confirmé par le serveur — plus aucune bascule erronée
  /// entre les deux dashboards pendant l'initialisation.
  void splashProbe() {
    if (_initialized) return;
    if (!_restoreTokensLoaded) return; // restauration en cours : attendre
    if (_accessToken != null || _user != null) return; // session présente
    forceProceedToLogin();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/$'), '');
    _baseSource = 'stored';
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
    // Les trois écritures sont indépendantes. En parallèle, elles évitent
    // d'ajouter trois allers-retours localStorage avant l'affichage du shell.
    await Future.wait([
      _tokenWrite(_kAccess, accessToken),
      _tokenWrite(_kRefresh, refreshToken),
      _tokenWrite(_kUser, jsonEncode(user.toJson())),
    ]);
    // Changement de pharmacie (poste partagé) : purge le cache catalogue pour
    // qu'aucun produit de l'ancienne pharmacie ne soit visible hors-ligne.
    if (previousPharmacyId != null && previousPharmacyId != user.pharmacyId) {
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
          DateTime.now().difference(_lastActivity!).inMinutes >=
              _inactivityMinutes) {
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
  /// Contrat serveur : `{ accessToken, refreshToken, user }` (profil
  /// assaini, aligné sur /auth/login, /auth/me et la fonction Edge).
  /// Une réponse SANS profil n'est JAMAIS considérée comme une
  /// authentification réussie : la session est refusée.
  ///
  /// Single-flight : si un renouvellement est déjà en cours, tous les
  /// appelants partagent le même résultat (évite la rotation concurrente
  /// du refresh token et les boucles 401).
  Future<bool> tryRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;

    // Un renouvellement est déjà en cours : tous les appelants
    // partagent le même résultat.
    if (_refreshing != null) {
      return await _refreshing!;
    }

    final completer = Completer<bool>();
    _refreshing = completer.future;

    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        completer.complete(false);
        return false;
      }
      final decoded = jsonDecode(res.body);
      final data = decoded is Map<String, dynamic>
          ? decoded['data']
          : null;
      if (data is! Map<String, dynamic>) {
        completer.complete(false);
        return false;
      }
      final userJson = data['user'];
      if (userJson is! Map<String, dynamic>) {
        completer.complete(false);
        return false;
      }
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      if (accessToken is! String || refreshToken is! String) {
        completer.complete(false);
        return false;
      }
      await saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: User.fromJson(userJson),
      );
      completer.complete(true);
      return true;
    } catch (e) {
      debugPrint('[AuthStore] refresh error: $e');
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> signOut() async {
    // Empêche plusieurs signOut concurrents (requêtes 401 simultanées).
    if (_signingOut) return;
    _signingOut = true;
    try {
      // Meilleur effort : révoquer la session côté serveur AVANT de purger le
      // local. Les erreurs réseau ne doivent pas empêcher le logout local.
      final token = _accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$_baseUrl/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
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
    } finally {
      _signingOut = false;
    }
  }
}
