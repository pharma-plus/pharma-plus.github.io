import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/core/models/user.dart';

/// P6 — Statut Super Admin TRI-ÉTAT (contrat serveur) :
///  - `true`  : confirmé par une réponse serveur authentifiée ;
///  - `false` : refusé explicitement par le serveur ;
///  - `null`  : inconnu (champ absent/null, profil local restauré,
///    erreur réseau) → accès CRM refusé jusqu'à confirmation serveur.
///
/// Règles vérifiées ici :
///  - un champ absent/null ne devient JAMAIS une autorisation ;
///  - un ancien `true` stocké localement n'autorise jamais le CRM ;
///  - une réponse serveur incomplète ne fusionne jamais une ancienne
///    autorisation locale ;
///  - aucun type inattendu ne provoque d'exception ni d'élévation.
void main() {
  final base = <String, dynamic>{
    'id': 'u-1',
    'first_name': 'Admin',
    'last_name': 'Test',
    'email': 'admin@pharma.ma',
    'role_id': 'r-1',
  };

  User user(Map<String, dynamic> extra) =>
      User.fromJson(<String, dynamic>{...base, ...extra});

  group('User.fromJson — les quatre cas du contrat admin', () {
    test('champ absent → null (inconnu, accès refusé)', () {
      final u = user({});
      expect(u.isSuperAdminFlag, isNull);
      expect(u.isSuperAdmin, isFalse);
    });

    test('champ null → null (inconnu, accès refusé)', () {
      final u = user({'is_super_admin': null});
      expect(u.isSuperAdminFlag, isNull);
      expect(u.isSuperAdmin, isFalse);
    });

    test('false → false (refus explicite serveur)', () {
      final u = user({'is_super_admin': false});
      expect(u.isSuperAdminFlag, isFalse);
      expect(u.isSuperAdmin, isFalse);
    });

    test('true → true (confirmation explicite serveur)', () {
      final u = user({'is_super_admin': true});
      expect(u.isSuperAdminFlag, isTrue);
      expect(u.isSuperAdmin, isTrue);
    });

    test('clé camelCase isSuperAdmin supportée (contrat alternatif)', () {
      final u = user({'is_super_admin': null, 'isSuperAdmin': true});
      expect(u.isSuperAdminFlag, isTrue);
    });

    test('type inattendu (1, "true") → inconnu, jamais une exception', () {
      expect(user({'is_super_admin': 1}).isSuperAdminFlag, isNull);
      expect(user({'is_super_admin': 'true'}).isSuperAdminFlag, isNull);
      expect(user({'is_super_admin': 1}).isSuperAdmin, isFalse);
    });
  });

  group('Restauration locale (ancien pmg_user) — sans autorisation', () {
    test('ancien profil local true → sans confirmation → refus', () {
      final legacy = user({'is_super_admin': true, 'permissions': ['stock:view']});
      final restored = legacy.withoutAdminConfirmation();
      expect(restored.isSuperAdminFlag, isNull);
      expect(restored.isSuperAdmin, isFalse);
      // Les informations non sensibles sont conservées pour l'affichage.
      expect(restored.permissions, contains('stock:view'));
      expect(restored.email, 'admin@pharma.ma');
    });

    test('round-trip toJson/fromJson : null reste null (jamais un false)', () {
      final unknown = user({}).withoutAdminConfirmation();
      final decoded = User.fromJson(
          jsonDecode(jsonEncode(unknown.toJson())) as Map<String, dynamic>);
      expect(decoded.isSuperAdminFlag, isNull);
      expect(decoded.isSuperAdmin, isFalse);
    });

    test('round-trip toJson/fromJson : true confirmé reste true', () {
      final confirmed = user({'is_super_admin': true});
      final decoded = User.fromJson(
          jsonDecode(jsonEncode(confirmed.toJson())) as Map<String, dynamic>);
      expect(decoded.isSuperAdminFlag, isTrue);
    });
  });

  group('applyServerConfirmation — synchronisation _doInit', () {
    final stored = user({'is_super_admin': true, 'permissions': ['stock:view']});

    test('réponse serveur complète false → remplacement immédiat', () {
      final server = user({'is_super_admin': false});
      final merged = stored.applyServerConfirmation(server);
      expect(merged.isSuperAdminFlag, isFalse);
      expect(merged.isSuperAdmin, isFalse);
    });

    test('réponse serveur complète true → confirmation serveur', () {
      final server = user({'is_super_admin': true});
      final merged = stored.applyServerConfirmation(server);
      expect(merged.isSuperAdminFlag, isTrue);
      expect(identical(merged, server), isTrue);
    });

    test('réponse serveur incomplète (champ absent) → profil local sans confirmation', () {
      final incomplete = user({}); // /auth/me amputé (ancien backend local)
      final merged = stored.applyServerConfirmation(incomplete);
      expect(merged.isSuperAdminFlag, isNull);
      expect(merged.isSuperAdmin, isFalse);
      // Jamais de fusion d'une ancienne autorisation locale.
      expect(identical(merged, stored), isFalse);
    });

    test('pas de réponse serveur (erreur réseau, null) → profil local sans confirmation', () {
      final merged = stored.applyServerConfirmation(null);
      expect(merged.isSuperAdminFlag, isNull);
      expect(merged.isSuperAdmin, isFalse);
      expect(merged.permissions, contains('stock:view'));
    });
  });

  group('Autorisation CRM (équivalent RootGate: auth.user?.isSuperAdmin == true)', () {
    test('uniquement isSuperAdminFlag == true autorise', () {
      bool crmVisible(User? u) => u?.isSuperAdmin == true;
      expect(crmVisible(user({'is_super_admin': true})), isTrue);
      expect(crmVisible(user({'is_super_admin': false})), isFalse);
      expect(crmVisible(user({})), isFalse); // inconnu → refus
      expect(crmVisible(null), isFalse);
    });
  });
}
