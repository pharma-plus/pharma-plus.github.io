import '../../core/models/medication.dart';

/// Ligne de panier (calculs réutilisés par le récapitulatif).
class CartLine {
  final Medication medication;
  double quantity;
  double unitPrice;
  double discountPercent;

  CartLine({
    required this.medication,
    this.quantity = 1,
    double? unitPrice,
    this.discountPercent = 0,
  }) : unitPrice = unitPrice ?? medication.priceSale;

  double get gross => unitPrice * quantity;
  double get discountAmount => gross * (discountPercent / 100);
  double get tvaRate => medication.tvaRate;
  double get net => gross - discountAmount;
  double get tvaAmount => net * (tvaRate / 100);
  double get total => net + tvaAmount;

  Map<String, dynamic> toPayload() => {
        'medication_id': medication.id,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discountPercent,
      };
}

/// Panier complet avec remise globale.
class Cart {
  final List<CartLine> lines;
  double globalDiscountPercent;

  Cart({List<CartLine>? lines, this.globalDiscountPercent = 0})
      : lines = List<CartLine>.from(lines ?? const []);

  double get subtotal => lines.fold(0, (s, l) => s + l.net);
  double get tvaTotal => lines.fold(0, (s, l) => s + l.tvaAmount);
  double get globalDiscount => subtotal * (globalDiscountPercent / 100);
  double get total => subtotal + tvaTotal - globalDiscount;
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity.round());

  bool get isEmpty => lines.isEmpty;

  void add(Medication medication, {double? quantity, double? unitPrice}) {
    final existing =
        lines.where((l) => l.medication.id == medication.id).firstOrNull;
    if (existing != null) {
      existing.quantity += quantity ?? 1;
    } else {
      lines.add(CartLine(
          medication: medication,
          quantity: quantity ?? 1,
          unitPrice: unitPrice));
    }
  }

  void removeLine(String medicationId) {
    lines.removeWhere((l) => l.medication.id == medicationId);
  }

  void clear() {
    lines.clear();
    globalDiscountPercent = 0;
  }
}
