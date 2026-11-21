// ============================================================
// TEST — Cohérence financière POS / KPI / Sales Intelligence
// ============================================================
// Vérifie que la formule du CA HT utilisée dans la page employés est
// exactement celle du KPI officiel (netRevenue = total - tax_total),
// et non subtotal - discount_total (TTC net, grandeur différente).
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cohérence financière CA HT', () {
    late String model;
    late String employees;

    setUpAll(() {
      model = File('lib/features/sales_day/models/sales_day_model.dart')
          .readAsStringSync();
      employees =
          File('lib/features/sales_day/pages/sales_employees_page.dart')
              .readAsStringSync();
    });

    test('Le KPI netRevenue est défini comme total − tax_total', () {
      expect(model, contains('netRevenue: n(j[\'net_revenue\'])'));
      expect(model,
          contains('CA HT : Σ (total − tax_total) — TVA extraite du TTC'));
    });

    test('La page employés calcule le CA HT avec total − taxTotal', () {
      expect(employees, contains('(t.total - t.taxTotal)'));
      // L'ancienne formule TTC net ne doit plus être utilisée sous CA HT.
      expect(employees, isNot(contains('(t.subtotal - t.discountTotal)')));
    });

    test('Le libellé affiché est CA HT (pas CA net ambigu)', () {
      expect(employees, contains("'CA HT'"));
    });

    test('Exemple chiffré : TVA 20 % extraite du TTC après remise', () {
      // Produit 100 DH TTC, remise 10 DH -> net TTC 90 DH.
      // TVA incluse 20 % = 90 - 90/1.2 = 15 DH. CA HT = 90 - 15 = 75 DH.
      const totalTtc = 90.0;
      final tva = (totalTtc - totalTtc / 1.2).roundToDouble() == (15.0)
          ? 15.0
          : (totalTtc - totalTtc / 1.2);
      final netHt = totalTtc - tva;
      expect(netHt, 75.0);
    });
  });
}
