/// ============================================================
/// VENTES DU JOUR — Service d'analyse (périodes, bornes, deltas)
/// ============================================================
/// Sémantique des bornes : [inclus, exclus) sur created_at.
/// Les bornes sont construites en heure LOCALE de l'appareil (fus =
/// Africa/Casablanca sur les postes marocains) puis exportées en ISO
/// AVEC décalage — le serveur compare en absolu, sans ambiguïté UTC.
/// Aucun report de donnée : la journée « Aujourd'hui » = 00:00 → demain
/// 00:00 locale, exactement la journ commerciale.
/// ============================================================

import 'package:flutter/material.dart';

enum SalesPeriod { today, yesterday, thisWeek, thisMonth, custom }

extension SalesPeriodX on SalesPeriod {
  String get label {
    switch (this) {
      case SalesPeriod.today:
        return "Aujourd'hui";
      case SalesPeriod.yesterday:
        return 'Hier';
      case SalesPeriod.thisWeek:
        return 'Cette semaine';
      case SalesPeriod.thisMonth:
        return 'Ce mois';
      case SalesPeriod.custom:
        return 'Personnalisé';
    }
  }

  bool get isSingleDay =>
      this == SalesPeriod.today || this == SalesPeriod.yesterday;
}

/// Comparaison vs période précédente (même durée) — Optionalité stricte.
class SalesDelta {
  final double current;
  final double? previous;

  const SalesDelta({required this.current, this.previous});

  /// Variation en % — null si incomparable (période précédente inconnue ou 0).
  double? get pct {
    final p = previous;
    if (p == null) return null;
    if (p <= 0) return null;
    return ((current - p) / p) * 100;
  }
}

class SalesDateRange {
  final DateTime start; // inclus, heure locale
  final DateTime end;   // exclus, heure locale
  const SalesDateRange(this.start, this.end);

  bool get isSingleDay => end.difference(start).inDays == 1;
}

/// Borne ISO locale : inclut le décalage horaire de l'appareil, panier de
/// la sémantique réelle (aucune conversion UTC silencieuse).
String isoLocal(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final off = d.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}'
      '$sign${two(off.inHours)}:${two(off.inMinutes.remainder(60))}';
}

class SalesAnalyticsService {
  const SalesAnalyticsService._();

  /// Bornes de la période [index]/[SalesPeriod] en heure locale.
  static SalesDateRange rangeFor(
    SalesPeriod period, {
    DateTimeRange? custom,
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now());
    final today = DateTime(reference.year, reference.month, reference.day);
    switch (period) {
      case SalesPeriod.today:
        return SalesDateRange(today, today.add(const Duration(days: 1)));
      case SalesPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return SalesDateRange(y, today);
      case SalesPeriod.thisWeek:
        // Semaine du lundi au lundi suivant (norme ISO).
        final weekday = (reference.weekday == DateTime.sunday)
            ? 7
            : reference.weekday;
        final monday = today.subtract(Duration(days: weekday - 1));
        return SalesDateRange(monday, monday.add(const Duration(days: 7)));
      case SalesPeriod.thisMonth:
        final first = DateTime(reference.year, reference.month, 1);
        return SalesDateRange(first, DateTime(reference.year, reference.month + 1, 1));
      case SalesPeriod.custom:
        final c = custom;
        if (c != null) {
          final s = DateTime(c.start.year, c.start.month, c.start.day);
          final e =
              DateTime(c.end.year, c.end.month, c.end.day).add(const Duration(days: 1));
          return SalesDateRange(s, e);
        }
        return SalesDateRange(today, today.add(const Duration(days: 1)));
    }
  }

  /// Étiquette humaine de la période.
  static String periodLabel(SalesPeriod period, SalesDateRange range) {
    String two(int v) => v.toString().padLeft(2, '0');
    String d(DateTime dt) =>
        '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    final endIncl = range.end.subtract(const Duration(days: 1));
    if (range.isSingleDay) return d(range.start);
    return '${d(range.start)} → ${d(endIncl)}';
  }

  /// Période précédente de même durée (comparaison honnête des KPI).
  static SalesDateRange previousOf(SalesDateRange r) =>
      SalesDateRange(r.start.subtract(r.end.difference(r.start)), r.start);

  /// Delta % entre les KPI courants et la période précédente (si connue).
  static SalesDelta delta(double current, double? previous) =>
      SalesDelta(current: current, previous: previous);

  /// Heure affichée de la transaction (HH:mm dans la locale de l'appara).
  static String hourMinute(DateTime? ts) {
    if (ts == null) return '--:--';
    String two(int v) => v.toString().padLeft(2, '0');
    final d = ts.toLocal();
    return '${two(d.hour)}:${two(d.minute)}';
  }
}
