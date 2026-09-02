import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/main.dart';

void main() {
  testWidgets('PHARMA+ app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AuthStore.instance,
        child: const PharmaGoldApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PHARMA+'), findsWidgets);
  });
}
