// PHARMA+ — LOGIQUE METIER PURE DU MODULE STOCK.
// Statut d'une ligne (péremption, rupture, seuil) et filtres d'affichage.
// Fonctions sans dépendance UI : testables unitairement (stock_logic_test).
library;

/// Fenêtre de « péremption proche » utilisée par /reports/stock (90 jours).
const int kExpiringWindowDays = 90;

enum StockStatus { rupture, expired, expiring, low, ok }

/// Statut prioritaire d'une ligne de stock.
/// Priorité : périmé > expire bientôt > rupture > sous seuil > OK.
/// Aucune valeur n'est inventée : sans date de lot, les statuts de
/// péremption ne s'appliquent pas ; sans seuil (> 0), le statut « bas »
/// ne s'applique pas (reorder_level absent = pas de seuil défini).
StockStatus computeStockStatus({
  required double available,
  required double reorderLevel,
  DateTime? expiry,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  if (expiry != null) {
    // Une péremption le jour même est déjà périmée.
    final expDay = DateTime(expiry.year, expiry.month, expiry.day);
    if (!expDay.isAfter(DateTime(ref.year, ref.month, ref.day))) {
      return StockStatus.expired;
    }
    if (expDay.difference(ref).inDays <= kExpiringWindowDays) {
      return StockStatus.expiring;
    }
  }
  if (available <= 0) return StockStatus.rupture;
  if (reorderLevel > 0 && available <= reorderLevel) return StockStatus.low;
  return StockStatus.ok;
}

/// Clés de filtre UI : tous | rupture | low | expiring | expired.
/// `initialFilter` historique (low|expiring|expired) reste accepté.
const Set<String> kStockFilterKeys = {
  'all',
  'rupture',
  'low',
  'expiring',
  'expired'
};

String normalizeStockFilter(String? raw) {
  if (raw == null || raw.isEmpty) return 'all';
  final v = raw.trim().toLowerCase();
  if (v == 'out' || v == 'rupture') return 'rupture';
  if (v == 'low' || v == 'expiring' || v == 'expired') return v;
  return 'all';
}

/// Filtre une liste de lignes par statut. `all` retourne la liste.
List<T> filterStockRows<T>(
  List<T> rows,
  String filter,
  StockStatus Function(T row) statusOf,
) {
  final f = normalizeStockFilter(filter);
  if (f == 'all') return rows;
  final target = switch (f) {
    'rupture' => StockStatus.rupture,
    'low' => StockStatus.low,
    'expiring' => StockStatus.expiring,
    'expired' => StockStatus.expired,
    _ => null,
  };
  if (target == null) return rows;
  return rows.where((r) => statusOf(r) == target).toList();
}

/// Recherche client (nom, détail, lot, code-barres) — jamais de rechargement
/// serveur sur chaque frappe (délégation au filtre local).
bool stockRowMatchesQuery(
  Map<String, dynamic> row,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final name = '${row['medication_name'] ?? ''}'.toLowerCase();
  final detail = '${row['med_detail'] ?? ''}'.toLowerCase();
  final lot = '${row['lot_number'] ?? ''}'.toLowerCase();
  final barcode = '${row['barcode_ean13'] ?? ''}'.toLowerCase();
  return name.contains(q) ||
      detail.contains(q) ||
      lot.contains(q) ||
      barcode.contains(q);
}

/// Libellé FR d'un type de mouvement de stock (12 types de la CHECK DB).
String movementTypeLabel(String type) {
  return switch (type) {
    'purchase_receipt' => 'Réception achat',
    'sale' => 'Vente',
    'sale_return' => 'Retour vente',
    'inventory_in' => 'Inventaire +',
    'inventory_out' => 'Inventaire −',
    'adjustment' => 'Ajustement',
    'transfer_in' => 'Entrée transfert',
    'transfer_out' => 'Sortie transfert',
    'reservation' => 'Réservation',
    'release' => 'Libération',
    'expiry_loss' => 'Perte péremption',
    'write_off' => 'Écriture à zéro',
    _ => type,
  };
}
