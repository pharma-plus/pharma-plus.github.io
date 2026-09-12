import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../shell/shell_nav.dart';

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
    _selected = widget.focusZoneId ?? 'meds';
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

  /// Plein écran : la scène occupe tout l'écran avec les mêmes
  /// interactions (rotation, zoom, sélection). Bouton de fermeture +
  /// navigation retour toujours disponibles.
  void _openFullscreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenPlan(
        zones: _zones,
        rot: _rot,
        zoom: _zoom,
        locale: locale,
      ),
    ));
  }

  String get locale => context.read<AuthStore>().locale;

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
                onFullscreen: _openFullscreen,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    final proj = _Projector(rot: _rot, zoom: _zoom, size: size);
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
                                  color: Colors.black.withValues(alpha: 0.45),
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
                            onClose: () => setState(() => _selected = 'meds'),
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
          // ← HOME : retour toujours visible, sortie garantie de la page
          // (navigation interne + bouton retour navigateur fonctionnels).
          const ShellBackButton(),
          const SizedBox(width: 2),
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
  final VoidCallback onFullscreen;

  const _Controls({
    required this.locale,
    required this.auto,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onAuto,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onFullscreen,
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
          // Zoom initial = vue réinitialisée (rotation + zoom d'origine).
          _btn(Icons.restart_alt, S.t('resetView', locale), fg, onReset),
          _btn(Icons.fullscreen, 'Plein écran', fg, onFullscreen),
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
                          Text(
                              '${S.t('occupancy', locale)} · ${zone.occupancy}%',
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

  _Projector({required this.rot, required this.zoom, required Size size})
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
      : depth = pts.fold(0.0, (double s, _P p) => s + (p.x + p.y) - p.z * 0.5) /
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
        x0: -0.9,
        y0: 3.15,
        x1: 0.9,
        y1: 4.15,
        hasShelves: false,
      ),
      const _Zone(
        id: 'counter',
        labelKey: 'zoneCounter',
        color: Color(0xFFFFB300),
        x0: -2.0,
        y0: 2.1,
        x1: 2.0,
        y1: 3.15,
        hasShelves: true,
        shelfHeight: 0.8,
        shelfCount: 4,
        occupancy: 86,
        products: ['Caisse', 'Conseil', 'TPE', 'Paiement'],
      ),
      const _Zone(
        id: 'meds',
        labelKey: 'zoneMedications',
        color: Color(0xFF2E7D32),
        x0: -5.0,
        y0: -4.0,
        x1: -0.7,
        y1: 0.8,
        shelfHeight: 1.7,
        shelfCount: 20,
        occupancy: 78,
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
        id: 'presc',
        labelKey: 'zonePrescriptions',
        color: Color(0xFF7B1FA2),
        x0: -4.9,
        y0: 1.0,
        x1: -2.6,
        y1: 3.1,
        shelfHeight: 1.4,
        shelfCount: 8,
        occupancy: 46,
        products: ['Ordonnances', 'Boîtes', 'Trames', 'Ajustement'],
      ),
      const _Zone(
        id: 'vac',
        labelKey: 'zoneVaccines',
        color: Color(0xFF039BE5),
        x0: -2.5,
        y0: 1.0,
        x1: -0.8,
        y1: 3.1,
        shelfHeight: 1.2,
        shelfCount: 6,
        occupancy: 38,
        products: ['Vaccin grippe', 'Réfrigérateur', 'Antitétanique'],
      ),
      const _Zone(
        id: 'para',
        labelKey: 'zoneParapharmacy',
        color: Color(0xFF00BFA5),
        x0: 0.8,
        y0: -4.0,
        x1: 5.0,
        y1: -1.2,
        shelfHeight: 1.4,
        shelfCount: 13,
        occupancy: 66,
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
        x0: 0.8,
        y0: -1.2,
        x1: 5.0,
        y1: 1.0,
        shelfHeight: 1.35,
        shelfCount: 12,
        occupancy: 58,
        products: ['Rouge à lèvres', 'Fond de teint', 'Mascara', 'Crème jour'],
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
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.28);
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
      canvas.drawPath(path, stroke);
    }
    _drawSigns(canvas);
    _drawLabels(canvas);
  }

  /// Sol : damier 1×1 (deux tons verts discrets) + joints clairs —
  /// carrelage pharmacie comme sur la maquette.
  void _drawFloor(Canvas canvas) {
    for (int i = -5; i < 5; i++) {
      for (int j = -4; j < 4; j++) {
        final path = _quadPath([
          _P(i.toDouble(), j.toDouble(), 0),
          _P(i + 1.0, j.toDouble(), 0),
          _P(i + 1.0, j + 1.0, 0),
          _P(i.toDouble(), j + 1.0, 0),
        ]);
        canvas.drawPath(
            path,
            Paint()
              ..color = ((i + j).isEven
                  ? const Color(0xFF15251C)
                  : const Color(0xFF101B15)));
      }
    }
    final g = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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
    // Liseré du périmètre (plinth) : trait clair autour du sol.
    final perim = Path()
      ..moveTo(_proj.project(-5, -4, 0).dx, _proj.project(-5, -4, 0).dy)
      ..lineTo(_proj.project(5, -4, 0).dx, _proj.project(5, -4, 0).dy)
      ..lineTo(_proj.project(5, 4, 0).dx, _proj.project(5, 4, 0).dy)
      ..lineTo(_proj.project(-5, 4, 0).dx, _proj.project(-5, 4, 0).dy)
      ..close();
    canvas.drawPath(
        perim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF2E5241).withValues(alpha: 0.9));
  }

  Path _quadPath(List<_P> pts) {
    final path = Path();
    for (int k = 0; k < pts.length; k++) {
      final o = _proj.project(pts[k].x, pts[k].y, pts[k].z);
      if (k == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
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
            ..color = z.color.withValues(alpha: selected ? 0.38 : 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      if (selected) {
        canvas.drawPath(
            path,
            Paint()
              ..color = z.color.withValues(alpha: 1)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
    }
  }

  /// Boîte 3D complète entre z0 et z1 (5 faces : dessus + 4 côtés).
  void _addBox(List<_Face> faces, double x0, double y0, double x1, double y1,
      double z0, double z1, Color base) {
    faces.add(_Face(
        [_P(x0, y0, z1), _P(x1, y0, z1), _P(x1, y1, z1), _P(x0, y1, z1)],
        _lighten(base, 0.16)));
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

  /// Face unique quad (vitrine, écran, enseigne...).
  void _addQuad(List<_Face> faces, _P a, _P b, _P c, _P d, Color color) {
    faces.add(_Face([a, b, c, d], color));
  }

  /// Ombre portée au sol sous un meuble (rectangle fondu, alpha faible).
  void _addShadow(
      List<_Face> faces, double x0, double y0, double x1, double y1) {
    const grow = 0.14;
    faces.add(_Face([
      _P(x0 - grow, y0 - grow, 0.002),
      _P(x1 + grow, y0 - grow, 0.002),
      _P(x1 + grow, y1 + grow, 0.002),
      _P(x0 - grow, y1 + grow, 0.002),
    ], Colors.black.withValues(alpha: 0.34)));
  }

  /// PETITS PRODUITS sur une tablette : boîtes colorées de hauteurs
  /// variées (déterministe — aucune valeur aléatoire instable).
  void _addProductRow(List<_Face> faces, double x0, double y0, double x1,
      double y1, double zBoard, int seed) {
    const palette = <Color>[
      Color(0xFF3FA96C), // vert
      Color(0xFFE8E2D4), // blanc cassé
      Color(0xFFF0C75E), // or
      Color(0xFF8ED0F0), // bleu clair
      Color(0xFFE77C8E), // rose
      Color(0xFFB79CD8), // violet doux
    ];
    final count = 3 + (seed % 2);
    final w = (x1 - x0) / count;
    for (int k = 0; k < count; k++) {
      final s = seed * 7 + k * 13;
      final ph = 0.14 + ((s % 5) * 0.035);
      final gap = 0.03 + ((s % 3) * 0.012);
      final px0 = x0 + k * w + gap;
      final px1 = x0 + (k + 1) * w - gap;
      const py0 = 0.05;
      final color = palette[(s + k) % palette.length];
      // 2 faces seulement (dessus + façade sud) : perf maîtrisée.
      faces.add(_Face([
        _P(px0, y0 + py0, zBoard + ph),
        _P(px1, y0 + py0, zBoard + ph),
        _P(px1, y1 - py0, zBoard + ph),
        _P(px0, y1 - py0, zBoard + ph),
      ], _lighten(color, 0.10)));
      faces.add(_Face([
        _P(px0, y1 - py0, zBoard),
        _P(px1, y1 - py0, zBoard),
        _P(px1, y1 - py0, zBoard + ph),
        _P(px0, y1 - py0, zBoard + ph),
      ], _darken(color, 0.12)));
    }
  }

  /// GONDOLE COMPLÈTE pour une cellule de zone : montants latéraux +
  /// tablettes en bois clair + rangées de produits colorés.
  void _addShelfUnit(List<_Face> faces, double bx0, double by0, double bx1,
      double by1, double height, Color base, int seed) {
    final frame = _darken(base, 0.42);
    // Montants latéraux.
    _addBox(faces, bx0, by0, bx0 + 0.07, by1, 0, height, frame);
    _addBox(faces, bx1 - 0.07, by0, bx1, by1, 0, height, frame);
    // Tablettes + produits dessus (la dernière près du sommet).
    final levels = <double>[0.10, height * 0.38, height * 0.66, height * 0.92];
    for (int l = 0; l < levels.length; l++) {
      final zl = levels[l];
      _addBox(faces, bx0 + 0.07, by0 + 0.03, bx1 - 0.07, by1 - 0.03, zl,
          zl + 0.05, const Color(0xFFB99B6B)); // tablette bois clair
      if (l < levels.length - 1) {
        _addProductRow(faces, bx0 + 0.09, by0 + 0.04, bx1 - 0.09, by1 - 0.04,
            zl + 0.05, seed + l);
      }
    }
  }

  /// COMPTOIR 3D (zone 'counter') : meuble vert PHARMA+, plateau bois,
  /// TPE à écran vert, imprimante + rouleau de reçu, écran de caisse.
  void _addCounter(List<_Face> faces, _Zone z) {
    _addShadow(faces, z.x0, z.y0 + 0.22, z.x1, z.y1 - 0.06);
    const body = Color(0xFF16402F);
    final w = z.x1 - z.x0;
    // Corps du comptoir.
    _addBox(faces, z.x0, z.y0 + 0.28, z.x1, z.y1 - 0.08, 0, 0.92, body);
    // Plateau bois clair en porte-à-faux.
    _addBox(faces, z.x0 - 0.05, z.y0 + 0.20, z.x1 + 0.05, z.y1 - 0.02, 0.92,
        1.02, const Color(0xFFD9BC8C));
    // TPE (terminal de paiement) — écran vert orienté entrée.
    final tpeX0 = z.x0 + w * 0.30, tpeX1 = z.x0 + w * 0.44;
    _addBox(faces, tpeX0, z.y0 + 0.36, tpeX1, z.y0 + 0.56, 1.02, 1.22,
        const Color(0xFF0B1712));
    _addQuad(
        faces,
        _P(tpeX0 + 0.02, z.y0 + 0.565, 1.195),
        _P(tpeX1 - 0.02, z.y0 + 0.565, 1.195),
        _P(tpeX1 - 0.02, z.y0 + 0.565, 1.115),
        _P(tpeX0 + 0.02, z.y0 + 0.565, 1.115),
        const Color(0xFF00C96B)); // écran vert lumineux
    // Imprimante de reçus + rouleau.
    _addBox(faces, z.x0 + w * 0.52, z.y0 + 0.36, z.x0 + w * 0.70, z.y0 + 0.54,
        1.02, 1.13, const Color(0xFFE8E2D4));
    _addBox(faces, z.x0 + w * 0.575, z.y0 + 0.385, z.x0 + w * 0.645,
        z.y0 + 0.515, 1.13, 1.25, const Color(0xFFF4EFE3));
    // Écran de caisse orienté vendeur.
    _addBox(faces, z.x0 + w * 0.76, z.y0 + 0.40, z.x0 + w * 0.88, z.y0 + 0.46,
        1.02, 1.36, const Color(0xFF101D16));
    _addQuad(
        faces,
        _P(z.x0 + w * 0.765, z.y0 + 0.462, 1.345),
        _P(z.x0 + w * 0.875, z.y0 + 0.462, 1.345),
        _P(z.x0 + w * 0.875, z.y0 + 0.462, 1.175),
        _P(z.x0 + w * 0.765, z.y0 + 0.462, 1.175),
        const Color(0xFF1F7A4D)); // dalle caisse
  }

  /// VITRINE D'ENTRÉE : portes vitrées translucides + enseigne PHARMA+
  /// lumineuse au-dessus de l'entrée.
  void _addEntranceGlass(List<_Face> faces, _Zone z) {
    final y = z.y1 - 0.04; // bord sud (façade)
    // Montants de porte + linteau.
    _addBox(faces, z.x0 - 0.04, y - 0.06, z.x0 + 0.05, y + 0.06, 0, 2.15,
        const Color(0xFF24483A));
    _addBox(faces, z.x1 - 0.05, y - 0.06, z.x1 + 0.04, y + 0.06, 0, 2.15,
        const Color(0xFF24483A));
    _addBox(faces, -0.05, y - 0.05, 0.05, y + 0.05, 0, 2.15,
        const Color(0xFF24483A));
    _addBox(faces, z.x0, y - 0.06, z.x1, y + 0.06, 2.05, 2.15,
        const Color(0xFF24483A));
    // Vitrage translucide (2 vantaux).
    final glass = const Color(0xFF9FD8C8).withValues(alpha: 0.16);
    _addQuad(faces, _P(z.x0 + 0.05, y, 1.98), _P(-0.05, y, 1.98),
        _P(-0.05, y, 0.04), _P(z.x0 + 0.05, y, 0.04), glass);
    _addQuad(faces, _P(0.05, y, 1.98), _P(z.x1 - 0.05, y, 1.98),
        _P(z.x1 - 0.05, y, 0.04), _P(0.05, y, 0.04), glass);
    // Enseigne lumineuse PHARMA+ au-dessus de la porte.
    _addQuad(
        faces,
        _P(z.x0 + 0.02, y + 0.02, 2.42),
        _P(z.x1 - 0.02, y + 0.02, 2.42),
        _P(z.x1 - 0.02, y + 0.02, 2.06),
        _P(z.x0 + 0.02, y + 0.02, 2.06),
        const Color(0xFF00C96B));
  }

  /// MURS du fond (coupe 3D « maquette » : nord + ouest visibles,
  /// sud et est ouverts pour ne jamais masquer la vue intérieure).
  void _addWalls(List<_Face> faces) {
    const h = 2.7;
    // Mur nord (plan y = -4) + frise claire.
    _addQuad(faces, _P(-5, -4, h), _P(5, -4, h), _P(5, -4, 0), _P(-5, -4, 0),
        const Color(0xFF1A2C22));
    _addQuad(faces, _P(-5, -4, h), _P(5, -4, h), _P(5, -4, h - 0.14),
        _P(-5, -4, h - 0.14), const Color(0xFF2E5241));
    // Mur ouest (plan x = -5) + frise claire.
    _addQuad(faces, _P(-5, -4, h), _P(-5, 4, h), _P(-5, 4, 0), _P(-5, -4, 0),
        const Color(0xFF16241C));
    _addQuad(faces, _P(-5, -4, h), _P(-5, 4, h), _P(-5, 4, h - 0.14),
        _P(-5, -4, h - 0.14), const Color(0xFF284638));
  }

  List<_Face> _buildFaces() {
    final faces = <_Face>[];
    _addWalls(faces);
    for (final z in zones) {
      if (z.id == 'entrance') {
        _addEntranceGlass(faces, z);
        continue;
      }
      if (z.id == 'counter') {
        _addCounter(faces, z);
        continue;
      }
      if (!z.hasShelves) continue;
      _addShadow(faces, z.x0 + 0.05, z.y0 + 0.05, z.x1 - 0.05, z.y1 - 0.05);
      const mx = 0.15;
      final ix0 = z.x0 + mx, iy0 = z.y0 + mx;
      final ix1 = z.x1 - mx, iy1 = z.y1 - mx;
      if (ix1 - ix0 < 0.2 || iy1 - iy0 < 0.2) continue;
      int cols = ((ix1 - ix0) / 1.15).floor();
      if (cols < 1) cols = 1;
      if (cols > 5) cols = 5;
      int rows = ((iy1 - iy0) / 1.15).floor();
      if (rows < 1) rows = 1;
      if (rows > 5) rows = 5;
      final cw = (ix1 - ix0) / cols, rh = (iy1 - iy0) / rows;
      for (int i = 0; i < cols; i++) {
        for (int j = 0; j < rows; j++) {
          final bx0 = ix0 + i * cw + 0.06;
          final by0 = iy0 + j * rh + 0.06;
          final bx1 = ix0 + (i + 1) * cw - 0.06;
          final by1 = iy0 + (j + 1) * rh - 0.06;
          _addShelfUnit(faces, bx0, by0, bx1, by1, z.shelfHeight, z.color,
              i * 11 + j * 5 + (z.x0 * 3).toInt() + (z.y0 * 7).toInt());
        }
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    return faces;
  }

  /// ENSEIGNES texte projetées dans la scène (PHARMA+ entrée + comptoir).
  void _drawSigns(Canvas canvas) {
    // 1) Enseigne blanche sur la barre émeraude de l'entrée.
    final p1 = _proj.project(0, 4.16, 2.24);
    _drawSignText(canvas, 'PHARMA+', p1, const Color(0xFF062E1E),
        const Color(0xFFEAFFF4), 11.5, 30, 16);
    // 2) Nom sur la face avant du comptoir (or, sans fond).
    final p2 = _proj.project(0, 3.165, 0.58);
    _drawSignText(canvas, 'PHARMA+', p2, Colors.transparent,
        const Color(0xFFE9C873), 9, 0, 0);
  }

  void _drawSignText(Canvas canvas, String text, Offset c, Color bg, Color fg,
      double fontSize, double padX, double padY) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: fg,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (bg.a != 0) {
      final r = Rect.fromCenter(
          center: c, width: tp.width + padX * 2, height: tp.height + padY * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = bg,
      );
    }
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _drawLabels(Canvas canvas) {
    for (final z in zones) {
      final c = _proj.project((z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2, 0);
      final active = z.id == selectedId;
      final tp = TextPainter(
        text: TextSpan(
          text: S.t(z.labelKey, locale),
          style: TextStyle(
              color:
                  active ? Colors.white : Colors.white.withValues(alpha: 0.88),
              fontSize: active ? 12.5 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: active ? 0.5 : 0.2),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final r = Rect.fromCenter(
          center: c, width: tp.width + 22, height: tp.height + 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = z.color.withValues(alpha: active ? 0.94 : 0.75),
      );
      if (active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
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

/// ============================================================
/// PLEIN ÉCRAN — scène isométrique sur tout l'écran :
/// glisser = tourner, boutons = zoom +/− / zoom initial,
/// sélection de zone au clic, fermeture always-available (✕,
/// ESC via route plein écran, bouton retour navigateur).
/// ============================================================
class _FullScreenPlan extends StatefulWidget {
  final List<_Zone> zones;
  final double rot;
  final double zoom;
  final String locale;
  const _FullScreenPlan({
    required this.zones,
    required this.rot,
    required this.zoom,
    required this.locale,
  });

  @override
  State<_FullScreenPlan> createState() => _FullScreenPlanState();
}

class _FullScreenPlanState extends State<_FullScreenPlan> {
  late double _rot = widget.rot;
  late double _zoom = widget.zoom;
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1210),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final proj = _Projector(rot: _rot, zoom: _zoom, size: size);
                return Stack(children: [
                  GestureDetector(
                    onPanUpdate: (d) =>
                        setState(() => _rot += d.delta.dx * 0.01),
                    child: CustomPaint(
                      size: size,
                      painter: _PlanPainter(
                        zones: widget.zones,
                        rot: _rot,
                        zoom: _zoom,
                        locale: widget.locale,
                        size: size,
                        selectedId: _selected,
                      ),
                    ),
                  ),
                  for (final z in widget.zones)
                    Positioned(
                      left: _hitRect(proj, z).left,
                      top: _hitRect(proj, z).top,
                      width: _hitRect(proj, z).width,
                      height: _hitRect(proj, z).height,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = z.id),
                      ),
                    ),
                ]);
              },
            ),
          ),
          // Contrôles flottants + sortie garantie.
          Positioned(
            top: 12,
            left: 12,
            child: Row(children: [
              _fsBtn(Icons.home_rounded, 'Tableau de bord', () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ShellNav.goHome();
              }),
              const SizedBox(width: 8),
              _fsBtn(Icons.remove, 'Zoom -',
                  () => setState(() => _zoom = math.max(0.5, _zoom / 1.15))),
              const SizedBox(width: 8),
              _fsBtn(Icons.add, 'Zoom +',
                  () => setState(() => _zoom = math.min(3.0, _zoom * 1.15))),
              const SizedBox(width: 8),
              _fsBtn(
                  Icons.restart_alt,
                  'Zoom initial',
                  () => setState(() {
                        _rot = 0.6;
                        _zoom = 1.0;
                      })),
              const SizedBox(width: 8),
              _fsBtn(Icons.close_rounded, 'Quitter le plein écran', () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ShellNav.goHome();
              }),
            ]),
          ),
        ]),
      ),
    );
  }

  Rect _hitRect(_Projector proj, _Zone z) {
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
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Widget _fsBtn(IconData icon, String tip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tip,
        onPressed: onTap,
      ),
    );
  }
}
