// ============================================================
// TEST — Format du clientSaleId (idempotence hors-ligne)
// ============================================================
// Le clientSaleId doit rester une chaîne unique complete (millis + aléa).
// .hashCode réduirait à un entier 32-bit signé (négatifs + collisions),
// ce qui ferait refuser la seconde vente par l'idempotence serveur.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clientSaleId — format unique', () {
    late String posPage;
    late String posPanel;

    setUpAll(() {
      posPage = File('lib/features/pos/pos_page.dart').readAsStringSync();
      posPanel =
          File('lib/features/dashboard/pos_panel.dart').readAsStringSync();
    });

    for (final entry in [
      {'name': 'POS complet', 'source': 'posPage'},
      {'name': 'Mini-POS dashboard', 'source': 'posPanel'},
    ]) {
      test('${entry['name']} : clientSaleId sans .hashCode', () {
        final src = entry['source'] == 'posPage' ? posPage : posPanel;
        // Extrait la déclaration de clientSaleId.
        final idx = src.indexOf('final clientSaleId =');
        expect(idx, isNot(-1));
        final snippet = src.substring(idx, idx + 220);
        expect(snippet, contains('millisecondsSinceEpoch'));
        expect(snippet, isNot(contains('.hashCode')));
      });
    }
  });
}
