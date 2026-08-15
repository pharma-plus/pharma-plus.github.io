import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Identité visuelle PHARMA+.
///
/// `mark` : pastille dégradée vert pharmacie → turquoise avec croix médicale
/// stylisée (+ symbole « + ») et capsule. Lisible sur fond sombre et clair.
/// `full` : marque + wordmark « PHARMA+ ».
class PharmaPlusLogo extends StatelessWidget {
  final double size;
  final bool full;

  const PharmaPlusLogo({super.key, this.size = 64, this.full = false});

  @override
  Widget build(BuildContext context) {
    if (full) {
      return SvgPicture.asset(
        'assets/logo/pharma_plus_logo.svg',
        height: size,
        fit: BoxFit.contain,
      );
    }
    return SvgPicture.asset(
      'assets/logo/pharma_plus_mark.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
