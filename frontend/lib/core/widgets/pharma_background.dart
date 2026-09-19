import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
    Widget bg;
    if (assetImage != null) {
      bg = Image.asset(
        assetImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF07130F)),
      );
    } else if (networkImage != null) {
      bg = Image.network(
        networkImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF07130F)),
      );
    } else if (kIsWeb) {
      bg = Image.network(
        'assets/assets/images/background.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.network(
          'images/pharma_login_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF07130F)),
        ),
      );
    } else {
      bg = Image.asset(
        'assets/images/background.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF07130F)),
      );
    }

    final bool customImage = networkImage != null || assetImage != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        if (!customImage)
          ColoredBox(color: Color(0xFF00110A).withValues(alpha: overlayOpacity)),
        child,
      ],
    );
  }
}
