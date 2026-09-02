import 'package:flutter/material.dart';

/// Palette DARK PREMIUM PHARMA+ — Vert émeraude très sombre + Noirs profonds
class AppColors {
  AppColors._();

  // === MARQUE PHARMA+ ===
  static const Color primary = Color(0xFF0D1F20);        // Vert émeraude très sombre
  static const Color primaryLight = Color(0xFF1B3A3A);   // Vert émeraude profond
  static const Color secondary = Color(0xFF1A2E2E);      // Presque noir
  static const Color emerald = Color(0xFF00C853);        // Vert émeraude (actif)
  static const Color emeraldDark = Color(0xFF008F57);    // Vert émeraude foncé
  static const Color emeraldLight = Color(0xFF4CAF50);   // Vert émeraude clair (subtil)

  // === FONDS PREMIUM SOMBRES ===
  static const Color backgroundDark = Color(0xFF0A0A0A); // Noir absolu
  static const Color surfaceDark = Color(0xFF0D1B1F);    // Fond de panel très sombre
  static const Color surfaceCard = Color(0xFF1A2E2F);    // Carte sombre
  static const Color surfacePanel = Color(0xFF162428);   // Panneau sombre
  static const Color surfaceSidebar = Color(0xFF0E1418); // Sidebar

  // === GRIS CLAIR POUR TEXTES SECONDAIRES ===
  static const Color textPrimary = Color(0xFFE8E8E8);    // Texte principal blanc cassé
  static const Color textSecondary = Color(0xFF9E9E9E); // Texte secondaire gris clair
  static const Color textTertiary = Color(0xFF6E6E6E);  // Texte tertiary gris moyen
  static const Color textDisabled = Color(0xFF4A4A4A);  // Texte disabled

  // === BORDURES FINES ===
  static const Color dividerLight = Color(0xFF2A3A3F);   // Bordure légère
  static const Color dividerDark = Color(0xFF1E2E31);    // Bordure sombre
  static const Color borderLight = Color(0xFF2A3A3F);    // Bordure légère cartes
  static const Color borderDark = Color(0xFF1E2E31);     // Bordure sombre cartes

  // === ORANGE/DORÉ POUR STOCK ===
  static const Color warning = Color(0xFFFF8F00);        // Orange vif
  static const Color warningLight = Color(0xFFFFB347);   // Orange clair
  static const Color gold = Color(0xFFFFD100);           // Or 24K

  // === VIOLET POUR COMMANDES ===
  static const Color purple = Color(0xFF9C27B0);        // Violet principal
  static const Color purpleDark = Color(0xFF7B1FA2);    // Violet foncé

  // === CYAN/BLEU POUR FOURNISSEURS ===
  static const Color cyan = Color(0xFF00BCD4);          // Cyan
  static const Color cyanLight = Color(0xFF4DD0E1);     // Cyan clair

  // === ROSE/VIOLET POUR CLIENTS ===
  static const Color pink = Color(0xFFE91E63);          // Rose
  static const Color pinkLight = Color(0xFFEC407A);     // Rose clair

  // === VERT/OLIVE POUR EMPLOYÉS ===
  static const Color olive = Color(0xFF8BC34A);         // Olive
  static const Color oliveLight = Color(0xFFAED581);    // Olive clair

  // === SEMANTIQUE ===
  static const Color success = Color(0xFF00C853);
  static const Color danger = Color(0xFFFF3D00);
  static const Color info = Color(0xFF29B6F6);

  // === ROUGE POUR BOUTONS VIDER ==========================================
  // (non utilisé directement, mais référence)

  // === GLOW / OMBRE COULEURS ===
  static const Color shadowColor = Color(0xFF000000);   // Ombre noire

  // === GRADIENTS SOMBRES (tout est très sombre + emerald) ===

