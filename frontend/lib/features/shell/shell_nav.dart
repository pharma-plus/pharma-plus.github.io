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

/// Bouton retour universel des pages :
/// · page poussée depuis le dashboard → pop normal du Navigator ;
/// · page racine du shell (IndexedStack) → retour au dashboard via [ShellNav].
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        } else {
          ShellNav.goHome();
        }
      },
    );
  }
}
