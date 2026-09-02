import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/features/pos/pos_models.dart';
import 'package:pharma_maroc_gold/core/models/medication.dart';

Medication med({
  String id = 'm1',
  double priceSale = 100,
  double tvaRate = 20,
}) =>
    Medication(id: id, name: 'Médicament $id', priceSale: priceSale, tvaRate: tvaRate);

void main() {
  group('CartLine', () {
    test('calcul simple (TVA 20%)', () {
      final line = CartLine(medication: med(priceSale: 100), quantity: 2);
      expect(line.gross, 200);
      expect(line.net, 200);
      expect(line.tvaAmount, 40);
      expect(line.total, 240);
    });

    test('remise en pourcentage', () {
      final line = CartLine(
        medication: med(priceSale: 100),
        quantity: 3,
        discountPercent: 10,
      );
      expect(line.gross, 300);
      expect(line.discountAmount, 30);
      expect(line.net, 270);
      expect(line.total, 324);
    });

    test('remise de 100% -> net nul', () {
      final line = CartLine(medication: med(priceSale: 100), discountPercent: 100);
      expect(line.net, 0);
      expect(line.total, 0);
    });

    test('arrondis flottants maîtrisés', () {
      final line = CartLine(
        medication: med(priceSale: 99.99),
        quantity: 3,
        discountPercent: 33.33,
      );
      expect((line.total * 100).round(), (line.total * 100).round());
    });

    test('payload en snake_case conforme API', () {
      final line = CartLine(medication: med(priceSale: 50), quantity: 2, unitPrice: 45);
      expect(line.toPayload(), {
        'medication_id': 'm1',
        'quantity': 2,
        'unit_price': 45,
        'discount': 0,
      });
    });
  });

  group('Cart', () {
    test('sous-total et TVA agrégés', () {
      final cart = Cart(lines: [
        CartLine(medication: med(priceSale: 100), quantity: 1),
        CartLine(medication: med(id: 'm2', priceSale: 50, tvaRate: 10), quantity: 2),
      ]);
      expect(cart.subtotal, 200);
      expect(cart.tvaTotal, 30); // 20 + 2*5
      expect(cart.total, 230);
    });

    test('remise globale appliquée après TVA', () {
      final cart = Cart(
        lines: [CartLine(medication: med(priceSale: 100), quantity: 2)],
        globalDiscountPercent: 10,
      );
      expect(cart.subtotal, 200);
      expect(cart.tvaTotal, 40);
      expect(cart.globalDiscount, 20);
      expect(cart.total, 220);
    });

    test('add fusionne les lignes du même médicament', () {
      final cart = Cart();
      cart.add(med(), quantity: 2);
      cart.add(med(), quantity: 3);
      expect(cart.itemCount, 5);
      expect(cart.lines.length, 1);
    });

    test('removeLine et clear', () {
      final cart = Cart(lines: [
        CartLine(medication: med(priceSale: 10), quantity: 1),
        CartLine(medication: med(id: 'm2', priceSale: 20), quantity: 1),
      ]);
      cart.removeLine('m2');
      expect(cart.lines.length, 1);
      cart.clear();
      expect(cart.isEmpty, true);
      expect(cart.total, 0);
    });

    test('itemCount compte les unités', () {
      final cart = Cart(lines: [
        CartLine(medication: med(priceSale: 10), quantity: 2),
        CartLine(medication: med(id: 'm2', priceSale: 20), quantity: 1),
      ]);
      expect(cart.itemCount, 3);
    });
  });
}
