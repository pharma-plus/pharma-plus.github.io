import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// File d'attente hors-ligne (SQLite).
/// Les opérations critiques (ventes, mouvements de stock) sont mises en file
/// quand le réseau est indisponible, puis rejouées par [SyncEngine].
class OfflineStore {
  OfflineStore._();

  static final OfflineStore instance = OfflineStore._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'pmg_offline.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_sales (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_state (
            entity TEXT PRIMARY KEY,
            last_revision INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  /// Ajoute une opération différée.
  Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final db = await _database;
    await db.insert('outbox', {
      'method': method,
      'path': path,
      'body': body == null ? null : _json(body),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> pending({int limit = 50}) async {
    final db = await _database;
    return db.query('outbox', orderBy: 'id ASC', limit: limit);
  }

  Future<void> remove(int id) async {
    final db = await _database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailed(int id, String error) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<void> savePendingSale(String id, Map<String, dynamic> payload) async {
    final db = await _database;
    await db.insert(
        'pending_sales',
        {
          'id': id,
          'payload': _json(payload),
          'created_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> pendingSales() async {
    final db = await _database;
    return db.query('pending_sales',
        where: 'synced = 0', orderBy: 'created_at ASC');
  }

  Future<void> markSaleSynced(String id) async {
    final db = await _database;
    await db
        .rawUpdate('UPDATE pending_sales SET synced = 1 WHERE id = ?', [id]);
  }

  Future<int> getRevision(String entity) async {
    final db = await _database;
    final rows =
        await db.query('sync_state', where: 'entity = ?', whereArgs: [entity]);
    if (rows.isEmpty) return 0;
    return (rows.first['last_revision'] as int?) ?? 0;
  }

  Future<void> setRevision(String entity, int revision) async {
    final db = await _database;
    await db.insert('sync_state', {'entity': entity, 'last_revision': revision},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String _json(Map<String, dynamic> map) {
    try {
      return const JsonCodec().encode(map);
    } catch (_) {
      return '{}';
    }
  }
}
