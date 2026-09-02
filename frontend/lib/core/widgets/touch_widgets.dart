import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Bouton tactile optimisé - au moins 48dp pour doigts
class TouchButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool outlined;
  final bool small;

  const TouchButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.outlined = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = small ? 40.0 : ResponsiveHelper.touchTargetSize;

    if (outlined) {
      return SizedBox(
        height: height,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: small ? 12 : 16,
              vertical: small ? 8 : 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 16,
            vertical: small ? 8 : 12,
          ),
        ),
      ),
    );
  }
}

/// Carte tactile grande pour les écrans tactiles
class TouchCard extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double padding;

  const TouchCard({
    this.onTap,
    required this.child,
    this.padding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}

/// Bouton flottant tactile grand
class TouchFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;

  const TouchFab({
    required this.onPressed,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return FloatingActionButton(
        onPressed: onPressed,
        child: Icon(icon),
      );
    }

    return SizedBox(
      height: 56,
      width: 56,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: label,
        child: Icon(icon),
      ),
    );
  }
}

/// Zone cliquable tactile
class TouchZone extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final double minSize;

  const TouchZone({
    required this.onTap,
    required this.child,
    this.minSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minSize,
          minWidth: minSize,
        ),
        child: child,
      ),
    );
  }
}
