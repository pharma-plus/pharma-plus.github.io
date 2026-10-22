import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/features/stock/stock_logic.dart';

void main() {
  final ref = DateTime(2026, 10, 22);

  group('computeStockStatus', () {
    test('périmé : date de péremption passée ou le jour même', () {
      expect(
        computeStockStatus(
            available: 50,
            reorderLevel: 10,
            expiry: DateTime(2026, 10, 21),
            now: ref),
        StockStatus.expired,
      );
      expect(
        computeStockStatus(
            available: 50,
            reorderLevel: 10,
            expiry: DateTime(2026, 10, 22),
            now: ref),
        StockStatus.expired,
      );
    });

    test('expire bientôt : dans la fenêtre 90 jours', () {
      expect(
        computeStockStatus(
            available: 50,
            reorderLevel: 10,
            expiry: DateTime(2026, 11, 1),
            now: ref),
        StockStatus.expiring,
      );
      expect(
        computeStockStatus(
            available: 50,
            reorderLevel: 10,
            expiry: DateTime(2026, 10, 22).add(const Duration(days: 90)),
            now: ref),
        StockStatus.expiring,
      );
    });

    test('hors fenêtre : pas de statut de péremption', () {
      expect(
        computeStockStatus(
            available: 50,
            reorderLevel: 10,
            expiry: DateTime(2027, 6, 30),
            now: ref),
        StockStatus.ok,
      );
    });

    test('sans date de lot : aucun statut de péremption inventé', () {
      expect(
        computeStockStatus(available: 50, reorderLevel: 10, now: ref),
        StockStatus.ok,
      );
      expect(
        computeStockStatus(available: 0, reorderLevel: 10, now: ref),
        StockStatus.rupture,
      );
    });

    test('rupture : disponible <= 0', () {
      expect(
        computeStockStatus(available: 0, reorderLevel: 0, now: ref),
        StockStatus.rupture,
      );
      expect(
        computeStockStatus(available: -2, reorderLevel: 0, now: ref),
        StockStatus.rupture,
      );
    });

    test('sous seuil : disponible <= reorder_level > 0', () {
      expect(
        computeStockStatus(available: 5, reorderLevel: 10, now: ref),
        StockStatus.low,
      );
      expect(
        computeStockStatus(available: 10, reorderLevel: 10, now: ref),
        StockStatus.low,
      );
      // reorder_level absent (0) : pas de seuil défini → OK.
      expect(
        computeStockStatus(available: 5, reorderLevel: 0, now: ref),
        StockStatus.ok,
      );
    });

    test('priorité : périmé l’emporte sur rupture et seuil', () {
      expect(
        computeStockStatus(
            available: 0,
            reorderLevel: 10,
            expiry: DateTime(2025, 1, 1),
            now: ref),
        StockStatus.expired,
      );
    });
  });

  group('normalizeStockFilter / filterStockRows', () {
    StockStatus statusOf(int v) => v > 10
        ? StockStatus.ok
        : v > 0
            ? StockStatus.low
            : StockStatus.rupture;

    test('clés historiques et nouvelles normalisées', () {
      expect(normalizeStockFilter(null), 'all');
      expect(normalizeStockFilter(''), 'all');
      expect(normalizeStockFilter('low'), 'low');
      expect(normalizeStockFilter('expiring'), 'expiring');
      expect(normalizeStockFilter('expired'), 'expired');
      expect(normalizeStockFilter('rupture'), 'rupture');
      expect(normalizeStockFilter('out'), 'rupture');
      expect(normalizeStockFilter('zzz'), 'all');
    });

    test('filtrage par statut', () {
      final rows = [20, 5, 0, 12];
      expect(filterStockRows(rows, 'all', statusOf), [20, 5, 0, 12]);
      expect(filterStockRows(rows, 'rupture', statusOf), [0]);
      expect(filterStockRows(rows, 'low', statusOf), [5]);
      expect(filterStockRows(rows, 'expiring', statusOf), isEmpty);
    });
  });

  group('stockRowMatchesQuery', () {
    final row = {
      'medication_name': 'Doliprane',
      'med_detail': '1000 mg · Comprimé · Sanofi',
      'lot_number': 'LOT-A1',
      'barcode_ean13': '3400930123456',
    };

    test('recherche nom, détail, lot, code-barres, vide = tout', () {
      expect(stockRowMatchesQuery(row, ''), isTrue);
      expect(stockRowMatchesQuery(row, 'doli'), isTrue);
      expect(stockRowMatchesQuery(row, '1000'), isTrue);
      expect(stockRowMatchesQuery(row, 'lot-a'), isTrue);
      expect(stockRowMatchesQuery(row, '340093'), isTrue);
      expect(stockRowMatchesQuery(row, 'augmentin'), isFalse);
    });
  });

  group('movementTypeLabel', () {
    test('les 12 types de la CHECK ont un libellé FR', () {
      const types = [
        'purchase_receipt',
        'sale',
        'sale_return',
        'inventory_in',
        'inventory_out',
        'adjustment',
        'transfer_in',
        'transfer_out',
        'reservation',
        'release',
        'expiry_loss',
        'write_off',
      ];
      for (final t in types) {
        final label = movementTypeLabel(t);
        expect(label, isNotEmpty);
        expect(label, isNot(equals(t)));
      }
      // Type inconnu : retourne tel quel (aucune invention).
      expect(movementTypeLabel('custom_type'), 'custom_type');
    });
  });
}
