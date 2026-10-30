import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/auth/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    // `tester.view` met à jour la surface ET le MediaQuery : l'aperçu
    // `setSurfaceSize` laissait MediaQuery à 800x600, ce qui basculait
    // LoginPage en maquette desktop même à 320 px.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('Connexion mobile : actions mot de passe sans chevauchement',
      (tester) async {
    await pumpLogin(tester, const Size(320, 720));

    expect(tester.takeException(), isNull);
    expect(find.text('Se souvenir de moi'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);

    // Le panneau du formulaire doit occuper la largeur de la carte,
    // pas se replier sur sa largeur intrinsèque.
    final panelWidth =
        tester.getSize(find.byKey(const ValueKey('login-form-panel'))).width;
    expect(panelWidth, greaterThan(200), reason: 'Panneau mobile trop étroit');
  });

  testWidgets('Connexion tactile : panneau stable à 390 px', (tester) async {
    await pumpLogin(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('SE CONNECTER'), findsOneWidget);

    final panelWidth =
        tester.getSize(find.byKey(const ValueKey('login-form-panel'))).width;
    expect(panelWidth, greaterThan(250), reason: 'Panneau tactile trop étroit');
  });
}
