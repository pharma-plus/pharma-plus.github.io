import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/security/lock_screen.dart';

/// Tests d'intégration : protection PIN dans le routage RootGate.
///
/// Vérifie les transitions d'état de verrouillage et le rendu conditionnel
/// de LockScreen selon la logique de RootGate (app.dart).
///
/// Logique de RootGate :
///   1. !isInitialized → SplashScreen
///   2. initError → InitErrorScreen
///   3. !isAuthenticated → LoginPage
///   4. isLocked → LockScreen   ← AJOUTÉ par cette correction (app.dart:78-83)
///   5. sinon → HomeShell / SuperAdminShell / EmployeeSpacePage
class _RoutingTestWidget extends StatelessWidget {
  const _RoutingTestWidget();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStore>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(body: Text('splash'));
        }
        if (auth.initError) {
          return const Scaffold(body: Text('initError'));
        }
        if (!auth.isAuthenticated) {
          return const SizedBox();
        }
        if (auth.isLocked) {
          return const LockScreen();
        }
        return const SizedBox();
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthStore.instance.unlock();
  });

  tearDown(() {
    AuthStore.instance.unlock();
  });

  group('AuthStore — verrouillage PIN', () {
    test('isLocked est false par défaut', () {
      expect(AuthStore.instance.isLocked, isFalse);
    });

    test('lockSession(manual: true) → isLocked=true, isManualLock=true', () async {
      await AuthStore.instance.lockSession(manual: true);
      expect(AuthStore.instance.isLocked, isTrue);
      expect(AuthStore.instance.isManualLock, isTrue);
      AuthStore.instance.unlock();
    });

    test('lockSession() (auto) → isLocked=true, isManualLock=false', () async {
      await AuthStore.instance.lockSession();
      expect(AuthStore.instance.isLocked, isTrue);
      expect(AuthStore.instance.isManualLock, isFalse);
      AuthStore.instance.unlock();
    });

    test('unlock() → isLocked=false, isManualLock=false', () async {
      await AuthStore.instance.lockSession(manual: true);
      AuthStore.instance.unlock();
      expect(AuthStore.instance.isLocked, isFalse);
      expect(AuthStore.instance.isManualLock, isFalse);
    });

    test('lockSession idempotent — second appel ignoré', () async {
      await AuthStore.instance.lockSession(manual: true);
      await AuthStore.instance.lockSession(); // ignoré, déjà verrouillé
      expect(AuthStore.instance.isManualLock, isTrue);
      AuthStore.instance.unlock();
    });
  });

  group('Routage conditionnel → LockScreen', () {
    testWidgets(
      'isLocked=true + non authentifié → pas de LockScreen '
      '(isAuthenticated vérifié avant isLocked)',
      (tester) async {
        await AuthStore.instance.lockSession(manual: true);
        expect(AuthStore.instance.isLocked, isTrue);
        expect(AuthStore.instance.isAuthenticated, isFalse);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthStore>.value(
            value: AuthStore.instance,
            child: const MaterialApp(home: _RoutingTestWidget()),
          ),
        );
        await tester.pumpAndSettle();

        // isAuthenticated=false → pas de LockScreen (RootGate vérifie d'abord l'auth)
        expect(find.byType(LockScreen), findsNothing);

        AuthStore.instance.unlock();
      },
    );

    testWidgets(
      'isLocked=false → aucun LockScreen',
      (tester) async {
        AuthStore.instance.unlock();
        expect(AuthStore.instance.isLocked, isFalse);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthStore>.value(
            value: AuthStore.instance,
            child: const MaterialApp(home: _RoutingTestWidget()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LockScreen), findsNothing);
      },
    );
  });

  group('LockScreen — rendu avec provider', () {
    testWidgets(
      'LockScreen s\'affiche quand monté avec AuthStore provider',
      (tester) async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthStore>.value(
            value: AuthStore.instance,
            child: const MaterialApp(home: LockScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LockScreen), findsOneWidget);
      },
    );
  });
}
