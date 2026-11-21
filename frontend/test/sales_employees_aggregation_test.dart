// ============================================================
// TEST — Agrégation des ventes par employé (défaut homonymes)
// ============================================================
// Deux employés portant le même nom mais des identifiants serveur
// distincts ne doivent jamais être fusionnés dans le classement.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/features/sales_day/models/sales_day_model.dart';
import 'package:pharma_maroc_gold/features/sales_day/pages/sales_employees_page.dart';

SalesTransaction _tx({
  required String id,
  String? userId,
  String? userName,
  double total = 100.0,
}) {
  return SalesTransaction(
    id: id,
    number: id,
    createdAt: DateTime.utc(2026, 11, 20, 10),
    status: 'completed',
    saleType: 'pos',
    subtotal: total,
    discountTotal: 0,
    taxTotal: 0,
    total: total,
    paidAmount: total,
    changeAmount: 0,
    paymentMethod: 'cash',
    customer: null,
    itemsCount: 1,
    userId: userId,
    userName: userName,
  );
}

void main() {
  group('groupTransactionsByEmployee', () {
    test('Deux employés homonymes avec des user_id distincts restent séparés',
        () {
      final rows = [
        _tx(id: 't1', userId: 'u-001', userName: 'Ahmed Bennani', total: 100),
        _tx(id: 't2', userId: 'u-002', userName: 'Ahmed Bennani', total: 250),
        _tx(id: 't3', userId: 'u-001', userName: 'Ahmed Bennani', total: 50),
      ];

      final grouped = groupTransactionsByEmployee(rows);

      // Deux clés distinctes (u-001 et u-002), pas une seule clé « Ahmed ».
      expect(grouped.length, 2);
      expect(grouped.containsKey('u-001'), isTrue);
      expect(grouped.containsKey('u-002'), isTrue);
      expect(grouped['u-001']!.length, 2);
      expect(grouped['u-002']!.length, 1);
    });

    test('Repli sur le nom quand user_id est absent', () {
      final rows = [
        _tx(id: 't1', userName: 'Fatima Zahra', total: 100),
        _tx(id: 't2', userName: 'Fatima Zahra', total: 100),
      ];

      final grouped = groupTransactionsByEmployee(rows);

      expect(grouped.length, 1);
      expect(grouped.containsKey('Fatima Zahra'), isTrue);
      expect(grouped['Fatima Zahra']!.length, 2);
    });

    test('Transactions sans identifiant ni nom sont regroupées en Non identifié',
        () {
      final rows = [
        _tx(id: 't1'),
        _tx(id: 't2'),
      ];

      final grouped = groupTransactionsByEmployee(rows);

      expect(grouped.length, 1);
      expect(grouped.containsKey('Non identifié'), isTrue);
      expect(grouped['Non identifié']!.length, 2);
    });

    test('user_id prioritaire sur user_name quand les deux sont présents', () {
      final rows = [
        _tx(id: 't1', userId: 'u-100', userName: 'Nom A'),
        _tx(id: 't2', userId: 'u-200', userName: 'Nom A'),
      ];

      final grouped = groupTransactionsByEmployee(rows);

      // La clé est l'identifiant, pas le nom.
      expect(grouped.keys, containsAll(['u-100', 'u-200']));
      expect(grouped.containsKey('Nom A'), isFalse);
    });

    test('Liste vide retourne une map vide', () {
      expect(groupTransactionsByEmployee(const []), isEmpty);
    });
  });
}
