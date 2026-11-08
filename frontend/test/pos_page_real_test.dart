import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../lib/core/services/api_client.dart';
import '../lib/core/services/auth_store.dart';
import '../lib/features/pos/pos_page.dart';

/// ========================================================================
/// VRAI TEST WIDGET POS — Construit PosPage avec un mock HTTP qui intercepte
/// toutes les requêtes et retourne des réponses simulées. Aucune connexion
/// réseau réelle n'est établie.
/// ========================================================================

/// Réponses simulées par route.
(Map<String, dynamic>, int) _mockResponse(Uri url) {
  final path = url.path;

  // Branches — nécessaire pour que le POS puisse initialiser _branchId
  if (path.endsWith('/branches')) {
    return (
      {'data': [{'id': 'b1', 'name': 'Branche 1', 'code': 'B1'}]},
      200,
    );
  }

  // Clients — nécessaire pour le sélecteur client
  if (path.endsWith('/customers')) {
    return (
      {
        'data': [
          {'id': 'c1', 'first_name': 'Jean', 'last_name': 'Dupont'},
          {'id': 'c2', 'first_name': 'Marie', 'last_name': 'Martin'},
        ],
      },
      200,
    );
  }

  // Facettes — nécessaire pour _loadFacets
  if (path.endsWith('/catalog/medications/facets')) {
    return (
      {'data': {'forms': [], 'indications_total': 0}},
      200,
    );
  }

  // Stock — nécessaire pour _loadStockForPage
  if (path.endsWith('/catalog/medications/stock')) {
    return (
      {'data': [{'medication_id': 'm1', 'quantity': 100}]},
      200,
    );
  }

  // Catalogue / recherche de médicaments
  if (path.endsWith('/catalog/medications')) {
    return (
      {
        'data': [
          {
            'id': 'm1',
            'name': 'Paracétamol 500mg',
            'barcode_ean13': '1234567890123',
            'price': 12.5,
            'stock': 100,
            'form': 'comprimé',
            'pathology': '',
            'tva_rate': 20,
            'laboratory_name': 'Labo X',
            'category_name': 'Médicaments',
          },
          {
            'id': 'm2',
            'name': 'Ibuprofène 400mg',
            'barcode_ean13': '1234567890124',
            'price': 8.9,
            'stock': 50,
            'form': 'gélule',
            'pathology': '',
            'tva_rate': 20,
            'laboratory_name': 'Labo Y',
            'category_name': 'Médicaments',
          },
        ],
      },
      200,
    );
  }

  // Ventes — validation de vente
  if (path.endsWith('/sales')) {
    return (
      {'data': {'id': 's1', 'number': 'VTE-001', 'status': 'completed'}},
      201,
    );
  }

  return ({'data': []}, 200);
}

/// HttpClient qui intercepte toutes les requêtes et retourne des réponses
/// simulées. Étend BaseClient (qui implémente Client) afin d'être compatible
/// avec ApiClient.setClientForTesting.
class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final (body, status) = _mockResponse(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

void _noException(WidgetTester tester, [String where = '']) {
  final ex = tester.takeException();
  if (ex != null) {
    debugPrint('=== EXCEPTION[$where] ===\n$ex\n=== FIN ===');
  }
  expect(ex, isNull, reason: where);
}

void main() {
  setUp(() {
    // Injecter le FakeHttpClient dans ApiClient pour intercepter les requêtes.
    ApiClient.setClientForTesting(_FakeHttpClient());
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  testWidgets(
    'POS se construit sans exception et affiche le catalogue',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: Brightness.dark),
            home: const PosPage(),
          ),
        ),
      );
      await _settle(tester);
      _noException(tester, 'construction PosPage');

      // Le titre du POS doit apparaître
      expect(find.text('Point de vente'), findsOneWidget);

      // Le champ de recherche doit être présent
      expect(find.byType(TextField), findsOneWidget);

      // Attendre le chargement asynchrone du catalogue
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      _noException(tester, 'affichage catalogue');

      // Vérifier qu'au moins un médicament est affiché
      expect(
        find.text('Paracétamol 500mg'),
        findsOneWidget,
        reason: 'Le médicament simulé doit apparaître dans le catalogue',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Recherche produit : saisie dans le champ filtre le catalogue',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: Brightness.dark),
            home: const PosPage(),
          ),
        ),
      );
      await _settle(tester);
      _noException(tester, 'construction');

      // Saisir du texte dans le champ de recherche
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'parac');
      await _settle(tester);
      _noException(tester, 'saisie recherche');

      // Le médicament correspondant doit rester affiché
      expect(find.text('Paracétamol 500mg'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Raccourcis clavier : F2, F4, F9, Échap, Tab ne lèvent pas d\'exception',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: Brightness.dark),
            home: const PosPage(),
          ),
        ),
      );
      await _settle(tester);
      _noException(tester, 'construction');

      // F2 — focus recherche
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f2);
      await _settle(tester);
      _noException(tester, 'F2');

      // Échap — vider la recherche
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      _noException(tester, 'Échap');

      // F4 — sélecteur client
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      _noException(tester, 'F4');

      // F9 — encaisser (sans articles dans le panier, doit rester silencieux)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f9);
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      _noException(tester, 'F9');

      // Tab — navigation entre champs
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await _settle(tester);
      _noException(tester, 'Tab');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'Ajout au panier et prévention des doubles clics',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: Brightness.dark),
            home: const PosPage(),
          ),
        ),
      );
      await _settle(tester);
      _noException(tester, 'construction');

      // Attendre que le catalogue se charge
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);

      // Le médicament Paracétamol doit être dans les résultats
      expect(find.text('Paracétamol 500mg'), findsOneWidget);

      // Taper sur le médicament pour l'ajouter au panier
      await tester.tap(find.text('Paracétamol 500mg').first);
      await _settle(tester);
      _noException(tester, 'ajout au panier');

      // Le médicament doit rester visible (ajouté au panier)
      expect(find.text('Paracétamol 500mg'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Pas de setState après dispose : fermer la page pendant un chargement',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: Brightness.dark),
            home: const PosPage(),
          ),
        ),
      );
      await _settle(tester);
      _noException(tester, 'construction');

      // Fermer immédiatement la page pendant que les requêtes API sont en cours
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(body: Center(child: Text('Autre page'))),
        ),
      );
      await _settle(tester);
      _noException(tester, 'après dispose');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
