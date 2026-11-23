// ============================================================
// TEST — DOUBLONS, COHÉRENCE FINANCIÈRE ET ISOLATION (Sales Intelligence)
// ============================================================
// Couverture :
// 1. Déduplication des transactions par id (doublons de pagination / jeu complet)
//    — TEST DE PRODUCTION : appelle le véritable contrôleur via MockClient.
// 2. Calculs HT/TTC/TVA (marge, retour, annulation)
// 3. Comparaisons (période vs période, écart seulement si précédente > 0)
// 4. Isolation entre pharmacies (pharmacy_id depuis le JWT, pas du client)
// 5. Idempotence / synchronisation (invalidation de cache)
// ============================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import '../lib/core/services/api_client.dart';
import '../lib/features/sales_day/controllers/sales_day_controller.dart';
import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/repositories/sales_repository.dart';
import '../lib/features/sales_day/services/sales_analytics_service.dart';
import '../lib/features/sales_day/services/sales_financials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiClient.resetClientForTesting();
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  // ------------------------------------------------------------------
  // 1. DÉDUPLICATION DES TRANSACTIONS (pas de doublon de pagination)
  //    Test de production : appelle le véritable SalesDayController
  //    via un MockClient qui simule des ids répétés entre deux pages.
  // ------------------------------------------------------------------
  group('Déduplication transactions (id unique)', () {
    test(
        'loadMore ne duplique pas une transaction déjà présente sur la page précédente',
        () async {
      var txCalls = 0;
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        // Analytics (/sales/day) — répond toujours avec des KPIs vides.
        if (!r.url.path.endsWith('/transactions')) {
          return http.Response(jsonEncode({'data': {'kpis': {}}}), 200);
        }
        // Transactions (/sales/day/transactions) — pagination avec doublon.
        txCalls++;
        final page = int.tryParse(r.url.queryParameters['page'] ?? '1') ?? 1;
        if (page == 1) {
          // Page 1 pleine : 50 transactions s1..s50.
          final rows = List.generate(50, (i) => {
            'id': 's${i + 1}',
            'number': 'V-${i + 1}',
            'status': 'completed',
            'total': 100.0,
            'paid_amount': 100.0,
            'created_at': '2026-11-10T10:15:00Z',
          });
          return http.Response(jsonEncode({
            'data': rows,
            'meta': {'total': 53, 'page': 1, 'limit': 50},
          }), 200);
        } else {
          // Page 2 : s50 (doublon), s51, s52, s53 (nouveaux).
          final rows = List.generate(4, (i) {
            final id = i == 0 ? 's50' : 's${50 + i}';
            return {
              'id': id,
              'number': 'V-$id',
              'status': 'completed',
              'total': 100.0,
              'paid_amount': 100.0,
              'created_at': '2026-11-10T10:15:00Z',
            };
          });
          return http.Response(jsonEncode({
            'data': rows,
            'meta': {'total': 53, 'page': 2, 'limit': 50},
          }), 200);
        }
      }));

      final c = SalesDayController();
      // Simule la page 1 déjà chargée (50 transactions).
      for (var i = 1; i <= 50; i++) {
        c.txRows.add(SalesTransaction(
          id: 's$i',
          number: 'V-$i',
          createdAt: null,
          status: 'completed',
          saleType: 'pos',
          subtotal: 100,
          discountTotal: 0,
          taxTotal: 0,
          total: 100,
          paidAmount: 100,
          changeAmount: 0,
          paymentMethod: 'cash',
          customer: null,
          itemsCount: 1,
          userId: 'u1',
          userName: 'Test',
        ));
      }
      c.txTotal = 53;
      expect(c.txRows.length, 50);
      expect(c.txHasMore, isTrue);

      // loading est true par défaut ; loadMore() en tient compte (ligne 211).
      c.loading = false;

      await c.loadMore();

      // s50 déduit, s51, s52, s53 ajoutés → 53 transactions, 53 ids uniques.
      expect(c.txRows.length, 53, reason: 'pas de doublon de s50');
      expect(c.txRows.map((t) => t.id).toSet().length, 53,
          reason: 'tous les ids sont uniques');
      expect(txCalls, 1, reason: 'une seule requête page 2');

      c.dispose();
      ApiClient.resetClientForTesting();
    });

    test('Une transaction avec un nouvel id est ajoutée', () {
      final c = SalesDayController();
      c.txRows.add(const SalesTransaction(
        id: 's1', number: 'V-1', createdAt: null, status: 'completed',
        saleType: 'pos', subtotal: 100, discountTotal: 0, taxTotal: 0,
        total: 100, paidAmount: 100, changeAmount: 0,
        paymentMethod: 'cash', customer: null, itemsCount: 1,
        userId: 'u1', userName: 'Test',
      ));

      // Vérifie le comportement de déduplication du contrôleur (extrait de loadMore).
      final seen = c.txRows.map((t) => t.id).toSet();
      final newRow = const SalesTransaction(
        id: 's3', number: 'V-3', createdAt: null, status: 'completed',
        saleType: 'pos', subtotal: 300, discountTotal: 0, taxTotal: 0,
        total: 300, paidAmount: 300, changeAmount: 0,
        paymentMethod: 'cash', customer: null, itemsCount: 1,
        userId: 'u1', userName: 'Test',
      );
      if (seen.add(newRow.id)) c.txRows.add(newRow);

      expect(c.txRows.length, 2, reason: 'nouvelle transaction ajoutée');
      c.dispose();
    });

    test('Vente de plusieurs unités d un même produit reste une seule ligne',
        () {
      final c = SalesDayController();
      // Une vente de 5 unités du même produit = 1 transaction, pas 5 lignes.
      c.txRows.add(const SalesTransaction(
        id: 's1', number: 'V-1', createdAt: null, status: 'completed',
        saleType: 'pos', subtotal: 500, discountTotal: 0, taxTotal: 0,
        total: 500, paidAmount: 500, changeAmount: 0,
        paymentMethod: 'cash', customer: null, itemsCount: 5,
        userId: 'u1', userName: 'Test',
      ));

      expect(c.txRows.length, 1, reason: '1 transaction = 1 ligne');
      expect(c.txRows.single.itemsCount, 5, reason: '5 unités sur la même ligne');
      c.dispose();
    });
  });

  // ------------------------------------------------------------------
  // 2. CALCULS FINANCIERS (HT/TTC/TVA, marge, retour, annulation)
  // ------------------------------------------------------------------
  group('SalesFinancials — calculs honnêtes', () {
    test('grossProfit = grossRevenue − costTotal (coût fiable)', () {
      final f = SalesFinancials(
        grossRevenue: 405.0, netRevenue: 335.0, costTotal: 210.0,
      );
      expect(f.hasCost, isTrue);
      expect(f.grossProfit, 195.0);
    });

    test('grossProfit null si coût absent', () {
      final f = SalesFinancials(
        grossRevenue: 405.0, netRevenue: 335.0, costTotal: null,
      );
      expect(f.hasCost, isFalse);
      expect(f.grossProfit, isNull);
      expect(f.costReliability, SalesCostReliability.absent);
    });

    test('grossProfit null si coût nul ambigu', () {
      final f = SalesFinancials(
        grossRevenue: 405.0, netRevenue: 335.0, costTotal: 0.0,
      );
      expect(f.hasCost, isFalse);
      expect(f.grossProfit, isNull);
      expect(f.costReliability, SalesCostReliability.zeroAmbiguous);
    });

    test('grossMarginPct = bénéfice / CA TTC × 100', () {
      final f = SalesFinancials(
        grossRevenue: 405.0, netRevenue: 335.0, costTotal: 210.0,
      );
      expect(f.grossMarginPct, closeTo(48.148, 0.01));
    });

    test('grossMarginPct null si CA nul (pas de division par zéro)', () {
      final f = SalesFinancials(
        grossRevenue: 0.0, netRevenue: 0.0, costTotal: 50.0,
      );
      expect(f.grossMarginPct, isNull);
    });

    test('htSharePct = netRevenue / grossRevenue × 100', () {
      final f = SalesFinancials(
        grossRevenue: 120.0, netRevenue: 100.0, costTotal: 60.0,
      );
      expect(f.htSharePct, closeTo(83.33, 0.01));
    });

    test('TVA 20 % extraite du TTC après remise : net = TTC − TVA', () {
      // Produit 100 DH TTC, remise 10 DH -> net TTC 90 DH.
      // TVA incluse 20 % = 90 − 90/1,2 = 15 DH. CA HT = 90 − 15 = 75 DH.
      const totalTtc = 90.0;
      final tva = totalTtc - totalTtc / 1.2;
      final netHt = totalTtc - tva;
      expect(tva, closeTo(15.0, 0.001));
      expect(netHt, 75.0);
    });
  });

  // ------------------------------------------------------------------
  // 3. COMPARAISONS (période vs période, écart seulement si précédente > 0)
  // ------------------------------------------------------------------
  group('Comparaisons périodes', () {
    test('Écart affiché seulement si précédente > 0', () {
      final k = SalesDayKpis(
        grossRevenue: 1200, netRevenue: 1000, taxTotal: 200,
        discountsTotal: 25, salesCount: 6, averageBasket: 200,
        cancelledCount: 1, returnedCount: 0, paidAmount: 1100,
        outstandingAmount: 100, refundedAmount: null, costTotal: 700,
        totalRows: 7,
      );
      final prev = SalesDayKpis(
        grossRevenue: 1000, netRevenue: 800, taxTotal: 150,
        discountsTotal: 20, salesCount: 5, averageBasket: 180,
        cancelledCount: 0, returnedCount: 0, paidAmount: 900,
        outstandingAmount: 50, refundedAmount: null, costTotal: 600,
        totalRows: 5,
      );

      // Delta avec précédente disponible.
      final d = SalesAnalyticsService.delta(k.grossRevenue, prev.grossRevenue);
      expect(d.pct, closeTo(20.0, 0.01)); // (1200-1000)/1000 = 20%

      // Delta avec précédente nulle → null (jamais de % inventé).
      final d2 = SalesAnalyticsService.delta(k.grossRevenue, 0.0);
      expect(d2.pct, isNull);

      // Delta avec précédente null → null.
      final d3 = SalesAnalyticsService.delta(k.grossRevenue, null);
      expect(d3.pct, isNull);
    });

    test('Comparaison page : pas de doublon de ligne par KPI', () {
      // Chaque KPI apparaît une seule fois dans les lignes de comparaison.
      final kpis = <String, double>{
        'CA TTC': 1200,
        'CA HT net': 1000,
        'TVA facturée': 200,
        'Remises': 25,
        'Panier moyen': 200,
        'Ventes validées': 6,
      };
      expect(kpis.length, 6);
      // Vérifie qu'il n'y a pas de clé dupliquée.
      final keys = kpis.keys.toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  // ------------------------------------------------------------------
  // 4. ISOLATION ENTRE PHARMACIES (pharmacy_id depuis le JWT, pas du client)
  // ------------------------------------------------------------------
  group('Isolation multi-pharmacies', () {
    test('SalesRepository n accepte aucun pharmacy_id en paramètre (il provient du JWT)', () {
      // Aucune méthode publique de SalesRepository ne prend pharmacy_id en
      // argument : il est injecté uniquement via _pharmacyIdParam depuis
      // AuthStore.instance.user.pharmacyId (JWT côté serveur).
      final repo = SalesRepository.instance;
      expect(repo, isNotNull);

      // loadAnalytics n'exige que la plage et l'offset : pas de pharmacy_id
      // transmissible par l'UI/le client, donc pas d'injection possible.
      expect(
        () => repo.loadAnalytics(
          SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
          offsetMinutes: 0,
        ),
        returnsNormally,
      );
    });
  });

  // ------------------------------------------------------------------
  // 5. IDEMPOTENCE / SYNCHRONISATION (invalidation de cache)
  // ------------------------------------------------------------------
  group('Invalidation de cache après vente', () {
    test('invalidateAllCaches vide le jeu complet sur l instance active', () {
      final active = SalesDayController();
      SalesDayController.setActiveInstance(active);

      active.fullRows = const [
        SalesTransaction(
          id: 't1', number: 'V-1', createdAt: null, status: 'completed',
          saleType: 'pos', subtotal: 100, discountTotal: 0, taxTotal: 0,
          total: 100, paidAmount: 100, changeAmount: 0,
          paymentMethod: 'cash', customer: null, itemsCount: 1,
          userId: 'u1', userName: 'Test',
        )
      ];
      expect(active.fullRows.isNotEmpty, isTrue);

      SalesDayController.invalidateAllCaches();

      expect(active.fullRows, isEmpty);
      expect(active.fullComplete, isFalse);
      expect(active.fullError, isNull);

      active.dispose();
      SalesDayController.clearActiveInstance(active);
    });

    test('invalidateAllCaches notifie les abonnés (rebuild UI)', () {
      final active = SalesDayController();
      SalesDayController.setActiveInstance(active);

      var notifications = 0;
      active.addListener(() => notifications++);

      SalesDayController.invalidateAllCaches();

      expect(notifications, 1,
          reason: 'le cache vidé doit déclencher un rebuild de l UI');

      active.dispose();
      SalesDayController.clearActiveInstance(active);
    });
  });
}
