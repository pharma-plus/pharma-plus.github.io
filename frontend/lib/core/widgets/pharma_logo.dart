import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PharmaPlusLogo extends StatelessWidget {
  const PharmaPlusLogo({super.key, this.size = 96, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PharmaLogoPainter(),
        child: showText
            ? const SizedBox.shrink()
            : null,
      ),
    );
  }
}

class _PharmaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide * 0.47;

    final glowPaint = Paint()
      ..color = const Color(0xFF3AE88C).withValues(alpha: 0.35)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);
    canvas.drawCircle(center, outerRadius + 18, glowPaint);

    final ringGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE5E7EB), Color(0xFF8A8F99), Color(0xFFDDE3E9)],
    );
    final ringPaint = Paint()
      ..shader = ringGradient.createShader(
        Rect.fromCircle(center: center, radius: outerRadius + 10),
      );
    canvas.drawCircle(center, outerRadius + 10, ringPaint);

    final innerGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0FDE7D), Color(0xFF0AAE62), Color(0xFF04B65A)],
    );
    final innerPaint = Paint()
      ..shader = innerGradient.createShader(
        Rect.fromCircle(center: center, radius: outerRadius),
      );
    canvas.drawCircle(center, outerRadius, innerPaint);

    final cut = Paint()..color = const Color(0xFF0B2019);
    canvas.drawCircle(center, outerRadius - 6, cut);

    final white = Paint()..color = const Color(0xFFF6F9F8);
    final green = Paint()..color = const Color(0xFF38E48A);

    final whiteBulk = Path()
      ..moveTo(center.dx - 50, center.dy + 12)
      ..quadraticBezierTo(
        center.dx - 84,
        center.dy - 26,
        center.dx - 16,
        center.dy - 62,
      )
      ..quadraticBezierTo(
        center.dx + 44,
        center.dy - 18,
        center.dx + 32,
        center.dy + 52,
      )
      ..quadraticBezierTo(
        center.dx - 10,
        center.dy + 68,
        center.dx - 50,
        center.dy + 12,
      )
      ..close();
    canvas.drawPath(whiteBulk, white);

    final greenLeaf = Path()
      ..moveTo(center.dx - 62, center.dy + 8)
      ..quadraticBezierTo(
        center.dx - 104,
        center.dy - 28,
        center.dx - 56,
        center.dy - 56,
      )
      ..quadraticBezierTo(
        center.dx - 18,
        center.dy - 24,
        center.dx - 20,
        center.dy + 22,
      )
      ..close();
    canvas.drawPath(greenLeaf, green);

    final tablet = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + 46, center.dy + 52),
        width: 58,
        height: 26,
      ),
      const Radius.circular(13),
    );
    canvas.drawRRect(tablet, white);

    final tabletCore = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + 46, center.dy + 52),
        width: 22,
        height: 10,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(tabletCore, green);

    final caduceus = Paint()..color = const Color(0xFFF0F4F2);
    canvas.drawLine(
      Offset(center.dx + 46, center.dy - 16),
      Offset(center.dx + 46, center.dy + 36),
      caduceus..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(center.dx + 64, center.dy - 16),
      Offset(center.dx + 64, center.dy + 40),
      caduceus..strokeWidth = 5,
    );

    final serpent = Path()
      ..moveTo(center.dx + 46, center.dy - 36)
      ..quadraticBezierTo(
        center.dx + 88,
        center.dy - 16,
        center.dx + 82,
        center.dy + 8,
      )
      ..quadraticBezierTo(
        center.dx + 64,
        center.dy + 18,
        center.dx + 56,
        center.dy + 8,
      )
      ..quadraticBezierTo(
        center.dx + 72,
        center.dy - 8,
        center.dx + 46,
        center.dy - 36,
      );
    canvas.drawPath(
      serpent,
      Paint()
        ..color = const Color(0xFFF4F7F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    final arc = Paint()
      ..color = const Color(0xFFEBF4EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx + 52, center.dy + 12), radius: 30),
      1.5,
      1.7,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
