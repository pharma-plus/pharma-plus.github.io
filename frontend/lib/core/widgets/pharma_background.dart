import 'package:flutter/material.dart';

/// Fond visuel PHARMA+ partagé par le démarrage et l'espace applicatif.
class PharmaBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;

  const PharmaBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.78,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/pharma_login_background.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF07130F)),
        ),
        ColoredBox(color: const Color(0xFF00110A).withValues(alpha: overlayOpacity)),
        child,
      ],
    );
  }
}
