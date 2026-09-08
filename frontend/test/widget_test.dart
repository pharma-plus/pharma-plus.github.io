import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/app.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/utils/calculations.dart';
import 'package:pharma_maroc_gold/core/widgets/pharma_logo.dart';
import 'package:pharma_maroc_gold/main.dart';

void main() {
  testWidgets('PHARMA+ app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AuthStore.instance,
        child: const PharmaGoldApp(),
      ),
    );

        expect(find.byType(MaterialApp), findsOneWidget);
    // Le splash affiche le logo officiel PHARMA+ (asset image, fond transparent),
    // pas de texte brut. On vérifie la présence du widget logo au lieu de texte.
    expect(find.byType(PharmaFullLogo), findsWidgets);

    // Le Splash s'affiche immédiatement au démarrage (RootGate) : il est
    // la première chose visible tant que l'authentification n'est pas
    // initialisée — conforme au cycle de démarrage demandé.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RootGate), findsOneWidget);
  });

  testWidgets('calculations.dart : discount et totaux centralisés',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

        // Remise en % : 10 % sur 200 (TTC 240 avec 20% TVA) → remise 24, total 216.
    final pct = calculateSaleTotalExcl(
      [SaleLine(unitPrice: 200, quantity: 1, tvaRate: 0.20)],
      discountValue: 10,
      discountIsPercent: true,
    );
    expect(pct.subtotal, equals(200.0));
    expect(pct.tva, equals(40.0));
    expect(pct.discount, equals(24.0));
    expect(pct.total, equals(216.0));

    // Remise plafonnée au sous-total (jamais négatif / jamais supérieur).
    final capped = calculateSaleTotalExcl(
      [SaleLine(unitPrice: 50, quantity: 2, tvaRate: 0)],
      discountValue: 999,
      discountIsPercent: false,
    );
    expect(capped.total, equals(0.0));

    // Bénéfice = ventes − coûts d'achat.
    final profit = calculateProfit(revenue: 1000, cost: 650.5);
    expect(profit, equals(349.5));
  });

  testWidgets('calculations.dart : low stock et agrégats',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    final low = calculateLowStock([
      (stock: 4, reorderLevel: 5, minStock: 2),
      (stock: 8, reorderLevel: 5, minStock: 2),
      (stock: 2, reorderLevel: 5, minStock: 2),
    ]);
    expect(low, equals(2));

    final suppliers = calculateSupplierTotals([
      (supplierId: 'a', orderTotal: 100),
      (supplierId: 'b', orderTotal: 50),
      (supplierId: 'a', orderTotal: 25),
    ]);
    expect(suppliers.length, equals(2));
    expect(suppliers[0].value.orders, equals(2));
    expect(suppliers[0].value.total, equals(125.0));
  });
}
