import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// PLAN 3D DE LA PHARMACIE — SCÈNE ISOMÉTRIQUE « MAQUETTE »
/// Sol beige carrelé · murs vert profond (coupe 3D nord/ouest) ·
/// gondoles blanches à plateaux verts garnies de produits ·
/// unités murales · comptoirs de caisse « Caisses » ·
/// réfrigérateur vaccins · plantes · tapis d'entrée ·
/// étiquettes vertes flottantes (Médicaments, Ordonnances,
/// Caisses, Caisse…) · enseigne PHARMA+.
///
/// Boutons maquette : Vue 3D · Tourner · Zoom + · Vue Plafond ·
/// Plein écran — et légende intégrée (Médicaments, Ordonnances,
/// Stock, Caisse).
///
/// LE MÊME PAINTER EST UTILISÉ PAR LE DASHBOARD ET LA PAGE
/// PLAN 3D → rendu strictement IDENTIQUE sur les deux pages
/// (« Plan 3D identique sur Dashboard et Page Plan 3D »).
/// ============================================================

/// Étendue monde de la scène : 10 × 8 (entrée au sud, y = 8).
const double kPlanW = 10.0;
const double kPlanD = 8.0;

/// Zone fonctionnelle : rectangle au sol (hit-test + étiquette).
class Plan3DZone {
  const Plan3DZone({
    required this.id,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    this.chip = true,
  });
  final String id;
  final double x0, y0, x1, y1;
  final bool chip;
}

/// Zones de la pharmacie (identiques aux ids de la page Plan 3D
/// pour le panneau de détail : meds, para, counter, presc, vac,
/// cos, entrance).
const List<Plan3DZone> kPharmacyZones = [
  Plan3DZone(id: 'meds', x0: 0.6, y0: 0.25, x1: 6.0, y1: 5.3),
  Plan3DZone(id: 'para', x0: 6.5, y0: 1.2, x1: 8.95, y1: 4.45),
  Plan3DZone(id: 'counter', x0: 6.55, y0: 4.85, x1: 9.55, y1: 6.8),
  Plan3DZone(id: 'presc', x0: 0.5, y0: 5.7, x1: 2.5, y1: 7.1),
  Plan3DZone(id: 'vac', x0: 2.85, y0: 5.8, x1: 3.95, y1: 7.1),
  Plan3DZone(id: 'cos', x0: 4.25, y0: 5.8, x1: 6.0, y1: 7.1),
  Plan3DZone(
    id: 'entrance',
    x0: 3.85,
    y0: 7.0,
    x1: 6.2,
    y1: 7.85,
    chip: false,
  ),
];

/// Étiquettes par défaut (dashboard, FR). La page Plan 3D passe
/// les siennes traduites via [PharmacyPlan3D.labels].
const Map<String, String> kDefaultPlanLabels = {
  'meds': 'Médicaments',
  'presc': 'Ordonnances',
  'counter': 'Caisses',
  'vac': 'Vaccins',
  'para': 'Parapharmacie',
  'cos': 'Cosmétiques',
};

/// Icône des étiquettes flottantes (style maquette : chip verte).
const Map<String, IconData> kPlanChipIcons = {
  'meds': Icons.medication_rounded,
  'presc': Icons.receipt_long_rounded,
  'counter': Icons.point_of_sale_rounded,
  'vac': Icons.ac_unit_rounded,
  'para': Icons.spa_rounded,
  'cos': Icons.brush_rounded,
};

/// Contrôleur partagé de la scène (dashboard ↔ page Plan 3D).
/// Tourner / Zoom + / Vue Plafond / rotation automatique agissent
/// réellement sur la scène affichée.
class PharmacyPlanController extends ChangeNotifier {
  PharmacyPlanController({
    double rot = 0.55,
    double zoom = 1.0,
    bool ceiling = false,
    bool autoRotate = false,
  })  : _rot = rot,
        _zoom = zoom,
        _ceiling = ceiling,
        _autoRotate = autoRotate;

  static const double _minZoom = 0.62;
  static const double _maxZoom = 2.3;
  static const double defaultRot = 0.55;

  double _rot;
  double _zoom;
  bool _ceiling;
  bool _autoRotate;
  Timer? _timer;

  double get rot => _rot;
  double get zoom => _zoom;
  bool get ceiling => _ceiling;
  bool get autoRotate => _autoRotate;

  set rot(double v) {
    if (v == _rot) return;
    _rot = v;
    notifyListeners();
  }

  set zoom(double v) {
    final n = v.clamp(_minZoom, _maxZoom);
    if (n == _zoom) return;
    _zoom = n;
    notifyListeners();
  }

  void rotate(double delta) {
    _rot += delta;
    notifyListeners();
  }

  void zoomBy(double factor) => zoom = _zoom * factor;
  void zoomIn() => zoomBy(1.18);
  void zoomOut() => zoomBy(1 / 1.18);

  void toggleCeiling() {
    _ceiling = !_ceiling;
    notifyListeners();
  }

