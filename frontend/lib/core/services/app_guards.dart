import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'unsaved_changes_guard.dart';

/// Fermeture reelle de l'application / du conteneur, si la plateforme
/// le permet (Android : SystemNavigator ; Web : window.close()).
Future<void> closeAppOrContainer() async {
  if (kIsWeb) {
    try {
      await SystemNavigator.pop(animated: true);
    } catch (_) {}
  } else {
    await SystemNavigator.pop();
  }
}

/// Dialogue "Voulez-vous quitter PHARMA+ ?" -- Rester / Quitter.
/// Appele UNIQUEMENT depuis le dashboard racine (bouton retour Android /
/// tentative de fermeture) : jamais pendant la navigation interne.
Future<bool> confirmQuitApp(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Voulez-vous quitter PHARMA+ ?'),
      content: const Text(
          'La navigation interne ne ferme jamais l\'application : ce message '
          'n\'apparait que depuis le Tableau de bord.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Rester'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Quitter'),
        ),
      ],
    ),
  );
  if (leave == true) await closeAppOrContainer();
  return leave ?? false;
}

/// Dialogue de DECONNEXION -- Annuler / Se deconnecter.
/// Distinct du bouton retour et de la fermeture de l'application.
Future<bool> confirmSignOut(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Voulez-vous vous deconnecter de PHARMA+ ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Se deconnecter'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Widget qui enveloppe une page/formulaire et gere le retour
/// (bouton Android, geste, fleche UI, bouton retour navigateur)
/// avec verification des modifications non enregistrees.
///
/// Usage:
/// ```dart
/// class MyFormPage extends StatefulWidget {
///   @override State<MyFormPage> createState() => _MyFormPageState();
/// }
///
/// class _MyFormPageState extends State<MyFormPage>
///     with UnsavedChangesGuard {
///   @override
///   Widget build(BuildContext context) {
///     return UnsavedChangesPopScope(
///       hasUnsavedChanges: hasUnsavedChanges,
///       onWillPop: canPopWithUnsavedCheck,
///       child: Scaffold(...),
///     );
///   }
/// }
/// ```
class UnsavedChangesPopScope extends StatelessWidget {
  final bool hasUnsavedChanges;
  final Future<bool> Function(BuildContext) onWillPop;
  final Widget child;

  const UnsavedChangesPopScope({
    super.key,
    required this.hasUnsavedChanges,
    required this.onWillPop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!hasUnsavedChanges) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        final confirmed = await onWillPop(context);
        if (confirmed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

/// Point d'entree unique pour le retour systeme (bouton Android, geste,
/// fleche UI, bouton retour navigateur).
/// Retourne true si le retour a ete gere (ne pas propager), false sinon.
Future<bool> handleSystemBack(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    // Il y a une route a fermer (dialogue, bottom sheet, sous-page)
    // On laisse le PopScope local gerer les changements non enregistres.
    nav.pop();
    return true;
  }
  // Aucune route a pop : on est au niveau racine (shell)
  // La logique shell (Dashboard vs onglet) est dans app.dart / system_back_guard_web.dart
  return false;
}