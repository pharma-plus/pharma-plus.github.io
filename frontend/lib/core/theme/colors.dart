import 'package:flutter/material.dart';

/// Palette de marque PHARMA MAROC GOLD.
/// Les couleurs peuvent être surchargées par celles reçues de l'API
/// (`pharmacies.colors`), appliquées à la volée dans [ThemeOverride].
class AppColors {
  AppColors._();

  // Marque
  static const Color primary = Color(0xFF1B5E20); // vert émeraude
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color secondary = Color(0xFF0D47A1); // bleu profond
  static const Color accent = Color(0xFFFFB300); // ambre doré (gold)
  static const Color menu = Color(0xFF0A2A0F); // vert très sombre

  // PHARMA+ — turquoise (complète la palette vert émeraude / or)
  static const Color turquoise = Color(0xFF00BFA5);
  static const Color turquoiseLight = Color(0xFF64FFDA);
  static const Color turquoiseDark = Color(0xFF00897B);
  static const Color teal = Color(0xFF0F766E);

  // Sémantique
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFF8F00);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);

  // Neutres
  static const Color backgroundLight = Color(0xFFF4F7F4);
  static const Color backgroundDark = Color(0xFF0B1210);
  static const Color surfaceDark = Color(0xFF14201B);
  static const Color dividerLight = Color(0xFFE0E7E0);
  static const Color dividerDark = Color(0xFF2A3A32);

  // Or 3D (rehauts)
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFC67C00)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0F3D12)],
  );

  /// Gradient PHARMA+ turquoise → émeraude (panneau central des cartes 3D).
  static const LinearGradient turquoiseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BFA5), Color(0xFF1B8A6A), Color(0xFF0F766E)],
  );

  /// Gradient AI (violet → turquoise) pour la grande carte PHARMA AI.
  static const LinearGradient aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C4DFF), Color(0xFF00BFA5), Color(0xFF0D47A1)],
  );

  /// Détermine si un fond est sombre pour choisir la couleur du texte.
  static bool isDark(Color color) => color.computeLuminance() < 0.35;
}
