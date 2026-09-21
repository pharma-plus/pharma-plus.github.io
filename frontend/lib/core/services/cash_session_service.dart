// PHARMA+ — Sessions de caisse : ouverture, journal, fermeture, écart.
// Phases 9-12 : chaque vente est rattachée automatiquement à la session
// ouverte (côté serveur). ÉCART = MONTANT RÉEL − MONTANT THÉORIQUE.
library;

import '../services/api_client.dart';

class CashSessionService {
  static Future<Map<String, dynamic>?> openSession({String? branchId}) async {
    final r = await ApiClient.instance.get(
      '/cash-sessions/open',
      query: branchId != null && branchId.isNotEmpty
          ? {'branchId': branchId}
          : null,
    );
    if (!r.success) return null;
    return r.data as Map<String, dynamic>?;
  }

  static Future<bool> open({
    required String branchId,
    required double initialCash,
    String? notes,
  }) async {
    final r = await ApiClient.instance.post('/cash-sessions', body: {
      'branchId': branchId,
      'initialCash': initialCash,
      if (notes != null) 'notes': notes,
    });
    return r.success;
  }

  static Future<bool> addEvent({
    required String sessionId,
    required String eventType, // entry | exit | refund
    required double amount,
    String method = 'cash',
    String? note,
  }) async {
    final r = await ApiClient.instance.post('/cash-sessions/$sessionId/events',
        body: {
          'eventType': eventType,
          'amount': amount,
          'method': method,
          if (note != null) 'note': note,
        });
    return r.success;
  }

  static Future<Map<String, dynamic>?> close({
    required String sessionId,
    required double countedCash,
    String? notes,
  }) async {
    final r = await ApiClient.instance.post('/cash-sessions/$sessionId/close',
        body: {
          'countedCash': countedCash,
          if (notes != null) 'notes': notes,
        });
    if (!r.success) return null;
    return r.data as Map<String, dynamic>?;
  }
}
