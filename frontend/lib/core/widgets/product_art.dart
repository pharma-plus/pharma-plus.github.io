import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ============================================================
/// MINIATURES 3D DES PRODUITS (panier POS, catalogue) — style
/// « rendu 3D premium » PHARMA+ : boîtes, flacons, plaquettes
/// en volume avec socle lumineux. Espace logique : 100 x 80.
/// Chaque produit référence son [ProductArt] ; le champ
/// `Product.image` (asset ou URL) reste prioritaire lorsqu'il
/// existe — l'illustration peinte sert de fallback propre.
/// ============================================================
enum ProductArt {
  doliprane,
  bio3,
  eauThermale,
  vitamineC,
  paracetamol,
  mucosolvan,
  generic,
}

/// Widget prêt à l'emploi : image réelle si disponible (chargement
/// paresseux natif web), sinon miniature 3D peinte. Fallback
/// automatique en cas d'erreur de chargement.
class ProductThumb extends StatelessWidget {
  final ProductArt art;
  final String? image;
  final Color tint;
  final double size;
  final String? semanticLabel;
  const ProductThumb({
    super.key,
    required this.art,
    this.image,
    required this.tint,
    this.size = 26,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        CustomPaint(size: Size.square(size), painter: ProductArtPainter(art));
    Widget inner = fallback();
    final img = image;
    if (img != null && img.trim().isNotEmpty) {
      final uri = img.trim();
      inner = uri.startsWith('http')
          ? Image.network(uri,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low, // miniatures : léger
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) => fallback())
          : Image.asset(uri,
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) => fallback());
    }
    return Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: tint.withValues(alpha: 0.38)),
      ),
      child: Center(child: Semantics(label: semanticLabel, child: inner)),
    );
  }
}

class ProductArtPainter extends CustomPainter {
  final ProductArt art;
  const ProductArtPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ux = w / 100.0, uy = h / 80.0;
    Offset P(double x, double y) => Offset(x * ux, y * uy);
    Rect R(double x, double y, double w2, double h2) =>
        Rect.fromLTWH(x * ux, y * uy, w2 * ux, h2 * uy);
    RRect RR(double x, double y, double w2, double h2, double r) =>
        RRect.fromRectAndRadius(R(x, y, w2, h2), Radius.circular(r * ux));

    // ---- Socle lumineux commun ----
    canvas.drawOval(
        Rect.fromCenter(center: P(50, 74), width: 74 * ux, height: 14 * uy),
        Paint()
          ..color = const Color(0xFF00C96B).withValues(alpha: 0.16)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
    canvas.drawOval(
        Rect.fromCenter(center: P(50, 75), width: 62 * ux, height: 10 * uy),
        Paint()..color = const Color(0xFF0B241A));

    // Ombre portée douce.
    final shadow = Paint()
      ..color = const Color(0xFF020E08).withValues(alpha: 0.50)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);

