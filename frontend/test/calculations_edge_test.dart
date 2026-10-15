import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/core/utils/calculations.dart';

/// Cas limites des formules centralisées + cohérence avec le calcul serveur
/// (Edge POST /sales : total = Σ net + TVA, TVA lue sur la fiche produit,
/// remise appliquée AVANT TVA sur la base HT).
void main() {
  group('calculateSaleTotalExcl — cas limites', () {
    test('panier vide : total 0, pas de NaN', () {
      final t = calculateSaleTotalExcl(const []);
      expect(t.subtotal, 0);
      expect(t.discount, 0);
      expect(t.tva, 0);
      expect(t.total, 0);
      expect(t.total.isNaN, isFalse);
    });

    test('ligne prix nul avec TVA 20 % : pas de division par zéro', () {
      final t = calculateSaleTotalExcl(const [
        SaleLine(unitPrice: 0, quantity: 3, tvaRate: 0.20),
      ]);
      expect(t.total.isNaN, isFalse);
      expect(t.total, 0);
      expect(t.tva, 0);
    });

    test('remise fixe supérieure au sous-total : plafonnée au sous-total', () {
      final t = calculateSaleTotalExcl(
        const [SaleLine(unitPrice: 10, quantity: 2, tvaRate: 0.20)],
        discountValue: 999,
      );
      expect(t.discount, 20);
      expect(t.total, 0);
    });

    test('remise 100 % : TVA et total nuls', () {
      final t = calculateSaleTotalExcl(
        const [SaleLine(unitPrice: 50, quantity: 1, tvaRate: 0.10)],
        discountValue: 100,
        discountIsPercent: true,
      );
      expect(t.total, 0);
      expect(t.tva, 0);
    });

    test('quantité nulle : ligne ignorée sans NaN', () {
      final t = calculateSaleTotalExcl(const [
        SaleLine(unitPrice: 35, quantity: 0, tvaRate: 0.20),
        SaleLine(unitPrice: 10, quantity: 1, tvaRate: 0),
      ]);
      expect(t.total.isNaN, isFalse);
      expect(t.total, 10);
    });

    test('cohérence Edge : médicament TVA 0 → total = Σ prix×qté', () {
      // Edge lit tva_rate=0 sur la fiche produit et calcule
      // subtotal + taxTotal(=0) − globalDiscount.
      final t = calculateSaleTotalExcl(const [
        SaleLine(unitPrice: 35, quantity: 2, tvaRate: 0),
        SaleLine(unitPrice: 4.2, quantity: 1, tvaRate: 0),
      ]);
      expect(t.subtotal, closeTo(74.2, 1e-9));
      expect(t.tva, 0);
      expect(t.total, closeTo(74.2, 1e-9));
    });

    test('cohérence Edge : TVA 20 % s\'ajoute à la base HT après remise', () {
      // Edge : remise 10 % sur 100 HT → net 90 → TVA 18 → total 108.
      final t = calculateSaleTotalExcl(
        const [SaleLine(unitPrice: 100, quantity: 1, tvaRate: 0.20)],
        discountValue: 10,
        discountIsPercent: true,
      );
      expect(t.subtotal, 100);
      expect(t.discount, 10);
      expect(t.tva, closeTo(18, 1e-9));
      expect(t.total, closeTo(108, 1e-9));
    });
  });

  group('calculateSaleTotal (TVA incluse) — cas limites', () {
    test('panier vide : tva 0 (garde net<=0)', () {
      final t = calculateSaleTotal(const []);
      expect(t.tva, 0);
      expect(t.total, 0);
    });

    test('remise totale : tva recalculée à 0', () {
      final t = calculateSaleTotal(
        const [SaleLine(unitPrice: 100, quantity: 1, tvaRate: 0.20)],
        discountValue: 100,
        discountIsPercent: true,
      );
      expect(t.total, 0);
      expect(t.tva, 0);
    });
  });

  group('paiement espèces', () {
    test('monnaie rendue arrondie au centime', () {
      // 0.1 + 0.2 = 0.30000000000000004 en flottant.
      expect(calculateChange(received: 0.3, total: 0.1), closeTo(0.2, 1e-12));
      expect(((calculateChange(received: 0.3, total: 0.1) * 100).round()), 20);
    });

    test('reçu inférieur : monnaie 0 et reste dû', () {
      expect(calculateChange(received: 90, total: 100), 0);
      expect(remainingDue(received: 90, total: 100), 10);
      expect(isPaymentSufficient(received: 90, total: 100), isFalse);
    });

    test('tolérance : résidu flottant accepté, centime réel refusé', () {
      // isPaymentSufficient = reçu + 0.009 >= total : absorbe les résidus
      // flottants (99.999999), pas une pénurie réelle d'un centime
      // (99.99 + 0.009 = 99.999 < 100).
      expect(isPaymentSufficient(received: 99.999999, total: 100), isTrue);
      expect(isPaymentSufficient(received: 100, total: 100), isTrue);
      expect(isPaymentSufficient(received: 99.99, total: 100), isFalse);
      expect(isPaymentSufficient(received: 99.97, total: 100), isFalse);
    });
  });
}
