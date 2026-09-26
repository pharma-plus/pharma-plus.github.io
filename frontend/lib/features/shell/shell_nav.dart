import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/app_guards.dart';

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
/// · icone maison qui retourne au Tableau de bord.
/// Utilise la logique centralisee de retour (unsaved changes -> pop -> shell).
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_rounded),
      tooltip: 'Retour',
      onPressed: () async {
        final handled = await handleSystemBack(context);
        if (!handled && context.mounted) {
          ShellNav.goHome();
        }
      },
    );
  }
}

/// Bouton flèche retour pour les sous-sous-pages (pages poussées).
/// Pop la page en cours pour revenir à la page précédente.
/// Utilise la logique centralisee de retour.
class BackArrowButton extends StatelessWidget {
  const BackArrowButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: 'Retour',
      onPressed: () async {
        final handled = await handleSystemBack(context);
        // Si non gere (pas de route a pop, pas shell), ne rien faire
        // (le PopScope racine gerera le dialogue quitter si necessaire)
      },
    );
  }
}
