import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// ============================================================
/// FONDS « MARBRE GRIS ARGENTÉ » (thème clair) et
/// « GRAPHITE MÉTAL BROSSÉ » (thème sombre) — dessinés par code.
///
/// Aucun asset requis : la texture est peinte par un CustomPainter
/// déterministe (graine fixe), peinte UNE seule fois puis mise en
/// cache (shouldRepaint => false + RepaintBoundary).
///
/// Clarté : sur marbre clair le texte doit être inkDark ;
/// sur graphite brossé le texte doit être porcelain.
/// ============================================================
class MarbleBackground extends StatelessWidget {
  final Widget? child;
  final bool dark;

  /// Opacité globale de la texture (1 = pleine).
  final double opacity;

  const MarbleBackground({
    super.key,
    this.child,
    this.dark = false,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Thème clair : la VRAIE texture marbre de la maquette, en WebP
    // LÉGER (71 Ko, décodée une fois et mise en cache par Flutter).
    // Repli : texture peinte (sous le calque image, visible si l'asset
    // échoue à charger).
    if (!dark) {
      return RepaintBoundary(
        child: Stack(
          children: [
            // Calque texture peinte (repli si l'asset échoue).
            Positioned.fill(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _SilverMarblePainter(opacity: opacity),
              ),
            ),
            // Calque image WebP légère.
            Positioned.fill(
              child: Image.asset(
                'assets/images/marble_principale.webp',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Contenu : contraintes libres (shrink-wrap OK dans les
            // barres compactes).
            if (child != null) child!,
          ],
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: false,
        painter: _GraphiteBrushedPainter(opacity: opacity),
        child: child,
      ),
    );
  }
}

/// Peintre marbre gris argenté : base argent (#F1F2F4 → #E6E9EB),
/// veines très fines et discrètes, léger voile lumineux.
class _SilverMarblePainter extends CustomPainter {
  final double opacity;
  const _SilverMarblePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1) Base argent très claire (jamais blanc pur : thème « sans cellule
    //    blanche » de la charte).
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF2F3F4),
          Color(0xFFE9ECEF),
          Color(0xFFE3E7EA),
        ],
      ).createShader(Offset.zero & size);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, base);

    // 2) Voiles lumineux discrets (grandes zones molles).
    final rng = math.Random(7);
    for (var i = 0; i < 5; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = size.shortestSide * (0.35 + rng.nextDouble() * 0.45);
      final veil = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10 * opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, veil);
    }

    // 3) Veines : fines diagonales irrégulières, très discrètes.
    final veinCount = 26;
    for (var i = 0; i < veinCount; i++) {
      final start = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final path = Path()..moveTo(start.dx, start.dy);
      var cur = start;
      var dir = (rng.nextDouble() - 0.5) > 0 ? 1.0 : -1.0;
      final segs = 3 + rng.nextInt(4);
      for (var s = 0; s < segs; s++) {
        final len = size.shortestSide * (0.08 + rng.nextDouble() * 0.22);
        final angle =
            (-math.pi / 4 + dir * 0.4) + (rng.nextDouble() - 0.5) * 0.9;
        final mid = Offset(
          cur.dx + len * 0.5 * math.cos(angle) +
              (rng.nextDouble() - 0.5) * len * 0.35,
          cur.dy + len * 0.5 * math.sin(angle) +
              (rng.nextDouble() - 0.5) * len * 0.35,
        );
        cur = Offset(
          cur.dx + len * math.cos(angle),
          cur.dy + len * math.sin(angle),
        );
        path.quadraticBezierTo(mid.dx, mid.dy, cur.dx, cur.dy);
      }

      // Halo clair (large, très transparent) puis trait fin gris.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.white.withValues(alpha: 0.35 * opacity)
          ..strokeCap = StrokeCap.round,
      );
      final shade = i % 5 == 0
          ? const Color(0xFF9AA3A9)
          : const Color(0xFFB9C1C7);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i % 5 == 0 ? 1.0 : 0.7
          ..color = shade.withValues(alpha: 0.30 * opacity)
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4) Micro-grain : points très fins, à peine perceptibles.
    final grain = Paint()
      ..color = const Color(0xFF8F979D).withValues(alpha: 0.05 * opacity);
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.6,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SilverMarblePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// Peintre graphite métal brossé : base #20272D, stries horizontales
/// fines claires/sombres, reflet discret.
class _GraphiteBrushedPainter extends CustomPainter {
  final double opacity;
  const _GraphiteBrushedPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    // 1) Base graphite.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF242B31),
            AppColors.graphite,
            Color(0xFF1C2227),
          ],
        ).createShader(rect),
    );

    // 2) Stries horizontales « métal brossé » (déterministes).
    final rng = math.Random(11);
    for (var i = 0; i < 130; i++) {
      final y = rng.nextDouble() * size.height;
      final h = 0.5 + rng.nextDouble() * 1.2;
      final bright = rng.nextBool();
      final a = (bright ? 0.020 : 0.030) * opacity *
          (0.5 + rng.nextDouble());
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, h),
        Paint()
          ..color = (bright ? Colors.white : Colors.black)
              .withValues(alpha: a.clamp(0.0, 0.08)),
      );
    }

    // 3) Reflet doux diagonal (discret).
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.035 * opacity),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sheen);
  }

  @override
  bool shouldRepaint(covariant _GraphiteBrushedPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
