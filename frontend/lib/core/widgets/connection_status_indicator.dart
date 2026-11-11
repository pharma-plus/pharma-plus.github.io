/// Indicateur permanent et discret de l'état de connexion PHARMA+.
///
/// Affiche :
///  - EN LIGNE (serveur accessible) — point vert ;
///  - HORS CONNEXION (travail local) — point orange ;
///  - SYNCHRONISATION (transfert en cours) — point bleu animé ;
///  - EN ATTENTE (opérations non synchronisées) — point orange avec badge ;
///  - ERREUR DE SYNCHRONISATION (intervention nécessaire) — point rouge.
///
/// En dessous : date de dernière synchronisation réussie et nombre d'opérations
/// en attente (si > 0).
///
/// Ce widget est conçu pour être placé dans la barre supérieure ou le footer
/// sans masquer le contenu principal.
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/services/connection_status_service.dart';
import '../../core/widgets/sync_status_panel.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  /// Position de l'indicateur : topBar (barre supérieure) ou bottom (bas d'écran).
  final ConnectionStatusIndicatorPosition position;
  /// Afficher le texte détaillé (dernière sync, opérations en attente).
  final bool showDetails;
  final double iconSize;

  const ConnectionStatusIndicator({
    super.key,
    this.position = ConnectionStatusIndicatorPosition.topBar,
    this.showDetails = true,
    this.iconSize = 14,
  });

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

enum ConnectionStatusIndicatorPosition { topBar, bottom }

class _ConnectionStatusIndicatorState
    extends State<ConnectionStatusIndicator> {
  final ConnectionStatusService _svc = ConnectionStatusService.instance;

  Color _statusColor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.online:
        return AppColors.sageGreen;
      case ConnectionStatus.offline:
        return AppColors.champagne;
      case ConnectionStatus.syncing:
        return AppColors.sageGreen;
      case ConnectionStatus.syncError:
        return AppColors.danger;
    }
  }

  IconData _statusIcon(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.online:
        return Icons.cloud_done_rounded;
      case ConnectionStatus.offline:
        return Icons.wifi_off_rounded;
      case ConnectionStatus.syncing:
        return Icons.sync_rounded;
      case ConnectionStatus.syncError:
        return Icons.error_outline_rounded;
    }
  }

  String _statusLabel(ConnectionStatus s, BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnState>(
      stream: _svc.statusStream,
      initialData: _svc.currentState,
      builder: (context, snap) {
        final state = snap.data ?? _svc.currentState;
        final color = _statusColor(state.status);
        final icon = _statusIcon(state.status);
        final label = _statusLabel(state.status, context);

        final details = <Widget>[];
        if (widget.showDetails) {
          if (state.lastSyncAt != null) {
            details.add(Text(
              'Dernière sync : ${_formatTime(state.lastSyncAt!)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ));
          }
          if (state.pendingCount > 0) {
            details.add(Text(
              '${state.pendingCount} opération(s) en attente',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.champagneLight,
              ),
            ));
          }
          if (state.failedCount > 0) {
            details.add(Text(
              '${state.failedCount} échec(s)',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.danger,
              ),
            ));
          }
        }

        final children = <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.iconSize + 4,
                height: widget.iconSize + 4,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: state.status == ConnectionStatus.syncing
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: AppColors.porcelain.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: widget.iconSize,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ];
        children.addAll(details);

        return GestureDetector(
          onTap: () => _openSyncPanel(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.graphite.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.porcelain.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        );
      },
    );
  }

  void _openSyncPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncStatusPanel()),
    );
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
