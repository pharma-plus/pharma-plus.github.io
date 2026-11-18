// ============================================================
// PHARMA+ SALES INTELLIGENCE — Design System commun
// ============================================================
// Tokens et primitives visuelles réutilisés par les 10 pages du module.
//
// Règle d'or (Phase 5) : le fond émeraude officiel est conservé, mais
// toutes les surfaces du module sont SOMBRES et translucides avec un
// liseré or champagne. Aucune surface ne dépend du thème clair global
// (`GlassCard` choisissait `Colors.white` sous `AppTheme.light()`).
// Les textes sont champagne / porcelaine, jamais `inkDark` sur sombre.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Tokens de design du module SALES INTELLIGENCE.
class SalesDesign {
  SalesDesign._();

  /// Rayon de la carte/panel principal.
  static const double radiusPanel = 18.0;

  /// Rayon des éléments internes (lignes, rangements).
  static const double radiusInner = 12.0;

  /// Épaisseur de la bordure.
  static const double borderWidth = 1.0;

  static const double spacingXS = 8.0;
  static const double spacingSM = 12.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 20.0;

  /// Hauteurs maîtrisées des graphiques.
  static const double chartHourlyHeight = 168.0;
  static const double chartHourlyHeightDetail = 172.0;

  static const int kpiGridDesktopColumns = 4;
  static const int kpiGridTabletColumns = 2;

  /// surfaces sombres translucides, indépendantes du thème global.
  static const Color panelFill = Color(0x8C3A424A);
  static const Color panelFillStrong = Color(0xE63A424A);

  /// Texte principal clair sur fond sombre.
  static const Color onDark = AppColors.champagneLight;
  static const Color onDarkMuted = Color(0xBFE8D5B5);
  static const Color onDarkSoft = Color(0x8FE8D5B5);

  /// Éclaircit une couleur sémantique pour la rendre lisible sur sombre.
  static Color readable(Color color, [double amount = 0.42]) =>
      Color.lerp(color, AppColors.porcelain, amount) ?? color;
}

/// Panel standard : surface sombre translucide + liseré champagne.
class SalesPanel extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;
  final Widget child;

  const SalesPanel({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.margin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: SalesDesign.panelFill,
        borderRadius: BorderRadius.circular(SalesDesign.radiusPanel),
        border: Border.all(
          color: borderColor ?? AppColors.goldBorder,
          width: SalesDesign.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle(
          style: const TextStyle(color: SalesDesign.onDark),
          child: child,
        ),
      ),
    );
    if (margin != null) return Padding(padding: margin!, child: panel);
    return panel;
  }
}

/// Tuile KPI uniforme (libellé, valeur, unité, éventuelle indication).
class SalesMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final String? hint;

  const SalesMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color = SalesDesign.onDark,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final readableColor = SalesDesign.readable(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SalesDesign.onDarkMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: readableColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: const TextStyle(
                  color: SalesDesign.onDarkMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(
              color: SalesDesign.onDarkSoft,
              fontSize: 9,
            ),
          ),
        ],
      ],
    );
  }
}

/// Avis inline uniforme (information ou avertissement).
class SalesNotice extends StatelessWidget {
  final String message;
  final bool warning;

  const SalesNotice({super.key, required this.message, this.warning = true});

  @override
  Widget build(BuildContext context) {
    final raw = warning ? AppColors.pharmaWarning : AppColors.cardBlue;
    final accent = SalesDesign.readable(raw, 0.3);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: accent, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête de section standard (titre + sous-titre).
class SalesSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextAlign? textAlign;

  const SalesSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            color: SalesDesign.onDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: const TextStyle(
              color: SalesDesign.onDarkMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

/// État vide standard (aucune donnée réelle sur la période).
class SalesEmptyState extends StatelessWidget {
  final String message;

  const SalesEmptyState({super.key, this.message = 'Aucune donnée'});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SalesDesign.panelFill,
        borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
        border: Border.all(
            color: AppColors.goldBorder, width: SalesDesign.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SalesDesign.onDarkMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
