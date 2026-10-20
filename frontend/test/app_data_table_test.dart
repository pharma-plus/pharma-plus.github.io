import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/core/widgets/shared/app_data_table.dart';
import 'package:pharma_maroc_gold/core/widgets/shared/app_loading_state.dart';

/// Tests du tableau partagé AppDataTable — Étape 3 (tableaux réels).
/// Couvre : rendu, tri (clé + bascule asc/desc), indicateur de tri avec
/// colonne de numérotation (régression off-by-one), pagination contrôlée,
/// sélection, états loading/empty, changement du nombre de lignes par page.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(height: 560, child: child)),
    );

List<Map<String, dynamic>> _rows(int n) => [
      for (var i = 1; i <= n; i++) {'name': 'Item $i', 'qty': i},
    ];

void main() {
  group('AppDataTable', () {
    testWidgets('affiche en-têtes et cellules', (tester) async {
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
            AppDataColumn(key: 'qty', label: 'Qty', numeric: true),
          ],
          data: _rows(3),
        ),
      ));

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // cellule numérique
    });

    testWidgets('tap en-tête : onSort reçoit la clé et bascule asc/desc',
        (tester) async {
      String? lastKey;
      bool? lastAsc;
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
            AppDataColumn(key: 'qty', label: 'Qty', numeric: true),
          ],
          data: _rows(3),
          onSort: (key, ascending) {
            lastKey = key;
            lastAsc = ascending;
          },
        ),
      ));

      // Bug corrigé : l'ancien code envoyait toujours null comme clé.
      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(lastKey, 'name');
      expect(lastAsc, true);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Deuxième tap : bascule vers descendant (l'ancien code restait
      // bloqué en descendant).
      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(lastKey, 'name');
      expect(lastAsc, false);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('colonne non triable : aucun tri déclenché', (tester) async {
      String? lastKey;
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
            AppDataColumn(key: 'qty', label: 'Qty', sortable: false),
          ],
          data: _rows(3),
          onSort: (key, _) => lastKey = key,
        ),
      ));

      await tester.tap(find.text('Qty'));
      await tester.pump();
      expect(lastKey, isNull);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('indicateur de tri aligné avec colonne de numérotation',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
            AppDataColumn(key: 'qty', label: 'Qty', numeric: true),
          ],
          data: _rows(3),
          sortColumnKey: 'qty',
          showRowNumbers: true,
        ),
      ));

      final table = tester.widget<DataTable>(find.byType(DataTable));
      // Colonnes DataTable = [N°, name, qty] → la colonne triée (index
      // interne 1) doit être décalée de 1. Sans le fix : 1 au lieu de 2.
      expect(table.sortColumnIndex, 2);
      expect(table.sortAscending, isTrue);
    });

    testWidgets('indicateur de tri sans colonne de numérotation',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
            AppDataColumn(key: 'qty', label: 'Qty', numeric: true),
          ],
          data: _rows(3),
          sortColumnKey: 'name',
        ),
      ));

      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.sortColumnIndex, 0);

      // Clé inconnue : aucun index invalide transmis à DataTable (assert).
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [
            AppDataColumn(key: 'name', label: 'Name'),
          ],
          data: _rows(3),
          sortColumnKey: 'missing',
        ),
      ));
      final table2 = tester.widget<DataTable>(find.byType(DataTable));
      expect(table2.sortColumnIndex, isNull);
    });

    testWidgets('pagination : tranche, info et navigation contrôlées',
        (tester) async {
      var page = 0;
      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => AppDataTable<Map<String, dynamic>>(
            columns: const [AppDataColumn(key: 'name', label: 'Name')],
            data: _rows(30),
            pagination: true,
            pageSize: 10,
            currentPage: page,
            onPageChanged: (p) => setState(() => page = p),
          ),
        ),
      ));

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 11'), findsNothing);
      expect(find.textContaining('Affichage 1–10 sur 30'), findsOneWidget);

      await tester.tap(find.byTooltip('Page suivante'));
      await tester.pump();
      expect(page, 1);
      expect(find.text('Item 11'), findsOneWidget);
      expect(find.text('Item 1'), findsNothing);
      expect(find.textContaining('Affichage 11–20 sur 30'), findsOneWidget);

      // Sélecteur de page direct.
      await tester.tap(find.text('3').last);
      await tester.pump();
      expect(page, 2);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.textContaining('Affichage 21–30 sur 30'), findsOneWidget);

      // Dernière page : chevron « suivant » présent mais désactivé.
      final nextButton = tester.widget<IconButton>(find
          .ancestor(
              of: find.byTooltip('Page suivante'), matching: find.byType(IconButton))
          .first);
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('sélection : case à cocher ligne et tout sélectionner',
        (tester) async {
      List<Map<String, dynamic>> selected = [];
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [AppDataColumn(key: 'name', label: 'Name')],
          data: _rows(3),
          config: const AppDataTableConfig(showCheckboxColumn: true),
          onSelectionChanged: (items) => selected = items,
        ),
      ));

      // 1 case de tête (tout sélectionner) + 3 cases de lignes.
      expect(find.byType(Checkbox), findsNWidgets(4));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(selected, hasLength(1));
      expect(selected.first['name'], 'Item 1');

      // Tout sélectionner via l'en-tête.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      expect(selected, hasLength(3));
    });

    testWidgets('états loading et empty', (tester) async {
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [AppDataColumn(key: 'name', label: 'Name')],
          data: _rows(3),
          loading: true,
        ),
      ));
      expect(find.byType(AppLoadingState), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);

      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [AppDataColumn(key: 'name', label: 'Name')],
          data: const [],
        ),
      ));
      expect(find.text('Aucune donnée à afficher'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('changement du nombre de lignes par page',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AppDataTable<Map<String, dynamic>>(
          columns: const [AppDataColumn(key: 'name', label: 'Name')],
          data: _rows(30),
          pagination: true,
          pageSize: 10,
        ),
      ));

      expect(find.textContaining('Affichage 1–10 sur 30'), findsOneWidget);

      await tester.tap(find.text('10 par page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 par page'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Affichage 1–25 sur 30'), findsOneWidget);
      expect(find.text('Item 25'), findsOneWidget);
      expect(find.text('Item 26'), findsNothing);
    });
  });
}
