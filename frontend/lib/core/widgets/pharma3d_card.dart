import 'package:flutter/material.dart';

/// Carte 3D premium du tableau de bord PHARMA+.
///
/// Profondeur 3D (ombres multi-couches), icône en relief, reflet lumineux,
/// animation au survol (web) et au clic (enfoncement + ripple).
class Pharma3DCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Gradient gradient;
  final Color glow;
  final VoidCallback? onTap;
  final String? badge;
  final Widget? visual;
  final double iconSize;
  final Duration entranceDelay;

  const Pharma3DCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.gradient,
    required this.glow,
    this.onTap,
    this.badge,
    this.visual,
    this.iconSize = 26,
    this.entranceDelay = Duration.zero,
  });

  @override
  State<Pharma3DCard> createState() => _Pharma3DCardState();
}

class _Pharma3DCardState extends State<Pharma3DCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 0,
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
    value: 0.5,
  );

  @override
  void initState() {
    super.initState();
    if (widget.entranceDelay > Duration.zero) {
      Future.delayed(widget.entranceDelay, () {
        if (mounted) _entrance.forward();
      });
    } else {
      _entrance.forward();
    }
    _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entrance, _float]),
          builder: (context, _) {
            final entrance = Curves.easeOutBack.transform(_entrance.value);
            final floatDy = ((_float.value - 0.5) * 6) * (_hovered ? 0 : 1);
            return Opacity(
              opacity: _entrance.value,
              child: Transform.translate(
                offset: Offset(0, floatDy),
                child: Transform.scale(
                  scale: (0.9 + 0.1 * entrance) *
                      (_pressed ? 0.97 : (_hovered ? 1.03 : 1)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _shadows(),
                    ),
                    child: _buildSurface(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<BoxShadow> _shadows() {
    final lift = _hovered ? 18.0 : 10.0;
    final alpha = _hovered ? 0.5 : 0.32;
    return [
      BoxShadow(
        color: widget.glow.withValues(alpha: alpha),
        blurRadius: 26,
        offset: Offset(0, lift),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: _pressed ? 0.32 : 0.24),
        blurRadius: 14,
        offset: Offset(0, _pressed ? 2 : 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.14),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  Widget _buildSurface() {
    return Container(
      decoration: BoxDecoration(
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Reflet lumineux en haut (effet verre / lumière)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Halo décoratif en bas à droite
            Positioned(
              right: -30,
              bottom: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
             Positioned(
               right: 6,
               bottom: 6,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16)),
                ),
              ),
             ),
            if (widget.visual != null)
              Positioned(
                right: 8,
                bottom: 4,
                child: IgnorePointer(child: widget.visual!),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _PharmaIcon3D(
                        icon: widget.icon,
                        size: widget.iconSize,
                        glow: widget.glow,
                      ),
                      const Spacer(),
                      if (widget.badge != null)
                        _Badge3D(text: widget.badge!)
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.75),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.7),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                   Text(
                     widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                       fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône en relief avec dégradé, liseré et ombre portée (effet 3D).
class _PharmaIcon3D extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color glow;

  const _PharmaIcon3D({
    required this.icon,
    required this.size,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

/// Petit badge arrondi (ex. statut).
class _Badge3D extends StatelessWidget {
  final String text;
  const _Badge3D({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
