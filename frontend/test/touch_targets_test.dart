// ============================================================
// TEST — Cibles tactiles POS (non-régression)
// ============================================================
// Vérifie par inspection du code source que les boutons critiques du POS
// (_QtyBtn, _QuickBtn, _ToggleBtn) utilisent des cibles tactiles >= 44px
// et HitTestBehavior.opaque (compatibilité écran tactile / doigt).
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cibles tactiles POS', () {
    late String source;

    setUpAll(() {
      final file = File(
          'lib/features/pos/pos_page.dart');
      source = file.readAsStringSync();
    });

    String classBody(String className) {
      final start = source.indexOf('class $className extends StatelessWidget');
      expect(start, isNot(-1), reason: '$className doit exister');
      // Fin approxative : prochaine déclaration de classe.
      final next = source.indexOf('\nclass ', start + 1);
      final end = next == -1 ? source.length : next;
      return source.substring(start, end);
    }

    test('_QtyBtn : cible 44x44 et HitTestBehavior.opaque', () {
      final body = classBody('_QtyBtn');
      expect(body, contains('width: 44'));
      expect(body, contains('height: 44'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('_QuickBtn : minHeight 44 et HitTestBehavior.opaque', () {
      final body = classBody('_QuickBtn');
      expect(body, contains('BoxConstraints(minHeight: 44)'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('_ToggleBtn : minHeight 44 et HitTestBehavior.opaque', () {
      final body = classBody('_ToggleBtn');
      expect(body, contains('BoxConstraints(minHeight: 44)'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('Aucun onHover exclusif dans POS', () {
      expect(source.contains('onHover:'), isFalse);
    });

    test('Notification de stock : bouton fermer en cible 44x44', () {
      final notif = File('lib/core/widgets/stock_notification.dart')
          .readAsStringSync();
      // L'IconButton de fermeture ne doit plus être réduit à 28x28.
      expect(notif, contains('BoxConstraints(minWidth: 44, minHeight: 44)'));
      expect(notif, isNot(contains('minWidth: 28, minHeight: 28')));
    });
  });
}
