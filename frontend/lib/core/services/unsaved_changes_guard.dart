import 'package:flutter/material.dart';

/// Mixin pour les pages/formulaires avec modifications non enregistrées.
/// Utilisation : `with UnsavedChangesGuard`
/// - Définir `_hasUnsavedChanges = true` quand le formulaire est modifié.
/// - Appeler `markSaved()` quand l'utilisateur enregistre/valide.
/// - Le système retour (Android back, geste, flèche UI) affichera
///   automatiquement le dialogue si `_hasUnsavedChanges == true`.
mixin UnsavedChangesGuard<T extends StatefulWidget> on State<T> {
  bool _hasUnsavedChanges = false;

  /// Le formulaire a des modifications non sauvegardées.
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Marquer le formulaire comme modifié (appeler dans les onChanged).
  void markUnsaved() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// Marquer le formulaire comme sauvegardé (après POST réussi / validation).
  void markSaved() {
    if (_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = false);
    }
  }

  /// Réinitialiser l'état (quitter sans enregistrer forcé).
  void resetUnsaved() {
    _hasUnsavedChanges = false;
  }

  /// Dialogue standard "Modifications non enregistrées".
  /// Retourne true si l'utilisateur confirme quitter sans enregistrer.
  Future<bool> confirmUnsavedChanges(BuildContext context) async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text(
            'Vous avez des modifications non enregistrées. '
            'Voulez-vous quitter sans les sauvegarder ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer l\'édition'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter sans enregistrer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Vérifie si on peut quitter (pop) : vrai si pas de changements,
  /// ou si l'utilisateur confirme dans le dialogue.
  Future<bool> canPopWithUnsavedCheck(BuildContext context) async {
    if (!_hasUnsavedChanges) return true;
    return await confirmUnsavedChanges(context);
  }
}