    void text(String s, Offset c, double fs, Color color,
        {FontWeight fw = FontWeight.w900, double maxW = 40}) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                color: color,
                fontSize: fs * ux,
                fontWeight: fw,
                letterSpacing: 0.2)),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout(maxWidth: maxW * ux);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    /// Boîte 3D : face avant + dessus + tranche droite.
    void box3d(double x, double y, double bw, double bh, double depth,
        Color face, Color top, Color side) {
      final faceR = RR(x, y, bw, bh, 2);
      canvas.drawRRect(faceR.shift(const Offset(1.6, 1.6)), shadow);
      canvas.drawRRect(faceR, Paint()..color = face);
      // Tranche droite (perspective).
      final sidePath = Path()
        ..moveTo(P(x + bw, y + 1.4).dx, P(x + bw, y + 1.4).dy)
        ..lineTo(P(x + bw + depth, y - 1).dx, P(x + bw + depth, y - 1).dy)
        ..lineTo(P(x + bw + depth, y + bh - 2.6).dx,
            P(x + bw + depth, y + bh - 2.6).dy)
        ..lineTo(P(x + bw, y + bh - 1).dx, P(x + bw, y + bh - 1).dy)
        ..close();
      canvas.drawPath(sidePath, Paint()..color = side);
      // Dessus.
      final topPath = Path()
        ..moveTo(P(x, y).dx, P(x, y).dy)
        ..lineTo(P(x + depth * 0.9, y - depth * 0.75).dx,
            P(x + depth * 0.9, y - depth * 0.75).dy)
        ..lineTo(P(x + bw + depth, y - 1).dx, P(x + bw + depth, y - 1).dy)
        ..lineTo(P(x + bw, y + 1.4).dx, P(x + bw, y + 1.4).dy)
        ..close();
      canvas.drawPath(topPath, Paint()..color = top);
      // Reflet vertical.
      canvas.drawRect(R(x + 1.6, y + 1.6, 2, bh - 3.2),
          Paint()..color = Colors.white.withValues(alpha: 0.30));
    }

    /// Flacon 3D (corps + épaules + bouchon + étiquette).
    void bottle(double cx, double cy, double bw, double bh, Color body,
        Color cap, Color labelBand, double capH) {
      final bodyR = RRect.fromRectAndRadius(
          Rect.fromLTWH(
              (cx - bw / 2) * ux, (cy - bh / 2) * uy, bw * ux, bh * uy),
          Radius.circular(bw * 0.30 * ux));
      canvas.drawRRect(bodyR.shift(const Offset(1.5, 1.5)), shadow);
      canvas.drawRRect(bodyR, Paint()..color = body);
      // Épaules.
      canvas.drawOval(
          Rect.fromCenter(
              center: P(cx, cy - bh / 2), width: bw * ux, height: bw * 0.5 * uy),
          Paint()..color = body);
      // Reflet.
      canvas.drawRRect(
          RR(cx - bw / 2 + 1.4, cy - bh / 2 + 2, bw * 0.22, bh - 5, 2),
          Paint()..color = Colors.white.withValues(alpha: 0.35));
      // Bouchon.
      canvas.drawRRect(
          RR(cx - bw * 0.30, cy - bh / 2 - capH, bw * 0.60, capH + 1.5, 1.5),
          Paint()
            ..shader = ui.Gradient.linear(P(cx - bw * 0.3, cy),
                P(cx + bw * 0.3, cy), [cap, cap.withValues(alpha: 0.75)]));
      // Étiquette.
      canvas.drawRRect(
          RR(cx - bw / 2 + 1, cy - bh * 0.16, bw - 2, bh * 0.42, 1.5),
          Paint()..color = labelBand);
    }

    /// Plaquette de comprimés (blister).
    void blister(double x, double y, double bw, double bh, Color pill) {
      canvas.drawRRect(
          RR(x, y, bw, bh, 2.5), Paint()..color = const Color(0xFFE9F1EC));
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(P(x + 5 + i * 7, y + bh / 2), 2.6 * ux,
            Paint()..color = pill);
        canvas.drawCircle(
            P(x + 5 + i * 7 - 0.8, y + bh / 2 - 0.8),
            1 * ux,
            Paint()..color = Colors.white.withValues(alpha: 0.6));
      }
      canvas.drawRRect(
          RR(x, y, bw, bh, 2.5),
          Paint()
            ..color = const Color(0xFF0B2418).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);
    }

    switch (art) {
      // ---- DOLIPRANE 1g : boîte blanche/verte + blister ----
      case ProductArt.doliprane:
        box3d(26, 20, 34, 42, 6, const Color(0xFFF4F8F5),
            const Color(0xFFDDE8E1), const Color(0xFFC3D2C9));
        canvas.drawRRect(
            RR(26, 28, 34, 9, 1.2), Paint()..color = const Color(0xFF00A651));
        text('DOLIPRANE', P(43, 32.6), 4.6, Colors.white, maxW: 32);
        text('1g', P(43, 46), 10, const Color(0xFF0B3B23));
        blister(52, 50, 30, 14, const Color(0xFF2FB563));

      // ---- BIO 3 : flacon ambré + compte-gouttes ----
      case ProductArt.bio3:
        bottle(
            46,
            42,
            20,
            36,
            const Color(0xFF8A5A2B),
            const Color(0xFF2E2A26),
            const Color(0xFFF3E9D8),
            5);
        // Compte-gouttes.
        canvas.drawRRect(RR(44.4, 4, 3.2, 10, 1.2),
            Paint()..color = const Color(0xFFB9C6BF));
        canvas.drawCircle(
            P(46, 17), 2.4 * ux, Paint()..color = const Color(0xFFDCE8E2));
        text('BIO 3', P(46, 42), 6, const Color(0xFF6B4A1F));
        // Goutte violette (identité produit).
        canvas.drawCircle(
            P(66, 30),
            2.4 * ux,
            Paint()
              ..color = const Color(0xFF9B5FC0)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2));

      // ---- EAU THERMALE : bouteille spray bleue ----
      case ProductArt.eauThermale:
        bottle(
            46,
            40,
            22,
            40,
            const Color(0xFF5B8FD9),
            const Color(0xFF3B6CB4),
            const Color(0xFFEAF2FC),
            5.5);
        text('EAU', P(46, 37), 6, const Color(0xFF2E4A66));
        text('THERMALE', P(46, 44), 3.6, const Color(0xFF2E4A66));
        // Gouttelettes.
        canvas.drawCircle(
            P(66, 24), 1.6 * ux, Paint()..color = const Color(0xFF9CC4F5));
        canvas.drawCircle(
            P(70, 32), 1.2 * ux, Paint()..color = const Color(0xFF9CC4F5));

      // ---- VITAMINE C 1000 : tube effervescent + bulles ----
      case ProductArt.vitamineC:
        box3d(28, 18, 26, 44, 5, const Color(0xFFF0B429),
            const Color(0xFFD9A11F), const Color(0xFFC48E17));
        text('VIT', P(41, 26), 5.5, const Color(0xFF5B4203));
        text('C', P(41, 42), 12, Colors.white);
        text('1000', P(41, 52), 4.5, const Color(0xFF5B4203));
        // Comprimé effervescent + bulles.
        canvas.drawCircle(
            P(66, 52), 6 * ux, Paint()..color = const Color(0xFFFDF4E0));
        canvas.drawCircle(
            P(66, 52),
            6 * ux,
            Paint()
              ..color = const Color(0xFFC98A1B)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        for (final (bx, by) in const [
          (60.0, 40.0),
          (67.0, 36.0),
          (72.0, 42.0),
          (63.0, 33.0)
        ]) {
          canvas.drawCircle(P(bx, by), 1.1 * ux,
              Paint()..color = const Color(0xFFBFE3FF));
        }

      // ---- PARACÉTAMOL 500 : boîte verte + plaquette ----
      case ProductArt.paracetamol:
        box3d(28, 22, 30, 38, 5.5, const Color(0xFF2FB563),
            const Color(0xFF249A52), const Color(0xFF1E8144));
        text('500', P(43, 38), 7.5, Colors.white);
        text('mg', P(43, 47), 5, const Color(0xFFE6F7EE));
        blister(50, 46, 30, 15, const Color(0xFFF4F8F5));

      // ---- MUCOSOLVAN : boîte + flacon sirop ----
      case ProductArt.mucosolvan:
        box3d(26, 24, 22, 34, 4.5, const Color(0xFFE0557C),
            const Color(0xFFC64566), const Color(0xFFA93A58));
        bottle(
            60,
            44,
            18,
            32,
            const Color(0xFF2FB563),
            const Color(0xFF1E8144),
            const Color(0xFFEAF7F0),
            4.5);
        text('MU', P(60, 42), 5, const Color(0xFF0B3B23));

      // ---- FALLBACK : boîte verte croix blanche ----
      case ProductArt.generic:
        box3d(32, 22, 30, 38, 5.5, const Color(0xFF0E8C4F),
            const Color(0xFF0B7440), const Color(0xFF096035));
        final cross = Paint()..color = Colors.white;
        canvas.drawRRect(RR(44, 32, 6, 16, 1.2), cross);
        canvas.drawRRect(RR(39, 37, 16, 6, 1.2), cross);
    }
  }

  @override
  bool shouldRepaint(covariant ProductArtPainter old) => old.art != art;
}
