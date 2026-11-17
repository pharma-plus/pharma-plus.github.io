import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// ============================================================
/// FONDS « ÉMERAUDE MÉTALLISÉE ORÉE » (thème clair) et
/// « GRAPHITE MÉTAL BROSSÉ » (thème sombre).
///
/// La texture du thème clair est votre image « Fond émeraude métallisé
/// aux accents dorés » (assets/images/emerald_principale.png) seule ;
/// le thème sombre conserve le graphite métal brossé.
///
/// Les deux fonds sont FONCÉS : le texte doit être CLAIR (champagne /
/// blanc) par-dessus. `lightText` est exposé via un InheritedWidget pour
/// que les enfants (titres, libellés, séparateurs) s'adaptent
/// automatiquement.
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
              if (dark)
                Positioned.fill(
                  child: CustomPaint(
                    isComplex: true,
                    willChange: false,
                    painter: _GraphiteBrushedPainter(opacity: opacity),
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
