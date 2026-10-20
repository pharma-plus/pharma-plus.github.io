import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/l10n/strings.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/widgets/gradient_button.dart';
import 'package:pharma_maroc_gold/features/customers/customers_page.dart';
import 'package:pharma_maroc_gold/features/suppliers/suppliers_page.dart';

/// Tests des formulaires fournisseurs / clients (étape formulaires) :
/// validation sous champ, messages i18n, préremplissage en édition.
/// Les tests s'arrêtent avant l'appel réseau (validate() échoue) ou
/// touchent uniquement le rendu.
late String _locale;

Future<void> _pumpForm(WidgetTester tester, Widget form) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: AuthStore.instance,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SingleChildScrollView(child: form)),
        ),
      ),
    ),
  );
}

Future<void> _type(WidgetTester tester, int field, String value) async {
  final finder = find.byType(TextFormField).at(field);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
}

Future<void> _submit(WidgetTester tester) async {
  // Appel direct du callback : le bouton peut être à la limite du viewport
  // dans ce harness, on teste la validation, pas le plumbing de geste.
  final btn = tester.widget<GradientButton>(find.byType(GradientButton));
  btn.onPressed!();
  await tester.pump();
}

void main() {
  setUpAll(() {
    _locale = AuthStore.instance.locale;
  });

  group('SupplierForm', () {
    testWidgets('nom requis : erreur sous champ après enregistrement',
        (tester) async {
      await _pumpForm(tester, const SupplierForm());
      await _submit(tester);

      expect(find.text(S.t('requiredField', _locale)), findsOneWidget);
      expect(find.text(S.t('invalidPhone', _locale)), findsNothing);
    });

    testWidgets('téléphone invalide signalé, nom validé', (tester) async {
      await _pumpForm(tester, const SupplierForm());
      await _type(tester, 0, 'Distri Pharma');
      await _type(tester, 2, 'abc');
      await _submit(tester);

      expect(find.text(S.t('invalidPhone', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });

    testWidgets('e-mail invalide signalé', (tester) async {
      await _pumpForm(tester, const SupplierForm());
      await _type(tester, 0, 'Distri Pharma');
      await _type(tester, 2, '0612345678');
      await _type(tester, 4, 'pas-un-email');
      await _submit(tester);

      expect(find.text(S.t('invalidEmail', _locale)), findsOneWidget);
    });

    testWidgets('édition : valeurs préremplies dans les champs',
        (tester) async {
      await _pumpForm(
        tester,
        const SupplierForm(
            supplier: {'name': 'MedStore', 'phone': '0611223344'}),
      );

      expect(find.text('MedStore'), findsOneWidget);
      expect(find.text('0611223344'), findsOneWidget);
    });
  });

  group('CustomerForm', () {
    testWidgets('nom requis : erreur sous champ après enregistrement',
        (tester) async {
      await _pumpForm(tester, const CustomerForm());
      await _submit(tester);

      expect(find.text(S.t('requiredField', _locale)), findsOneWidget);
    });

    testWidgets('plafond de crédit invalide signalé', (tester) async {
      await _pumpForm(tester, const CustomerForm());
      await _type(tester, 0, 'Amina B.');
      await _type(tester, 5, 'abc');
      await _submit(tester);

      expect(find.text(S.t('invalidNumber', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });

    testWidgets('plafond de crédit négatif refusé', (tester) async {
      await _pumpForm(tester, const CustomerForm());
      await _type(tester, 0, 'Amina B.');
      await _type(tester, 5, '-5');
      await _submit(tester);

      expect(find.text(S.t('invalidNumber', _locale)), findsOneWidget);
    });
  });
}
