import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// ========================================================================
/// TEST DE VÉRIFICATION DU MÉCANISME DE PROTECTION POS
///
/// Vérifie que pos_page.dart contient les blocs try/catch nécessaires pour
/// éviter les exceptions non attrapées qui provoquaient le gel de l'interface.
/// ========================================================================

void main() {
  test('pos_page.dart contient try/catch dans _searchMedications', () {
    final content = File('lib/features/pos/pos_page.dart').readAsStringSync();
    expect(content, contains('_searchMedications(String query) async {'));
    expect(content, contains('setState(() => _searching = true);'));
    expect(content, contains('catch (e, stack)'));
    expect(content, contains('if (mounted) setState(() => _searching = false);'));
  });

  test('pos_page.dart contient try/catch dans _loadBranches', () {
    final content = File('lib/features/pos/pos_page.dart').readAsStringSync();
    expect(content, contains('Future<void> _loadBranches() async {'));
    expect(content, contains('try {'));
    expect(content, contains('catch (e, stack)'));
    expect(content, contains('Erreur chargement branches'));
  });

  test('pos_page.dart contient try/catch dans _loadCustomers', () {
    final content = File('lib/features/pos/pos_page.dart').readAsStringSync();
    expect(content, contains('Future<void> _loadCustomers() async {'));
    expect(content, contains('try {'));
    expect(content, contains('catch (e, stack)'));
    expect(content, contains('Erreur chargement clients'));
  });

  test('pos_page.dart contient try/catch dans _loadFacets', () {
    final content = File('lib/features/pos/pos_page.dart').readAsStringSync();
    expect(content, contains('Future<void> _loadFacets() async {'));
    expect(content, contains('try {'));
    expect(content, contains('catch (e, stack)'));
    expect(content, contains('Erreur chargement facettes'));
  });

  test('pos_page.dart contient _checkout mutex pour éviter les doubles validations', () {
    final content = File('lib/features/pos/pos_page.dart').readAsStringSync();
    expect(content, contains('bool _checkout = false;'));
    expect(content, contains('if (_cart.isEmpty || _checkout) return;'));
    expect(content, contains('setState(() => _checkout = true);'));
  });
}
