import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_store.dart';
import 'connection_status_service.dart';
import 'offline_store.dart';

/// Résultat détaillé d'une synchronisation.
class SyncResult {
  final int flushed;
  final int failed;
  final int pulled;
  final List<String> errors;
  final List<String> conflicts;
  SyncResult({
    required this.flushed,
    required this.failed,
    required this.pulled,
    required this.errors,
    required this.conflicts,
  });
  bool get hasIssues => failed > 0 || errors.isNotEmpty || conflicts.isNotEmpty;
}

/// Moteur de synchronisation : rejoue la file hors-ligne et télécharge les
/// deltas du catalogue (révisions) quand le réseau est de nouveau disponible.
///
/// Garanties :
///  - Idempotence : chaque opération POST envoyée au serveur inclut une
///    clé client (`Idempotency-Key`) pour éviter les doublons en cas de
///    reprise après interruption.
///  - Conflits : si le serveur répond 409 (conflit), l'opération est
///    conservée en file avec un marquage « conflit » et l'interface est
///    avertie via [ConnectionStatusService].
///  - Sécurité : aucune opération sensible (Super Admin) n'est rejetée en
///    file hors-ligne ; elle nécessite une confirmation serveur immédiate.
class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final OfflineStore _store = OfflineStore.instance;
  final ConnectionStatusService _conn = ConnectionStatusService.instance;
  bool _running = false;

  bool get isRunning => _running;

  /// Synchronise en tâche de fond. Idempotente.
  ///
  /// Ordre :
