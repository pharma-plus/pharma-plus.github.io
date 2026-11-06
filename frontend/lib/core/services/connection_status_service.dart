/// Service de détection de connectivité pour le mode hors-ligne PHARMA+.
///
/// Fournit :
///  - l'état réseau actuel (en ligne / hors-ligne) via `connectivity` ;
///  - la disponibilité réelle du serveur (dernière requête API réussie) via `serverReachable` ;
///  - le nombre d'opérations en attente de synchronisation (`pendingCount`) ;
///  - la date et l'heure de la dernière synchronisation réussie (`lastSyncAt`) ;
///  - un flux (`statusStream`) permettant à l'interface de se réactualiser
///    automatiquement à chaque changement d'état.
///
/// Ce service ne fait pas de requêtes réseau lui-même : il est alimenté
/// par [AuthStore] (jetons), [OfflineStore] (file d'attente) et
/// [SyncEngine] (dernière synchro), ainsi que par les appels API effectués
/// via [ApiClient].
library;

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'auth_store.dart';
import 'offline_store.dart';

/// État de connexion affiché à l'utilisateur.
enum ConnectionStatus {
  /// Serveur joignable, toutes les opérations passent normalement.
  online,
  /// Réseau coupé : l'application travaille en local, les opérations sont
  /// mises en file d'attente.
  offline,
  /// Synchronisation en cours (replay de la file d'attente + pull catalogue).
  syncing,
  /// Certaines opérations n'ont pas pu être envoyées au serveur.
  syncError,
}

/// Résultat d'un test de reachability serveur.
class ServerReachability {
  final bool reachable;
  final String? lastError;
  final DateTime? checkedAt;
  ServerReachability({
    required this.reachable,
    this.lastError,
    this.checkedAt,
  });
}

/// État agrégé de connexion.
class ConnState {
  final ConnectionStatus status;
  final bool serverReachable;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final int failedCount;
  const ConnState({
    required this.status,
    required this.serverReachable,
    required this.pendingCount,
    required this.lastSyncAt,
    required this.failedCount,
  });
  bool get hasPending => pendingCount > 0;
  bool get hasErrors => failedCount > 0;
}

/// Service unique de suivi de la connexion et de la synchronisation.
class ConnectionStatusService {
  ConnectionStatusService._();
  static final ConnectionStatusService instance = ConnectionStatusService._();

  final AuthStore _auth = AuthStore.instance;
  final OfflineStore _store = OfflineStore.instance;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _kLastSyncAt = 'pmg_last_sync_at';
  static const _kLastServerOk = 'pmg_last_server_ok';
  static const _kSyncFailedCount = 'pmg_sync_failed_count';

  final StreamController<ConnState> _controller =
      StreamController<ConnState>.broadcast();
  Stream<ConnState> get statusStream => _controller.stream;

  ConnectionStatus _status = ConnectionStatus.online;
  bool _serverReachable = true;
  int _pendingCount = 0;
  DateTime? _lastSyncAt;
  int _failedCount = 0;
  Timer? _pollTimer;

  bool get isOnline => _status == ConnectionStatus.online &&
      _serverReachable;

  /// Initialise le service : lit les préférences, lance le polling de
  /// reachabilité et s'abonne aux changements d'authentification.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _lastSyncAt = _readLastSyncAt();
    _failedCount = _prefs!.getInt(_kSyncFailedCount) ?? 0;
    _refreshPendingCount();
    _status = _serverReachable
        ? ConnectionStatus.online
        : ConnectionStatus.offline;

