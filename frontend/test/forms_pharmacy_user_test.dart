import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/l10n/strings.dart';
import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/widgets/gradient_button.dart';
import 'package:pharma_maroc_gold/features/super_admin/super_admin_portal.dart';
import 'package:pharma_maroc_gold/features/super_admin/users_management_page.dart';

/// Tests des formulaires pharmacie (super-admin) et utilisateur (étape 4c) :
/// validation sous champ, messages i18n, branches édition/création.
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

/// UserFormDialog racine AlertDialog : monté tel quel dans le Scaffold
/// (Center+SingleChildScrollView resserrait le dialogue à ~280 px).
Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: AuthStore.instance,
      child: MaterialApp(home: Scaffold(body: dialog)),
    ),
  );
}

Future<void> _type(WidgetTester tester, int field, String value) async {
  final finder = find.byType(TextFormField).at(field);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
}

Future<void> _submitGradient(WidgetTester tester) async {
  final btn = tester.widget<GradientButton>(find.byType(GradientButton));
  btn.onPressed!();
  await tester.pump();
}

Future<void> _submitFilled(WidgetTester tester) async {
  final btn = tester.widget<FilledButton>(find.byType(FilledButton));
  btn.onPressed!();
  await tester.pump();
}

void main() {
  setUpAll(() {
    _locale = AuthStore.instance.locale;
  });

  group('PharmacyForm', () {
    testWidgets('nom, slug et e-mail obligatoires : 3 erreurs sous champ',
        (tester) async {
      await _pumpForm(tester, const PharmacyForm());
      await _submitGradient(tester);

      expect(find.text(S.t('requiredField', _locale)), findsNWidgets(3));
    });

    testWidgets('e-mail invalide signalé', (tester) async {
      await _pumpForm(tester, const PharmacyForm());
      await _type(tester, 0, 'Pharma Test');
      await _type(tester, 1, 'pharma-test');
      await _type(tester, 3, 'pas-un-email');
      await _submitGradient(tester);

      expect(find.text(S.t('invalidEmail', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });

    testWidgets('téléphone invalide signalé', (tester) async {
      await _pumpForm(tester, const PharmacyForm());
      await _type(tester, 0, 'Pharma Test');
      await _type(tester, 1, 'pharma-test');
      await _type(tester, 3, 'admin@pharma.ma');
      await _type(tester, 2, 'abc');
      await _submitGradient(tester);

      expect(find.text(S.t('invalidPhone', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });

    testWidgets('mot de passe court refusé, mot de passe vide accepté',
        (tester) async {
      await _pumpForm(tester, const PharmacyForm());
      await _type(tester, 0, 'Pharma Test');
      await _type(tester, 1, 'pharma-test');
      await _type(tester, 3, 'admin@pharma.ma');
      await _type(tester, 4, '123');
      await _submitGradient(tester);

      expect(find.text(S.t('passwordMin8', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });
  });

  group('UserFormDialog', () {
    testWidgets(
        'création : prénom, nom, e-mail et mot de passe obligatoires',
        (tester) async {
      await _pumpDialog(
        tester,
        const UserFormDialog(roles: [
          {'id': 'r1', 'name': 'Admin'}
        ]),
      );
      await _submitFilled(tester);

      expect(find.text(S.t('requiredField', _locale)), findsNWidgets(4));
    });

    testWidgets('mot de passe court refusé en création', (tester) async {
      await _pumpDialog(
        tester,
        const UserFormDialog(roles: [
          {'id': 'r1', 'name': 'Admin'}
        ]),
      );
      await _type(tester, 0, 'Amina');
      await _type(tester, 1, 'Berrada');
      await _type(tester, 2, 'amina@pharma.ma');
      await _type(tester, 4, '123');
      await _submitFilled(tester);

      expect(find.text(S.t('passwordMin8', _locale)), findsOneWidget);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
    });

    testWidgets('édition : pas de champ mot de passe, validation OK',
        (tester) async {
      await _pumpDialog(
        tester,
        const UserFormDialog(
          user: {
            'id': 'u1',
            'first_name': 'Sam',
            'last_name': 'Touch',
            'email': 'sam@pharma.ma',
          },
          roles: [
            {'id': 'r1', 'name': 'Admin'}
          ],
        ),
      );

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('sam@pharma.ma'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));

      await _submitFilled(tester);
      expect(find.text(S.t('requiredField', _locale)), findsNothing);
      expect(find.text(S.t('passwordMin8', _locale)), findsNothing);
    });
  });
}
