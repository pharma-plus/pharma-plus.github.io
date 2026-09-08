/// ============================================================
/// CALCULS CENTRALISÉS PHARMA+
/// ============================================================
library;

/// Toute l'application utilise CE fichier pour les totaux,
/// remises, bénéfices, seuils de stock et agrégats métier.
/// Interdiction de recopier ces formules dans les widgets.
/// ============================================================
import 'dart:math' as math;

/// Ligne de panier minimale attendue par les helpers de vente.
class SaleLine {
  final double unitPrice;
  final double quantity;
  final double tvaRate; // ex. 0.20
  const SaleLine({
    required this.unitPrice,
    required this.quantity,
    this.tvaRate = 0,
  });

  /// Montant ligne HT/TTC avant remise globale.
  double get lineTotal => unitPrice * quantity;
  double get lineTva => lineTotal * tvaRate;
}

/// Montant réellement déduit par une remise.
/// [discountValue] : valeur saisie ; [isPercent] : % ou montant fixe.
/// Le résultat est plafonné au sous-total (jamais négatif).
double calculateDiscount(
  double subtotal,
  double discountValue, {
  bool isPercent = false,
}) {
  if (discountValue <= 0) return 0;
  final raw = isPercent ? subtotal * (discountValue / 100) : discountValue;
  return math.max(0, math.min(subtotal, raw));
}

/// Résultat complet d'une vente (sous-total, remise, TVA, total).
class SaleTotals {
  final double subtotal;
  final double discount;
  final double tva;
  final double total;
  const SaleTotals({
    required this.subtotal,
    required this.discount,
    required this.tva,
    required this.total,
  });
}

/// Calcul central du total d'une vente :
/// Σ(ligne × qté) − remise = total final (TVA incluse dans les prix).
SaleTotals calculateSaleTotal(
  List<SaleLine> lines, {
  double discountValue = 0,
  bool discountIsPercent = false,
}) {
  final subtotal =
      lines.fold<double>(0, (s, l) => s + l.unitPrice * l.quantity);
  final discount =
      calculateDiscount(subtotal, discountValue, isPercent: discountIsPercent);
  final net = subtotal - discount;
  return SaleTotals(
    subtotal: subtotal,
    discount: discount,
    // Les prix publics marocains (PPV) sont TTC : la part de TVA est
    // extraite proportionnellement à la remise appliquée.
    tva: _includedTva(net, lines, subtotal),
    total: net,
  );
}

/// TVA incluse : pour chaque ligne nette, TVA = TTC − TTC/(1+taux).
double _includedTva(double net, List<SaleLine> lines, double subtotal) {
  if (net <= 0 || subtotal <= 0) return 0;
  var tva = 0.0;
  for (final l in lines) {
    if (l.tvaRate <= 0) continue;
    final netLine = l.lineTotal / subtotal * net;
    tva += netLine - netLine / (1 + l.tvaRate);
  }
  return tva;
}

/// Convention POS / moteur de ventes : prix saisis HORS taxes, la TVA
/// s'ajoute au total (total = Σ prix×qté + TVA − remise). Utilisée pour
/// que l'encart POS du dashboard affiche EXACTEMENT les mêmes montants
/// que le POS complet et que la vente enregistrée.
SaleTotals calculateSaleTotalExcl(
  List<SaleLine> lines, {
  double discountValue = 0,
  bool discountIsPercent = false,
}) {
  final subtotal =
      lines.fold<double>(0, (s, l) => s + l.unitPrice * l.quantity);
  final tvaGross = lines.fold<double>(0, (s, l) => s + l.lineTva);
  final discount =
      calculateDiscount(subtotal + tvaGross, discountValue,
          isPercent: discountIsPercent);
  return SaleTotals(
    subtotal: subtotal,
    discount: discount,
    tva: tvaGross,
    total: subtotal + tvaGross - discount,
  );
}

/// Bénéfice = ventes − coûts d'achat (par ligne : (prix vente − coût) × qté).
double calculateProfit({
  required double revenue,
  required double cost,
}) =>
    revenue - cost;

double calculateProfitFromLines(
  List<({double priceSale, double costPrice, double quantity})> lines,
) =>
    lines.fold<double>(
        0,
        (s, l) =>
            s + (l.priceSale - l.costPrice) * l.quantity);

/// Produits en stock faible : stock ≤ seuil configuré (reorder/min).
int calculateLowStock(
  Iterable<({double stock, double reorderLevel, double minStock})> items,
) =>
    items
        .where((i) =>
            i.stock <= math.max(i.reorderLevel, i.minStock.clamp(0, 1e9)))
        .length;

/// Produits expirés / expirant avant [deadline].
int calculateExpiredProducts(
  Iterable<DateTime?> expiryDates,
  DateTime deadline,
) =>
    expiryDates.where((d) => d != null && d.isBefore(deadline)).length;

/// Somme des ventes du jour (lignes `total` de ventes du jour).
double calculateDailySales(Iterable<double> saleTotalsOfToday) =>
    saleTotalsOfToday.fold(0, (s, v) => s + v);

/// Somme des ventes du mois.
double calculateMonthlySales(Iterable<double> saleTotalsOfMonth) =>
    saleTotalsOfMonth.fold(0, (s, v) => s + v);

/// Agrégats par fournisseur (commandes + total achats).
List<MapEntry<String, ({int orders, double total})>> calculateSupplierTotals(
  Iterable<({String supplierId, double orderTotal})> orders,
) {
  final map = <String, ({int orders, double total})>{};
  for (final o in orders) {
    final cur = map[o.supplierId] ?? (orders: 0, total: 0.0);
    map[o.supplierId] = (
      orders: cur.orders + 1,
      total: cur.total + o.orderTotal,
    );
  }
  return map.entries.toList();
}

/// Agrégats par client (achats + total dépensé).
List<MapEntry<String, ({int purchases, double total})>> calculateCustomerTotals(
  Iterable<({String customerId, double saleTotal})> sales,
) {
  final map = <String, ({int purchases, double total})>{};
  for (final s in sales) {
    final cur = map[s.customerId] ?? (purchases: 0, total: 0.0);
    map[s.customerId] = (
      purchases: cur.purchases + 1,
      total: cur.total + s.saleTotal,
    );
  }
  return map.entries.toList();
}

/// Variation en % entre deux périodes ; null si incomparable.
double? periodVariation(double current, double previous) {
  if (previous == 0) return null;
  return ((current - previous) / previous) * 100;
}

/// ============================================================
/// PAIEMENT ESPÈCES (POS) — monnaie et couverture du total.
/// Source unique : ni le POS ni la feuille de paiement ne
/// recalculent ces valeurs localement.
/// ============================================================

/// Monnaie à rendre = montant reçu − total (0 si reçu ≤ total).
/// Ex. reçu 1200 · total 140 → 1060 MAD.
/// Arrondie au centime pour éviter les résidus flottants.
double calculateChange({required double received, required double total}) {
  if (received <= total) return 0;
  return ((received - total) * 100).roundToDouble() / 100;
}

/// Montant encore dû par le client (0 dès que reçu ≥ total).
double remainingDue({required double received, required double total}) {
  if (received >= total) return 0;
  return ((total - received) * 100).roundToDouble() / 100;
}

/// Le montant reçu couvre-t-il le total ? (tolérance 1 centime)
bool isPaymentSufficient({required double received, required double total}) =>
    received + 0.009 >= total;
