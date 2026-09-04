import 'package:flutter/material.dart';

/// ============================================================
/// PALETTE PHARMA+ v3 — « LUXE PHARMACEUTIQUE »
/// Vert pétrole profond · Vert forêt · Noir profond · Or champagne
/// Design tokens officiels de la maquette :
///   --pharma-bg #03100D · --pharma-bg-2 #061A15
///   --pharma-surface #08231C · --pharma-surface-2 #0B2C23
///   --pharma-green #00C96B · --pharma-green-dark #006B43
///   --pharma-gold #D6A84F · --pharma-gold-light #F1D58A
///   --pharma-text #F4F4EE · --pharma-muted #9BAEA7
///   --pharma-danger #EF4444 · --pharma-warning #F59E0B
/// ============================================================
class AppColors {
  AppColors._();

  // === DESIGN TOKENS OFFICIELS PHARMA+ ===
  static const Color pharmaBg = Color(0xFF03100D);
  static const Color pharmaBg2 = Color(0xFF061A15);
  static const Color pharmaSurface = Color(0xFF08231C);
  static const Color pharmaSurface2 = Color(0xFF0B2C23);
  static const Color pharmaGreen = Color(0xFF00C96B);
  static const Color pharmaGreenDark = Color(0xFF006B43);
  static const Color pharmaGold = Color(0xFFD6A84F);
  static const Color pharmaGoldLight = Color(0xFFF1D58A);
  static const Color pharmaText = Color(0xFFF4F4EE);
  static const Color pharmaMuted = Color(0xFF9BAEA7);
  static const Color pharmaDanger = Color(0xFFEF4444);
  static const Color pharmaWarning = Color(0xFFF59E0B);

  /// Liseré or maquette : 1px rgba(214,168,79,0.15)
  static const Color goldBorder = Color(0x26D6A84F);
  /// Liseré or renforcé : rgba(214,168,79,0.32)
      static const Color goldBorderStrong = Color(0x52D6A84F);

  // === MARQUE PHARMA+ ===
  static const Color primary = Color(0xFF006B43);        // Vert pétrole profond
  static const Color primaryLight = Color(0xFF0E3B2C);   // Vert forêt
  static const Color secondary = Color(0xFF08231C);      // Presque noir
  static const Color emerald = Color(0xFF00C96B);        // Vert PHARMA+ (actif)
  static const Color emeraldDark = Color(0xFF006B43);    // Vert foncé
  static const Color emeraldLight = Color(0xFF3BE39A);   // Vert clair subtil

  /// Palette graphique cohérente (illustrations / KPI / rapports)
  static const Color chart = Color(0xFF5B8FD9);         // Bleu outil/graphique
  static const Color chartAccent = Color(0xFF00C96B);    // Dernière barre / flèche ↑
  static const Color warnAmber = Color(0xFFF59E0B);     // Alertes expirations / stock faible
  static const Color alertRed = Color(0xFFEF4444);      // Rupture / danger
  static const Color danger = Color(0xFFEF4444);

  // === FONDS PREMIUM SOMBRES ===
  static const Color backgroundDark = Color(0xFF03100D); // Vert pétrole profond
  static const Color surfaceDark = Color(0xFF061A15);    // Fond secondaire
  static const Color surfaceCard = Color(0xFF08231C);    // Surface carte
  static const Color surfacePanel = Color(0xFF0B2C23);   // Surface panneau
  static const Color surfaceSidebar = Color(0xFF020B08); // Sidebar

  // === TEXTES ===
  static const Color textPrimary = Color(0xFFF4F4EE);    // Blanc crème
  static const Color textSecondary = Color(0xFF9BAEA7);  // Texte secondaire
  static const Color textTertiary = Color(0xFF6B857C);   // Texte tertiaire
  static const Color textDisabled = Color(0xFF3E5A50);   // Texte disabled

  // === BORDURES FINES ===
  static const Color dividerLight = Color(0xFF143B2B);   // Bordure légère
  static const Color dividerDark = Color(0xFF0A241B);    // Bordure sombre
  static const Color borderLight = Color(0xFF1A4734);    // Bordure légère cartes
  static const Color borderDark = Color(0xFF0C2B20);     // Bordure sombre cartes

  // === ORANGE/DORÉ POUR STOCK ===
  static const Color warning = Color(0xFFF59E0B);        // Ambre premium
  static const Color warningLight = Color(0xFFFBBF49);   // Ambre clair
  static const Color gold = Color(0xFFD6A84F);           // Or champagne

  // === OR DE MARQUE (maquette connexion) ===
  static const Color brandGold = Color(0xFFD6A84F);      // Liseré or des cartes/panneaux

  // === VIOLET POUR COMMANDES ===
  static const Color purple = Color(0xFF9B5FC0);        // Violet
  static const Color purpleDark = Color(0xFF7A3FA8);    // Violet foncé

