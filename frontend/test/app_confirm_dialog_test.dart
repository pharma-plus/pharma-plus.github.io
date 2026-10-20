import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/core/widgets/shared/app_confirm_dialog.dart';

/// Tests du dialogue de confirmation standardisé (étape 5) :
/// retour true/false selon le bouton, callbacks optionnels (boutons
/// actifs même sans callback), barrière non active en destructif.
late Future<bool?> _pending;

Future<void> _pumpConfirm(
  WidgetTester tester, {
  Future<void> Function()? onConfirm,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                _pending = AppConfirmDialog.show(
                  context: context,
                  title: 'Supprimer la caméra',
                  message: 'Caméra 1',
                  isDestructive: true,
                  type: AppConfirmType.danger,
                  onConfirm: onConfirm,
                  onCancel: onCancel,
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirmer : appelle onConfirm puis retourne true',
      (tester) async {
    var called = false;
    await _pumpConfirm(
      tester,
      onConfirm: () async {
        called = true;
      },
    );
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(await _pending, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('annuler actif sans onCancel : retourne false',
      (tester) async {
    await _pumpConfirm(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(await _pending, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirmer actif sans onConfirm : retourne true',
      (tester) async {
    await _pumpConfirm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pumpAndSettle();

    expect(await _pending, isTrue);
  });

  testWidgets('destructif : la barrière ne ferme pas le dialogue',
      (tester) async {
    await _pumpConfirm(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();
    expect(await _pending, isFalse);
  });
}
