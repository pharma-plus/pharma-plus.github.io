import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'pharma_logo.dart';

/// Médaillon de marque PHARMA+ — identique à la maquette de connexion :
/// disque sombre en dégradé émeraude, liseré or #D7AE4F et halo émeraude.
/// Utilisé sur le splash, le dashboard et toute surface de marque.
class PharmaLogoMedallion extends StatelessWidget {
  const PharmaLogoMedallion({
    super.key,
    this.size = 120,
    this.showTitle = false,
    this.subtitle,
  });

  final double size;
  final bool showTitle;
  final String? subtitle;

  /// Or de marque (liserés, accents actifs, titres secondaires).
  static const Color goldBorder = AppColors.brandGold;

  /// Or clair du titre « PHARMA+ » (maquette connexion).
  static const Color titleGold = Color(0xFFF0D89E);

  /// Vert menthe du sous-titre (maquette connexion).
  static const Color subtitleMint = Color(0xFFB9E5D1);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B3A2A),
                Color(0xFF06251D),
              ],
            ),
            border: Border.all(color: goldBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withValues(alpha: 0.38),
                blurRadius: 28,
              ),
            ],
          ),
          child: Center(child: PharmaPlusLogo(size: size * 0.65)),
        ),
        if (showTitle) ...[
          SizedBox(height: size * 0.08),
          Text(
            'PHARMA+',
            style: TextStyle(
              color: titleGold,
              fontSize: size * 0.25,
              fontWeight: FontWeight.w900,
              letterSpacing: -2 * (size / 170),
            ),
          ),
        ],
        if (subtitle != null) ...[
          SizedBox(height: size * 0.03),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtitleMint,
              fontSize: (size * 0.075).clamp(10.0, 13.0).toDouble(),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}
