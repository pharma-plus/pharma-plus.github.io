/// Panneau détaillé de synchronisation hors-ligne.
///
/// Affiche :
///  - l'état de connexion (en ligne / hors-ligne / synchronisation / erreur) ;
///  - la date et l'heure de la dernière synchronisation réussie ;
///  - le nombre d'opérations en attente et en erreur ;
///  - la liste des opérations en attente (replay de la file d'attente) ;
///  - les actions : synchroniser maintenant, exporter/importer une sauvegarde.
///
/// Ce widget est conçu pour être affiché dans un dialogue ou une page dédiée,
/// accessible depuis l'indicateur de connexion ou le menu.
library;

import 'package:flutter/material.dart';

import '../../core/services/connection_status_service.dart';
import '../../core/services/offline_store.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/colors.dart';

/// Panneau détaillé de synchronisation (état, file d'attente, sauvegarde).
class SyncStatusPanel extends StatefulWidget {
  const SyncStatusPanel({super.key});

  @override
  State<SyncStatusPanel> createState() => _SyncStatusPanelState();
}

class _SyncStatusPanelState extends State<SyncStatusPanel> {
  final ConnectionStatusService _svc = ConnectionStatusService.instance;
  final SyncEngine _sync = SyncEngine.instance;
  final OfflineStore _store = OfflineStore.instance;

  List<Map<String, dynamic>> _pending = [];
  bool _syncing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPending();
    _svc.statusStream.listen((_) => setState(() {}));
  }

  Future<void> _loadPending() async {
    try {
      _pending = await _store.pending(limit: 100);
    } catch (_) {
      _pending = <Map<String, dynamic>>[];
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _statusMessage = 'Synchronisation en cours…';
    });
    try {
      final result = await _sync.sync(verbose: true);
      setState(() {
        _syncing = false;
        _statusMessage = result.hasIssues
            ? '${result.flushed} envoyée(s), ${result.failed} échec(s), ${result.conflicts.length} conflit(s)'
            : 'Synchronisation terminée (${result.flushed} opération(s))';
      });
      await _loadPending();
    } catch (e) {
      setState(() {
        _syncing = false;
        _statusMessage = 'Erreur : $e';
      });
    }
  }

  Future<void> _exportBackup() async {
    try {
      final json = await _store.exportBackupJson();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _BackupDialog(
          title: 'Exporter la sauvegarde',
          json: json,
          onCopy: () {},
        ),
      );
    } catch (e) {
      setState(() => _statusMessage = 'Erreur export : $e');
    }
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer une sauvegarde'),
        content: const Text(
          'Collez le contenu JSON de votre fichier de sauvegarde. '
          'Cette opération écrase les données locales actuelles.',
        ),
        contentTextStyle: const TextStyle(fontSize: 13),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Demander le JSON dans un second dialogue.
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contenu JSON de la sauvegarde'),
        content: SizedBox(
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: 20,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Collez ici le JSON exporté…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (json == null || json.isEmpty || !mounted) return;

    // Valider avant d'appliquer.
    final (valid, count, message) = await _store.validateBackupJson(json);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
      return;
    }

    final restored = await _store.importBackupJson(json);
    setState(() {
      _syncing = false;
      _statusMessage = '$restored clé(s) restaurée(s)';
    });
    await _loadPending();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$restored élément(s) importé(s)'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _svc.currentState;
    final color = _statusColor(state.status);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Synchronisation hors-ligne'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte d'état
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusLabel(state.status),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.serverReachable) ...[
                    Text(
                      'Serveur : accessible',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Serveur : inaccessible (mode hors-ligne)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (state.lastSyncAt != null)
                    Text(
                      'Dernière sync : ${_formatTime(state.lastSyncAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  if (state.pendingCount > 0)
                    Text(
                      '${state.pendingCount} opération(s) en attente',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF1D58A),
                      ),
                    ),
                  if (state.failedCount > 0)
                    Text(
                      '${state.failedCount} opération(s) en échec',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE94545),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions principales
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(_syncing ? 'Synchronisation…' : 'Synchroniser maintenant'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Exporter sauvegarde'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _syncing
                  ? const Center(child: CircularProgressIndicator())
                  : _pending.isEmpty
                      ? _EmptyState(message: _statusMessage.isNotEmpty ? _statusMessage : 'Aucune opération en attente.')
                      : _PendingList(
                          pending: _pending,
                          onRetry: _syncNow,
                          onLoadPending: _loadPending,
                        ),
            ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importBackup,
        icon: const Icon(Icons.upload, size: 20),
        label: const Text('Importer'),
      ),
    );
  }

  Color _statusColor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.online:
        return const Color(0xFF2FB563);
      case ConnectionStatus.offline:
        return const Color(0xFFF1A53A);
      case ConnectionStatus.syncing:
        return const Color(0xFF2E7D32);
      case ConnectionStatus.syncError:
        return const Color(0xFFE94545);
    }
  }

  String _statusLabel(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.online:
        return 'En ligne';
      case ConnectionStatus.offline:
        return 'Hors connexion — travail local';
      case ConnectionStatus.syncing:
        return 'Synchronisation…';
      case ConnectionStatus.syncError:
        return 'Erreur de synchronisation';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Liste des opérations en attente de synchronisation.
class _PendingList extends StatelessWidget {
  final List<Map<String, dynamic>> pending;
  final VoidCallback onRetry;
  final VoidCallback onLoadPending;

  const _PendingList({
    required this.pending,
    required this.onRetry,
    required this.onLoadPending,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: pending.length,
      itemBuilder: (context, i) {
        final op = pending[i];
        final method = op['method'] ?? '';
        final path = op['path'] ?? '';
        final attempts = op['attempts'] ?? 0;
        final lastError = op['last_error'] ?? '';
        final String createdAt = op['created_at'] as String? ?? '';
        final conflict = lastError != null && lastError.toString().contains('conflit');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: conflict
                ? Border.all(color: const Color(0xFFE94545).withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: conflict ? const Color(0xFFE94545) : const Color(0xFFF1A53A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$method $path',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'tentative #${attempts + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (createdAt.isNotEmpty)
                Text(
                  'Créé le $createdAt',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              if (lastError is String && lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Dernière erreur : $lastError',
                    style: TextStyle(
                      fontSize: 10,
                      color: conflict
                          ? const Color(0xFFE94545)
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// État vide.
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF2FB563)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialogue d'export de sauvegarde (affiche le JSON pour copie).
class _BackupDialog extends StatelessWidget {
  final String title;
  final String json;
  final VoidCallback onCopy;

  const _BackupDialog({
    required this.title,
    required this.json,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        height: 300,
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copiez ce contenu et enregistrez-le dans un fichier :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
