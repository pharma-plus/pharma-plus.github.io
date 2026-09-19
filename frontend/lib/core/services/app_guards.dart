import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fermeture réelle de l'application / du conteneur, si la plateforme
/// le permet (Android : SystemNavigator ; Web : window.close()).
Future<void> closeAppOrContainer() async {
  if (kIsWeb) {
    // Web : tentative de fermeture du conteneur (souvent bloquée par le
    // navigateur si l'onglet n'a pas été ouvert par script) — sans danger.
    try {
      await SystemNavigator.pop(animated: true);
    } catch (_) {}
  } else {
    await SystemNavigator.pop();
  }
}

/// Dialogue "Voulez-vous quitter PHARMA+ ?" — Rester / Quitter.
/// Appelé UNIQUEMENT depuis le dashboard racine (bouton retour Android /
/// tentative de fermeture) : jamais pendant la navigation interne.
Future<bool> confirmQuitApp(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Voulez-vous quitter PHARMA+ ?'),
      content: const Text(
          'La navigation interne ne ferme jamais l\'application : ce message '
          'n\'apparaît que depuis le Tableau de bord.'),
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

/// Dialogue de DÉCONNEXION — Annuler / Se déconnecter.
/// Distinct du bouton retour et de la fermeture de l'application.
Future<bool> confirmSignOut(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Voulez-vous vous déconnecter de PHARMA+ ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Garde du bouton retour Android/PC :
/// · sous-page ouverte → pop normal de cette sous-page ;
/// · page racine (dashboard / espace employé) → dialogue quitter.
/// La navigation interne entre les pages NE FERME JAMAIS l'application.
Future<bool> handleAppBack(BuildContext context, bool atRoot) async {
  if (!atRoot) return false; // pop normal de la sous-page
  await confirmQuitApp(context);
  return true;
}
