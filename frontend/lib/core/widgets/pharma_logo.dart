import 'package:flutter/material.dart';

/// ============================================================
/// LOGO OFFICIEL PHARMA+ — ASSET OFFICIEL UNIQUE.
/// Symbole : croix médicale 3D verte + feuille + finition or.
/// Source figée : assets/branding/source/pharma_plus_official.png
/// Variantes   : assets/branding/ (full / icon / light / dark...)
/// Interdit de redessiner le logo : on affiche l'asset officiel.
/// ============================================================
class PharmaPlusLogo extends StatelessWidget {
  const PharmaPlusLogo({super.key, this.size = 96, this.showText = false});

  final double size;
  final bool showText;

  /// Chemin de l'asset officiel (symbole seul, fond transparent).
  /// Version 512 px : poids optimisé (265 Ko) pour sidebar/login/header.
  static const String assetPath = 'assets/branding/pharma-logo-icon-512.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'PHARMA+',
    );
  }
}

/// ============================================================
/// LOGO OFFICIEL COMPLET PHARMA+ — bloc de marque intégral :
/// symbole 3D + mot-symbole « PHARMA+ » + signature dorée,
/// tels qu'ils figurent dans l'asset officiel.
/// ATTENTION : les phrases du logo sont DÉJÀ dans l'image.
/// Ne jamais afficher de titre « PHARMA+ » ni de slogan en
/// dessous (interdiction de dupliquer les textes du logo).
/// Largeur seule : la hauteur suit le ratio officiel (1400x943).
/// ============================================================
class PharmaFullLogo extends StatelessWidget {
  const PharmaFullLogo({super.key, this.width = 220});

  final double width;

  /// Asset officiel complet (fond transparent, ratio préservé).
  static const String assetPath = 'assets/branding/pharma-logo-full.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'PHARMA+ — Gestion intelligente de votre pharmacie',
    );
  }
}
