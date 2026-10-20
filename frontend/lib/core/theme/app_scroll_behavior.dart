import 'package:flutter/material.dart';

/// ScrollBehavior global PHARMA+.
///
/// Le comportement Material par défaut n'ajoute une [Scrollbar] que sur
/// Windows/macOS/Linux — or PHARMA+ est majoritairement consommée sur web
/// (TargetPlatform.android par défaut), où AUCUNE barre n'apparaît.
/// Ce comportement rend la barre de défilement verticale toujours visible
/// (thumbVisibility) et interactive sur TOUTES les plateformes, tout en
/// consommant le scrollbarTheme déclaré dans AppTheme.
///
/// Les axes horizontaux restent gérés au cas par cas (ex. : tableau
/// catalogue large avec sa dédiée Scrollbar + contrôleur dédié).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      interactive: true,
      child: child,
    );
  }
}
