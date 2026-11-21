// ============================================================
// TEST — Invalidation du cache Sales Intelligence après vente
// ============================================================
// Vérifie que l'instance active est correctement enregistrée, que
// l'invalidation du cache est ciblée, et que le dispose d'un shell
// non-actif n'efface pas la référence d'un autre shell encore monté.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/features/sales_day/controllers/sales_day_controller.dart';
import 'package:pharma_maroc_gold/features/sales_day/models/sales_day_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SalesDayController — instance active et cache', () {
    test('invalidateAllCaches vide le jeu complet sur l instance active', () {
      final active = SalesDayController();

      SalesDayController.setActiveInstance(active);

      // Simule un jeu complet chargé.
      active.fullRows = const [
        SalesTransaction(
          id: 't1',
          number: 'V-1',
          createdAt: null,
          status: 'completed',
          saleType: 'pos',
          subtotal: 100,
          discountTotal: 0,
          taxTotal: 0,
          total: 100,
          paidAmount: 100,
          changeAmount: 0,
          paymentMethod: 'cash',
          customer: null,
          itemsCount: 1,
          userId: 'u1',
          userName: 'Test',
        )
      ];
      expect(active.fullRows.isNotEmpty, isTrue);

      SalesDayController.invalidateAllCaches();

      expect(active.fullRows, isEmpty);
      expect(active.fullComplete, isFalse);
      expect(active.fullError, isNull);

      active.dispose();
      SalesDayController.clearActiveInstance(active);
    });

    test('invalidateAllCaches notifie les widgets abonnés (rebuild)', () {
      final active = SalesDayController();
      SalesDayController.setActiveInstance(active);

      var notifications = 0;
      active.addListener(() => notifications++);

      SalesDayController.invalidateAllCaches();

      expect(notifications, 1,
          reason: 'le cache vidé doit déclencher un rebuild de l UI');

      active.dispose();
      SalesDayController.clearActiveInstance(active);
    });

    test('dispose d un controller non actif n efface pas l instance active', () {
      final active = SalesDayController();
      final other = SalesDayController();

      SalesDayController.setActiveInstance(active);

      // Le shell « other » se dispose : ne doit pas toucher à « active ».
      other.dispose();
      SalesDayController.clearActiveInstance(other);

      // L'invalidation doit toujours cibler « active ».
      active.fullRows = const [
        SalesTransaction(
          id: 't2',
          number: 'V-2',
          createdAt: null,
          status: 'completed',
          saleType: 'pos',
          subtotal: 50,
          discountTotal: 0,
          taxTotal: 0,
          total: 50,
          paidAmount: 50,
          changeAmount: 0,
          paymentMethod: 'cash',
          customer: null,
          itemsCount: 1,
          userId: 'u1',
          userName: 'Test',
        )
      ];
      SalesDayController.invalidateAllCaches();
      expect(active.fullRows, isEmpty,
          reason: 'instance active préservée après dispose non-actif');

      active.dispose();
      SalesDayController.clearActiveInstance(active);
    });
  });
}
