// PMG-POS-CATEGORY-GRID
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Tuile de catégorie du POS — illustration 3D légère, sans texte intégré
/// dans le visuel. Le libellé reste une donnée UI séparée et reste lisible
/// dans le mini-POS comme dans le POS complet.
/// Le libelle pilote le glyphe : antalgique, antibiotique, cardio,
/// diabete, vitamines, respiratoire, digestif, autres.
class PosCategoryTile extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Dimensions fixes optionnelles ; null = remplir la cellule parente
  /// (grille stricte 2×4 du panneau POS).
  final double? width;
  final double? height;
  const PosCategoryTile({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.width,
    this.height,
  });
  @override
  State<PosCategoryTile> createState() => _PosCategoryTileState();
}

class _PosCategoryTileState extends State<PosCategoryTile> {
  bool _hover = false;

  _GlyphKind get _kind => _kindFor(widget.label);

  @override
  Widget build(BuildContext context) {
    final k = _kind;
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF123324), Color(0xFF0A1D13)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: widget.selected || _hover
                        ? const Color(0xFFC9A24B)
                        : const Color(0xFF27543C),
                    width: widget.selected ? 1.6 : 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                  if (widget.selected || _hover)
                    BoxShadow(
                        color: const Color(0xFF00C96B).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: CustomPaint(
                      size: const Size(82, 62), painter: _GlyphPainter(k)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _GlyphKind { pill, shield, heart, drop, citrus, lungs, stomach, box }

_GlyphKind _kindFor(String label) {
  final s = label.toLowerCase();
  if (s.contains('antalg') || s.contains('douleur') || s.contains('analge')) {
    return _GlyphKind.pill;
  }
  if (s.contains('antibio') || s.contains('infect')) return _GlyphKind.shield;
  if (s.contains('cardio') || s.contains('coeur') || s.contains('tension')) {
    return _GlyphKind.heart;
  }
  if (s.contains('diab') || s.contains('sucre') || s.contains('sang')) {
    return _GlyphKind.drop;
  }
  if (s.contains('vitam') || s.contains('compl') || s.contains('nutrit')) {
    return _GlyphKind.citrus;
  }
  if (s.contains('respir') ||
      s.contains('toux') ||
      s.contains('poumon') ||
      s.contains('spray') ||
      s.contains('aérosol') ||
      s.contains('aerosol') ||
      s.contains('inhal')) {
    return _GlyphKind.lungs;
  }
  if (s.contains('digest') || s.contains('estomac')) return _GlyphKind.stomach;
  // Formes galéniques réelles (facettes du catalogue).
  if (s.contains('comprim') ||
      s.contains('gélul') ||
      s.contains('gelul') ||
      s.contains('capsul') ||
      s.contains('dragée') ||
      s.contains('dragee') ||
      s.contains('granul') ||
      s.contains('lyophilisat')) {
    return _GlyphKind.pill;
  }
  if (s.contains('sirop') ||
      s.contains('solution') ||
      s.contains('suspension') ||
      s.contains('inject') ||
      s.contains('collyre') ||
      s.contains('gouttes') ||
      s.contains('crème') ||
      s.contains('creme') ||
      s.contains('pommade') ||
      s.contains('gel')) {
    return _GlyphKind.drop;
  }
  return _GlyphKind.box;
}

class _GlyphPainter extends CustomPainter {
  final _GlyphKind kind;
  _GlyphPainter(this.kind);

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    // Halo, profondeur et podium : l'illustration reste entièrement dans sa
    // cellule grâce au FittedBox du parent, même sur les écrans tactiles.
    c.drawCircle(
        Offset(cx - 4, cy - 5),
        s.width * .29,
        Paint()
          ..shader = ui.Gradient.radial(
              Offset(cx - 9, cy - 11), s.width * .34, [
            const Color(0xFFB9F5D9).withValues(alpha: .18),
            Colors.transparent
          ]));
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx, s.height - 4), width: s.width * 0.68, height: 7),
        Paint()
          ..color = const Color(0xFF00C96B).withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx, s.height - 5), width: s.width * .52, height: 3),
        Paint()..color = const Color(0xFFB9F5D9).withValues(alpha: .28));
    // Les objets occupent réellement la carte : le volume reste lisible
    // même lorsque la grille du POS est compacte.
    c.save();
    c.translate(cx, cy);
    c.scale(1.24, 1.24);
    c.translate(-cx, -cy);
    switch (kind) {
      case _GlyphKind.pill:
        c.save();
        c.translate(cx, cy);
        c.rotate(-0.5);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 34, height: 15),
                const Radius.circular(7.5)),
            Paint()
              ..shader = ui.Gradient.linear(
                  const Offset(-17, 0),
                  const Offset(17, 0),
                  [const Color(0xFFE9C873), const Color(0xFFB4882F)]));
        c.drawLine(
            const Offset(0, -7.5),
            const Offset(0, 7.5),
            Paint()
              ..color = const Color(0xFF8A6520)
              ..strokeWidth = 1.4);
        c.restore();
        break;
      case _GlyphKind.shield:
        final sp = Path()
          ..moveTo(cx, cy - 15)
          ..lineTo(cx + 13, cy - 9)
          ..lineTo(cx + 13, cy + 3)
          ..quadraticBezierTo(cx + 13, cy + 13, cx, cy + 17)
          ..quadraticBezierTo(cx - 13, cy + 13, cx - 13, cy + 3)
          ..lineTo(cx - 13, cy - 9)
          ..close();
        c.drawPath(
            sp,
            Paint()
              ..shader = ui.Gradient.linear(
                  Offset(cx, cy - 15),
                  Offset(cx, cy + 17),
                  [const Color(0xFF2E7A50), const Color(0xFF14522F)]));
        final gp = Paint()
          ..color = const Color(0xFFE9C873)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        c.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 8), gp);
        c.drawLine(Offset(cx - 7, cy + 1), Offset(cx + 7, cy + 1), gp);
        break;
      case _GlyphKind.heart:
        final hp = Path()..moveTo(cx, cy + 13);
        hp.cubicTo(cx - 20, cy - 2, cx - 10, cy - 16, cx, cy - 6);
        hp.cubicTo(cx + 10, cy - 16, cx + 20, cy - 2, cx, cy + 13);
        c.drawPath(
            hp,
            Paint()
              ..shader = ui.Gradient.linear(
                  Offset(cx, cy - 14),
                  Offset(cx, cy + 13),
                  [const Color(0xFFFF6B7A), const Color(0xFFC22B3E)]));
        break;
      case _GlyphKind.drop:
        final dp = Path()..moveTo(cx, cy - 15);
        dp.quadraticBezierTo(cx + 12, cy + 1, cx, cy + 13);
        dp.quadraticBezierTo(cx - 12, cy + 1, cx, cy - 15);
        c.drawPath(
            dp,
            Paint()
              ..shader = ui.Gradient.linear(
                  Offset(cx, cy - 15),
                  Offset(cx, cy + 13),
                  [const Color(0xFF7FD8FF), const Color(0xFF1E7FB8)]));
        break;
      case _GlyphKind.citrus:
        c.drawCircle(
            Offset(cx, cy),
            13,
            Paint()
              ..shader = ui.Gradient.radial(Offset(cx - 4, cy - 4), 17,
                  [const Color(0xFFFFC24B), const Color(0xFFE07B12)]));
        c.drawCircle(
            Offset(cx, cy), 9.5, Paint()..color = const Color(0xFFFFE3A3));
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          c.drawLine(
              Offset(cx, cy),
              Offset(cx + 9 * math.cos(a), cy + 9 * math.sin(a)),
              Paint()
                ..color = const Color(0xFFE07B12)
                ..strokeWidth = 1.6);
        }
        break;
      case _GlyphKind.lungs:
        final lp = Paint()
          ..shader = ui.Gradient.linear(
              Offset(cx, cy - 12),
              Offset(cx, cy + 14),
              [const Color(0xFF8FE3C0), const Color(0xFF1E7A55)]);
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(cx - 13, cy - 4, 10, 18),
                const Radius.circular(5)),
            lp);
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(cx + 3, cy - 4, 10, 18),
                const Radius.circular(5)),
            lp);
        c.drawRect(Rect.fromLTWH(cx - 1.4, cy - 15, 2.8, 12), lp);
        break;
      case _GlyphKind.stomach:
        final gp = Path()
          ..moveTo(cx - 3, cy - 14)
          ..lineTo(cx + 6, cy - 14)
          ..lineTo(cx + 6, cy - 2);
        gp.quadraticBezierTo(cx + 14, cy + 2, cx + 6, cy + 12);
        gp.quadraticBezierTo(cx - 6, cy + 18, cx - 12, cy + 6);
        gp.quadraticBezierTo(cx - 14, cy - 4, cx - 3, cy - 2);
        gp.close();
        c.drawPath(
            gp,
            Paint()
              ..shader = ui.Gradient.linear(
                  Offset(cx, cy - 14),
                  Offset(cx, cy + 14),
                  [const Color(0xFFFFB37B), const Color(0xFFC05A1E)]));
        break;
      case _GlyphKind.box:
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy + 2), width: 26, height: 20),
                const Radius.circular(5)),
            Paint()
              ..shader = ui.Gradient.linear(
                  Offset(cx, cy - 8),
                  Offset(cx, cy + 12),
                  [const Color(0xFF9DB4A6), const Color(0xFF4E6B5B)]));
        c.drawLine(
            Offset(cx - 13, cy + 2),
            Offset(cx + 13, cy + 2),
            Paint()
              ..color = const Color(0xFF2E4A3A)
              ..strokeWidth = 1.2);
        break;
    }
    c.restore();

    // Reflet studio commun aux objets, pour une finition 3D plus attractive.
    c.drawArc(
        Rect.fromCenter(
            center: Offset(cx - 5, cy - 8), width: s.width * .22, height: 9),
        3.7,
        1.8,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.kind != kind;
}
