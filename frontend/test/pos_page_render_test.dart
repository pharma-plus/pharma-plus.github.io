import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/pos/pos_page.dart';
import 'package:pharma_maroc_gold/features/shell/shell_nav.dart';

void main() {
  testWidgets('[POS FORENSIQUE] Dashboard -> Point de vente contenu visible + HOME -> Dashboard', (tester) async {
    // Arrange : HomeShell-like avec IndexedStack + PosPage push
    ShellNav.index.value = 0;
    final auth = AuthStore.instance;
    // On ne peut pas init AuthStore complet ici, on mock le provider
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: ShellNav.index,
              builder: (context, idx, _) => IndexedStack(index: idx, children: const [
                Scaffold(body: Text('DASHBOARD')),
                Scaffold(body: Text('MODULES')),
                PosPage(),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Act : aller au POS comme le fait Vente du jour (index 2) ou _push
    // Cas 1 : via IndexedStack
    ShellNav.index.value = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Assert : POS doit afficher recherche + categories + grille (pas uniquement AppBar)
    // Si PosCategoriesGrid était SliverGrid dans SizedBox, le pump lèverait FlutterError
    final exceptions = tester.takeException();
    expect(exceptions, isNull, reason: '[POS DEBUG] exception pendant build PosPage: $exceptions');

    expect(find.text('Point de vente'), findsOneWidget, reason: 'AppBar titre manquant');
    expect(find.byIcon(Icons.home_rounded), findsOneWidget, reason: 'Icône HOME manquante');
    // Contenu principal : champ recherche + categories
    expect(find.byType(TextField), findsOneWidget, reason: 'Champ recherche POS manquant -> page vide');
    expect(find.text('Antalgiques'), findsWidgets, reason: 'Grille catégories POS manquante');

    // Act : clic HOME doit revenir Dashboard
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ShellNav.index.value, 0, reason: 'HOME doit forcer index 0 (Dashboard)');

    // Cas 2 : POS poussé via Navigator.push (Vente du jour Card 3D)
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: Builder(builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosPage())),
              child: const Text('GO POS'),
            ),
          )),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('GO POS'));
    await tester.pumpAndSettle();
    expect(find.text('Point de vente'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Point de vente'), findsNothing, reason: 'HOME doit dépiler PosPage poussée');
  });
}