  void setAutoRotate(bool on) {
    if (_autoRotate == on) return;
    _autoRotate = on;
    _timer?.cancel();
    _timer = null;
    if (on) {
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        _rot += 0.012;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void toggleAutoRotate() => setAutoRotate(!_autoRotate);

  /// Vue initiale (rotation + zoom + coupe 3D).
  void reset() {
    _timer?.cancel();
    _timer = null;
    _autoRotate = false;
    _rot = defaultRot;
    _zoom = 1.0;
    _ceiling = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// ============================================================
/// WIDGET PLAN 3D — scène + boutons maquette + légende.
/// Utilisé tel quel par le panneau du dashboard (compact, boutons
/// intégrés) et par la page Plan 3D (contrôles de la page).
/// ============================================================
class PharmacyPlan3D extends StatefulWidget {
  const PharmacyPlan3D({
    super.key,
    this.controller,
    this.compact = false,
    this.interactive = true,
    this.showLabels = true,
    this.minimalChips = true,
    this.showControls = false,
    this.showLegend = false,
    this.onOpen,
    this.onZoneTap,
    this.selectedId,
    this.labels = kDefaultPlanLabels,
  });

  /// Contrôleur externe (page Plan 3D). Sinon un contrôleur
  /// interne gère rotation / zoom / vue plafond.
  final PharmacyPlanController? controller;

  /// Rendu compact (panneau du dashboard).
  final bool compact;

  /// Glisser = faire tourner la scène ; molette = zoom.
  final bool interactive;

  /// Étiquettes flottantes visibles.
  final bool showLabels;

  /// true = chips maquette uniquement (Médicaments, Ordonnances,
  /// Caisses) ; false = toutes les zones (page Plan 3D).
  final bool minimalChips;

  /// Colonne de boutons maquette intégrée à droite de la scène.
  final bool showControls;

  /// Légende intégrée (Médicaments · Ordonnances · Stock · Caisse).
  final bool showLegend;

  /// « Vue 3D » / « Plein écran » → ouvrir la page complète.
  final VoidCallback? onOpen;

  /// Tap sur une zone (page Plan 3D : panneau de détail).
  final ValueChanged<String>? onZoneTap;

  /// Zone active surlignée.
  final String? selectedId;

  /// Libellés affichés (traduits par la page Plan 3D).
  final Map<String, String> labels;

  @override
  State<PharmacyPlan3D> createState() => _PharmacyPlan3DState();
}

class _PharmacyPlan3DState extends State<PharmacyPlan3D> {
  PharmacyPlanController? _internal;
  final Map<String, Rect> _hitRects = <String, Rect>{};

  PharmacyPlanController get _ctl =>
      widget.controller ?? (_internal ??= PharmacyPlanController());

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant PharmacyPlan3D old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onChange);
      _ctl.addListener(_onChange);
    }
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctl.removeListener(_onChange);
    _internal?.dispose();
    super.dispose();
  }

  void _onScroll(PointerSignalEvent e) {
    if (!widget.interactive) return;
    if (e is PointerScrollEvent) {
      _ctl.zoomBy(e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
    }
  }

  /// Tap sur une zone : hit-test sur les rectangles projetés.
  void _onTap(TapUpDetails d) {
    final onTap = widget.onZoneTap;
    if (onTap == null) return;
    final p = d.localPosition;
    String? best;
    double bestArea = double.infinity;
    _hitRects.forEach((id, r) {
      if (r.contains(p) && r.width * r.height < bestArea) {
        best = id;
        bestArea = r.width * r.height;
      }
    });
    if (best != null) onTap(best!);
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final bs = compact ? 31.0 : 37.0;
    final gap = compact ? 7.0 : 9.0;
    final buttons = <Widget>[
      if (widget.onOpen != null) ...[
        _PlanButton(
          icon: Icons.view_in_ar_rounded,
          tooltip: 'Vue 3D · Ouvrir le Plan 3D complet',
          size: bs,
          onTap: widget.onOpen!,
        ),
        SizedBox(height: gap),
      ],
      _PlanButton(
        icon: Icons.rotate_right_rounded,
        tooltip: 'Tourner',
        size: bs,
        onTap: () => _ctl.rotate(0.45),
      ),
      SizedBox(height: gap),
      _PlanButton(
        icon: Icons.add_rounded,
        tooltip: 'Zoom +',
        size: bs,
        onTap: _ctl.zoomIn,
      ),
      SizedBox(height: gap),
      _PlanButton(
        icon: Icons.roofing_rounded,
        tooltip: _ctl.ceiling ? 'Vue 3D' : 'Vue Plafond',
        size: bs,
        active: _ctl.ceiling,
        onTap: _ctl.toggleCeiling,
      ),
      SizedBox(height: gap),
      if (widget.onOpen != null)
        _PlanButton(
          icon: Icons.fullscreen_rounded,
          tooltip: 'Plein écran',
          size: bs,
          onTap: widget.onOpen!,
        ),
    ];

    return ClipRect(
      child: Stack(children: [
        Positioned.fill(
          child: Listener(
            onPointerSignal: _onScroll,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: widget.interactive
                  ? (d) => _ctl.rotate(d.delta.dx * 0.008)
                  : null,
              onTapUp: widget.onZoneTap == null ? null : _onTap,
              child: CustomPaint(
                painter: PharmacyPlan3DPainter(
                  rot: _ctl.rot,
                  zoom: _ctl.zoom,
                  ceiling: _ctl.ceiling,
                  compact: compact,
                  minimalChips: widget.minimalChips || compact,
                  labels: widget.labels,
                  selectedId: widget.selectedId,
                  showLabels: widget.showLabels,
                  hitRects: _hitRects,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        // ---- Colonne de boutons maquette (droite de la scène) ----
        if (widget.showControls)
          Positioned(
            right: compact ? 8 : 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min, children: buttons),
            ),
          ),
        // ---- Légende maquette (bas de la scène) ----
        if (widget.showLegend)
          Positioned(
            left: compact ? 8 : 12,
            bottom: compact ? 6 : 9,
            child: _PlanLegendRow(compact: compact),
          ),
      ]),
    );
  }
}

/// Bouton circulaire maquette : fond vert nuit, liseré émeraude,
/// icône lumineuse — Vue 3D · Tourner · Zoom + · Vue Plafond ·
/// Plein écran.
class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? const Color(0xFF0E3B27)
                  : const Color(0xFF0A241A).withValues(alpha: 0.92),
              border: Border.all(
                color: active
                    ? const Color(0xFF00C96B)
                    : const Color(0xFF1F5C40).withValues(alpha: 0.9),
                width: active ? 1.4 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: active
                  ? const Color(0xFF3BE39A)
                  : const Color(0xFF2FD37F),
            ),
          ),
        ),
      ),
    );
  }
}

