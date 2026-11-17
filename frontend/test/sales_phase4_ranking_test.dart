// Test contrôlé : une ligne de classement sans fiche produit cible
// ne doit pas se présenter comme cliquable (InkWell supprimé).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/widgets/sales_product_ranking.dart';

void main() {
  final product = SalesProductRank.fromJson({
    'medication_id': 'm1',
    'name': 'DOLIPRANE',
    'dosage': '1000 mg',
    'quantity': 5.0,
    'revenue': 500.0,
    'profit': 200.0,
    'marginPct': 40.0,
    'sales': 3,
    'sortBy': 'rev',
  });

  testWidgets('sans callback : présentation non interactive', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesProductRanking(
          title: 'Top 10 par CA',
          products: [product],
          sortBy: 'rev',
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(InkWell), findsNothing,
        reason: 'aucune affordance d’action sans fiche produit');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('DOLIPRANE'), findsOneWidget);
  });

  testWidgets('avec callback : action réellement disponible', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesProductRanking(
          title: 'Top 10 par CA',
          products: [product],
          sortBy: 'rev',
          onProductTap: (_) => taps++,
        ),
      ),
    ));
    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