  // Gradient principal vert émeraude sombre
  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D1F20),
      Color(0xFF1B3A3A),
      Color(0xFF0D2A2E),
    ],
  );

  // Gradient sidebar
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0E1418),
      Color(0xFF162428),
    ],
  );

  // Gradient carte
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A2E2F),
      Color(0xFF0D1B1F),
    ],
  );

  // Gradient alerte
  static const LinearGradient alertGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1A0F),
      Color(0xFF1E100A),
    ],
  );

  // ============================================================
  // === ALIASES DE COMPATIBILITE (autres pages de l'app) =======
  // ============================================================
  static const Color menu = Color(0xFF0E1418);            // Ancien fond menu
  static const Color accent = Color(0xFF00C853);          // Accent vert émeraude
  static const Color accentDeep = Color(0xFF008F57);      // Accent vert foncé
  static const Color turquoise = Color(0xFF00C853);       // Ancien turquoise => vert émeraude
  static const Color turquoiseLight = Color(0xFF6EFFD8);  // Turquoise néon clair (garde)
  static const Color turquoiseDark = Color(0xFF008F57);   // Turquoise profond
  static const Color teal = Color(0xFF00695C);            // Teal
  static const Color backgroundLight = Color(0xFFFAFAF5); // Fond clair (mode light)
  static const Color goldLight = Color(0xFFFFE066);       // Or clair
  static const Color goldDeep = Color(0xFFC69800);        // Or foncé
  static const Color goldRose = Color(0xFFFFD7AE);        // Or rosé
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A3A2F),
      Color(0xFF1E3A1F),
      Color(0xFF3A2A0F),
    ],
  );
  static const LinearGradient goldGradientHover = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A3A2F),
      Color(0xFF1E3A1F),
      Color(0xFF3A2A0F),
    ],
  );
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B6E2F),
      Color(0xFF0D3F1A),
      Color(0xFF05240F),
    ],
  );
  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF123B1A),
      Color(0xFF0A2A10),
      Color(0xFF051A08),
    ],
  );
  static const LinearGradient turquoiseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00E8B5),
      Color(0xFF00BFA3),
      Color(0xFF008F72),
      Color(0xFF006B58),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );
  static const LinearGradient turquoiseGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00E8B5),
      Color(0xFF00BFA3),
      Color(0xFFFFD100),
      Color(0xFFE6B800),
    ],
    stops: [0.0, 0.35, 0.65, 1.0],
  );
  static const LinearGradient aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6A1B9A),
      Color(0xFF7C4DFF),
      Color(0xFF00E8B5),
      Color(0xFFFFD100),
    ],
    stops: [0.0, 0.3, 0.65, 1.0],
  );

  // === Couleurs de glow (ombres) par défaut - vert émeraude ==========
  static const Map<String, Color> premiumGlowColors = {
    'revenue': Color(0xFF00C853),        // Vert émeraude glow
    'stock': Color(0xFFFF8F00),          // Orange glow
    'sales': Color(0xFF00C853),
    'revenue_month': Color(0xFF00C853),
    'prescriptions': Color(0xFF9C27B0),  // Violet glow
    'customers': Color(0xFFE91E63),      // Rose glow
    'suppliers': Color(0xFF00BCD4),      // Cyan glow
    'parapharmacy': Color(0xFF00C853),
    'alerts': Color(0xFFFF8F00),         // Orange glow alerts
    'ai': Color(0xFF9C27B0),
    'analytics': Color(0xFF00BCD4),
  };

  // Détermine si un fond est sombre
  static bool isDark(Color color) => color.computeLuminance() < 0.25;

  // Obtenir gradient premium par clé
  static LinearGradient getGradient(String key) =>
      _premiumCardGradients[key] ?? emeraldGradient;

  // Obtenir glow color par clé
  static Color getGlow(String key) => premiumGlowColors[key] ?? emerald;

  // Gradients de cartes par type (sombres avec emerald)
  static const Map<String, LinearGradient> _premiumCardGradients = {
    'revenue': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A2E2F),
        Color(0xFF0D1B1F),
      ],
    ),
    'stock': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A1A0F),
        Color(0xFF1E0D00),
      ],
    ),
    'sales': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A2E2F),
        Color(0xFF0D1B1F),
      ],
    ),
    'revenue_month': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1E3A3A),
        Color(0xFF162E32),
      ],
    ),
    'prescriptions': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A1A2E),
        Color(0xFF1D1425),
      ],
    ),
    'customers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A1A2E),
        Color(0xFF1E1425),
      ],
    ),
    'suppliers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A2E36),
        Color(0xFF122530),
      ],
    ),
    'parapharmacy': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A2E2F),
        Color(0xFF0D1B1F),
      ],
    ),
    'alerts': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF251A0F),
        Color(0xFF1A0F05),
      ],
    ),
    'ai': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A1A2E),
        Color(0xFF1D1425),
      ],
    ),
    'analytics': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A2E36),
        Color(0xFF122530),
      ],
    ),
  };
}