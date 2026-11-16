import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// ============================================================
/// FONDS « ÉMERAUDE MÉTALLISÉE ORÉE » (thème clair) et
/// « GRAPHITE MÉTAL BROSSÉ » (thème sombre) — dessinés par code.
///
/// La texture du thème clair est votre image « Fond émeraude métallisé
/// aux accents dorés » (assets/images/emerald_principale.png) ; le thème
/// sombre conserve le graphite métal brossé.
///
/// Les deux fonds sont FONCÉS : le texte doit être CLAIR (champagne /
/// blanc) par-dessus. `lightText` est exposé via un InheritedWidget pour
/// que les enfants (titres, libellés, séparateurs) s'adaptent
/// automatiquement.
///
/// Le thème clair est PEINT (CustomPainter déterministe, graine fixe)
/// et mis en cache (shouldRepaint => false + RepaintBoundary) ; l'image
/// est superposée par-dessus (errorBuilder => repli peint si l'asset
/// échoue à charger).
/// ============================================================
class MarbleBackground extends StatelessWidget {
  final Widget? child;
  final bool dark;

  /// Opacité globale de la texture (1 = pleine).
  final double opacity;

  /// Si true, le texte sur ce fond doit être CLAIR (fond émeraude ou
  /// graphite foncés). Défaut true car les deux textures sont foncées.
  final bool lightText;

  const MarbleBackground({
    super.key,
    this.child,
    this.dark = false,
    this.opacity = 1.0,
    this.lightText = true,
  });

  /// Récupère la configuration de texte du `MarbleBackground` ancêtre.
  static MarbleBackgroundData? of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_MarbleBackgroundScope>();
    return scope?.data;
  }

  @override
  Widget build(BuildContext context) {
    // Données de texte exposées aux descendants (couleur claire sur fond foncé).
    final data = MarbleBackgroundData(
      dark: dark,
      lightText: lightText,
      textColor: lightText
          ? (dark ? AppColors.porcelain : AppColors.champagne)
          : AppColors.inkDark,
    );
    return _MarbleBackgroundScope(
      data: data,
      child: DefaultTextStyle(
        style: TextStyle(color: data.textColor, inherit: true),
        child: RepaintBoundary(
          child: Stack(
            children: [
              // Calque texture peinte (repli si l'asset échoue).
              Positioned.fill(
                child: CustomPaint(
                  isComplex: true,
                  willChange: false,
                  painter:
                      dark
                          ? _GraphiteBrushedPainter(opacity: opacity)
                          : _EmeraldPainted(opacity: opacity),
                ),
              ),
              // Calque image (émeraude ou graphite).
              Positioned.fill(
                child: Image.asset(
                  dark
                      ? 'assets/images/graphite_principale.webp'
                      : 'assets/images/emerald_principale.png',
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
        ),
      ),
    );
  }
}

/// Données exposées aux enfants par l'InheritedWidget.
class MarbleBackgroundData {
  final bool dark;
  final bool lightText;
  final Color textColor;

  const MarbleBackgroundData({
    required this.dark,
    required this.lightText,
    required this.textColor,
  });
}

/// InheritedWidget : propage la config de texte aux descendants.
class _MarbleBackgroundScope extends InheritedWidget {
  final MarbleBackgroundData data;

  const _MarbleBackgroundScope({
    super.key,
    required this.data,
    required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant _MarbleBackgroundScope old) =>
      old.data != data;
}

/// Peintre de repli thème clair (émeraude foncée) : base émeraude, veines
/// dorées discrètes, léger voile lumineux — utilisé uniquement si
/// l'asset PNG émeraude échoue à charger.
class _EmeraldPainted extends CustomPainter {
  final double opacity;
  const _EmeraldPainted({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1) Base émeraude foncée (jamais blanc pur).
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B2A1E),
          Color(0xFF103A28),
          Color(0xFF0B2A1E),
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
            AppColors.champagne.withValues(alpha: 0.12 * opacity),
            AppColors.champagne.withValues(alpha: 0.0),
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
          cur.dx +
              len * 0.5 * math.cos(angle) +
              (rng.nextDouble() - 0.5) * len * 0.35,
          cur.dy +
              len * 0.5 * math.sin(angle) +
              (rng.nextDouble() - 0.5) * len * 0.35,
        );
        cur = Offset(
          cur.dx + len * math.cos(angle),
          cur.dy + len * math.sin(angle),
        );
        path.quadraticBezierTo(mid.dx, mid.dy, cur.dx, cur.dy);
      }

      // Halo doré puis trait fin.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = AppColors.champagne.withValues(alpha: 0.25 * opacity)
          ..strokeCap = StrokeCap.round,
      );
      final shade =
          i % 5 == 0 ? const Color(0xFF8A6A1D) : const Color(0xFFB4881F);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i % 5 == 0 ? 1.0 : 0.7
          ..color = shade.withValues(alpha: 0.22 * opacity)
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4) Micro-grain : points très fins, à peine perceptibles.
    final grain = Paint()
      ..color = const Color(0xFF5F7A64).withValues(alpha: 0.06 * opacity);
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.6,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmeraldPainted oldDelegate) =>
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
      final a = (bright ? 0.020 : 0.030) * opacity * (0.5 + rng.nextDouble());
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
