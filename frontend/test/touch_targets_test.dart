// ============================================================
// TEST — Cibles tactiles POS (non-régression)
// ============================================================
// Vérifie par inspection du code source que les boutons critiques du POS
// (_QtyBtn, _QuickBtn, _ToggleBtn) utilisent des cibles tactiles >= 44px
// et HitTestBehavior.opaque (compatibilité écran tactile / doigt).
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cibles tactiles POS', () {
    late String source;

    setUpAll(() {
      final file = File(
          'lib/features/pos/pos_page.dart');
      source = file.readAsStringSync();
    });

    String classBody(String className) {
      final start = source.indexOf('class $className extends StatelessWidget');
      expect(start, isNot(-1), reason: '$className doit exister');
      // Fin approxative : prochaine déclaration de classe.
      final next = source.indexOf('\nclass ', start + 1);
      final end = next == -1 ? source.length : next;
      return source.substring(start, end);
    }

    test('_QtyBtn : cible 44x44 et HitTestBehavior.opaque', () {
      final body = classBody('_QtyBtn');
      expect(body, contains('width: 44'));
      expect(body, contains('height: 44'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('_QuickBtn : minHeight 44 et HitTestBehavior.opaque', () {
      final body = classBody('_QuickBtn');
      expect(body, contains('BoxConstraints(minHeight: 44)'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('_ToggleBtn : minHeight 44 et HitTestBehavior.opaque', () {
      final body = classBody('_ToggleBtn');
      expect(body, contains('BoxConstraints(minHeight: 44)'));
      expect(body, contains('HitTestBehavior.opaque'));
    });

    test('Aucun onHover exclusif dans POS', () {
      expect(source.contains('onHover:'), isFalse);
    });

    test('Notification de stock : bouton fermer en cible 44x44', () {
      final notif = File('lib/core/widgets/stock_notification.dart')
          .readAsStringSync();
      // L'IconButton de fermeture ne doit plus être réduit à 28x28.
      expect(notif, contains('BoxConstraints(minWidth: 44, minHeight: 44)'));
      expect(notif, isNot(contains('minWidth: 28, minHeight: 28')));
    });

    test('Catalogue : 4 cibles actives rendues 44x44 (densité -1)', () {
      final catalog =
          File('lib/features/catalog/catalog_page.dart').readAsStringSync();
      // Mesure réelle : VisualDensity.compact -> 40x40 (sous le seuil),
      // constraints est ignoré -> 48x48, VisualDensity(-1,-1) -> 44x44.
      // Aucune action active ne doit rester en compact 40x40.
      expect(catalog, isNot(contains('visualDensity: VisualDensity.compact,\n')));
      final tactileButtons =
          'VisualDensity(horizontal: -1, vertical: -1)'.allMatches(catalog).length;
      expect(tactileButtons, 4,
          reason: '3 actions tableau + 1 action carte, toutes à 44x44 mesuré');
    });

    test('TouchZone : HitTestBehavior.opaque présent', () {
      final zones =
          File('lib/core/widgets/touch_widgets.dart').readAsStringSync();
      final idx = zones.indexOf('class TouchZone');
      final snippet = zones.substring(idx);
      expect(snippet, contains('HitTestBehavior.opaque'));
    });

    // --- Corrections composants partagés (adaptation tactile globale) ---

    test('Tableau : Checkbox sélection sans densité compacte', () {
      final table =
          File('lib/core/widgets/shared/app_data_table.dart')
              .readAsStringSync();
      final idx = table.indexOf('class AppDataRow');
      final snippet = table.substring(idx, table.indexOf('class ', idx + 1));
      // La Checkbox de sélection doit garder une cible ≥44 px.
      expect(snippet, isNot(contains('VisualDensity.compact')));
      expect(snippet, isNot(contains('materialTapTargetSize: MaterialTapTargetSize.shrinkWrap')));
    });

    test('Tableau colonnes : 2 IconButtons actions à 44x44 (densité -1)', () {
      final cols =
          File('lib/core/utils/table_columns.dart').readAsStringSync();
      expect(cols, isNot(contains('VisualDensity.compact')));
      expect(cols, contains('VisualDensity(horizontal: -1, vertical: -1)'));
      expect(cols, isNot(contains('minWidth: 28')));
    });

    test('Transactions ventes : plus de cible 28x28', () {
      final tx =
          File('lib/features/sales_day/widgets/sales_transactions_table.dart')
              .readAsStringSync();
      expect(tx, isNot(contains('BoxConstraints(minWidth: 28, minHeight: 28)')));
      expect(tx, contains('VisualDensity(horizontal: -1, vertical: -1)'));
    });

    test('Super Admin rôle : bouton création ≥44 px (pas de densité compacte)', () {
      final rm =
          File('lib/features/super_admin/role_management_page.dart')
              .readAsStringSync();
      final idx = rm.indexOf('class RoleManagementPage');
      final snippet = rm.substring(idx);
      // Le bouton « Nouveau rôle » ne doit pas utiliser VisualDensity.compact.
      expect(snippet, isNot(contains('visualDensity: VisualDensity.compact')));
      expect(snippet, contains('minimumSize: const Size(double.infinity, 48)'));
    });

    test('TouchButton small : hauteur ≥44 px (système de design)', () {
      final tw =
          File('lib/core/widgets/touch_widgets.dart').readAsStringSync();
      final idx = tw.indexOf('class TouchButton');
      final snippet = tw.substring(idx, tw.indexOf('class ', idx + 1));
      expect(snippet, isNot(contains('small ? 40.0')));
      expect(snippet, contains('small ? 44.0'));
    });
  });
}
