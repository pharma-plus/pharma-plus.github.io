import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';

/// Représentation isométrique 2.5D interactive de la pharmacie :
/// sol, rayons (étagères en volume), zones colorées et interaction au toucher.
class PharmacyPlanPage extends StatefulWidget {
  final String? focusZoneId;
  const PharmacyPlanPage({super.key, this.focusZoneId});

  @override
  State<PharmacyPlanPage> createState() => _PharmacyPlanPageState();
}

class _PharmacyPlanPageState extends State<PharmacyPlanPage> {
  double _rot = 0.6;
  double _zoom = 1.0;
  String? _selected;
  bool _auto = false;
  Timer? _timer;

  final List<_Zone> _zones = _buildZones();

  @override
  void initState() {
    super.initState();
    if (widget.focusZoneId != null) _selected = widget.focusZoneId;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    _timer?.cancel();
    if (_auto) {
      _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() => _rot += 0.01);
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _auto = false;
      _rot = 0.6;
      _zoom = 1.0;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    _Zone? sel;
    for (final z in _zones) {
      if (z.id == _selected) {
        sel = z;
        break;
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.menu, Color(0xFF0B1210)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(locale: locale),
              _Controls(
                locale: locale,
                auto: _auto,
                onRotateLeft: () => setState(() => _rot -= 0.35),
                onRotateRight: () => setState(() => _rot += 0.35),
                onAuto: _toggleAuto,
                onZoomIn: () =>
                    setState(() => _zoom = math.min(3.0, _zoom * 1.15)),
                onZoomOut: () =>
                    setState(() => _zoom = math.max(0.5, _zoom / 1.15)),
                onReset: _reset,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    final proj =
                        _Projector(rot: _rot, zoom: _zoom, size: size);
                    return Stack(
                      children: [
                        GestureDetector(
                          onPanUpdate: (d) =>
                              setState(() => _rot += d.delta.dx * 0.01),
                          child: CustomPaint(
                            size: size,
                            painter: _PlanPainter(
                              zones: _zones,
                              rot: _rot,
                              zoom: _zoom,
                              locale: locale,
                              size: size,
                              selectedId: _selected,
                            ),
                          ),
                        ),
                        for (final z in _zones) _zoneHit(proj, z),
                        if (_selected == null)
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  S.t('selectZoneHint', locale),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        if (sel != null)
                          _DetailPanel(
                            zone: sel,
                            locale: locale,
                            onClose: () => setState(() => _selected = null),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneHit(_Projector proj, _Zone z) {
    final corners = [
      proj.project(z.x0, z.y0, 0),
      proj.project(z.x1, z.y0, 0),
      proj.project(z.x1, z.y1, 0),
      proj.project(z.x0, z.y1, 0),
    ];
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final o in corners) {
      minX = math.min(minX, o.dx);
      minY = math.min(minY, o.dy);
      maxX = math.max(maxX, o.dx);
      maxY = math.max(maxY, o.dy);
    }
    return Positioned(
      left: minX,
      top: minY,
      width: maxX - minX,
      height: maxY - minY,
      child: GestureDetector(
        onTap: () => setState(() => _selected = z.id),
        child: Container(
          color: _selected == z.id
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String locale;
  const _Header({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.storefront, color: Color(0xFF3E2A00)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.t('pharmacyPlanTitle', locale),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  S.t('pharmacyPlanSub', locale),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final String locale;
  final bool auto;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onAuto;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _Controls({
    required this.locale,
    required this.auto,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onAuto,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _btn(Icons.rotate_left, S.t('rotateLeft', locale), fg, onRotateLeft),
          _btn(Icons.rotate_right, S.t('rotateRight', locale), fg,
              onRotateRight),
          _btn(auto ? Icons.pause : Icons.play_arrow,
              auto ? 'Pause' : S.t('rotateLeft', locale), fg, onAuto),
          _btn(Icons.remove, S.t('zoomOut', locale), fg, onZoomOut),
          _btn(Icons.add, S.t('zoomIn', locale), fg, onZoomIn),
          _btn(Icons.restart_alt, S.t('resetView', locale), fg, onReset),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String tip, Color fg, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: IconButton(
        icon: Icon(icon, color: fg, size: 20),
        tooltip: tip,
        onPressed: onTap,
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final _Zone zone;
  final String locale;
  final VoidCallback onClose;

  const _DetailPanel(
      {required this.zone, required this.locale, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: zone.color.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 24, spreadRadius: 2)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: zone.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.t(zone.labelKey, locale),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(S.t('shelves', locale), '${zone.shelfCount}'),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${S.t('occupancy', locale)} · ${zone.occupancy}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: zone.occupancy / 100,
                            backgroundColor: Colors.white12,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(zone.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(S.t('inZone', locale),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in zone.products)
                      Chip(
                        backgroundColor: zone.color.withValues(alpha: 0.18),
                        label: Text(p,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

/// Projection isométrique 2:1 d'un repère monde (x largeur, y profondeur, z hauteur).
class _Projector {
  final double rot;
  final double zoom;
  final double scale;
  final double originX;
  final double originY;

  _Projector(
      {required this.rot, required this.zoom, required Size size})
      : scale = (math.min(size.width, size.height) / 13) * zoom,
        originX = size.width / 2,
        originY = size.height * 0.56;

  Offset project(double x, double y, double z) {
    final c = math.cos(rot), s = math.sin(rot);
    final rx = x * c - y * s;
    final ry = x * s + y * c;
    final sx = originX + (rx - ry) * 0.866 * scale;
    final sy = originY + (rx + ry) * 0.5 * scale - z * scale;
    return Offset(sx, sy);
  }
}

class _P {
  final double x, y, z;
  const _P(this.x, this.y, this.z);
}

class _Face {
  final List<_P> pts;
  final Color color;
  final double depth;
  _Face(this.pts, this.color)
      : depth = pts.fold(
                0.0, (double s, _P p) => s + (p.x + p.y) - p.z * 0.5) /
            pts.length;
}

class _Zone {
  final String id;
  final String labelKey;
  final Color color;
  final double x0, y0, x1, y1;
  final bool hasShelves;
  final double shelfHeight;
  final int shelfCount;
  final int occupancy;
  final List<String> products;

  const _Zone({
    required this.id,
    required this.labelKey,
    required this.color,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    this.hasShelves = true,
    this.shelfHeight = 1.4,
    this.shelfCount = 0,
    this.occupancy = 0,
    this.products = const [],
  });
}

List<_Zone> _buildZones() => [
      const _Zone(
        id: 'entrance',
        labelKey: 'zoneEntrance',
        color: Color(0xFF9E9E9E),
        x0: -1.5,
        y0: 3.0,
        x1: 1.5,
        y1: 4.0,
        hasShelves: false,
      ),
      const _Zone(
        id: 'counter',
        labelKey: 'zoneCounter',
        color: Color(0xFFFFB300),
        x0: -1.5,
        y0: 2.0,
        x1: 1.5,
        y1: 3.0,
        hasShelves: true,
        shelfHeight: 0.7,
        shelfCount: 3,
        occupancy: 80,
        products: ['Caisse', 'Conseil', 'TPE'],
      ),
      const _Zone(
        id: 'meds',
        labelKey: 'zoneMedications',
        color: Color(0xFF2E7D32),
        x0: -4.7,
        y0: -3.7,
        x1: -0.5,
        y1: 0.9,
        shelfHeight: 1.6,
        shelfCount: 18,
        occupancy: 74,
        products: [
          'Doliprane 1000',
          'Augmentin',
          'Ventoline',
          'Amoxicilline',
          'Spasfon',
          'Levothyrox'
        ],
      ),
      const _Zone(
        id: 'para',
        labelKey: 'zoneParapharmacy',
        color: Color(0xFF00BFA5),
        x0: 0.7,
        y0: -3.7,
        x1: 4.7,
        y1: -1.5,
        shelfHeight: 1.3,
        shelfCount: 12,
        occupancy: 61,
        products: [
          'Biafine',
          'La Roche-Posay',
          'Avène',
          'Cicaplast',
          'Dermalibour'
        ],
      ),
      const _Zone(
        id: 'cos',
        labelKey: 'zoneCosmetics',
        color: Color(0xFFD81B60),
        x0: 0.7,
        y0: -1.3,
        x1: 4.7,
        y1: 0.7,
        shelfHeight: 1.3,
        shelfCount: 12,
        occupancy: 55,
        products: [
          'Rouge à lèvres',
          'Fond de teint',
          'Mascara',
          'Crème jour'
        ],
      ),
      const _Zone(
        id: 'presc',
        labelKey: 'zonePrescriptions',
        color: Color(0xFF7B1FA2),
        x0: -4.7,
        y0: 1.1,
        x1: -2.7,
        y1: 3.3,
        shelfHeight: 1.5,
        shelfCount: 8,
        occupancy: 42,
        products: ['Ordonnances', 'Boîtes', 'Trames'],
      ),
      const _Zone(
        id: 'vac',
        labelKey: 'zoneVaccines',
        color: Color(0xFF039BE5),
        x0: -2.5,
        y0: 1.1,
        x1: -0.9,
        y1: 3.3,
        shelfHeight: 1.2,
        shelfCount: 6,
        occupancy: 33,
        products: ['Vaccin grippe', 'Réfrigérateur', 'Antitétanique'],
      ),
    ];

class _PlanPainter extends CustomPainter {
  final List<_Zone> zones;
  final double rot;
  final double zoom;
  final String locale;
  final Size size;
  final String? selectedId;

  _PlanPainter({
    required this.zones,
    required this.rot,
    required this.zoom,
    required this.locale,
    required this.size,
    required this.selectedId,
  });

  late final _Projector _proj = _Projector(rot: rot, zoom: zoom, size: size);

  @override
  void paint(Canvas canvas, Size size) {
    _drawFloor(canvas);
    _drawZoneTints(canvas);
    final faces = _buildFaces();
    final paint = Paint()..style = PaintingStyle.fill;
    for (final f in faces) {
      final path = Path();
      for (int k = 0; k < f.pts.length; k++) {
        final o = _proj.project(f.pts[k].x, f.pts[k].y, f.pts[k].z);
        if (k == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      paint.color = f.color;
      canvas.drawPath(path, paint);
    }
    _drawLabels(canvas);
  }

  void _drawFloor(Canvas canvas) {
    final c0 = _proj.project(-5, -4, 0);
    final c1 = _proj.project(5, -4, 0);
    final c2 = _proj.project(5, 4, 0);
    final c3 = _proj.project(-5, 4, 0);
    final path = Path()
      ..moveTo(c0.dx, c0.dy)
      ..lineTo(c1.dx, c1.dy)
      ..lineTo(c2.dx, c2.dy)
      ..lineTo(c3.dx, c3.dy)
      ..close();
    canvas.drawPath(
        path, Paint()..color = const Color(0xFF0E1A14));
    final g = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = -5; i <= 5; i++) {
      final a = _proj.project(i.toDouble(), -4, 0);
      final b = _proj.project(i.toDouble(), 4, 0);
      canvas.drawLine(a, b, g);
    }
    for (int j = -4; j <= 4; j++) {
      final a = _proj.project(-5, j.toDouble(), 0);
      final b = _proj.project(5, j.toDouble(), 0);
      canvas.drawLine(a, b, g);
    }
  }

  void _drawZoneTints(Canvas canvas) {
    for (final z in zones) {
      final p = [
        _proj.project(z.x0, z.y0, 0),
        _proj.project(z.x1, z.y0, 0),
        _proj.project(z.x1, z.y1, 0),
        _proj.project(z.x0, z.y1, 0),
      ];
      final path = Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..lineTo(p[1].dx, p[1].dy)
        ..lineTo(p[2].dx, p[2].dy)
        ..lineTo(p[3].dx, p[3].dy)
        ..close();
      final selected = z.id == selectedId;
      canvas.drawPath(
          path,
          Paint()
            ..color = z.color
                .withValues(alpha: selected ? 0.30 : 0.16));
      if (selected) {
        canvas.drawPath(
            path,
            Paint()
              ..color = z.color.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
  }

  void _addBox(List<_Face> faces, double x0, double y0, double x1, double y1,
      double z1, Color base) {
    const z0 = 0.0;
    faces.add(_Face(
        [_P(x0, y0, z1), _P(x1, y0, z1), _P(x1, y1, z1), _P(x0, y1, z1)],
        _lighten(base, 0.14)));
    faces.add(_Face(
        [_P(x1, y0, z0), _P(x1, y1, z0), _P(x1, y1, z1), _P(x1, y0, z1)],
        _darken(base, 0.30)));
    faces.add(_Face(
        [_P(x0, y0, z0), _P(x0, y1, z0), _P(x0, y1, z1), _P(x0, y0, z1)],
        _darken(base, 0.46)));
    faces.add(_Face(
        [_P(x0, y1, z0), _P(x1, y1, z0), _P(x1, y1, z1), _P(x0, y1, z1)],
        _darken(base, 0.22)));
    faces.add(_Face(
        [_P(x0, y0, z0), _P(x1, y0, z0), _P(x1, y0, z1), _P(x0, y0, z1)],
        _darken(base, 0.38)));
  }

  List<_Face> _buildFaces() {
    final faces = <_Face>[];
    for (final z in zones) {
      if (!z.hasShelves) continue;
      const mx = 0.18;
      final ix0 = z.x0 + mx, iy0 = z.y0 + mx;
      final ix1 = z.x1 - mx, iy1 = z.y1 - mx;
      if (ix1 - ix0 < 0.2 || iy1 - iy0 < 0.2) continue;
      int cols = ((ix1 - ix0) / 1.0).floor();
      if (cols < 1) cols = 1;
      if (cols > 6) cols = 6;
      int rows = ((iy1 - iy0) / 1.0).floor();
      if (rows < 1) rows = 1;
      if (rows > 6) rows = 6;
      final cw = (ix1 - ix0) / cols, rh = (iy1 - iy0) / rows;
      for (int i = 0; i < cols; i++) {
        for (int j = 0; j < rows; j++) {
          final bx0 = ix0 + i * cw + 0.07;
          final by0 = iy0 + j * rh + 0.07;
          final bx1 = ix0 + (i + 1) * cw - 0.07;
          final by1 = iy0 + (j + 1) * rh - 0.07;
          _addBox(faces, bx0, by0, bx1, by1, z.shelfHeight, z.color);
        }
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    return faces;
  }

  void _drawLabels(Canvas canvas) {
    for (final z in zones) {
      final c = _proj.project((z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2, 0);
      final tp = TextPainter(
        text: TextSpan(
          text: S.t(z.labelKey, locale),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final r = Rect.fromCenter(
          center: c, width: tp.width + 16, height: tp.height + 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = z.color.withValues(alpha: 0.9),
      );
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  Color _lighten(Color c, double a) => Color.lerp(c, Colors.white, a)!;
  Color _darken(Color c, double a) => Color.lerp(c, Colors.black, a)!;

  @override
  bool shouldRepaint(covariant _PlanPainter old) =>
      old.rot != rot ||
      old.zoom != zoom ||
      old.selectedId != selectedId ||
      old.locale != locale;
}
