import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/features/shell/shell_nav.dart';

/// Vérifie qu'un clic sur l'icône HOME (ShellBackButton) ramène toujours au
/// Tableau de bord, quel que soit l'état de la pile de navigation :
///  · POS affiché comme onglet du shell (aucune route poussée) ;
///  · POS ouvert comme route poussée au-dessus du shell (menu/gallery).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ShellNav.index.value = 0;
  });

  Widget harness() {
    return MaterialApp(
      home: Navigator(
        pages: const [
          MaterialPage<void>(
            child: _ShellHost(),
            key: ValueKey('host'),
          ),
        ],
        onDidRemovePage: (page) {},
      ),
    );
  }

  // Optionnellement pousse une route "POS" au-dessus du shell.
  Future<void> pushPos(WidgetTester tester) async {
    final navContext = tester.element(find.byType(_ShellHost));
    Navigator.of(navContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const _PosLike(),
        settings: const RouteSettings(name: 'pos-like'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'POS en onglet du shell : clic home -> retour au dashboard (index 0)',
      (tester) async {
    await tester.pumpWidget(harness());

    // On simule la sélection de l'onglet Point de vente.
    ShellNav.index.value = 2;
    await tester.pumpAndSettle();
    expect(find.text('PAGE POS (onglet)'), findsOneWidget);

    // Clic sur l'icône maison.
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(ShellNav.index.value, 0);
    expect(find.text('PAGE DASHBOARD (index 0)'), findsOneWidget);
  });

  testWidgets(
      'POS en route poussée au-dessus du shell : clic home -> dashboard',
      (tester) async {
    await tester.pumpWidget(harness());

    // Shell sur un autre onglet (Modules = index 1) puis POS poussé.
    ShellNav.index.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('PAGE MODULES (index 1)'), findsOneWidget);

    await pushPos(tester);
    expect(find.text('PAGE POS (posée)'), findsOneWidget);

    // Clic sur l'icône maison : doit fermer la route POS ET revenir au dashboard.
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(find.text('PAGE POS (posée)'), findsNothing);
    expect(ShellNav.index.value, 0);
    expect(find.text('PAGE DASHBOARD (index 0)'), findsOneWidget);
  });

  testWidgets('Route POS déjà fermée : clic home -> dashboard sans crash',
      (tester) async {
    await tester.pumpWidget(harness());

    await pushPos(tester);
    // L'utilisateur est sur la route POS et clique directement la maison.
    ShellNav.index.value = 2;
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(ShellNav.index.value, 0);
    expect(find.text('PAGE DASHBOARD (index 0)'), findsOneWidget);
  });
}

class _ShellHost extends StatelessWidget {
  const _ShellHost();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShellNav.index,
      builder: (context, index, _) {
        return Scaffold(
          appBar: AppBar(
            leading: const ShellBackButton(),
            title: Text('SHELL (index $index)'),
          ),
          body: Center(
            child: index == 0
                ? const Text('PAGE DASHBOARD (index 0)')
                : index == 1
                    ? const Text('PAGE MODULES (index 1)')
                    : const Text('PAGE POS (onglet)'),
          ),
        );
      },
    );
  }
}

/// Route posée (POS complet accessible par le menu modules / dashboard).
class _PosLike extends StatelessWidget {
  const _PosLike();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Point de vente'),
      ),
      body: const Center(child: Text('PAGE POS (posée)')),
    );
  }
}