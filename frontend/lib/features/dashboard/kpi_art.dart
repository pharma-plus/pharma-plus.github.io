import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ============================================================
/// ILLUSTRATIONS 3D DES CARTES KPI — style « rendu 3D premium »
/// de la maquette PHARMA+ : objets en volume, dégradés, reflets,
/// accents or, posés sur un socle vert lumineux.
/// Espace logique : 100 x 80.
/// ============================================================
enum KpiArt { register, bottle, boxes, clipboard, truck, people, pharmacist, bars }

class KpiArtPainter extends CustomPainter {
  final KpiArt art;
  const KpiArtPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ux = w / 100.0, uy = h / 80.0;
    Offset P(double x, double y) => Offset(x * ux, y * uy);
    Rect R(double x, double y, double w2, double h2) =>
        Rect.fromLTWH(x * ux, y * uy, w2 * ux, h2 * uy);
    RRect RR(double x, double y, double w2, double h2, double r) =>
        RRect.fromRectAndRadius(R(x, y, w2, h2), Radius.circular(r * ux));
    final shadow = Paint()
      ..color = const Color(0xFF020E08).withValues(alpha: 0.55)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

    Paint vgrad(Rect rc, Color top, Color bottom) => Paint()
      ..shader = ui.Gradient.linear(
          rc.topCenter, rc.bottomCenter, [top, bottom]);