    // Réévaluer la reachabilité serveur à intervalles réguliers.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkServerReachability(silent: true);
    });

    // À chaque changement d'état d'authentification, réévaluer.
    _auth.addListener(_onAuthChanged);
    await _checkServerReachability(silent: true);
    _notify();
  }

  void _onAuthChanged() {
    _refreshPendingCount();
    _notify();
  }

  /// Vérifie si le serveur est joignable (requête légère /auth/me ou /health).
  /// En cas d'échec, passe en mode hors-ligne.
  Future<void> checkServerReachability() async {
    await _checkServerReachability(silent: false);
  }

  Future<void> _checkServerReachability({required bool silent}) async {
    // On utilise l'endpoint /auth/me léger qui nécessite déjà un jeton.
    // Si pas de jeton, on considère le serveur comme injoignable pour
    // les opérations privées (mais l'app peut rester en mode public).
    final token = _auth.accessToken;
    if (token == null || token.isEmpty) {
      // Pas de session : on ne peut pas tester /auth/me.
      // On s'appuie sur la dernière réussite connue.
      final lastOk = _readLastServerOk();
      final now = DateTime.now();
      final reachable = lastOk != null &&
          now.difference(lastOk).inMinutes < 30;
      if (_serverReachable != reachable) {
        _serverReachable = reachable;
        _updateStatus();
      }
      if (!silent) _notify();
      return;
    }

    try {
      final result = await ApiClient.instance
          .get('/auth/me')
          .timeout(const Duration(seconds: 8));
      final now = DateTime.now();
      final reachable = result.success;
      if (reachable) {
        await _prefs?.setString(
            _kLastServerOk, now.toIso8601String());
      }
      if (_serverReachable != reachable) {
        _serverReachable = reachable;
        _updateStatus();
      }
    } catch (_) {
      if (_serverReachable) {
        _serverReachable = false;
        _updateStatus();
      }
    }
    if (!silent) _notify();
  }

  /// Nombre d'opérations en attente dans la file d'attente hors-ligne.
  Future<int> _refreshPendingCount() async {
    try {
      final pending = await _store.pending(limit: 100);
      _pendingCount = pending.length;
    } catch (_) {
      _pendingCount = 0;
    }
    return _pendingCount;
  }

  DateTime? _readLastSyncAt() {
    try {
      final raw = _prefs?.getString(_kLastSyncAt);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _readLastServerOk() {
    try {
      final raw = _prefs?.getString(_kLastServerOk);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Marque une synchronisation réussie : met à jour la date et remet le
  /// compteur d'erreurs à zéro.
  Future<void> markSyncSuccess() async {
    final now = DateTime.now();
    _lastSyncAt = now;
    _failedCount = 0;
    await _prefs?.setString(_kLastSyncAt, now.toIso8601String());
    await _prefs?.setInt(_kSyncFailedCount, 0);
    await _refreshPendingCount();
    _updateStatus();
    _notify();
  }

  /// Marque une échec de synchronisation : incrémente le compteur.
  Future<void> markSyncFailed() async {
    _failedCount = (_prefs?.getInt(_kSyncFailedCount) ?? 0) + 1;
    await _prefs?.setInt(_kSyncFailedCount, _failedCount);
    await _refreshPendingCount();
    _updateStatus();
    _notify();
  }

  /// Notifie les abonnés de l'interface.
  void _notify() {
    if (_controller.isClosed) return;
    _controller.add(ConnState(
      status: _status,
      serverReachable: _serverReachable,
      pendingCount: _pendingCount,
      lastSyncAt: _lastSyncAt,
      failedCount: _failedCount,
    ));
  }

  void _updateStatus() {
    if (!_serverReachable) {
      _status = ConnectionStatus.offline;
    } else if (_pendingCount > 0) {
      _status = ConnectionStatus.syncing;
    } else if (_failedCount > 0) {
      _status = ConnectionStatus.syncError;
    } else {
      _status = ConnectionStatus.online;
    }
  }

  /// Appelé par SyncEngine au début d'une synchronisation.
  void setSyncing() {
    _status = ConnectionStatus.syncing;
    _notify();
  }

  /// Appelé par SyncEngine à la fin d'une synchronisation réussie.
  Future<void> syncCompleted() async {
    await markSyncSuccess();
  }

  /// Appelé par SyncEngine à la fin d'une synchronisation en échec.
  Future<void> syncErrorOccurred() async {
    await markSyncFailed();
  }

  /// État actuel (snapshots).
  ConnState get currentState => ConnState(
    status: _status,
    serverReachable: _serverReachable,
    pendingCount: _pendingCount,
    lastSyncAt: _lastSyncAt,
    failedCount: _failedCount,
  );

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
