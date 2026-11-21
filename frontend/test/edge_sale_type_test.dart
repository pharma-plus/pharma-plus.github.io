// ============================================================
// TEST — Contrat sale_type Edge Function ↔ schéma SQL (non-régression)
// ============================================================
// Vérifie que l'Edge Function ne produit JAMAIS une valeur sale_type
// interdite par le CHECK de 007_sales.sql.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contrat sale_type (Edge ↔ SQL)', () {
    late String edge;
    late String schema;

    setUpAll(() {
      edge = File(
              '../supabase/functions/pharma-api/index.ts')
          .readAsStringSync();
      schema = File('../database/schema/007_sales.sql').readAsStringSync();
    });

    test('Le CHECK SQL sale_type autorise pos, credit, online, reservation',
        () {
      final checkLine = schema.split('\n').firstWhere(
            (l) => l.contains("CHECK (sale_type IN"),
          );
      expect(checkLine, contains("('pos','credit','online','reservation')"));
      expect(checkLine, isNot(contains('cash')));
    });

    test('Le mapping Edge mappe cash vers pos (jamais cash)', () {
      expect(edge, contains('cash: "pos"'));
      expect(edge, isNot(contains('cash: "cash"')));
    });

    test('Le mapping Edge ne produit aucune valeur hors CHECK', () {
      // Extrait la ligne de mapping et vérifie les valeurs produites.
      final line = edge.split('\n').firstWhere(
            (l) => l.contains('const saleType = ('),
          );
      expect(line, contains('pos: "pos"'));
      expect(line, contains('credit: "credit"'));
      expect(line, contains('online: "online"'));
      expect(line, contains('reservation: "reservation"'));
      expect(line, isNot(contains('"cash"')));
    });
  });
}