    void text(String s, Offset c, double fs, Color color,
        {FontWeight fw = FontWeight.w900, double ls = 0}) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                color: color,
                fontSize: fs * ux,
                fontWeight: fw,
                letterSpacing: ls)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    // ---- Socle elliptique (podium lumineux) ----
    final podC = Offset(w * 0.46, h * 0.86);
    final podRx = w * 0.46, podRy = h * 0.14;
    canvas.drawOval(
        Rect.fromCenter(
            center: podC.translate(0, 2.6),
            width: podRx * 2,
            height: podRy * 2),
        Paint()..color = const Color(0xFF06150E));
    canvas.drawOval(
        Rect.fromCenter(
            center: podC, width: podRx * 2.2, height: podRy * 2.6),
        Paint()
          ..color = const Color(0xFF00C96B).withValues(alpha: 0.14)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
    final podRect =
        Rect.fromCenter(center: podC, width: podRx * 2, height: podRy * 2);
    canvas.drawOval(
        podRect,
        Paint()
          ..shader = ui.Gradient.linear(
              podRect.topCenter,
              podRect.bottomCenter,
              [const Color(0xFF1D5238), const Color(0xFF0E2C1D)]));
    canvas.drawOval(
        podRect.deflate(1.2),
        Paint()
          ..color = const Color(0xFF2E7A50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3);

    switch (art) {
      // ==============================================
      // 1. TERMINAL DE PAIEMENT + reçu + billets + or
      // ==============================================
      case KpiArt.register:
        final receipt = Path()
          ..moveTo(P(56, 22).dx, P(56, 22).dy)
          ..lineTo(P(76, 16).dx, P(76, 16).dy)
          ..lineTo(P(79, 30).dx, P(79, 30).dy)
          ..lineTo(P(59, 36).dx, P(59, 36).dy)
          ..close();
        canvas.drawPath(receipt, shadow);
        canvas.drawPath(receipt, Paint()..color = const Color(0xFFF6F4EC));
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(P(61, 24.5 + i * 3.4), P(73, 21 + i * 3.4),
              Paint()..color = const Color(0xFFB9B4A5)..strokeWidth = 1.1);
        }
        final body = RR(14, 30, 60, 36, 6);
        final bodyRect = R(14, 30, 60, 36);
        canvas.drawRRect(body, shadow);
        canvas.drawRRect(body, vgrad(bodyRect, const Color(0xFF3A4249), const Color(0xFF15191D)));
        canvas.drawRRect(body, Paint()..color = const Color(0xFF566068)..style = PaintingStyle.stroke..strokeWidth = 1);
        canvas.drawRRect(RR(20, 35, 30, 13, 2.5), Paint()..color = const Color(0xFF0C241A));
        final scr = R(21.5, 36.5, 27, 10);
        canvas.drawRRect(RR(21.5, 36.5, 27, 10, 2), Paint()..shader = ui.Gradient.linear(scr.topLeft, scr.bottomRight, [const Color(0xFF9FEFC4), const Color(0xFF3ED489)]));
        text('12 540', P(35, 41.5), 5, const Color(0xFF06341E), fw: FontWeight.w800);
        canvas.drawRRect(RR(22, 51, 12, 3, 1.4), Paint()..color = const Color(0xFF0B0F12));
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 4; c++) {
            final cx = 42 + c * 7.2, cy = 52 + r * 5.4;
            canvas.drawCircle(P(cx, cy), 2.1 * ux, Paint()..color = const Color(0xFF232A30));
            canvas.drawCircle(P(cx - 0.5, cy - 0.6), 1.4 * ux, Paint()..color = (r == 2 && c == 3) ? const Color(0xFF00C96B) : const Color(0xFF4A545C));
          }
        }
        canvas.drawRRect(RR(20, 62, 26, 2.6, 1.2), Paint()..color = const Color(0xFFD6A84F));
        void note(double x, double y, Color c) {
          canvas.drawRRect(RR(x, y, 20, 10, 1.6), Paint()..color = c);
          canvas.drawRRect(RR(x + 8, y + 3, 4.4, 4.4, 0.8), Paint()..color = Colors.white.withValues(alpha: 0.85));
        }
        canvas.drawRRect(RR(74, 50, 20, 10, 1.6), shadow);
        note(74, 50, const Color(0xFF1F8A55));
        note(76, 55, const Color(0xFF2FB563));
        for (var i = 0; i < 3; i++) {
          final cy = 68 - i * 2.6;
          canvas.drawOval(Rect.fromCenter(center: P(92, cy), width: 11 * ux, height: 4.4 * uy), Paint()..color = const Color(0xFFB8860B));
          canvas.drawOval(Rect.fromCenter(center: P(92, cy - 0.8), width: 11 * ux, height: 4.4 * uy), Paint()..color = const Color(0xFFE9C873));
        }
      // ==============================================
      // 2. FLACON + BOÎTE PHARMA+ + PLAQUETTE
      // ==============================================
      case KpiArt.bottle:
        final boxRect = R(52, 16, 40, 46);
        canvas.drawRRect(RR(52, 16, 40, 46, 2.5), shadow);
        canvas.drawRRect(RR(52, 16, 40, 46, 2.5), vgrad(boxRect, const Color(0xFFFFFFFF), const Color(0xFFDCE4DF)));
        canvas.drawRRect(RR(52, 16, 40, 46, 2.5), Paint()..color = const Color(0xFFB9C4BD)..style = PaintingStyle.stroke..strokeWidth = 0.8);
        final cross = Paint()..color = const Color(0xFF00A651);
        canvas.drawRRect(RR(56, 21, 3, 9, 1), cross);
        canvas.drawRRect(RR(53, 24, 9, 3, 1), cross);
        text('PHARMA+', P(76, 31), 4.4, const Color(0xFF0E5C38));
        canvas.drawRRect(RR(54, 37, 36, 1.6, 0.8), Paint()..color = const Color(0xFFE3E9E4));
        canvas.drawRRect(RR(54, 41, 26, 1.6, 0.8), Paint()..color = const Color(0xFFE3E9E4));
        canvas.drawRRect(RR(52, 54, 40, 8, 2), Paint()..color = const Color(0xFF0E5C38));
        text('500 mg', P(72, 58.2), 3.4, Colors.white, fw: FontWeight.w700);
        canvas.drawRRect(RR(18, 30, 28, 36, 7), shadow);
        final botRect = R(18, 30, 28, 36);
        canvas.drawRRect(RR(18, 30, 28, 36, 7), vgrad(botRect, const Color(0xFF2FA367), const Color(0xFF0B4A2E)));
        canvas.drawRRect(RR(21, 33, 4.5, 30, 2.2), Paint()..color = Colors.white.withValues(alpha: 0.30));
        final capRect = R(19, 19, 26, 12);
        canvas.drawRRect(RR(19, 19, 26, 12, 3), vgrad(capRect, const Color(0xFFFFFFFF), const Color(0xFFC9D2CC)));
        for (var i = 0; i < 6; i++) {
          canvas.drawLine(P(22.5 + i * 3.8, 20.5), P(22.5 + i * 3.8, 29.5), Paint()..color = const Color(0xFFAEB8B2)..strokeWidth = 1);
        }
        canvas.drawRRect(RR(19, 29, 26, 2.4, 1), Paint()..color = const Color(0xFFD6A84F));
        canvas.drawRRect(RR(21, 38, 22, 20, 2), Paint()..color = const Color(0xFFF7FAF7));
        canvas.drawRRect(RR(29, 42, 6, 12, 1.4), cross);
        canvas.drawRRect(RR(26, 45, 12, 6, 1.4), cross);
        canvas.drawRRect(RR(24, 55, 16, 1.4, 0.7), Paint()..color = const Color(0xFFC4CDC7));
        canvas.save();
        canvas.translate(P(8, 60).dx, P(8, 60).dy);
        canvas.skew(-0.22, 0);
        final blisterRect = R(0, 0, 42, 15);
        canvas.drawRRect(RR(0, 0, 42, 15, 3), vgrad(blisterRect, const Color(0xFFE8EDF0), const Color(0xFFB6C0C7)));
        canvas.drawRRect(RR(0, 0, 42, 15, 3), Paint()..color = const Color(0xFF9AA5AD)..style = PaintingStyle.stroke..strokeWidth = 0.8);
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(P(7 + i * 9.6, 5.5), 3.1 * ux, Paint()..color = const Color(0xFF2FB563));
          canvas.drawCircle(P(6 + i * 9.6, 4.5), 1.1 * ux, Paint()..color = Colors.white.withValues(alpha: 0.8));
        }
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(P(7 + i * 9.6, 11), 3.1 * ux, Paint()..color = const Color(0xFFE9E2D2));
        }
        canvas.restore();
      // ==============================================
      // 3. CARTONS + ALERTE STOCK (triangle orange)
      // ==============================================
      case KpiArt.boxes:
        void carton(double x, double y, double w2, double h2) {
          final rc = R(x, y, w2, h2);
          canvas.drawRRect(RR(x, y, w2, h2, 2), shadow);
          canvas.drawRRect(RR(x, y, w2, h2, 2), vgrad(rc, const Color(0xFFD2A56E), const Color(0xFF9C7243)));
          canvas.drawRRect(RR(x, y, w2, h2, 2), Paint()..color = const Color(0xFF7A562F)..style = PaintingStyle.stroke..strokeWidth = 0.8);
          canvas.drawRect(R(x + w2 / 2 - 2.6, y, 5.2, h2), Paint()..color = const Color(0xFFB98F58).withValues(alpha: 0.9));
          canvas.drawLine(P(x + w2 / 2, y + 2), P(x + w2 / 2, y + h2 - 2), Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1);
          canvas.drawLine(P(x + 2, y + h2 * 0.45), P(x + w2 - 2, y + h2 * 0.45), Paint()..color = const Color(0xFF7A562F)..strokeWidth = 0.9);
        }
        carton(30, 20, 48, 26);
        text('PHARMA+', P(54, 33), 3.8, const Color(0xFF5C3D1E), fw: FontWeight.w800);
        carton(18, 42, 46, 28);
        canvas.drawRRect(RR(26, 49, 14, 7, 1), Paint()..color = const Color(0xFFF1E8D8));
        // Triangle d'alerte lumineux.
        canvas.drawCircle(P(72, 52), 17 * ux, Paint()..color = const Color(0xFFF0A73B).withValues(alpha: 0.18)..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8));
        final tri = Path()
          ..moveTo(P(72, 36).dx, P(72, 36).dy)
          ..lineTo(P(88, 64).dx, P(88, 64).dy)
          ..lineTo(P(56, 64).dx, P(56, 64).dy)
          ..close();
        canvas.drawPath(tri, shadow);
        canvas.drawPath(tri, Paint()..shader = ui.Gradient.linear(P(72, 36), P(72, 64), [const Color(0xFFFFC964), const Color(0xFFE88B1F)]));
        canvas.drawPath(tri, Paint()..color = const Color(0xFFB36A12)..style = PaintingStyle.stroke..strokeWidth = 1);
        text('!', P(72, 54), 13, Colors.white);
        // Petite croix verte sur le carton avant.
        final cross = Paint()..color = const Color(0xFF00A651);
        canvas.drawRRect(RR(46, 58, 2.4, 8, 0.9), cross);
        canvas.drawRRect(RR(43.2, 60.8, 8, 2.4, 0.9), cross);

      // ==============================================
      // 4. COMMANDE — presse-papiers + carton + badge or
      // ==============================================
      case KpiArt.clipboard:
        canvas.drawRRect(RR(30, 14, 38, 52, 4), shadow);
        final boardRect = R(30, 14, 38, 52);
        canvas.drawRRect(RR(30, 14, 38, 52, 4), vgrad(boardRect, const Color(0xFF3B7D5C), const Color(0xFF1E4A34)));
        canvas.drawRRect(RR(42, 10, 14, 9, 2.5), Paint()..color = const Color(0xFF9AA5AD));
        canvas.drawRRect(RR(43.5, 11.5, 11, 6, 1.8), Paint()..color = const Color(0xFFC9D2D8));
        final sheetRect = R(34, 20, 30, 42);
        canvas.drawRRect(RR(34, 20, 30, 42, 2), vgrad(sheetRect, const Color(0xFFFFFFFF), const Color(0xFFE9E6DC)));
        text('COMMANDE', P(49, 26), 4, const Color(0xFF1E7A46), fw: FontWeight.w800);
        canvas.drawLine(P(38, 30), P(60, 30), Paint()..color = const Color(0xFF2FA367)..strokeWidth = 1.2);
        for (var i = 0; i < 4; i++) {
          final y = 35.0 + i * 6.6;
          canvas.drawRRect(RR(38, y, 5, 5, 1.2), Paint()..color = const Color(0xFFEDF3EE)..style = PaintingStyle.stroke..strokeWidth = 1);
          final tick = Path()
            ..moveTo(P(39, y + 2.6).dx, P(39, y + 2.6).dy)
            ..lineTo(P(40.4, y + 4).dx, P(40.4, y + 4).dy)
            ..lineTo(P(43, y).dx, P(43, y).dy);
          canvas.drawPath(tick, Paint()..color = const Color(0xFF00A651)..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
          canvas.drawRRect(RR(46, y + 1.2, 14, 2.6, 1.2), Paint()..color = const Color(0xFFC9C2B4));
        }
        // Carton devant à droite.
        final rc = R(58, 46, 34, 28);
        canvas.drawRRect(RR(58, 46, 34, 28, 2), shadow);
        canvas.drawRRect(RR(58, 46, 34, 28, 2), vgrad(rc, const Color(0xFFD2A56E), const Color(0xFF9C7243)));
        canvas.drawRRect(RR(58, 46, 34, 28, 2), Paint()..color = const Color(0xFF7A562F)..style = PaintingStyle.stroke..strokeWidth = 0.8);
        canvas.drawRect(R(72.7, 46, 5.2, 28), Paint()..color = const Color(0xFFB98F58).withValues(alpha: 0.9));
        // Badge or.
        canvas.drawCircle(P(30, 62), 6.5 * ux, Paint()..color = const Color(0xFFB8860B));
        canvas.drawCircle(P(30, 61.2), 6 * ux, Paint()..color = const Color(0xFFE9C873));
        final badge = Path()
          ..moveTo(P(27.2, 61.4).dx, P(27.2, 61.4).dy)
          ..lineTo(P(29.2, 63.4).dx, P(29.2, 63.4).dy)
          ..lineTo(P(33, 58.6).dx, P(33, 58.6).dy);
        canvas.drawPath(badge, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      // ==============================================
      // 5. CAMION DE LIVRAISON PHARMA+
      // ==============================================
      case KpiArt.truck:
        // Ombre + lignes de route.
        canvas.drawLine(P(8, 62), P(94, 62), Paint()..color = Colors.white.withValues(alpha: 0.10)..strokeWidth = 1.4);
        canvas.drawLine(P(10, 66), P(30, 66), Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1.2);
        // Cargo blanc (dégradé) + bande verte.
        final cargoRect = R(10, 24, 54, 34);
        canvas.drawRRect(RR(10, 24, 54, 34, 2.5), shadow);
        canvas.drawRRect(RR(10, 24, 54, 34, 2.5), vgrad(cargoRect, const Color(0xFFFFFFFF), const Color(0xFFCBD5D2)));
        canvas.drawRRect(RR(10, 24, 54, 34, 2.5), Paint()..color = const Color(0xFF9FAEA9)..style = PaintingStyle.stroke..strokeWidth = 0.9);
        canvas.drawRect(R(10, 51.5, 54, 6.5), Paint()..color = const Color(0xFF0E7A44));
        text('PHARMA+', P(37, 40), 5.6, const Color(0xFF0E5C38), fw: FontWeight.w900);
        canvas.drawLine(P(14, 47), P(60, 47), Paint()..color = const Color(0xFFB9C4CA)..strokeWidth = 1);
        // Cadre de backbone (structure).
        canvas.drawLine(P(12, 27), P(62, 27), Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 0.8);
        // Cabine.
        final cab = Path()
          ..moveTo(P(64, 32).dx, P(64, 32).dy)
          ..lineTo(P(74, 32).dx, P(74, 32).dy)
          ..lineTo(P(81, 44).dx, P(81, 44).dy)
          ..lineTo(P(81, 58).dx, P(81, 58).dy)
          ..lineTo(P(64, 58).dx, P(64, 58).dy)
          ..close();
        canvas.drawPath(cab, shadow);
        final cabRect = R(64, 32, 17, 26);
        canvas.drawPath(cab, vgrad(cabRect, const Color(0xFFE3E9EA), const Color(0xFFB7C2C4)));
        canvas.drawPath(cab, Paint()..color = const Color(0xFF93A1A6)..style = PaintingStyle.stroke..strokeWidth = 0.9);
        final winRect = R(66.5, 35, 9.5, 9);
        canvas.drawRRect(RR(66.5, 35, 9.5, 9, 1.5), vgrad(winRect, const Color(0xFF8FB7C9), const Color(0xFF51707E)));
        canvas.drawRRect(RR(64, 52, 17, 6, 1), Paint()..color = const Color(0xFF0E7A44));
        // Phare + pare-chocs.
        canvas.drawRRect(RR(79.2, 47, 2.6, 3.4, 1), Paint()..color = const Color(0xFFE9C873));
        // Roues 3D.
        void wheel(double x) {
          canvas.drawCircle(P(x, 60), 6.4 * ux, shadow);
          canvas.drawCircle(P(x, 59), 6.2 * ux, Paint()..color = const Color(0xFF141B18));
          canvas.drawCircle(P(x, 59), 3.4 * ux, Paint()..color = const Color(0xFFAEB8BC));
          canvas.drawCircle(P(x, 59), 1.3 * ux, Paint()..color = const Color(0xFF5A666B));
        }
        wheel(24);
        wheel(45);
        wheel(72);
        // Petits cartons dans le dos du cargo.
        canvas.drawRRect(RR(14, 30, 9, 8, 1), Paint()..color = const Color(0xFFD2A56E).withValues(alpha: 0.0));

      // ==============================================
      // 6. CLIENTS — trio + bouclier santé
      // ==============================================
      case KpiArt.people:
        void client(double cx, double hr, double cy, Color skin, Color shirt, Color hair) {
          // Torse.
          final body = RRect.fromRectAndRadius(R(cx - hr * 2.1, cy + hr * 0.9, hr * 4.2, hr * 3.4), Radius.circular(hr * 1.3 * ux));
          canvas.drawRRect(body, shadow);
          canvas.drawRRect(body, Paint()..color = shirt);
          // Tête.
          canvas.drawCircle(P(cx, cy), hr * ux, shadow);
          canvas.drawCircle(P(cx, cy - 0.4), hr * ux, Paint()..color = skin);
          // Cheveux.
          final hairP = Path()
            ..moveTo(P(cx - hr * 0.95, cy - hr * 0.15).dx, P(cx - hr * 0.95, cy - hr * 0.15).dy)
            ..quadraticBezierTo(P(cx, cy - hr * 1.75).dx, P(cx, cy - hr * 1.75).dy, P(cx + hr * 0.95, cy - hr * 0.15).dx, P(cx + hr * 0.95, cy - hr * 0.15).dy)
            ..quadraticBezierTo(P(cx, cy - hr * 0.85).dx, P(cx, cy - hr * 0.85).dy, P(cx - hr * 0.95, cy - hr * 0.15).dx, P(cx - hr * 0.95, cy - hr * 0.15).dy)
            ..close();
          canvas.drawPath(hairP, Paint()..color = hair);
        }
        client(26, 6.6, 36, const Color(0xFFE8B58C), const Color(0xFF274435), const Color(0xFF2A211B));
        client(74, 6.6, 36, const Color(0xFFD9A67C), const Color(0xFF2E4A3C), const Color(0xFF3A2E26));
        client(50, 8.6, 28, const Color(0xFFE8B58C), const Color(0xFF1C382B), const Color(0xFF241C16));
        // Bouclier vert + croix blanche (centre).
        final shield = Path()
          ..moveTo(P(50, 46).dx, P(50, 46).dy)
          ..lineTo(P(62, 51).dx, P(62, 51).dy)
          ..quadraticBezierTo(P(62, 66).dx, P(62, 66).dy, P(50, 72).dx, P(50, 72).dy)
          ..quadraticBezierTo(P(38, 66).dx, P(38, 66).dy, P(38, 51).dx, P(38, 51).dy)
          ..close();
        canvas.drawPath(shield, Paint()..color = const Color(0xFF0B3D26));
        canvas.drawPath(shield, Paint()..shader = ui.Gradient.linear(P(50, 46), P(50, 72), [const Color(0xFF37C878), const Color(0xFF0E7A44)]));
        canvas.drawPath(shield, Paint()..color = const Color(0xFF8FF0B6).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1);
        final wc = Paint()..color = Colors.white;
        canvas.drawRRect(RR(48.4, 51, 3.2, 12, 1.2), wc);
        canvas.drawRRect(RR(44, 55.4, 12, 3.2, 1.2), wc);

      // ==============================================
      // 7. PHARMACIEN — blouse blanche + croix verte
      // ==============================================
      case KpiArt.pharmacist:
        // Halo vert derrière le personnage.
        canvas.drawCircle(
            P(50, 40),
            27 * ux,
            Paint()
              ..color = const Color(0xFF00C96B).withValues(alpha: 0.10)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8));
        // Tête + cheveux.
        canvas.drawCircle(P(50, 26), 10 * ux, shadow);
        final headR = Rect.fromCircle(center: P(50, 25.4), radius: 9 * ux);
        canvas.drawCircle(
            headR.center,
            9 * ux,
            Paint()
              ..shader = ui.Gradient.linear(headR.topCenter, headR.bottomCenter,
                  [const Color(0xFFF6D3AC), const Color(0xFFDBA878)]));
        final hair = Path()
          ..moveTo(P(41, 23.5).dx, P(41, 23.5).dy)
          ..quadraticBezierTo(
              P(50, 11.5).dx, P(50, 11.5).dy, P(59, 23.5).dx, P(59, 23.5).dy)
          ..quadraticBezierTo(
              P(50, 17.5).dx, P(50, 17.5).dy, P(41, 23.5).dx, P(41, 23.5).dy)
          ..close();
        canvas.drawPath(hair, Paint()..color = const Color(0xFF3A2E26));
        // Cou.
        canvas.drawRect(R(45.5, 31, 9, 8), Paint()..color = const Color(0xFFE3B98E));
        // Blouse blanche en volume.
        final coatRect = R(31, 37, 38, 29);
        final coat =
            RRect.fromRectAndRadius(coatRect, Radius.circular(10 * ux));
        canvas.drawRRect(coat, shadow);
        canvas.drawRRect(
            coat,
            vgrad(coatRect, const Color(0xFFFFFFFF), const Color(0xFFD8E2DC)));
        canvas.drawRRect(
            coat,
            Paint()
              ..color = const Color(0xFFB9C4BD)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9);
        // Col V + poche avec stylo or.
        final collar = Path()
          ..moveTo(P(43, 37).dx, P(43, 37).dy)
          ..lineTo(P(50, 46.5).dx, P(50, 46.5).dy)
          ..lineTo(P(57, 37).dx, P(57, 37).dy)
          ..close();
        canvas.drawPath(collar, Paint()..color = const Color(0xFFC9D6CF));
        canvas.drawRRect(RR(60, 52, 6.5, 7, 1.2), Paint()..color = const Color(0xFFE4ECE7));
        canvas.drawRect(R(62.2, 48.5, 1.4, 5), Paint()..color = const Color(0xFFD6A84F));
        // Croix verte lumineuse.
        final crossGlow = Paint()
          ..color = const Color(0xFF00C96B).withValues(alpha: 0.35)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
        canvas.drawRRect(RR(47.4, 49, 5.2, 11, 1.2), crossGlow);
        canvas.drawRRect(RR(44.5, 51.9, 11, 5.2, 1.2), crossGlow);
        final crossGreen = Paint()..color = const Color(0xFF00A651);
        canvas.drawRRect(RR(48.4, 50, 3.2, 9, 1), crossGreen);
        canvas.drawRRect(RR(45.5, 52.9, 9, 3.2, 1), crossGreen);

      // ==============================================
      // 8. BÉNÉFICE — barres montantes + flèche or
      // ==============================================
      case KpiArt.bars:
        // Sol.
        canvas.drawLine(P(18, 67), P(86, 67),
            Paint()..color = const Color(0xFF24473A)..strokeWidth = 1.6);
        void bar(double x, double top, Color cTop, Color cBottom) {
          final rc = R(x, top, 11, 67 - top);
          canvas.drawRRect(RR(x, top, 11, 67 - top, 2), shadow);
          canvas.drawRRect(RR(x, top, 11, 67 - top, 2), vgrad(rc, cTop, cBottom));
          canvas.drawRect(
              R(x + 1.4, top + 2.4, 2, 67 - top - 4.8),
              Paint()..color = Colors.white.withValues(alpha: 0.28));
        }
        bar(25, 50, const Color(0xFF35B473), const Color(0xFF0E5C38));
        bar(42, 40, const Color(0xFF52D68C), const Color(0xFF127246));
        bar(59, 28, const Color(0xFF7BEBA4), const Color(0xFF1F8A55));
        // Halo + flèche or montante.
        canvas.drawCircle(
            P(76, 21),
            9 * ux,
            Paint()
              ..color = const Color(0xFFE9C873).withValues(alpha: 0.22)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6));
        final arrow = Path()
          ..moveTo(P(26, 46).dx, P(26, 46).dy)
          ..lineTo(P(44, 34).dx, P(44, 34).dy)
          ..lineTo(P(56, 38).dx, P(56, 38).dy)
          ..lineTo(P(74, 22).dx, P(74, 22).dy);
        canvas.drawPath(
            arrow,
            Paint()
              ..shader = ui.Gradient.linear(P(26, 46), P(76, 21),
                  [const Color(0xFFD6A84F), const Color(0xFFF3D98B)])
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
        final head = Path()
          ..moveTo(P(78, 14.5).dx, P(78, 14.5).dy)
          ..lineTo(P(79.2, 24).dx, P(79.2, 24).dy)
          ..lineTo(P(70.5, 22).dx, P(70.5, 22).dy)
          ..close();
        canvas.drawPath(head, Paint()..color = const Color(0xFFE9C873));
        // Pièce d'or.
        canvas.drawCircle(P(20, 24), 5.5 * ux, Paint()..color = const Color(0xFFB8860B));
        canvas.drawCircle(P(20, 23), 5 * ux, Paint()..color = const Color(0xFFE9C873));
        text('MAD', P(20, 23), 3, const Color(0xFF8A6508), fw: FontWeight.w900);
    }
  }

  @override
  bool shouldRepaint(covariant KpiArtPainter old) => old.art != art;
}
