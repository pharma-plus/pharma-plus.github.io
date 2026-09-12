import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Premium gold pharmacy plan - self contained, ASCII only.
class PharmacyZone {
  const PharmacyZone({
    required this.id,
    this.label,
    this.color,
    this.x = 0,
    this.y = 0,
    this.depth = 1,
    this.shelves = 0,
    this.danger = false,
    this.hotspot = false,
  });
  final String id;
  final String? label;
  final Color? color;
  final double x;
  final double y;
  final double depth;
  final int shelves;
  final bool danger;
  final bool hotspot;
}

class PlanProjector {
  PlanProjector() {
    _size = Size.zero;
  }
  Size _size = Size.zero;
  double rot = 0;
  double zoom = 1;
  Offset origin = Offset.zero;
  void configure(Size size) { _size = size; }
  Offset project(Offset p) {
    final c = math.cos(rot);
    final s = math.sin(rot);
    final cx = _size.width / 2 + origin.dx;
    final cy = _size.height / 2 + origin.dy;
    final dx = (p.dx - _size.width / 2) * zoom;
    final dy = (p.dy - _size.height / 2) * zoom;
    return Offset(cx + dx * c - dy * s, cy + dx * s + dy * c);
  }
}

class PharmacyPlanPainter extends CustomPainter {
  PharmacyPlanPainter({
    this.zones = const [],
    this.projector,
    this.showLabels = true,
    this.onZoneTap,
  });
  final List<PharmacyZone> zones;
  final PlanProjector? projector;
  final bool showLabels;
  final ValueChanged<String>? onZoneTap;

  void _bg(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0C131B));
    final grd = Paint()
      ..shader = ui.Gradient.radial(Offset(size.width * 0.35, size.height * 0.35), size.longestSide * 0.75, const [Color(0x33E8C87B), Color(0x08000000)]);
    canvas.drawRect(rect, grd);
    final grid = Paint()..color = const Color(0x12E8C87B)..strokeWidth = 1;
    for (double gx = 0; gx <= size.width; gx += 32) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), grid);
    }
    for (double gy = 0; gy <= size.height; gy += 32) {
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }
  }

  void _zone(Canvas canvas, PharmacyZone z) {
    final pr = projector;
    if (pr == null) return;
    final p = pr.project(Offset(z.x, z.y));
    final w = (z.depth * 0.5 + 0.4) * pr.zoom;
    final rect = Rect.fromCenter(center: p, width: w * 2, height: w * 1.6);
    final c = z.color ?? const Color(0xFFE8C87B);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), Paint()..color = c.withValues(alpha: z.danger ? 0.35 : 0.62));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = z.hotspot ? const Color(0xFFFFD37E) : c);
    if (z.shelves > 0 && showLabels) {
      final sh = Paint()..color = const Color(0x88E8C87B)..strokeWidth = 1.2;
      for (int i = 1; i < math.min(z.shelves, 8); i++) {
        final dx = p.dx - w + (w * 2 / math.min(z.shelves, 8)) * i;
        canvas.drawLine(Offset(dx, p.dy - w * 0.8), Offset(dx, p.dy + w * 0.8), sh);
      }
    }
    if (showLabels && z.label != null && z.label!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: z.label, style: const TextStyle(color: Color(0xFFF3EDDC), fontSize: 9, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);
    for (final z in zones) {
      _zone(canvas, z);
    }
  }

  @override
  bool shouldRepaint(PharmacyPlanPainter old) => true;
}

/// Gold pharmacy 3D plan (interactive premium).
class PharmacyPlan3D extends StatefulWidget {
  const PharmacyPlan3D({super.key, this.plan, this.planData, this.showZoneLabels = true, this.showControls = false, this.showLegend = true, this.interactive = true, this.initialRot = 0.0, this.initialZoom = 1.0, this.onZoneTap});
  final List<PharmacyZone>? plan;
  final String? planData;
  final bool showZoneLabels;
  final bool showControls;
  final bool showLegend;
  final bool interactive;
  final double initialRot;
  final double initialZoom;
  final ValueChanged<String>? onZoneTap;
  @override
  State<PharmacyPlan3D> createState() => _PharmacyPlan3DState();
}

class _PharmacyPlan3DState extends State<PharmacyPlan3D> {
  double _rot = 0;
  double _zoom = 1;
  Offset _origin = Offset.zero;
  final PlanProjector _pr = PlanProjector();

  @override
  void initState() {
    super.initState();
    _rot = widget.initialRot;
    _zoom = widget.initialZoom;
    _origin = Offset.zero;
  }


  List<PharmacyZone> get _zones => widget.plan ?? const [];

  void _zoomBy(double f) =>
      setState(() => _zoom = (_zoom * f).clamp(0.7, 3.0));
  void _rotateBy(double d) => setState(() => _rot += d);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      _pr
        ..configure(size)
        ..rot = _rot
        ..zoom = _zoom
        ..origin = _origin;
      return Stack(children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onScaleStart: widget.interactive ? (_) => setState(() {}) : null,
            onScaleUpdate: widget.interactive
                ? (d) => setState(() {
                      _zoom = (_zoom * d.scale).clamp(0.7, 3.0);
                      _rot += d.rotation;
                    })
                : null,
            onScaleEnd: widget.interactive ? (_) => setState(() {}) : null,
            onPanUpdate: widget.interactive ? (d) => _drag(d.delta) : null,
            child: CustomPaint(
              size: size,
              painter: PharmacyPlanPainter(
                zones: _zones,
                projector: _pr,
                showLabels: widget.showZoneLabels,
                onZoneTap: widget.interactive ? widget.onZoneTap : null,
              ),
            ),
          ),
        ),
        if (widget.showControls)
          Positioned(
            left: 8,
            bottom: 12,
            child: Row(children: <Widget>[
              _GoldButton(Icons.add, () => _zoomBy(1.2)),
              _GoldButton(Icons.remove, () => _zoomBy(0.85)),
              _GoldButton(Icons.rotate_left, () => _rotateBy(-0.3)),
              _GoldButton(Icons.rotate_right, () => _rotateBy(0.3)),
              _GoldButton(Icons.restart_alt, () => setState(() { _rot = 0; _zoom = 1; _origin = Offset.zero; })),
            ]),
          ),
        if (widget.showLegend)
          Positioned(
            right: 8,
            top: 18,
            child: _GoldLegend(zones: _zones),
          ),
      ]);
    });
  }

  void _drag(Offset d) => setState(() => _origin += d);
}

class _GoldButton extends StatelessWidget {
  const _GoldButton(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: const Color(0xFFE8C87B)),
        ),
      );
}

class _GoldLegend extends StatelessWidget {
  const _GoldLegend({required this.zones});
  final List<PharmacyZone> zones;
  @override
  Widget build(BuildContext context) {
    final items = zones.where((z) => z.label != null && z.label!.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 180, maxHeight: 260),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xEF0B131B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33E8C87B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PHARMACIE GOLD',
            style: TextStyle(
              color: Color(0xFFE8C87B),
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((z) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: z.color ?? const Color(0xFFE8C87B),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      z.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFE6E7DE), fontSize: 11),
                    ),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}
