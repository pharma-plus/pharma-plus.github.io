import 'package:flutter/material.dart';

/// ============================================================
/// PALETTE PHARMA+ v4 — NOUVELLE IDENTITÉ VISUELLE
/// Vert sauge #A8C8B5 · Champagne #C6A76B · Texte foncé #26343D
/// Graphite #20272D · Texte clair #F5F6F5
/// ============================================================

class AppColors {
  AppColors._();

  // ============================================================
  // NOUVELLE PALETTE DE MARQUE PHARMA+
  // ============================================================

  // Vert sauge — couleur de marque principale (remplace vert pétrole #006B43 / #00C96B)
  static const Color sageGreen = Color(0xFFA8C8B5);
  static const Color sageGreenDark = Color(0xFF8FB39A);
  static const Color sageGreenLight = Color(0xFFD4E4DA);

  // Champagne — accents et sélections (remplace or #D6A84F)
  static const Color champagne = Color(0xFFC6A76B);
  static const Color champagneDark = Color(0xFFB08A3C);
  static const Color champagneLight = Color(0xFFE8D5B5);

  // Vert sauge foncé lisible sur marbre clair (valeurs/chiffres).
  // #A8C8B5 seul est trop pâle pour du texte sur surface claire.
  static const Color sageGreenInk = Color(0xFF3D6B51);

  // Champagne foncé lisible sur marbre clair (titres dorés).
  static const Color champagneInk = Color(0xFF9A7A30);
  static const Color champagneInkLight = Color(0xFFB08A3C);

  // Variantes dérivées (alias de lisibilité).
  static const Color sageGreenInkDark = Color(0xFF2F5440);
  static const Color sageGreenInkRich = Color(0xFF3D6B51);
  static const Color sageGreenInkDeep = Color(0xFF2F5440);
  static const Color sageGreenInkInk = Color(0xFF20272D);

  // Graphite — fonds sombres et texte
  static const Color graphite = Color(0xFF20272D);
  static const Color graphiteDark = Color(0xFF1A1F24);
  static const Color graphiteLight = Color(0xFF3A424A);

  // Texte foncé — pour les surfaces claires
  static const Color inkDark = Color(0xFF26343D);
  static const Color inkDarkLight = Color(0xFF4A5A65);

  // Texte clair — pour les surfaces sombres
  static const Color porcelain = Color(0xFFF5F6F5); // Blanc porcelaine / texte clair

  // Gris argent — surfaces principales (thème clair / marbre)
  static const Color silver = Color(0xFFE8EAEC); // Gris argent / marbre
  static const Color silverLight = Color(0xFFF0F1F2);
  static const Color silverDark = Color(0xFFCED3D8);

  // ============================================================
  // COULEURS SÉMANTIQUES (préservées — succès, erreur, avertissement)
  // ============================================================

  static const Color success = Color(0xFFA8C8B5);      // Vert sauge pour succès
  static const Color danger = Color(0xFFEF4444);       // Rouge (inchangé)
  static const Color warning = Color(0xFFF59E0B);      // Ambre (inchangé)
  static const Color info = Color(0xFF5BB8E8);         // Bleu (inchangé)

  // ============================================================
  // COULEURS MÉTIER SUPPLÉMENTAIRES (préservées)
  // ============================================================

  static const Color cardBlue = Color(0xFF5BB8E8);
  static const Color cardAmber = Color(0xFFF59E0B);
  static const Color cardPurple = Color(0xFF9B5FC0);
  static const Color purple = Color(0xFF9B5FC0);
  static const Color purpleDark = Color(0xFF7A3FA8);
  static const Color cyan = Color(0xFF2BD4C4);
  static const Color cyanLight = Color(0xFF67E6DA);
  static const Color pink = Color(0xFFE0557C);
  static const Color pinkLight = Color(0xFFED7FA0);
  static const Color olive = Color(0xFF9BCB6B);
  static const Color oliveLight = Color(0xFFB9E091);

  // ============================================================
  // ALIASES DE RÉTROCOMPATIBILITÉ (anciens noms → nouvelles valeurs)
  // Ces alias permettent aux composants existants de continuer à fonctionner
  // avec la nouvelle palette.
  // ============================================================

  /// Ancien "primary" (vert pétrole) → vert sauge
  static const Color primary = sageGreen;

