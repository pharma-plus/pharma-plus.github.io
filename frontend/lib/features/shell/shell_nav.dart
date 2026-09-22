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

/// Bouton retour universel des sous-pages :
/// · flèche retour (arrow_back_ios_new) qui pop la sous-page ;
/// · si aucune sous-page dans la pile, retour au Tableau de bord.
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: 'Retour',
      onPressed: () {
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
        } else {
          final localNav = Navigator.of(context);
          if (localNav.canPop()) {
            localNav.pop();
          } else {
            ShellNav.goHome();
          }
        }
      },
    );
  }
}