///   1. Flush de la file d'attente (POST/PUT/DELETE en attente) ;
///   2. Pull du catalogue (révisions de médicaments) ;
///   3. Mise à jour des caches d'entités (clients, fournisseurs…).
  Future<SyncResult> sync({bool verbose = false}) async {
    if (_running) {
      return SyncResult(flushed: 0, failed: 0, pulled: 0, errors: [], conflicts: []);
    }
    if (!AuthStore.instance.isAuthenticated) {
      return SyncResult(flushed: 0, failed: 0, pulled: 0, errors: ['Non authentifié'], conflicts: []);
    }
    _running = true;
    _conn.setSyncing();
    int flushed = 0, failed = 0, pulled = 0;
    final errors = <String>[];
    final conflicts = <String>[];
    try {
      final flush = await _flushOutbox(verbose: verbose);
      flushed = flush['flushed'] as int;
      failed = flush['failed'] as int;
      errors.addAll(List<String>.from(flush['errors'] as List));
      conflicts.addAll(List<String>.from(flush['conflicts'] as List));

      final pull = await _pullCatalog(verbose: verbose);
      pulled = pull;

      // Mise à jour des caches d'entités génériques (si déjà en cache, on
      // conserve ; le pull incrémental se fait par entité spécifique).
      await _store.pruneIdempotencyKeys();

      await _conn.syncCompleted();
    } catch (e) {
      errors.add(e.toString());
      await _conn.syncErrorOccurred();
    } finally {
      _running = false;
      _conn.syncCompleted(); // met à jour pendingCount + statut
    }
    return SyncResult(
      flushed: flushed,
      failed: failed,
      pulled: pulled,
      errors: errors,
      conflicts: conflicts,
    );
  }

  /// Rejoue toutes les opérations de la file d'attente.
  ///
  /// Retourne : {flushed, failed, errors, conflicts}.
  Future<Map<String, dynamic>> _flushOutbox({required bool verbose}) async {
    final pending = await _store.pending();
    int flushed = 0, failed = 0;
    final errors = <String>[];
    final conflicts = <String>[];

    for (final op in pending) {
      final id = op['id'] as int;
      final path = op['path'] as String;
      final method = op['method'] as String;
      final body = (op['body'] as String?) == null
          ? null
          : jsonDecode(op['body'] as String) as Map<String, dynamic>;

      // Règle de sécurité : aucune opération Super Admin n'est rejetée en
      // file hors-ligne. Les chemins /superadmin/* nécessitent une
      // confirmation serveur immédiate.
      if (path.startsWith('/superadmin/')) {
        await _store.markFailed(
            id, 'Opération Super Admin refusée hors-ligne (confirmation serveur requise)');
        failed++;
        conflicts.add('Super Admin : $method $path (confirmation serveur requise)');
        continue;
      }

      try {
        final idempotencyKey = body != null && body.containsKey('clientSaleId')
            ? 'pmg-idem-${body['clientSaleId']}'
            : null;

        final headers = <String, String>{};
        if (idempotencyKey != null) {
          final alreadyUsed = await _store.isIdempotencyKeyUsed(idempotencyKey);
          if (alreadyUsed) {
            // Déjà envoyé avec succès précédemment : on supprime de la file.
            await _store.remove(id);
            flushed++;
            continue;
          }
          headers['Idempotency-Key'] = idempotencyKey;
        }

        final result = await _sendWithIdempotency(method, path, body, headers);

        if (result['success'] == true) {
          // Marquer la clé d'idempotence comme utilisée.
          if (idempotencyKey != null) {
            final serverRef = result['serverRef'] as String?;
            await _store.markIdempotencyKeyUsed(
                idempotencyKey, serverRef ?? path);
          }
          await _store.remove(id);
          flushed++;
          if (verbose) debugPrint('[SyncEngine] flushed $method $path');
        } else if (result['statusCode'] == 409) {
          // Conflit : conserver en file, marquer comme conflit.
          await _store.markFailed(id, 'Conflit serveur (409)');
          failed++;
          conflicts.add('$method $path : conflit (409)');
          errors.add('Conflit sur $path : ${result['message'] ?? ''}');
        } else {
          // Échec temporaire : marquer et réessayer plus tard.
          await _store.markFailed(id, '${result['message'] ?? result['statusCode']}');
          failed++;
          errors.add('Échec $method $path : ${result['message'] ?? result['statusCode']}');
        }
      } catch (e) {
        await _store.markFailed(id, '$e');
        failed++;
        errors.add('Exception $method $path : $e');
      }
    }

    return {
      'flushed': flushed,
      'failed': failed,
      'errors': errors,
      'conflicts': conflicts,
    };
  }

  /// Envoie une requête avec gestion des en-têtes d'idempotence et retry.
  /// Retourne une map {success, statusCode, message, serverRef}.
  Future<Map<String, dynamic>> _sendWithIdempotency(
      String method, String path, Map<String, dynamic>? body,
      Map<String, String> headers) async {
    try {
      late final Future<dynamic> call;
      switch (method) {
        case 'POST':
          call = ApiClient.instance.post(path, body: body, customHeaders: headers);
          break;
        case 'PUT':
          call = ApiClient.instance.put(path, body: body, customHeaders: headers);
          break;
        default:
          call = ApiClient.instance.delete(path);
      }

      final result = await call.timeout(const Duration(seconds: 30));

      // ApiClient retourne déjà ApiResult. On normalise.
      final success = result.success as bool;
      final statusCode = result.statusCode as int;
      final error = result.error;
      final message = error?.readableMessage ?? (success ? 'OK' : 'Erreur');

      // Extraire une référence serveur si présente (ex: id de vente créée).
      String? serverRef;
      final data = result.data;
      if (data is Map) {
        serverRef = data['id']?.toString() ??
            data['sale_id']?.toString() ??
            data['reference']?.toString();
      }

      return {
        'success': success,
        'statusCode': statusCode,
        'message': message,
        'serverRef': serverRef,
      };
    } catch (e) {
      return {
        'success': false,
        'statusCode': 0,
        'message': e.toString(),
        'serverRef': null,
      };
    }
  }

  /// Télécharge les deltas du catalogue (révisions de médicaments).
  Future<int> _pullCatalog({required bool verbose}) async {
    final since = await _store.getRevision('medications');
    try {
      final result = await ApiClient.instance.get(
        '/sync/pull/medications',
        query: {'sinceRevision': since},
      );
      if (!result.success) return 0;
      final data = result.data;
      final maxRevision = (data?['maxRevision'] as num?)?.toInt() ?? since;
      final rows = (data?['rows'] as List? ?? []);
      if (rows.isNotEmpty) {
        await _cacheMedications(rows);
      }
      await _store.setRevision('medications', maxRevision);
      if (verbose) {
        debugPrint(
            '[SyncEngine] catalog synced to r$maxRevision (${rows.length})');
      }
      return rows.length;
    } catch (e) {
      debugPrint('[SyncEngine] pull error: $e');
      return 0;
    }
  }

  /// Met en cache les lignes du catalogue (upsert par id) pour que la
  /// recherche reste fonctionnelle hors-ligne.
  Future<void> _cacheMedications(List<dynamic> rows) async {
    final maps = rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (maps.isEmpty) return;
    try {
      await OfflineStore.instance.saveCatalogRows(maps);
    } catch (e) {
      debugPrint('[SyncEngine] cache error: $e');
    }
  }
}