  /// Ancien "emerald" (vert pétrole) → vert sauge
  static const Color emerald = sageGreen;

  /// Ancien "emeraldDark" → vert sauge foncé
  static const Color emeraldDark = sageGreenDark;

  /// Ancien "emeraldLight" → vert sauge clair
  static const Color emeraldLight = sageGreenLight;

  /// Ancien "emeraldRich" → vert sauge
  static const Color emeraldRich = sageGreen;

  /// Ancien "pharmaGreen" → vert sauge
  static const Color pharmaGreen = sageGreen;

  /// Ancien "pharmaGreenDark" → vert sauge foncé
  static const Color pharmaGreenDark = sageGreenDark;

  /// Ancien "turquoise" → vert sauge
  static const Color turquoise = sageGreen;

  /// Ancien "turquoiseLight" → vert sauge clair
  static const Color turquoiseLight = sageGreenLight;

  /// Ancien "turquoiseDark" → vert sauge foncé
  static const Color turquoiseDark = sageGreenDark;

  /// Ancien "teal" → vert sauge foncé
  static const Color teal = sageGreenDark;

  /// Ancien "accent" → vert sauge
  static const Color accent = sageGreen;

  /// Ancien "accentDeep" → vert sauge foncé
  static const Color accentDeep = sageGreenDark;

  /// Ancien "menu" (fond menu sombre) → graphite
  static const Color menu = graphite;

  /// Ancien "brandGold" → champagne
  static const Color brandGold = champagne;

  /// Ancien "gold" → champagne
  static const Color gold = champagne;

  /// Ancien "pharmaGold" → champagne
  static const Color pharmaGold = champagne;

  /// Ancien "goldLight" → champagne light
  static const Color goldLight = champagneLight;

  /// Ancien "goldDeep" → champagne dark
  static const Color goldDeep = champagneDark;

  /// Ancien "goldRose" → champagne light
  static const Color goldRose = champagneLight;

  /// Ancien "pharmaBg" (fond sombre) → graphite (thème sombre)
  static const Color pharmaBg = graphite;

  /// Ancien "pharmaBg2" → graphite dark
  static const Color pharmaBg2 = graphiteDark;

  /// Ancien "backgroundDark" → graphite
  static const Color backgroundDark = graphite;

  /// Ancien "surfaceDark" → graphite light
  static const Color surfaceDark = graphiteLight;

  /// Ancien "surfaceCard" → graphite light
  static const Color surfaceCard = graphiteLight;

  /// Ancien "surfacePanel" → graphite light
  static const Color surfacePanel = graphiteLight;

  /// Ancien "surfaceSidebar" → graphite
  static const Color surfaceSidebar = graphite;

  /// Ancien "backgroundLight" → silver (thème clair / marbre)
  static const Color backgroundLight = silver;

  /// Ancien "textPrimary" → porcelain (texte clair sur sombre)
  static const Color textPrimary = porcelain;

  /// Ancien "textSecondary" → gris ardoise lisible sur LES DEUX thèmes
  /// (#3A424A était invisible sur le graphite sombre).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Texte secondaire atténué, contrasté sur marbre clair ET graphite sombre.
  static const Color textMuted = Color(0xFF6B7280);

  /// Ancien "textTertiary" → graphite light
  static const Color textTertiary = graphiteLight;

  /// Ancien "textDisabled" → graphite light
  static const Color textDisabled = graphiteLight;

  /// Ancien "pharmaText" → porcelain
  static const Color pharmaText = porcelain;

  /// Ancien "pharmaMuted" → graphite light
  static const Color pharmaMuted = graphiteLight;

  /// Ancien "pharmaDanger" → danger
  static const Color pharmaDanger = danger;

  /// Ancien "pharmaWarning" → warning
  static const Color pharmaWarning = warning;

  /// Ancien "pharmaSurface" → graphite light
  static const Color pharmaSurface = graphiteLight;

  /// Ancien "pharmaSurface2" → graphite light
  static const Color pharmaSurface2 = graphiteLight;

  /// Ancien "primaryLight" → vert sauge foncé
  static const Color primaryLight = sageGreenDark;

  /// Ancien "pharmaGoldLight" → champagne light
  static const Color pharmaGoldLight = champagneLight;

  /// Ancien "warnAmber" → ambre
  static const Color warnAmber = warning;

