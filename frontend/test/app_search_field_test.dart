import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/core/widgets/shared/app_search_field.dart';

Widget _host(double width) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: const AppSearchField(showFilterButton: false),
        ),
      ),
    );

void main() {
  group('AppSearchField', () {
    testWidgets('reste limité à 380 pixels sur grand écran', (tester) async {
      await tester.pumpWidget(_host(900));

      expect(tester.getSize(find.byType(TextField)).width, 380);
      expect(tester.takeException(), isNull);
    });

    testWidgets('utilise la largeur disponible sous 380 pixels',
        (tester) async {
      await tester.pumpWidget(_host(320));

      expect(tester.getSize(find.byType(TextField)).width, 320);
      expect(tester.takeException(), isNull);
    });
  });
}