/// Légende maquette : Médicaments · Ordonnances · Stock · Caisse.
class _PlanLegendRow extends StatelessWidget {
  const _PlanLegendRow({required this.compact});
  final bool compact;

  static const List<(String, IconData, Color)> _items = [
    ('Médicaments', Icons.medication_rounded, Color(0xFF00C96B)),
    ('Ordonnances', Icons.receipt_long_rounded, Color(0xFF17A05E)),
    ('Stock', Icons.inventory_2_rounded, Color(0xFFF59E0B)),
    ('Caisse', Icons.shopping_cart_rounded, Color(0xFF5B8FD9)),
  ];

  @override
  Widget build(BuildContext context) {
    final s = compact ? 15.0 : 17.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11, vertical: compact ? 4 : 5.5),
      decoration: BoxDecoration(
        color: const Color(0xFF04120C).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF1F5C40).withValues(alpha: 0.85)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 9 : 14),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: _items[i].$3.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(5),
            ),
            child:
                Icon(_items[i].$2, size: s * 0.62, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Text(
            _items[i].$1,
            style: TextStyle(
              color: const Color(0xFFD9E8DF),
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ]),
    );
  }
}

/// ============================================================
/// PAINTER DE LA SCÈNE — isométrie maquette, faces triées par
/// profondeur écran, billboards (chips + enseigne) par-dessus.
/// ============================================================
class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
}

class _Face {
  const _Face(this.pts, this.color);
  final List<_V> pts;
  final Color color;
}

class _Obj {
  final faces = <_Face>[];
  double key = double.negativeInfinity;
}

/// Projection isométrique maquette (pitch léger) + vue plafond.
class _Proj {
  _Proj({
    required double rot,
    required this.zoom,
    required this.tilt,
    required Size size,
  }) : _rot = rot {
    s = math.min(size.width, size.height) / 12.4 * zoom;
    cx = size.width * 0.5;
    cy = size.height * 0.545;
  }
  final double _rot, zoom, tilt;
  late final double s, cx, cy;

  Offset pr(double x, double y, double z) {
    final c = math.cos(_rot), sn = math.sin(_rot);
    final rx = x * c - y * sn;
    final ry = x * sn + y * c;
    final sx =
        cx + (rx * (0.866 + 0.134 * tilt) - ry * (1 - tilt) * 0.866) * s;
    final sy = cy +
        ((rx + ry) * 0.55 * (1 - tilt) + ry * tilt) * s -
        z * s * 0.85 * (1 - tilt);
    return Offset(sx, sy);
  }
}

class PharmacyPlan3DPainter extends CustomPainter {
  PharmacyPlan3DPainter({
    required this.rot,
    required this.zoom,
    required this.ceiling,
    required this.compact,
    required this.minimalChips,
    required this.showLabels,
    required this.labels,
    this.selectedId,
    this.hitRects,
  });

  final double rot;
  final double zoom;
  final bool ceiling;
  final bool compact;
  final bool minimalChips;
  final bool showLabels;
  final Map<String, String> labels;
  final String? selectedId;
  final Map<String, Rect>? hitRects;

  late _Proj _p;
  final List<_Obj> _objs = <_Obj>[];

  // Palette maquette.
  static const Color _shelfBody = Color(0xFFF3EFE4);
  static const Color _shelfShade = Color(0xFFD9D2BE);
  static const Color _shelfTop = Color(0xFFE7E1CE);
  static const Color _greenTop = Color(0xFF3CB56D);
  static const Color _greenFront = Color(0xFF2F9E5C);
  static const Color _greenSide = Color(0xFF22804A);
  static const Color _creamFront = Color(0xFFF1EBDA);
  static const Color _creamSide = Color(0xFFD9D1B8);
  static const Color _creamTop = Color(0xFFE6DFC9);