  /// Ancien "alertRed" → danger
  static const Color alertRed = danger;

  /// Ancien "chart" → bleu info
  static const Color chart = info;

  /// Ancien "chartAccent" → vert sauge
  static const Color chartAccent = sageGreen;

  /// Ancien "petroleumBlue" → vert sauge foncé
  static const Color petroleumBlue = sageGreenDark;

  /// Ancien "emeraldDeep" → vert sauge foncé
  static const Color emeraldDeep = sageGreenDark;

  /// Ancien "emeraldInk" → graphite
  static const Color emeraldInk = graphite;

  /// Ancien "champagneGold" → champagne
  static const Color champagneGold = champagne;

  // Bordures — argent pour thème clair, graphite pour sombre
  static const Color dividerLight = silverDark;
  static const Color dividerDark = graphiteLight;
  static const Color borderLight = silverDark;
  static const Color borderDark = graphiteLight;

  // Liserés or → champagne
  static const Color goldBorder = Color(0x26C6A76B);
  static const Color goldBorderStrong = Color(0x52C6A76B);

  // Ombres
  static const Color shadowColor = Color(0xFF000000);

  // ============================================================
  // GRADIENTS — NOUVELLE IDENTITÉ
  // ============================================================

  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      sageGreenLight,
      sageGreen,
      sageGreenDark,
    ],
  );

  static const LinearGradient champagneGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      champagneLight,
      champagne,
      champagneDark,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient graphiteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      graphiteLight,
      graphite,
      graphiteDark,
    ],
  );

  static const LinearGradient silverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      silverLight,
      silver,
      silverDark,
    ],
  );

  // Gradients de compatibilité (anciens noms → nouveaux)
  static const LinearGradient emeraldGradient = sageGradient;
  static const LinearGradient greenGradient = sageGradient;
  static const LinearGradient goldGradient = champagneGradient;
  static const LinearGradient goldGradientHover = champagneGradient;
  static const LinearGradient forestGradient = graphiteGradient;
  static const LinearGradient turquoiseGradient = sageGradient;
  static const LinearGradient turquoiseGoldGradient = sageGradient;
  static const LinearGradient sidebarGradient = graphiteGradient;
  static const LinearGradient cardGradient = silverGradient;
  static const LinearGradient alertGradient = graphiteGradient;
  static const LinearGradient primaryGradient = sageGradient;

  // ============================================================
  // GLOW / OMBRES COLORÉES PAR DOMAINE
  // ============================================================

  static const Map<String, Color> premiumGlowColors = {
    'revenue': sageGreen,
    'stock': warning,
    'sales': sageGreen,
    'revenue_month': sageGreen,
    'prescriptions': info,
    'customers': danger,
    'suppliers': turquoise,
    'parapharmacy': sageGreen,
    'alerts': warning,
    'ai': info,
    'analytics': turquoise,
  };

  // ============================================================
  // HELPERS
  // ============================================================

  /// Détermine si un fond est sombre (luminance < 0.25)
  static bool isDark(Color color) => color.computeLuminance() < 0.25;

  /// Obtenir gradient premium par clé
  static LinearGradient getGradient(String key) =>
      _premiumCardGradients[key] ?? sageGradient;

  /// Obtenir glow color par clé
  static Color getGlow(String key) => premiumGlowColors[key] ?? sageGreen;

  // Gradients de cartes par type (nouvelle identité)
  static const Map<String, LinearGradient> _premiumCardGradients = {
    'revenue': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        sageGreenLight,
        sageGreen,
      ],
    ),
    'stock': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        champagneLight,
        champagne,
      ],
    ),
    'sales': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        sageGreenLight,
        sageGreen,
      ],
    ),
    'revenue_month': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        sageGreenLight,
        sageGreen,
      ],
    ),
    'prescriptions': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        champagneLight,
        champagne,
      ],
    ),
    'customers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF0E0D0),
        pink,
      ],
    ),
    'suppliers': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFD8E8E8),
        cyan,
      ],
    ),
    'parapharmacy': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        sageGreenLight,
        sageGreen,
      ],
    ),
    'alerts': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF5E0B0),
        warning,
      ],
    ),
    'ai': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFE8E0F0),
        purple,
      ],
    ),
    'analytics': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFD8E8E8),
        cyan,
      ],
    ),
  };
}
