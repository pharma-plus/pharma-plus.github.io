// ============================================================
// TEST WIDGET — Dimensions RÉELLEMENT RENDUES des cibles tactiles
// ============================================================
// Mesure la taille effective (tester.getSize) des widgets Flutter,
// pas seulement l'inspection du code source. Découvertes clés :
//  - VisualDensity.compact  -> IconButton rend 40x40 (SOUS le seuil 44).
//  - IconButton.constraints est IGNORÉ ici (rend 48x48 même avec min 44).
//  - VisualDensity(horizontal:-1, vertical:-1) -> 44x44 exact (correction).
//  - Checkbox par défaut -> cible ≥44 px (Material par défaut).
// Vérifie aussi que TouchZone capte les taps sur zones transparentes.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_maroc_gold/core/widgets/touch_widgets.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dimensions rendues (IconButton) — mesures réelles', () {
    testWidgets('VisualDensity.compact rend 40x40 — sous le seuil 44',
        (tester) async {
      await tester.pumpWidget(_host(IconButton(
        icon: const Icon(Icons.edit),
        visualDensity: VisualDensity.compact,
        onPressed: () {},
      )));
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, 40.0,
          reason: 'mesure réelle du compact sur cet environnement Flutter');
      expect(size.height, 40.0);
      expect(size.width < 44, isTrue,
          reason: 'confirme que compact est sous le seuil tactile 44');
    });

    testWidgets('IconButton.constraints est ignoré — rend 48x48, pas 44',
        (tester) async {
      await tester.pumpWidget(_host(IconButton(
        icon: const Icon(Icons.edit),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        onPressed: () {},
      )));
      final size = tester.getSize(find.byType(IconButton));
      // Piège documenté : dans cette version de Flutter, constraints ne
      // réduit pas la cible en dessous du minimum Material de 48 px.
      expect(size.width, 48.0);
      expect(size.height, 48.0);
    });

    testWidgets('VisualDensity(-1,-1) rend 44x44 et reçoit le tap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(IconButton(
        icon: const Icon(Icons.edit, size: 18),
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        onPressed: () => taps++,
      )));
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, 44.0,
          reason: 'correction appliquée aux boutons du catalogue');
      expect(size.height, 44.0);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(taps, 1, reason: 'l\'interaction doit rester fonctionnelle');
    });

    testWidgets('IconButton par défaut rend 48x48 (≥44)', (tester) async {
      await tester.pumpWidget(_host(IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {},
      )));
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width >= 44, isTrue,
          reason: 'IconButton par défaut doit faire ≥44 px');
      expect(size.height >= 44, isTrue);
    });
  });

  group('Dimensions rendues (Checkbox) — mesures réelles', () {
    testWidgets('Checkbox par défaut rend ≥44x44', (tester) async {
      var value = false;
      await tester.pumpWidget(_host(Checkbox(
        value: value,
        onChanged: (v) => value = v ?? false,
      )));
      final size = tester.getSize(find.byType(Checkbox));
      expect(size.width >= 44, isTrue,
          reason: 'Checkbox par défaut doit faire ≥44 px');
      expect(size.height >= 44, isTrue);
    });

    testWidgets('Checkbox avec densité compacte rend <44x44 (problème)',
        (tester) async {
      var value = false;
      await tester.pumpWidget(_host(Checkbox(
        value: value,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (v) => value = v ?? false,
      )));
      final size = tester.getSize(find.byType(Checkbox));
      expect(size.width < 44, isTrue,
          reason: 'Checkbox compacte est sous le seuil tactile 44');
      expect(size.height < 44, isTrue);
    });
  });

  group('Dimensions rendues (Boutons Material) — mesures réelles', () {
    testWidgets('FilledButton par défaut rend ≥44x44', (tester) async {
      await tester.pumpWidget(_host(FilledButton(
        onPressed: () {},
        child: const Text('OK'),
      )));
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.width >= 44, isTrue,
          reason: 'FilledButton par défaut doit faire ≥44 px');
      expect(size.height >= 44, isTrue);
    });

    testWidgets('TouchButton small rend 44x44 (pas 40)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(TouchButton(
        onPressed: () => tapped = true,
        label: 'Test',
        small: true,
      )));
      final size = tester.getSize(find.byType(TouchButton));
      expect(size.height >= 44, isTrue,
          reason: 'TouchButton small doit faire ≥44 px de hauteur');
      await tester.tap(find.byType(TouchButton));
      await tester.pump();
      expect(tapped, true, reason: 'l\'interaction doit rester fonctionnelle');
    });
  });

  group('TouchZone — capte les taps sur zone transparente', () {
    testWidgets('TouchZone avec enfant transparent reçoit le tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(TouchZone(
        onTap: () => taps++,
        child: const SizedBox(width: 48, height: 48), // transparent
      )));
      await tester.tap(find.byType(TouchZone));
      await tester.pump();
      expect(taps, 1,
          reason: 'HitTestBehavior.opaque doit capter le tap même sans decoration');
    });

    testWidgets('TouchZone respecte minSize', (tester) async {
      await tester.pumpWidget(_host(TouchZone(
        onTap: () {},
        minSize: 48,
        child: const SizedBox(width: 10, height: 10),
      )));
      final size = tester.getSize(find.byType(TouchZone));
      expect(size.width >= 48, isTrue);
      expect(size.height >= 48, isTrue);
    });
  });
}
