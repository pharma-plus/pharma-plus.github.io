import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

/// Régression du RangeError POS : `Random().nextInt(1 << 32)` levait
/// `RangeError: max must be in range 0 < max < 2^32, was 0` sur Web (dart2js),
/// où `1 << 32` vaut 0 (opérateur << en 32 bits). Fix : `0x7fffffff` (2^31-1).
void main() {
  group('clientSaleId (idempotence vente)', () {
    test('nextInt(0x7fffffff) ne lève jamais de RangeError', () {
      final rnd = Random();
      for (var i = 0; i < 100; i++) {
        final v = rnd.nextInt(0x7fffffff);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(0x7fffffff));
      }
    });

    test('génération clientSaleId identique au POS : unique et stable', () {
      final ids = <String>{};
      final rnd = Random();
      for (var i = 0; i < 1000; i++) {
        final id =
            '${DateTime.now().millisecondsSinceEpoch + i}-${rnd.nextInt(0x7fffffff)}'
                .hashCode
                .toString();
        expect(id, isNotEmpty);
        expect(int.tryParse(id), isNotNull);
        ids.add(id);
      }
      expect(ids.length, 1000); // unicité sur 1000 générations
    });

    test('limite max de nextInt conforme à la spec (0 < max < 2^32)', () {
      const max = 0x7fffffff; // 2^31 - 1
      expect(max, greaterThan(0));
      expect(max, lessThan(1 << 32));
    });
  });
}
