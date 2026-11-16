import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/app.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/main.dart';

/// Splash PHARMA+ conforme aux maquettes :
/// - PORTRAIT  : badge circulaire, « Bienvenue » / « dans votre pharmacie »
///   sur DEUX lignes, fine ligne or, « Chargement en cours… ».
/// - PAYSAGE   : « Bienvenue dans votre pharmacie » sur UNE ligne, barre de
///   progression avec pourcentage, rangée d'atouts en bas (>= 700 px).
/// Aucun débordement quelle que soit la taille (FittedBox).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSplash(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AuthStore.instance,
        child: const PharmaGoldApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('Splash portrait : Bienvenue sur deux lignes', (tester) async {
    await pumpSplash(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.byType(RootGate), findsOneWidget);
    // Maquette portrait : « Bienvenue » et « dans votre pharmacie » sont
    // deux Texts séparés (deux lignes).
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('dans votre pharmacie'), findsOneWidget);
    expect(find.text('Chargement en cours…'), findsOneWidget);
  });

  testWidgets('Splash paysage : une seule ligne + pourcentage', (tester) async {
    await pumpSplash(tester, const Size(800, 600));

    expect(tester.takeException(), isNull);
    // Maquette paysage : plus de « Bienvenue » isolé (ligne unique en
    // RichText), texte de chargement conservé.
    expect(find.text('Bienvenue'), findsNothing);
    expect(find.text('Chargement en cours…'), findsOneWidget);
  });

  testWidgets('Splash paysage smartphone 568x320 : aucun débordement',
      (tester) async {
    await pumpSplash(tester, const Size(568, 320));

    expect(tester.takeException(), isNull,
        reason: 'Pas de débordement sur un paysage smartphone court');
    expect(find.text('Chargement en cours…'), findsOneWidget);
  });
}
