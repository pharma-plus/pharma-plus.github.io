import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'marble_texture.dart';

class PharmaBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;

  /// Si fourni, remplace l'image de fond par défaut (chemin réseau pour web).
  final String? networkImage;

  /// Si fourni avec networkImage, utilise Image.asset (mobile native).
  final String? assetImage;

  const PharmaBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.52,
    this.networkImage,
    this.assetImage,
  });

    @override
  Widget build(BuildContext context) {
    // ADAPTATIF : thème principal (clair) = MARBRE du thème sur toutes les
    // pages ; thème sombre = scène pharmacie graphite (validée). Les textes
    // encre du thème clair redeviennent lisibles (bug "fournisseur").
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Widget bg;
    bool showOverlay = false;
    if (!isDark) {
      bg = MarbleBackground(dark: false);
    } else if (assetImage != null) {
      bg = Image.asset(
        assetImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF12171B)),
      );
    } else if (networkImage != null) {
      bg = Image.network(
        networkImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF12171B)),
      );
    } else if (kIsWeb) {
      bg = Image.network(
        'assets/assets/images/background.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.network(
          'images/pharma_login_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF12171B)),
        ),
      );
      showOverlay = true;
    } else {
      bg = Image.asset(
        'assets/images/background.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF12171B)),
      );
      showOverlay = true;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        if (showOverlay)
          ColoredBox(
              color:
                  const Color(0xFF0B0F13).withValues(alpha: overlayOpacity)),
        child,
      ],
    );
  }
}
