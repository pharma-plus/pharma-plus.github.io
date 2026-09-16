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
        // Retour GARANTI au Tableau de bord depuis n'importe quelle option :
        // - Vente du jour (Card 3D) -> PosPage
        // - Option Point de vente (sidebar Modules)
        // - Toute autre option (Catalogue, Stock...)
        // 1) On dépile TOUTES les routes poussées au-dessus du shell (même
        //    si plusieurs _push successifs), en utilisant le root navigator
        //    pour être sûr sur PC Windows/Mac (web) comme sur mobile.
        // 2) On force l'onglet Dashboard (index 0) — identique aux autres pages.
        // Un seul tap suffit, peu importe l'entrée (card 3D ou menu).
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.popUntil((route) => route.isFirst);
        } else {
          // Déjà sur le shell (IndexedStack) : dépile le navigator local si besoin
          final localNav = Navigator.of(context);
          if (localNav.canPop()) localNav.popUntil((route) => route.isFirst);
        }
        ShellNav.goHome();
        // Fallback : si la pile était verrouillée, on force un frame après
        WidgetsBinding.instance.addPostFrameCallback((_) => ShellNav.goHome());
      },
    );
  }
}
