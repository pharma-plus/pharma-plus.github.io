import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/l10n/strings.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/widgets/gradient_button.dart';
import 'package:pharma_maroc_gold/features/employees/employees_page.dart';
import 'package:pharma_maroc_gold/features/prescriptions/prescriptions_page.dart';
import 'package:pharma_maroc_gold/features/purchases/purchases_page.dart';

/// Tests formulaires lot 2 (employé, ordonnance, commande) — Étape 4b.
/// Les données API échouent (client HTTP mock 400) : les tests ciblent
/// la validation avant tout envoi.
late String _locale;

Future<void> _pumpForm(WidgetTester tester, Widget form) async {
  // Formulaire Dialog : placé tel quel dans le body pour qu'il prenne la
  // largeur du Scaffold (560) — un Center+scroll resserre le Dialog à ~280.
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: AuthStore.instance,
      child: MaterialApp(
        home: Scaffold(body: form),
      ),
    ),
  );
}

/// Laisse échouer les chargements initState (mock HTTP 400).
Future<void> _settleLoads(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _type(WidgetTester tester, int field, String value) async {
  final finder = find.byType(TextFormField).at(field);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
}

Future<void> _submit(WidgetTester tester) async {
  final btn = tester.widget<GradientButton>(find.byType(GradientButton));
  btn.onPressed!();
  await tester.pump();
}

void main() {
  setUpAll(() {
    _locale = AuthStore.instance.locale;
  });

  group('EmployeeForm', () {
    testWidgets('champs requis : erreurs sous champ après enregistrement',
        (tester) async {
      await _pumpForm(tester, const EmployeeForm());
      await _settleLoads(tester);
      await _submit(tester);

      expect(find.text(S.t('requiredField', _locale)),
          findsAtLeastNWidgets(1));
    });

    testWidgets('compte utilisateur : mot de passe court signalé',
        (tester) async {
      await _pumpForm(tester, const EmployeeForm());
      await _settleLoads(tester);

      // Cocher « Créer également un compte utilisateur » — tap sur la case
      // elle-même (la zone titre du ListTile dépend du layout du Dialog).
      final checkbox = find.byType(Checkbox).first;
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);

      await _type(tester, 0, 'Ali');
      await _type(tester, 1, 'Benali');
      await _type(tester, 2, 'Caissier');
      await _type(tester, 4, 'ali@pharma.ma');
      // Champs TextFormField : 0 prénom, 1 nom, 2 fonction, 3 tél,
      // 4 e-mail, 5 salaire, 6 mot de passe (cin/cnss/adresse restent
      // des TextField simples).
      await _type(tester, 6, '123');
      await _submit(tester);

      expect(find.text(S.t('passwordMin8', _locale)), findsOneWidget);
    });

    testWidgets('édition : préremplissage et pas de bloc compte',
        (tester) async {
      await _pumpForm(
        tester,
        const EmployeeForm(
            employee: {'first_name': 'Ali', 'last_name': 'Benali'}),
      );
      await _settleLoads(tester);

      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Benali'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  group('PrescriptionForm', () {
    testWidgets('patient requis : erreur sous champ', (tester) async {
      await _pumpForm(tester, const PrescriptionForm());
      await _settleLoads(tester);
      await _submit(tester);

      expect(
          find.text(S.t('requiredField', _locale)), findsOneWidget);
    });

    testWidgets('patient rempli mais aucune ligne : message visible',
        (tester) async {
      await _pumpForm(tester, const PrescriptionForm());
      await _settleLoads(tester);
      await _type(tester, 0, 'Yassine El Amrani');
      await _submit(tester);

      expect(find.text(S.t('itemsRequired', _locale)), findsOneWidget);
    });
  });

  group('OrderForm', () {
    testWidgets('fournisseur non choisi : erreur sous champ déroulant',
        (tester) async {
      await _pumpForm(tester, const OrderForm());
      await _settleLoads(tester);
      await _submit(tester);

      // Le message sert aussi de libellé : au moins un affichage.
      expect(find.text(S.t('chooseSupplier', _locale)),
          findsAtLeastNWidgets(1));
    });
  });
}
