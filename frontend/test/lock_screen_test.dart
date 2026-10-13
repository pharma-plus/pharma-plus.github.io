import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/security/lock_screen.dart';

/// Régression : le verrouillage d'inactivité doit poser un état LOCAL
/// (`isLocked`) indépendant du réseau, et l'écran PIN doit s'afficher en
/// mode non annulable pour un verrouillage automatique.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Remet le singleton à plat entre tests.
    AuthStore.instance.unlock();
  });

  group('AuthStore.lockSession / unlock', () {
    test('verrouillage automatique : isLocked=true, isManualLock=false', () async {
      await AuthStore.instance.lockSession();
      expect(AuthStore.instance.isLocked, isTrue);
      expect(AuthStore.instance.isManualLock, isFalse);
      AuthStore.instance.unlock();
    });

    test('verrouillage manuel : isManualLock=true', () async {
      await AuthStore.instance.lockSession(manual: true);
      expect(AuthStore.instance.isLocked, isTrue);
      expect(AuthStore.instance.isManualLock, isTrue);
      AuthStore.instance.unlock();
    });

    test('unlock remet isLocked et isManualLock à false', () async {
      await AuthStore.instance.lockSession(manual: true);
      AuthStore.instance.unlock();
      expect(AuthStore.instance.isLocked, isFalse);
      expect(AuthStore.instance.isManualLock, isFalse);
    });

    test('lockSession idempotent : un second appel ne repasse pas en auto',
        () async {
      await AuthStore.instance.lockSession(manual: true);
      await AuthStore.instance.lockSession(); // ignoré (déjà verrouillé)
      expect(AuthStore.instance.isManualLock, isTrue);
      AuthStore.instance.unlock();
    });
  });

  group('LockScreen', () {
    Future<void> pumpLock(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: const MaterialApp(home: LockScreen()),
        ),
      );
    }

    testWidgets('verrouillage auto : pas de bouton Annuler',
        (tester) async {
      await AuthStore.instance.lockSession();
      await pumpLock(tester);
      // Le bouton « Annuler » n'existe qu'en verrouillage manuel.
      expect(find.text('Annuler'), findsNothing);
      // L'écran de verrouillage reste affiché (PIN requis).
      expect(find.byType(LockScreen), findsOneWidget);
      AuthStore.instance.unlock();
    });

    testWidgets('verrouillage manuel : bouton Annuler présent',
        (tester) async {
      await AuthStore.instance.lockSession(manual: true);
      await pumpLock(tester);
      expect(find.text('Annuler'), findsOneWidget);
      AuthStore.instance.unlock();
    });
  });
}