  static const List<Color> _productColors = [
    Color(0xFFFFFFFF),
    Color(0xFFF3B9C6),
    Color(0xFFF6C46A),
    Color(0xFF9BD8F5),
    Color(0xFFC9E8B4),
    Color(0xFFEDE7D6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _p = _Proj(
        rot: rot, zoom: zoom, tilt: ceiling ? 1.0 : 0.0, size: size);
    _objs.clear();
    _background(canvas, size);
    _floor(canvas);
    _decals(canvas);
    _walls(canvas);
    _furniture();
    _objs.sort((a, b) => a.key.compareTo(b.key));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withValues(alpha: 0.10);
    for (final o in _objs) {
      for (final f in o.faces) {
        _paintFace(canvas, f, stroke);
      }
    }
    if (showLabels) _chips(canvas);
    _sign(canvas);
    _fillHitRects();
  }

  void _paintFace(Canvas canvas, _Face f, Paint stroke) {
    final path = Path();
    for (var i = 0; i < f.pts.length; i++) {
      final o = _p.pr(f.pts[i].x, f.pts[i].y, f.pts[i].z);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = f.color);
    canvas.drawPath(path, stroke);
  }

  /// Fond : vert nuit profond avec halo central diffus (maquette).
  void _background(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF05100B));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.5, size.height * 0.40),
            size.longestSide * 0.85,
            const [Color(0xFF13382A), Color(0xFF071510)],
          ));
  }

  void _drawQuad(Canvas canvas, List<_V> pts, Color color) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = _p.pr(pts[i].x, pts[i].y, pts[i].z);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Sol : dalles beiges + joints (carrelage pharmacie maquette),
  /// chants sombres de la plateforme au sud et à l'est.
  void _floor(Canvas canvas) {
    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 8; j++) {
        _drawQuad(
            canvas,
            [
              _V(i.toDouble(), j.toDouble(), 0),
              _V(i + 1.0, j.toDouble(), 0),
              _V(i + 1.0, j + 1.0, 0),
              _V(i.toDouble(), j + 1.0, 0),
            ],
            (i + j) % 2 == 0
                ? const Color(0xFFE6DAC0)
                : const Color(0xFFDCCFB0));
      }
    }
    final joint = Paint()
      ..color = const Color(0xFFC7B896).withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(_p.pr(i.toDouble(), 0, 0),
          _p.pr(i.toDouble(), 8, 0), joint);
    }
    for (int j = 0; j <= 8; j++) {
      canvas.drawLine(
          _p.pr(0, j.toDouble(), 0), _p.pr(10, j.toDouble(), 0), joint);
    }
    // Chants de la plateforme (face sud + face est).
    _drawQuad(
        canvas,
        [
          const _V(0, 8, 0),
          const _V(10, 8, 0),
          const _V(10, 8, -0.38),
          const _V(0, 8, -0.38),
        ],
        const Color(0xFF22392C));
    _drawQuad(
        canvas,
        [
          const _V(10, 0, 0),
          const _V(10, 8, 0),
          const _V(10, 8, -0.38),
          const _V(10, 0, -0.38),
        ],
        const Color(0xFF1B2E23));
    // Liseré clair (soubassement) en haut des chants.
    _drawQuad(
        canvas,
        [
          const _V(0, 8, 0),
          const _V(10, 8, 0),
          const _V(10, 8, -0.07),
          const _V(0, 8, -0.07),
        ],
        const Color(0xFFD8CFB8));
    _drawQuad(
        canvas,
        [
          const _V(10, 0, 0),
          const _V(10, 8, 0),
          const _V(10, 8, -0.07),
          const _V(10, 0, -0.07),
        ],
        const Color(0xFFCFC5AB));
  }

  /// Décalques au sol : tapis d'entrée + surbrillance de zone.
  void _decals(Canvas canvas) {
    _drawQuad(
        canvas,
        [
          const _V(4.0, 7.05, 0.006),
          const _V(6.1, 7.05, 0.006),
          const _V(6.1, 7.78, 0.006),
          const _V(4.0, 7.78, 0.006),
        ],
        const Color(0xFF143C2A));
    final inset = Path()
      ..moveTo(_p.pr(4.18, 7.23, 0.006).dx, _p.pr(4.18, 7.23, 0.006).dy)
      ..lineTo(_p.pr(5.92, 7.23, 0.006).dx, _p.pr(5.92, 7.23, 0.006).dy)
      ..lineTo(_p.pr(5.92, 7.6, 0.006).dx, _p.pr(5.92, 7.6, 0.006).dy)
      ..lineTo(_p.pr(4.18, 7.6, 0.006).dx, _p.pr(4.18, 7.6, 0.006).dy)
      ..close();
    canvas.drawPath(
        inset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFF2FA363));
    // Zone active : voile émeraude + contour.
    final sel = selectedId;
    if (sel == null) return;
    for (final z in kPharmacyZones) {
      if (z.id != sel) continue;
      _drawQuad(
          canvas,
          [
            _V(z.x0, z.y0, 0.008),
            _V(z.x1, z.y0, 0.008),
            _V(z.x1, z.y1, 0.008),
            _V(z.x0, z.y1, 0.008),
          ],
          const Color(0xFF00C96B).withValues(alpha: 0.14));
      final sp = Path()
        ..moveTo(_p.pr(z.x0, z.y0, 0.01).dx, _p.pr(z.x0, z.y0, 0.01).dy)
        ..lineTo(_p.pr(z.x1, z.y0, 0.01).dx, _p.pr(z.x1, z.y0, 0.01).dy)
        ..lineTo(_p.pr(z.x1, z.y1, 0.01).dx, _p.pr(z.x1, z.y1, 0.01).dy)
        ..lineTo(_p.pr(z.x0, z.y1, 0.01).dx, _p.pr(z.x0, z.y1, 0.01).dy)
        ..close();
      canvas.drawPath(
          sp,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF00C96B).withValues(alpha: 0.85));
    }
  }

  /// Murs vert profond (coupe 3D : nord + ouest ; sud et est ouverts
  /// pour ne jamais masquer l'intérieur) + plinthes claires.
  void _walls(Canvas canvas) {
    const h = 2.55;
    final c = math.cos(rot), s = math.sin(rot);
    // ---- Mur nord (plan y = 0) ----
    final northInner = (c - s) >= 0;
    final ny = northInner ? 0.02 : -0.02;
    _drawQuad(
        canvas,
        [
          _V(-0.12, ny, h),
          _V(10.12, ny, h),
          _V(10.12, ny, 0.24),
          _V(-0.12, ny, 0.24),
        ],
        northInner
            ? const Color(0xFF20402F)
            : const Color(0xFF142820));
    _drawQuad(
        canvas,
        [
          _V(-0.12, ny, 0.24),
          _V(10.12, ny, 0.24),
          _V(10.12, ny, 0),
          _V(-0.12, ny, 0),
        ],
        const Color(0xFFEBE2CB));
    _drawQuad(
        canvas,
        [
          _V(-0.12, ny, h),
          _V(10.12, ny, h),
          _V(10.12, ny, h - 0.09),
          _V(-0.12, ny, h - 0.09),
        ],
        const Color(0xFF2E5A44));
    // ---- Mur ouest (plan x = 0) ----
    final westInner = (c + s) >= 0;
    final wx = westInner ? 0.02 : -0.02;
    _drawQuad(
        canvas,
        [
          _V(wx, -0.02, h),
          _V(wx, 8.02, h),
          _V(wx, 8.02, 0.24),
          _V(wx, -0.02, 0.24),
        ],
        westInner
            ? const Color(0xFF1B362A)
            : const Color(0xFF12241C));
    _drawQuad(
        canvas,
        [
          _V(wx, -0.02, 0.24),
          _V(wx, 8.02, 0.24),
          _V(wx, 8.02, 0),
          _V(wx, -0.02, 0),
        ],
        const Color(0xFFE5DCC6));
    _drawQuad(
        canvas,
        [
          _V(wx, -0.02, h),
          _V(wx, 8.02, h),
          _V(wx, 8.02, h - 0.09),
          _V(wx, -0.02, h - 0.09),
        ],
        const Color(0xFF2A5340));
  }

  Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

  /// Clé de tri : profondeur écran du coin le plus proche du sol.
  double _cornerKey(double x0, double y0, double x1, double y1) {
    double key = double.negativeInfinity;
    for (final p in [
      [x0, y0],
      [x1, y0],
      [x1, y1],
      [x0, y1],
    ]) {
      final sy = _p.pr(p[0], p[1], 0).dy;
      if (sy > key) key = sy;
    }
    return key;
  }

  /// Boîte 3D : faces visibles seulement (culage par la rotation),
  /// ajoutées dans l'objet [into].
  void _box(
    double x0,
    double y0,
    double x1,
    double y1,
    double z0,
    double z1,
    _Obj into, {
    required Color front,
    required Color side,
    Color? top,
  }) {
    final flat = _p.tilt > 0.98;
    final c = math.cos(rot), s = math.sin(rot);
    if (!flat) {
      if (c - s > 0) {
        into.faces.add(_Face([
          _V(x0, y1, z0), _V(x1, y1, z0), _V(x1, y1, z1), _V(x0, y1, z1),
        ], front));
      }
      if (s - c > 0) {
        into.faces.add(_Face([
          _V(x1, y0, z0), _V(x0, y0, z0), _V(x0, y0, z1), _V(x1, y0, z1),
        ], _darken(front, 0.28)));
      }
      if (c + s > 0) {
        into.faces.add(_Face([
          _V(x1, y0, z0), _V(x1, y1, z0), _V(x1, y1, z1), _V(x1, y0, z1),
        ], side));
      }
      if (-(c + s) > 0) {
        into.faces.add(_Face([
          _V(x0, y1, z0), _V(x0, y0, z0), _V(x0, y0, z1), _V(x0, y1, z1),
        ], _darken(side, 0.18)));
      }
    }
    into.faces.add(_Face([
      _V(x0, y0, z1), _V(x1, y0, z1), _V(x1, y1, z1), _V(x0, y1, z1),
    ], top ?? _lighten(front, 0.20)));
  }

  void _shadow(_Obj o, double x0, double y0, double x1, double y1) {
    o.faces.add(_Face([
      _V(x0, y0, 0.004),
      _V(x1, y0, 0.004),
      _V(x1, y1, 0.004),
      _V(x0, y1, 0.004),
    ], Colors.black.withValues(alpha: 0.16)));
  }

  /// Gondole maquette : corps blanc cassé, plateau vert garni de
  /// produits colorés (orientation automatique selon la longueur).
  void _gondola(
      double x0, double y0, double x1, double y1, double h, int seed) {
    final o = _Obj();
    o.key = _cornerKey(x0, y0, x1, y1);
    _shadow(o, x0 - 0.07, y0 - 0.07, x1 + 0.07, y1 + 0.07);
    _box(x0, y0, x1, y1, 0.06, h, o,
        front: _shelfBody, side: _shelfShade, top: _shelfTop);
    _box(x0 - 0.03, y0 - 0.03, x1 + 0.03, y1 + 0.03, h, h + 0.07, o,
        front: _greenFront, side: _greenSide, top: _greenTop);
    final alongX = (x1 - x0) >= (y1 - y0);
    if (alongX) {
      final n = ((x1 - x0) / 0.62).floor().clamp(2, 12);
      for (int i = 0; i < n; i++) {
        final cx = x0 + (x1 - x0) * (i + 0.5) / n;
        final col = _productColors[(seed + i) % _productColors.length];
        _box(cx - 0.14, y0 + 0.1, cx + 0.14, y1 - 0.1, h + 0.07, h + 0.3,
            o,
            front: col,
            side: _darken(col, 0.10),
            top: _lighten(col, 0.3));
      }
    } else {
      final n = ((y1 - y0) / 0.62).floor().clamp(2, 12);
      for (int i = 0; i < n; i++) {
        final cy = y0 + (y1 - y0) * (i + 0.5) / n;
        final col = _productColors[(seed + i) % _productColors.length];
        _box(x0 + 0.1, cy - 0.14, x1 - 0.1, cy + 0.14, h + 0.07, h + 0.3,
            o,
            front: col,
            side: _darken(col, 0.10),
            top: _lighten(col, 0.3));
      }
    }
    _objs.add(o);
  }

  /// Unité murale : dossier, montants, 2 rayonnages garnis + plateau
  /// vert au sommet (pas de face avant : les produits restent lisibles).
  void _wallUnit(
      double x0, double y0, double x1, double y1, double h, int seed) {
    final o = _Obj();
    o.key = _cornerKey(x0, y0, x1, y1);
    _shadow(o, x0 - 0.06, y0 - 0.06, x1 + 0.06, y1 + 0.06);
    _box(x0, y0, x1, y0 + 0.09, 0.05, h, o,
        front: _shelfShade, side: _shelfBody, top: _shelfTop);
    _box(x0, y0, x0 + 0.08, y1, 0.05, h, o,
        front: _shelfBody, side: _shelfShade, top: _shelfTop);
    _box(x1 - 0.08, y0, x1, y1, 0.05, h, o,
        front: _shelfBody, side: _shelfShade, top: _shelfTop);
    for (final zl in [h * 0.34, h * 0.68]) {
      _box(x0 + 0.08, y0 + 0.09, x1 - 0.08, y1, zl, zl + 0.06, o,
          front: const Color(0xFFEDE7D4),
          side: const Color(0xFFD8D0B8),
          top: const Color(0xFFF6F1E0));
      final n = ((x1 - x0) / 0.75).floor().clamp(2, 10);
      for (int i = 0; i < n; i++) {
        final cx = x0 + (x1 - x0) * (i + 0.5) / n;
        final col = _productColors[(seed + i) % _productColors.length];
        _box(cx - 0.13, y0 + 0.14, cx + 0.13, y1 - 0.05, zl + 0.06,
            zl + 0.27, o,
            front: col,
            side: _darken(col, 0.10),
            top: _lighten(col, 0.3));
      }
    }
    _box(x0 - 0.03, y0 - 0.03, x1 + 0.03, y1 + 0.03, h, h + 0.07, o,
        front: _greenFront, side: _greenSide, top: _greenTop);
    _objs.add(o);
  }

  /// Comptoir de caisse maquette : meuble crème, plateau vert,
  /// écran de caisse ( dalle émeraude côté vendeur), TPE, rouleau.
  void _counter(double x0, double y0, double x1, double y1, double regX) {
    final o = _Obj();
    o.key = _cornerKey(x0, y0, x1, y1);
    _shadow(o, x0 - 0.07, y0 - 0.07, x1 + 0.07, y1 + 0.07);
    _box(x0, y0, x1, y1, 0.05, 0.92, o,
        front: _creamFront, side: _creamSide, top: _creamTop);
    _box(x0 - 0.05, y0 - 0.05, x1 + 0.05, y1 + 0.05, 0.92, 1.0, o,
        front: _greenFront, side: _greenSide, top: _greenTop);
    final cy = (y0 + y1) / 2;
    // Écran de caisse (côté vendeur) + dalle émeraude.
    _box(regX - 0.24, cy - 0.13, regX + 0.02, cy + 0.13, 1.0, 1.42, o,
        front: const Color(0xFF10241A),
        side: const Color(0xFF0B1B13),
        top: const Color(0xFF173323));
    o.faces.add(_Face([
      _V(regX - 0.22, cy + 0.131, 1.36),
      _V(regX + 0.0, cy + 0.131, 1.36),
      _V(regX + 0.0, cy + 0.131, 1.14),
      _V(regX - 0.22, cy + 0.131, 1.14),
    ], const Color(0xFF1F7A4D)));
    // TPE (terminal de paiement).
    _box(regX + 0.18, cy - 0.1, regX + 0.46, cy + 0.1, 1.0, 1.17, o,
        front: const Color(0xFF131C16),
        side: const Color(0xFF0D1410),
        top: const Color(0xFF22302A));
    // Rouleau de reçus.
    _box(regX - 0.52, cy - 0.09, regX - 0.36, cy + 0.09, 1.0, 1.2, o,
        front: const Color(0xFFF7F3E8),
        side: const Color(0xFFE4DDCB),
        top: const Color(0xFFFFFFFF));
    _objs.add(o);
  }

  /// Réfrigérateur vaccins : coffre clair bleuté, porte vitrée.
  void _fridge(double x0, double y0, double x1, double y1) {
    final o = _Obj();
    o.key = _cornerKey(x0, y0, x1, y1);
    _shadow(o, x0 - 0.06, y0 - 0.06, x1 + 0.06, y1 + 0.06);
    _box(x0, y0, x1, y1, 0.05, 1.7, o,
        front: const Color(0xFFE9F1F6),
        side: const Color(0xFFCBDAE4),
        top: const Color(0xFFF5F9FC));
    // Bande vitrée bleutée sur la face avant.
    o.faces.add(_Face([
      _V(x0 + 0.06, y1 + 0.001, 1.5),
      _V(x1 - 0.06, y1 + 0.001, 1.5),
      _V(x1 - 0.06, y1 + 0.001, 0.5),
      _V(x0 + 0.06, y1 + 0.001, 0.5),
    ], const Color(0xFFBFD9EC).withValues(alpha: 0.85)));
    // Liseré émeraude (chaîne du froid PHARMA+).
    o.faces.add(_Face([
      _V(x0 + 0.06, y1 + 0.002, 1.62),
      _V(x1 - 0.06, y1 + 0.002, 1.62),
      _V(x1 - 0.06, y1 + 0.002, 1.56),
      _V(x0 + 0.06, y1 + 0.002, 1.56),
    ], const Color(0xFF00C96B)));
    _objs.add(o);
  }

  /// Plante d'angle : pot terre + feuillage en cubes verts.
  void _plant(double x, double y) {
    final o = _Obj();
    o.key = _cornerKey(x - 0.24, y - 0.24, x + 0.24, y + 0.24);
    _shadow(o, x - 0.22, y - 0.22, x + 0.22, y + 0.22);
    _box(x - 0.15, y - 0.15, x + 0.15, y + 0.15, 0.0, 0.3, o,
        front: const Color(0xFF8A6A4B),
        side: const Color(0xFF6E5339),
        top: const Color(0xFF5C4630));
    _box(x - 0.16, y - 0.16, x + 0.16, y + 0.16, 0.3, 0.62, o,
        front: const Color(0xFF2E9E5B),
        side: const Color(0xFF237A46),
        top: const Color(0xFF48C27A));
    _box(x - 0.26, y - 0.06, x + 0.04, y + 0.18, 0.4, 0.68, o,
        front: const Color(0xFF35AE68),
        side: const Color(0xFF27854E),
        top: const Color(0xFF52D68C));
    _box(x - 0.04, y - 0.22, x + 0.26, y + 0.06, 0.36, 0.62, o,
        front: const Color(0xFF2E9E5B),
        side: const Color(0xFF237A46),
        top: const Color(0xFF48C27A));
    _objs.add(o);
  }

  /// Assemblage du mobilier (positions maquette).
  void _furniture() {
    // Unité murale nord + rangées de gondoles (Médicaments).
    _wallUnit(0.75, 0.28, 5.85, 0.92, 1.9, 3);
    _gondola(1.0, 1.7, 5.9, 2.35, 1.15, 0);
    _gondola(1.0, 3.15, 5.9, 3.8, 1.15, 7);
    _gondola(1.0, 4.6, 5.9, 5.25, 1.15, 13);
    // Parapharmacie : 2 gondoles le long de l'est.
    _gondola(6.6, 1.35, 7.35, 4.3, 1.15, 21);
    _gondola(8.0, 1.35, 8.75, 4.3, 1.15, 27);
    // Ordonnances : 2 petites gondoles à l'avant-gauche.
    _gondola(0.6, 5.85, 2.4, 6.42, 1.0, 33);
    _gondola(0.6, 6.55, 2.4, 7.1, 1.0, 37);
    // Vaccins : réfrigérateur.
    _fridge(2.9, 5.85, 3.9, 6.95);
    // Cosmétiques.
    _gondola(4.3, 5.95, 6.0, 6.55, 1.05, 41);
    // Caisses : 2 comptoirs.
    _counter(6.7, 5.0, 9.45, 5.68, 7.35);
    _counter(6.7, 6.05, 9.45, 6.73, 8.65);
    // Plantes d'angle.
    _plant(0.85, 7.4);
    _plant(9.35, 7.35);
    _plant(9.35, 0.8);
  }

  /// Étiquettes flottantes vertes (style maquette) + mini « Caisse ».
  void _chips(Canvas canvas) {
    final shown = minimalChips
        ? const ['meds', 'presc', 'counter']
        : const ['meds', 'presc', 'counter', 'vac', 'para', 'cos'];
    final anchors = <String, (double, double, double)>{
      'meds': (3.3, 2.78, 2.35),
      'presc': (1.5, 6.4, 2.0),
      'counter': (8.05, 5.83, 2.0),
      'vac': (3.4, 6.45, 2.5),
      'para': (7.73, 2.83, 2.2),
      'cos': (5.13, 6.45, 2.0),
    };
    for (final id in shown) {
      final label = labels[id];
      if (label == null || label.isEmpty) continue;
      final a = anchors[id]!;
      final o = _p.pr(a.$1, a.$2, a.$3);
      _chip(
        canvas,
        o,
        label,
        kPlanChipIcons[id] ?? Icons.place_rounded,
        active: selectedId == id,
        mini: false,
      );
    }
    // Mini chip « Caisse » sur le registre (toujours visible).
    final mc = _p.pr(7.45, 5.34, 1.95);
    _chip(canvas, mc, 'Caisse', Icons.point_of_sale_rounded,
        active: false, mini: true);
  }

  void _chip(
    Canvas canvas,
    Offset anchor,
    String label,
    IconData icon, {
    required bool active,
    required bool mini,
  }) {
    final s = _p.s;
    final h = mini
        ? (0.34 * s).clamp(11.0, compact ? 14.0 : 16.0)
        : (0.5 * s).clamp(compact ? 14.0 : 17.0, compact ? 19.0 : 26.0);
    final ip = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: h * 0.56,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.52,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final w = ip.width + tp.width + h * 0.55 + (mini ? 12 : 18);
    final r = Rect.fromCenter(
        center: anchor.translate(0, -h * 0.85), width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          r.translate(1.5, 2.5), Radius.circular(h / 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    final grad = ui.Gradient.linear(r.topLeft, r.bottomLeft,
        const [Color(0xFF1BD489), Color(0xFF069A52)]);
    final body = RRect.fromRectAndRadius(r, Radius.circular(h / 2));
    canvas.drawRRect(body, Paint()..shader = grad);
    if (active) {
      canvas.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.95));
    }
    final pointer = Path()
      ..moveTo(anchor.dx - h * 0.2, r.bottom - 0.5)
      ..lineTo(anchor.dx + h * 0.2, r.bottom - 0.5)
      ..lineTo(anchor.dx, r.bottom + h * 0.3)
      ..close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFF069A52));
    ip.paint(
        canvas, Offset(r.left + h * 0.28, r.center.dy - ip.height / 2));
    tp.paint(
        canvas,
        Offset(r.left + h * 0.28 + ip.width + h * 0.24,
            r.center.dy - tp.height / 2));
  }

  /// Enseigne PHARMA+ (billboard) à l'entrée : panneau blanc,
  /// croix verte, typographie PHARMA+.
  void _sign(Canvas canvas) {
    final s = _p.s;
    final anchor = _p.pr(5.05, 8.02, 1.05);
    final h =
        (0.86 * s).clamp(compact ? 20.0 : 26.0, compact ? 30.0 : 44.0);
    final w = h * 2.7;
    final r = Rect.fromCenter(
        center: anchor.translate(0, -h * 0.8), width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          r.translate(2, 3), Radius.circular(h * 0.16)),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(h * 0.16)),
      Paint()
        ..shader = ui.Gradient.linear(r.topLeft, r.bottomLeft,
            const [Color(0xFFFFFFFF), Color(0xFFE9EDE8)]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(h * 0.16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF0E7A44).withValues(alpha: 0.5),
    );
    // Croix verte (logo).
    final cx = r.left + h * 0.62, cy = r.center.dy;
    final t = h * 0.24;
    final cross = Paint()..color = const Color(0xFF00A651);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy), width: t, height: t * 2.6),
            Radius.circular(t * 0.28)),
        cross);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy), width: t * 2.6, height: t),
            Radius.circular(t * 0.28)),
        cross);
    // Texte PHARMA+.
    final tp = TextPainter(
      text: TextSpan(
        text: 'PHARMA+',
        style: TextStyle(
          color: const Color(0xFF0B3D26),
          fontSize: h * 0.42,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx + t * 1.9, cy - tp.height / 2));
  }

  /// Rectangles écran des zones (hit-test au tap).
  void _fillHitRects() {
    final map = hitRects;
    if (map == null) return;
    map.clear();
    for (final z in kPharmacyZones) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity,
          maxY = double.negativeInfinity;
      for (final p in [
        [z.x0, z.y0],
        [z.x1, z.y0],
        [z.x1, z.y1],
        [z.x0, z.y1],
      ]) {
        final o = _p.pr(p[0], p[1], 0);
        minX = math.min(minX, o.dx);
        minY = math.min(minY, o.dy);
        maxX = math.max(maxX, o.dx);
        maxY = math.max(maxY, o.dy);
      }
      map[z.id] = Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }

  @override
  bool shouldRepaint(covariant PharmacyPlan3DPainter old) =>
      old.rot != rot ||
      old.zoom != zoom ||
      old.ceiling != ceiling ||
      old.compact != compact ||
      old.minimalChips != minimalChips ||
      old.showLabels != showLabels ||
      old.selectedId != selectedId ||
      !identical(old.labels, labels);
}