  // === CYAN/BLEU POUR FOURNISSEURS ===
  static const Color cyan = Color(0xFF2BD4C4);          // Turquoise
  static const Color cyanLight = Color(0xFF67E6DA);     // Turquoise clair

  // === ROSE/VIOLET POUR CLIENTS ===
  static const Color pink = Color(0xFFE0557C);          // Rose
  static const Color pinkLight = Color(0xFFED7FA0);     // Rose clair

  // === VERT/OLIVE POUR EMPLOYÉS ===
  static const Color olive = Color(0xFF9BCB6B);         // Olive
  static const Color oliveLight = Color(0xFFB9E091);    // Olive clair

    // === SEMANTIQUE ===
  static const Color success = Color(0xFF00C96B);
  static const Color info = Color(0xFF5BB8E8);

  // === GLOW / OMBRE COULEURS ===
  static const Color shadowColor = Color(0xFF000000);   // Ombre noire

  // === GRADIENTS SOMBRES (tout est très sombre + emerald) ===

  // Gradient principal vert pétrole
  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B2C23),
      Color(0xFF061A15),
      Color(0xFF03100D),
    ],
  );

  // Gradient sidebar
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF020B08),
      Color(0xFF061A15),
    ],
  );

  // Gradient carte
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF08231C),
      Color(0xFF061A15),
    ],
  );

  // Gradient alerte
  static const LinearGradient alertGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF241A0F),
      Color(0xFF170E06),
    ],
  );

  // ============================================================
  // === ALIASES DE COMPATIBILITE (autres pages de l'app) =======
  // ============================================================
  static const Color menu = Color(0xFF020B08);            // Fond menu
  static const Color accent = Color(0xFF00C96B);          // Accent vert PHARMA+
  static const Color accentDeep = Color(0xFF006B43);      // Accent vert foncé
  static const Color turquoise = Color(0xFF00C96B);       // Turquoise => vert PHARMA+
  static const Color turquoiseLight = Color(0xFF8FFFE0);  // Turquoise clair
  static const Color turquoiseDark = Color(0xFF006B43);   // Turquoise profond
  static const Color teal = Color(0xFF0E5C4E);            // Teal
  static const Color backgroundLight = Color(0xFFFAFAF5); // Fond clair (mode light)
  static const Color goldLight = Color(0xFFF1D58A);       // Or champagne clair
  static const Color goldDeep = Color(0xFFA07E2E);        // Or foncé
  static const Color goldRose = Color(0xFFE8C893);        // Or rosé
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF1D58A),
      Color(0xFFD6A84F),
      Color(0xFFB08A3C),
    ],
    stops: [0.0, 0.55, 1.0],
  );
  static const LinearGradient goldGradientHover = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8C778),
      Color(0xFFC79A3E),
      Color(0xFF9C7528),
    ],
  );
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00C96B),
      Color(0xFF00A85C),
      Color(0xFF007C45),
    ],
  );
  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B2C23),
      Color(0xFF08231C),
      Color(0xFF041712),
    ],
  );
  static const LinearGradient turquoiseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00C96B),
      Color(0xFF00A878),
      Color(0xFF00875F),
      Color(0xFF006B43),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );
  static const LinearGradient turquoiseGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00C96B),
      Color(0xFF00A878),
      Color(0xFFD6A84F),
      Color(0xFFB08A3C),
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

  // === Couleurs de glow (ombres) par défaut - vert PHARMA+ ==========
  static const Map<String, Color> premiumGlowColors = {
    'revenue': Color(0xFF00C96B),        // Vert glow
    'stock': Color(0xFFF59E0B),          // Ambre glow
    'sales': Color(0xFF00C96B),
    'revenue_month': Color(0xFF00C96B),
    'prescriptions': Color(0xFF9B5FC0),  // Violet glow
    'customers': Color(0xFFE0557C),      // Rose glow
    'suppliers': Color(0xFF2BD4C4),      // Turquoise glow
    'parapharmacy': Color(0xFF00C96B),
    'alerts': Color(0xFFF59E0B),         // Ambre glow alerts
    'ai': Color(0xFF9B5FC0),
    'analytics': Color(0xFF2BD4C4),
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
        Color(0xFF0C2418),
        Color(0xFF081B12),
      ],
    ),
    'stock': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF271A0E),
        Color(0xFF180E06),
      ],
    ),
    'sales': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0C2418),
        Color(0xFF081B12),
      ],
    ),
    'revenue_month': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0E2A1C),
        Color(0xFF081B12),
      ],
    ),
    'prescriptions': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF23152E),
        Color(0xFF130A18),
      ],
    ),
    'customers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A1428),
        Color(0xFF180A16),
      ],
    ),
    'suppliers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0E262E),
        Color(0xFF07151C),
      ],
    ),
    'parapharmacy': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0C2418),
        Color(0xFF081B12),
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
        Color(0xFF23152E),
        Color(0xFF130A18),
      ],
    ),
    'analytics': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0E262E),
        Color(0xFF07151C),
      ],
    ),
  };
}


