import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ============================================================
/// ILLUSTRATIONS 3D DES 8 KPI ÔÇö fid├¿les ├á la maquette PHARMA+ :
/// 1 TPE + re├ºu + pi├¿ces d'or ┬À 2 pilulier bouchon vert + blister ┬À
/// 3 cartons + triangle d'alerte rouge ┬À 4 presse-papiers COMMANDE
/// + carton ┬À 5 camion PHARMADE + cartons ┬À 6 clients en polo vert ┬À
/// 7 employ├® blouse blanche croix verte ┬À 8 barres + fl├¿che + or.
/// Espace logique : 100 ├ù 80 ┬À socle vert lumineux (podium).
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
    RRect rr(double x, double y, double w2, double h2, double r) =>
        RRect.fromRectAndRadius(R(x, y, w2, h2), Radius.circular(r * ux));
    final shadow = Paint()
      ..color = const Color(0xFF020E08).withValues(alpha: 0.5)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

    Paint vgrad(Rect rc, Color top, Color bottom) => Paint()
      ..shader = ui.Gradient.linear(rc.topCenter, rc.bottomCenter, [top, bottom]);

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

    // ---- Socle elliptique (podium lumineux de la maquette) ----
    final podC = Offset(w * 0.46, h * 0.86);
    final podRx = w * 0.42, podRy = h * 0.12;
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

    // ---- Pi├¿ces d'or empil├®es (r├®utilisables) ----
    void coinStack(double cx, double baseY, int n, double rw) {
      for (var i = 0; i < n; i++) {
        final cy = baseY - i * 3.4;
        final rc = Rect.fromCenter(
            center: P(cx, cy), width: rw * ux, height: 5.4 * uy);
        canvas.drawOval(
            Rect.fromCenter(
                center: P(cx, cy + 1.6), width: rw * ux, height: 5.4 * uy),
            Paint()..color = const Color(0xFF8A6212));
        canvas.drawOval(rc, Paint()..color = const Color(0xFFC79A2E));
        canvas.drawOval(
            Rect.fromCenter(
                center: P(cx, cy - 0.8), width: rw * 0.86 * ux, height: 4.2 * uy),
            Paint()..color = const Color(0xFFEFCB6C));
        canvas.drawOval(
            Rect.fromCenter(
                center: P(cx, cy - 0.8), width: rw * 0.5 * ux, height: 2.6 * uy),
            Paint()..color = const Color(0xFFF7E2A0));
      }
    }

    switch (art) {
      // ==============================================
      // 1. VENTES DU JOUR — TPE + reçu + pièces d'or
      // ==============================================
      case KpiArt.register:
        // Reçu papier sortant du terminal.
        final receipt = Path()
          ..moveTo(P(41, 26).dx, P(41, 26).dy)
          ..lineTo(P(41, 9).dx, P(41, 9).dy)
          ..lineTo(P(44, 12).dx, P(44, 12).dy)
          ..lineTo(P(47, 8).dx, P(47, 8).dy)
          ..lineTo(P(50, 12).dx, P(50, 12).dy)
          ..lineTo(P(53, 9).dx, P(53, 9).dy)
          ..lineTo(P(53, 26).dx, P(53, 26).dy)
          ..close();
        canvas.drawPath(receipt, shadow);
        canvas.drawPath(receipt, Paint()..color = const Color(0xFFF8F6EE));
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(P(44, 13.5 + i * 3.4), P(50, 13.5 + i * 3.4),
              Paint()
                ..color = const Color(0xFFB9B4A6)
                ..strokeWidth = 1.1);
        }
        // Corps du terminal.
        final body = R(25, 24, 40, 40);
        canvas.drawRRect(rr(27, 26, 40, 40, 3), shadow);
        canvas.drawRRect(rr(25, 24, 40, 40, 3.4),
            vgrad(body, const Color(0xFF3A423C), const Color(0xFF181D19)));
        // Tranche droite sombre (volume).
        canvas.drawRRect(
            rr(61, 26, 4, 38, 2), Paint()..color = const Color(0xFF101512));
        // Écran vert lumineux.
        final scr = R(29.5, 28.5, 31, 11);
        canvas.drawRRect(rr(29.5, 28.5, 31, 11, 1.6),
            Paint()..color = const Color(0xFF0B1310));
        canvas.drawRRect(
            rr(31, 30, 28, 8, 1.2),
            Paint()
              ..shader = ui.Gradient.linear(scr.topLeft, scr.bottomRight, [
                const Color(0xFF25E08A),
                const Color(0xFF00A651),
              ]));
        canvas.drawRRect(
            rr(31.4, 30.4, 12, 3, 1),
            Paint()..color = Colors.white.withValues(alpha: 0.35));
        text('12,50', P(45, 34), 4.4, const Color(0xFF04351D),
            fw: FontWeight.w900);
        // Clavier.
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 4; c++) {
            final kx = 29.5 + c * 7.6, ky = 42.5 + r * 5.4;
            final isFunc = r == 0;
            canvas.drawRRect(
                rr(kx + 0.7, ky + 1.1, 6, 3.6, 1),
                Paint()..color = const Color(0xFF0D1210));
            canvas.drawRRect(
                rr(kx, ky, 6, 3.6, 1),
                Paint()
                  ..color = isFunc
                      ? const Color(0xFF00A651)
                      : const Color(0xFFE9E7E0));
            if (!isFunc) {
              canvas.drawRRect(
                  rr(kx + 1, ky + 0.7, 4, 1.4, 0.6),
                  Paint()..color = const Color(0xFFC7C4BA));
            }
          }
        }
        // Fente carte à droite.
        canvas.drawRRect(
            rr(56.5, 43.5, 5.4, 1.6, 0.8),
            Paint()..color = const Color(0xFF0D1210));
        // Billet vert derrière les pièces.
        canvas.drawRRect(
            rr(63, 40, 30, 13, 2),
            vgrad(R(63, 40, 30, 13), const Color(0xFF2FBF78),
                const Color(0xFF0B7A44)));
        canvas.drawRRect(
            rr(65.5, 43, 25, 7, 1.2),
            Paint()..color = Colors.white.withValues(alpha: 0.22));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                R(63, 40, 30, 13).deflate(1.4), const Radius.circular(2)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..color = const Color(0xFF085C34));
        // Pièces d'or + pièce debout avec +.
        coinStack(78, 66, 3, 17);
        canvas.drawCircle(
            P(66.5, 44.5), 6.6 * ux, Paint()..color = const Color(0xFFC79A2E));
        canvas.drawCircle(
            P(66.5, 44.5), 5.4 * ux, Paint()..color = const Color(0xFFEFCB6C));
        text('+', P(66.5, 44.7), 6, const Color(0xFF8A6212));

      // ==============================================
      // 2. MÉDICAMENTS — pilulier bouchon vert + blister
      // ==============================================
      case KpiArt.bottle:
        // Pilulier blanc.
        final bottleBody = R(30, 30, 27, 33);
        canvas.drawRRect(rr(32, 32, 27, 33, 5), shadow);
        canvas.drawRRect(
            rr(30, 30, 27, 33, 5),
            vgrad(bottleBody, const Color(0xFFFEFEFC),
                const Color(0xFFD5D5CC)));
        // Épaule du flacon.
        canvas.drawRRect(
            rr(31.5, 27, 24, 7, 3),
            vgrad(R(31.5, 27, 24, 7), const Color(0xFFFFFFFF),
                const Color(0xFFE4E4DB)));
        // Bouchon VERT rainuré (maquette).
        canvas.drawRRect(
            rr(31, 15, 25, 13, 2.4),
            vgrad(R(31, 15, 25, 13), const Color(0xFF17C97E),
                const Color(0xFF008A4C)));
        for (var i = 0; i < 5; i++) {
          canvas.drawLine(
              P(34.4 + i * 4.6, 16.4), P(34.4 + i * 4.6, 26.6),
              Paint()
                ..color = const Color(0xFF006B3C).withValues(alpha: 0.55)
                ..strokeWidth = 1.1);
        }
        canvas.drawRRect(
            rr(31, 15, 25, 3.2, 1.6),
            Paint()..color = Colors.white.withValues(alpha: 0.28));
        // Étiquette claire à croix verte + bande verte.
        canvas.drawRRect(
            rr(33.5, 38, 20, 20, 1.6),
            Paint()..color = const Color(0xFFF7FBF7));
        canvas.drawRRect(
            rr(33.5, 53.4, 20, 4.6, 1.4),
            Paint()..color = const Color(0xFF00A651));
        final cg = Paint()..color = const Color(0xFF00A651);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                R(41.4, 41, 4.2, 11), const Radius.circular(1.2)),
            cg);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                R(38.5, 43.9, 10, 5.2), const Radius.circular(1.2)),
            cg);
        canvas.drawLine(
            P(36, 48.2), P(38, 48.2),
            Paint()
              ..color = const Color(0xFFC9CFC9)
              ..strokeWidth = 1);
        // Reflet vertical.
        canvas.drawRRect(
            rr(33, 31, 3.4, 30, 1.7),
            Paint()..color = Colors.white.withValues(alpha: 0.5));
        // Blister blanc à pilules (avant, à droite).
        canvas.save();
        canvas.translate(P(69, 57).dx, P(69, 57).dy);
        canvas.rotate(-0.16);
        final bl = R(-19, -10, 38, 20);
        canvas.drawRRect(
            RRect.fromRectAndRadius(bl, const Radius.circular(3)), shadow);
        canvas.drawRRect(
            RRect.fromRectAndRadius(bl, const Radius.circular(3)),
            Paint()..color = const Color(0xFFF4F6F2));
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 4; c++) {
            final px = -13.5 + c * 9.0, py = -4.6 + r * 9.0;
            canvas.drawCircle(P(px + 1, py + 1), 3.4 * ux,
                Paint()..color = const Color(0xFFC9CCC4));
            canvas.drawCircle(P(px, py), 3.4 * ux,
                Paint()..color = const Color(0xFFFFFFFF));
            canvas.drawCircle(P(px - 0.8, py - 0.8), 1.3 * ux,
                Paint()..color = const Color(0xFFE4E8E2));
          }
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(bl, const Radius.circular(3)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..color = const Color(0xFFB9BFB6));
        canvas.restore();

      // ==============================================
      // 3. STOCK FAIBLE — cartons + triangle d'alerte
      // ==============================================
      case KpiArt.boxes:
        // Carton arrière.
        canvas.drawRRect(rr(24, 28, 26, 24, 2), shadow);
        final backTop = R(22, 26, 26, 7);
        canvas.drawRRect(
            rr(22, 33, 26, 19, 1.6),
            vgrad(R(22, 33, 26, 19), const Color(0xFFC89B5F),
                const Color(0xFF9C7440)));
        canvas.drawRRect(
            rr(22, 26, 26, 7, 1.6),
            vgrad(backTop, const Color(0xFFDDB277), const Color(0xFFC29255)));
        canvas.drawLine(
            P(35, 27), P(35, 33),
            Paint()
              ..color = const Color(0xFF7A5A30).withValues(alpha: 0.7)
              ..strokeWidth = 1.1);
        // Carton avant avec bande adhésive.
        canvas.drawRRect(rr(36, 42, 32, 26, 2), shadow);
        final frontTop = R(34, 40, 32, 8);
        canvas.drawRRect(
            rr(34, 48, 32, 20, 1.6),
            vgrad(R(34, 48, 32, 20), const Color(0xFFB98A4E),
                const Color(0xFF8A6435)));
        canvas.drawRRect(
            rr(34, 40, 32, 8, 1.6),
            vgrad(frontTop, const Color(0xFFD9AE72), const Color(0xFFBB8E51)));
        canvas.drawRRect(
            rr(46.5, 41, 7, 27, 0.8),
            Paint()..color = const Color(0xFFE4C98F).withValues(alpha: 0.9));
        canvas.drawLine(
            P(50, 41.4), P(50, 68),
            Paint()
              ..color = const Color(0xFF7A5A30).withValues(alpha: 0.5)
              ..strokeWidth = 1);
        // Triangle d'alerte rouge-orangé avec glow.
        canvas.drawCircle(
            P(76, 36), 15 * ux,
            Paint()
              ..color = const Color(0xFFF2542D).withValues(alpha: 0.22)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8));
        final triRounded = Path();
        triRounded.moveTo(P(76, 21).dx, P(76, 21).dy);
        triRounded.lineTo(P(90.6, 47.5).dx, P(90.6, 47.5).dy);
        triRounded.quadraticBezierTo(P(91.8, 49.6).dx, P(91.8, 49.6).dy, P(89.4, 49.6).dx, P(89.4, 49.6).dy);
        triRounded.lineTo(P(62.6, 49.6).dx, P(62.6, 49.6).dy);
        triRounded.quadraticBezierTo(P(60.2, 49.6).dx, P(60.2, 49.6).dy, P(61.4, 47.5).dx, P(61.4, 47.5).dy);
        triRounded.close();
        canvas.drawPath(triRounded, shadow);
        canvas.drawPath(
            triRounded,
            Paint()
              ..shader = ui.Gradient.linear(P(76, 20), P(76, 50),
                  [const Color(0xFFFF7A52), const Color(0xFFD93A1F)]));
        canvas.drawPath(
            triRounded,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Colors.white.withValues(alpha: 0.35));
        // « ! » blanc.
        canvas.drawRRect(
            rr(74.4, 30.5, 3.2, 10, 1.6),
            Paint()..color = Colors.white);
        canvas.drawCircle(P(76, 44.6), 1.9 * ux, Paint()..color = Colors.white);

      // ==============================================
      // 4. COMMANDES — presse-papiers COMMANDE + carton
      // ==============================================
      case KpiArt.clipboard:
        // Planche verte.
        canvas.drawRRect(rr(26, 18, 30, 52, 3), shadow);
        canvas.drawRRect(
            rr(24, 16, 30, 50, 3),
            vgrad(R(24, 16, 30, 50), const Color(0xFF0F6B3F),
                const Color(0xFF083F27)));
        // Papier blanc.
        canvas.drawRRect(
            rr(29, 24, 20, 40, 1.6), Paint()..color = const Color(0xFFFBFAF4));
        canvas.drawRRect(
            rr(29, 24, 20, 40, 1.6),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = const Color(0xFFD9D4C4));
        // En-tête COMMANDE + lignes + cachet rouge.
        text('COMMANDE', P(39, 29.5), 4.6, const Color(0xFFC43C3C),
            fw: FontWeight.w900);
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
              P(32, 35 + i * 4.6), P(46 - (i % 2) * 4, 35 + i * 4.6),
              Paint()
                ..color = const Color(0xFFC4C0B2)
                ..strokeWidth = 1.2);
        }
        canvas.drawCircle(
            P(35, 57), 3.4 * ux, Paint()..color = const Color(0xFFC43C3C));
        canvas.drawCircle(
            P(35, 57), 2.2 * ux,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.8));
        // Pince métallique.
        canvas.drawRRect(
            rr(33, 11, 12, 8, 2),
            vgrad(R(33, 11, 12, 8), const Color(0xFFD4D8DC),
                const Color(0xFF8E979E)));
        canvas.drawRRect(
            rr(36, 13.5, 6, 2.6, 1.3),
            Paint()..color = const Color(0xFF6B7378));
        // Carton kraft à droite.
        canvas.drawRRect(rr(58, 46, 30, 22, 2), shadow);
        final boxTop = R(56, 44, 30, 7);
        canvas.drawRRect(
            rr(56, 51, 30, 17, 1.6),
            vgrad(R(56, 51, 30, 17), const Color(0xFFB98A4E),
                const Color(0xFF8A6435)));
        canvas.drawRRect(
            rr(56, 44, 30, 7, 1.6),
            vgrad(boxTop, const Color(0xFFD9AE72), const Color(0xFFBB8E51)));
        canvas.drawRRect(
            rr(68.5, 45, 6, 23, 0.8),
            Paint()..color = const Color(0xFFE4C98F).withValues(alpha: 0.9));

      // ==============================================
      // 5. FOURNISSEURS — camion PHARMADE + cartons
      // ==============================================
      case KpiArt.truck:
        // Ombre au sol.
        canvas.drawOval(
            Rect.fromCenter(
                center: P(50, 66), width: 84 * ux, height: 7 * uy),
            Paint()..color = const Color(0xFF020E08).withValues(alpha: 0.4));
        // Cartons à l'arrière (gauche).
        canvas.drawRRect(
            rr(6, 46, 15, 16, 1.6),
            vgrad(R(6, 46, 15, 16), const Color(0xFFC89B5F),
                const Color(0xFF96703E)));
        canvas.drawRRect(
            rr(6, 42, 15, 5.5, 1.4),
            Paint()..color = const Color(0xFFDDB277));
        canvas.drawRRect(
            rr(10.5, 47, 5.5, 15, 0.8),
            Paint()..color = const Color(0xFFE4C98F).withValues(alpha: 0.85));
        // Caisse du camion (blanche à bande verte PHARMADE).
        final cargo = R(20, 22, 44, 32);
        canvas.drawRRect(rr(22, 24, 44, 32, 2), shadow);
        canvas.drawRRect(
            rr(20, 22, 44, 32, 2.4),
            vgrad(cargo, const Color(0xFFFDFDFB), const Color(0xFFE2E0D6)));
        canvas.drawRRect(
            rr(20, 22, 44, 32, 2.4),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFFC2BFAF));
        // Bande verte + PHARMADE.
        canvas.drawRRect(
            rr(20, 32, 44, 11, 0),
            Paint()
              ..shader = ui.Gradient.linear(
                  P(20, 32), P(20, 43),
                  [const Color(0xFF17C97E), const Color(0xFF067A44)]));
        text('PHARMADE', P(42, 37.5), 5.4, Colors.white, ls: 0.4);
        // Liseré supérieur de la caisse.
        canvas.drawRRect(
            rr(20, 22, 44, 2.6, 1.3),
            Paint()..color = Colors.white.withValues(alpha: 0.6));
        // Cabine (à droite).
        final cab = R(64, 28, 24, 28);
        canvas.drawRRect(rr(66, 30, 24, 28, 2), shadow);
        canvas.drawRRect(
            rr(64, 28, 24, 28, 3),
            vgrad(cab, const Color(0xFFFDFDFB), const Color(0xFFDCDAD0)));
        // Pare-brise + bas de caisse vert.
        canvas.drawRRect(
            rr(75, 32, 11, 10, 1.6),
            vgrad(R(75, 32, 11, 10), const Color(0xFF9FD8C8),
                const Color(0xFF1F5C40)));
        canvas.drawRRect(
            rr(64, 48, 24, 8, 0), Paint()..color = const Color(0xFF0B7A44));
        canvas.drawRRect(
            rr(64, 28, 24, 28, 3),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFFC2BFAF));
        // Phare + rétroviseur.
        canvas.drawRRect(
            rr(85.5, 44, 2.5, 4, 1), Paint()..color = const Color(0xFFF2C94C));
        canvas.drawLine(
            P(64, 30), P(61.5, 28),
            Paint()
              ..color = const Color(0xFF9AA29B)
              ..strokeWidth = 2);
        // Roues.
        void wheel(double cx, double cy, double rr2) {
          canvas.drawCircle(P(cx, cy), rr2 * ux,
              Paint()..color = const Color(0xFF1C211D));
          canvas.drawCircle(P(cx, cy), rr2 * 0.52 * ux,
              Paint()..color = const Color(0xFF8E948D));
          canvas.drawCircle(P(cx, cy), rr2 * 0.22 * ux,
              Paint()..color = const Color(0xFF4A524B));
        }
        wheel(32, 55, 6.4);
        wheel(72, 57, 6.4);

      // ==============================================
      // 6. CLIENTS — trio en polo vert + croix santé
      // ==============================================
      case KpiArt.people:
        void client(
            double cx, double top, double scale, Color shirt, Color hair) {
          final hr = 7.2 * scale;
          final hy = top + hr;
          canvas.drawCircle(P(cx, hy + 1), hr * ux, shadow);
          canvas.drawCircle(
              P(cx, hy), hr * ux, Paint()..color = const Color(0xFFE8B98E));
          // Cheveux (moitié supérieure de la tête).
          canvas.drawArc(
              Rect.fromCenter(
                  center: P(cx, hy - hr * 0.25),
                  width: hr * 2.2 * ux,
                  height: hr * 2.2 * uy),
              3.1416,
              3.1416,
              false,
              Paint()..color = hair);
          // Polo.
          final bw = 30 * scale, bh = 26 * scale;
          final by = hy + hr + 1.2;
          final bodyR = Rect.fromCenter(
              center: P(cx, by + bh / 2), width: bw * ux, height: bh * uy);
          final bodyRR =
              RRect.fromRectAndRadius(bodyR, Radius.circular(6 * scale * ux));
          canvas.drawRRect(bodyRR, shadow);
          canvas.drawRRect(
              bodyRR,
              Paint()
                ..shader = ui.Gradient.linear(bodyR.topCenter,
                    bodyR.bottomCenter, [shirt, const Color(0xFF0E5C38)]));
          // Col blanc.
          canvas.drawRRect(
              rr(cx - 5 * scale, by, 10 * scale, 3 * scale, 1),
              Paint()..color = Colors.white.withValues(alpha: 0.85));
          // Jambes.
          canvas.drawRRect(
              rr(cx - 9 * scale, by + bh, 6.4 * scale, 12 * scale, 2),
              Paint()..color = const Color(0xFF2A3430));
          canvas.drawRRect(
              rr(cx + 2.6 * scale, by + bh, 6.4 * scale, 12 * scale, 2),
              Paint()..color = const Color(0xFF2A3430));
        }

        // Trois clients décalés (arrière-plan → avant).
        client(30, 22, 0.92, const Color(0xFF35B473), const Color(0xFF3E2E22));
        client(50, 15, 1.06, const Color(0xFF1F8A55), const Color(0xFF241A14));
        client(71, 24, 0.88, const Color(0xFF52D68C), const Color(0xFF4A382B));
        // Croix santé verte.
        canvas.drawCircle(P(50, 62), 9 * ux, shadow);
        canvas.drawCircle(
            P(50, 60), 8.6 * ux, Paint()..color = const Color(0xFF00A651));
        canvas.drawCircle(P(50, 60), 6.8 * ux,
            Paint()..color = Colors.white.withValues(alpha: 0.14));
        final hc = Paint()..color = Colors.white;
        canvas.drawRRect(rr(48.6, 55.6, 2.8, 8.8, 0.8), hc);
        canvas.drawRRect(rr(45.6, 58.6, 8.8, 2.8, 0.8), hc);

      // ==============================================
      // 7. EMPLOYÉS — pharmacien blouse blanche + Rx
      // ==============================================
      case KpiArt.pharmacist:
        // Blouse blanche.
        final coat = R(30, 34, 40, 32);
        canvas.drawRRect(rr(32, 36, 40, 32, 4), shadow);
        canvas.drawRRect(
            rr(30, 34, 40, 32, 4),
            vgrad(
                coat,
                const Color(0xFFFFFFFF),
                const Color(0xFFDCE3DD)));
        canvas.drawRRect(
            rr(30, 34, 40, 32, 4),
            Paint()
              ..color = const Color(0xFFB9C4BD)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9);
        // Revers du col.
        canvas.drawPath(
            Path()
              ..moveTo(P(50, 34).dx, P(50, 34).dy)
              ..lineTo(P(42, 34).dx, P(42, 34).dy)
              ..lineTo(P(46, 44).dx, P(46, 44).dy)
              ..close(),
            Paint()..color = const Color(0xFFE4EAE5));
        canvas.drawPath(
            Path()
              ..moveTo(P(50, 34).dx, P(50, 34).dy)
              ..lineTo(P(58, 34).dx, P(58, 34).dy)
              ..lineTo(P(54, 44).dx, P(54, 44).dy)
              ..close(),
            Paint()..color = const Color(0xFFE4EAE5));
        // Badge croix verte (poche).
        canvas.drawRRect(
            rr(58, 48, 8, 6.4, 1.2), Paint()..color = const Color(0xFF00A651));
        final bc = Paint()..color = Colors.white;
        canvas.drawRRect(rr(61.4, 49.2, 1.6, 4, 0.5), bc);
        canvas.drawRRect(rr(59.7, 50.9, 5, 1.6, 0.5), bc);
        // Tête + cheveux.
        canvas.drawCircle(P(50, 22), 9 * ux, shadow);
        canvas.drawCircle(P(50, 20.6), 8.4 * ux,
            Paint()..color = const Color(0xFFE8B98E));
        canvas.drawArc(
            Rect.fromCenter(
                center: P(50, 18.4), width: 19 * ux, height: 19 * uy),
            3.1416,
            3.1416,
            false,
            Paint()..color = const Color(0xFF241A14));
        // Lunettes.
        canvas.drawCircle(
            P(46, 21),
            2.4 * ux,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFF2A3430));
        canvas.drawCircle(
            P(54, 21),
            2.4 * ux,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = const Color(0xFF2A3430));
        canvas.drawLine(P(48.4, 21), P(51.6, 21),
            Paint()..color = const Color(0xFF2A3430)..strokeWidth = 0.9);
        // Presse-papiers dans la main gauche.
        canvas.drawRRect(rr(24, 40, 10, 14, 1.4), shadow);
        canvas.drawRRect(
            rr(23, 39, 10, 14, 1.4),
            Paint()..color = const Color(0xFFFBFAF4));
        canvas.drawRRect(
            rr(25.5, 37, 5, 3, 1), Paint()..color = const Color(0xFF8E979E));
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
              P(25, 42.5 + i * 2.6), P(31, 42.5 + i * 2.6),
              Paint()
                ..color = const Color(0xFFC4C0B2)
                ..strokeWidth = 0.9);
        }
        // Ordonnance signée tenue à droite.
        canvas.save();
        canvas.translate(P(76, 52).dx, P(76, 52).dy);
        canvas.rotate(0.12);
        final rxRect = R(-9, -12, 18, 24);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rxRect, const Radius.circular(1.6)),
            shadow);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rxRect, const Radius.circular(1.6)),
            Paint()..color = const Color(0xFFFFFFFF));
        text('Rx', P(0, -4), 7, const Color(0xFF00A651));
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
              P(-6, 2 + i * 4), P(6 - (i % 2) * 3, 2 + i * 4),
              Paint()
                ..color = const Color(0xFFC4C0B2)
                ..strokeWidth = 1);
        }
        canvas.restore();

      // ==============================================
      // 8. CHIFFRE D'AFFAIRES — barres + flèche + or
      // ==============================================
      case KpiArt.bars:
        // Carte de fond claire (maquette).
        canvas.save();
        canvas.translate(P(46, 44).dx, P(46, 44).dy);
        canvas.rotate(-0.05);
        final card = R(-36, -26, 72, 52);
        canvas.drawRRect(
            RRect.fromRectAndRadius(card, const Radius.circular(3)), shadow);
        canvas.drawRRect(
            RRect.fromRectAndRadius(card, const Radius.circular(3)),
            Paint()..color = const Color(0xFFF6F5EE));
        canvas.restore();
        // Trois barres vertes montantes.
        void bar(double x, double top) {
          final rc = R(x, top, 13, 68 - top);
          canvas.drawRRect(
              rr(x, top, 13, 68 - top, 2),
              vgrad(
                  rc,
                  const Color(0xFF7BEBA4),
                  const Color(0xFF0E7A44)));
          canvas.drawRRect(
              rr(x, top, 13, 68 - top, 2),
              Paint()
                ..color = const Color(0xFF085C34).withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8);
        }

        bar(22, 46);
        bar(42, 36);
        bar(62, 26);
        // Flèche montante verte.
        final arrow = Path()
          ..moveTo(P(20, 42).dx, P(20, 42).dy)
          ..lineTo(P(40, 32).dx, P(40, 32).dy)
          ..lineTo(P(52, 36).dx, P(52, 36).dy)
          ..lineTo(P(72, 22).dx, P(72, 22).dy);
        canvas.drawPath(
            arrow,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF0E7A44));
        final head = Path()
          ..moveTo(P(76, 19).dx, P(76, 19).dy)
          ..lineTo(P(77, 28).dx, P(77, 28).dy)
          ..lineTo(P(68.5, 25.5).dx, P(68.5, 25.5).dy)
          ..close();
        canvas.drawPath(head, Paint()..color = const Color(0xFF0E7A44));
        // Pièces d'or empilées.
        coinStack(82, 64, 4, 15);
    }
  }

  @override
  bool shouldRepaint(covariant KpiArtPainter old) => old.art != art;
}