import 'package:flutter/material.dart';

/// Navigation interne du [HomeShell] : les pages affichées dans l'IndexedStack
/// sont des routes racines (Navigator.canPop == false) — le bouton retour
/// automatique n'y apparaît donc pas. Elles demandent au shell de revenir au
/// Tableau de bord via ce notificateur global.
class ShellNav {
  ShellNav._();

  /// Index de la page affichée par le shell (0 = Tableau de bord).
  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  /// Retour au Tableau de bord depuis n'importe quelle page du shell.
  static void goHome() => index.value = 0;
}

/// Bouton HOME universel des pages — remplace la flèche retour :
/// · icône maison (retour au Tableau de bord) sur TOUTES les pages ;
/// · sous-page ouverte au-dessus (ex : scanner, plein écran) → pop
///   de CETTE sous-page d'abord (retour à la page elle-même) ;
/// · aucune sous-page → retour direct au Tableau de bord via [ShellNav].
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_rounded),
      tooltip: 'Tableau de bord',
      onPressed: () {
        // Retour GARANTI au Tableau de bord depuis n'importe quelle page :
        // on ferme d'abord toute sous-page poussée au-dessus du shell
        // (POS, scanner, catalogue...), puis on force l'index 0 du shell.
        // Un seul clic suffit, quel que soit l'état de la pile.
        Navigator.of(context).popUntil((route) => route.isFirst);
        ShellNav.goHome();
      },
    );
  }
}
