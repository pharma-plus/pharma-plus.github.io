import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/invoices/invoice_ui.dart';
import 'package:pharma_maroc_gold/features/invoices/invoices_page.dart';

void main() {
  group('InvoiceUi.statusKey', () {
    test('mappe les 4 statuts API vers des clés i18n', () {
      expect(InvoiceUi.statusKey('unpaid'), 'invoiceUnpaid');
      expect(InvoiceUi.statusKey('partial'), 'invoicePartial');
      expect(InvoiceUi.statusKey('paid'), 'invoicePaid');
      expect(InvoiceUi.statusKey('cancelled'), 'invoiceCancelled');
    });

    test('repli honnête sur la clé générique pour un statut inconnu', () {
      expect(InvoiceUi.statusKey(''), 'status');
      expect(InvoiceUi.statusKey('something_else'), 'status');
    });
  });

  group('InvoiceUi.dueOf', () {
    test('reste dû = total − encaissé', () {
      expect(
        InvoiceUi.dueOf({'total': 100, 'paid_amount': 40}),
        60,
      );
    });

    test('facture soldée → 0', () {
      expect(
        InvoiceUi.dueOf({'total': 55, 'paid_amount': 55}),
        0,
      );
    });

    test('valeurs textuelles (champs API en string) parsées', () {
      expect(
        InvoiceUi.dueOf({'total': '80.50', 'paid_amount': '30.50'}),
        50.0,
      );
    });

    test('champs absents → 0 (jamais NaN)', () {
      expect(InvoiceUi.dueOf({}), 0);
      expect(InvoiceUi.dueOf({'total': 'abc'}), 0);
    });

    test('sursolde non écrêté : valeur brute honnête', () {
      expect(
        InvoiceUi.dueOf({'total': 100, 'paid_amount': 120}),
        -20,
      );
    });
  });

  group('InvoiceUi.issueDate', () {
    test('ISO string → DateTime', () {
      final d = InvoiceUi.issueDate({'issue_date': '2026-10-15'});
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 10);
      expect(d.day, 15);
    });

    test('DateTime passé tel quel', () {
      final now = DateTime(2026, 1, 2);
      expect(InvoiceUi.issueDate({'issue_date': now}), now);
    });

    test('invalide ou absent → null', () {
      expect(InvoiceUi.issueDate({'issue_date': 'pas-une-date'}), isNull);
      expect(InvoiceUi.issueDate({}), isNull);
      expect(InvoiceUi.issueDate({'issue_date': ''}), isNull);
    });
  });

  group('InvoicesPage', () {
    testWidgets('construit la page sans exception (API en échec en test)',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthStore>.value(
          value: AuthStore.instance,
          child: const MaterialApp(home: InvoicesPage()),
        ),
      );
      // Laisse la requête (mockée à 400 par flutter_test) aboutir.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(InvoicesPage), findsOneWidget);
      // 5 filtres : Tous + 4 statuts.
      expect(find.byType(ChoiceChip), findsNWidgets(5));
    });
  });
}
