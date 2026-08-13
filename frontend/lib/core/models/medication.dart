/// Médicament (entité catalogue, sous-ensemble utilisé par POS & stock).
class Medication {
  final String id;
  final String name;
  final String? dci;
  final String? genericName;
  final String? dosage;
  final String? form;
  final String? presentation;
  final String? photoUrl;
  final String? barcodeEan13;
  final double pricePurchase;
  final double priceSale;
  final double tvaRate;
  final bool prescriptionRequired;
  final double reorderLevel;
  final double minStock;
  final String status;
  final double? stockQuantity;
  /// Emplacement en pharmacie : A-03-02-05 (Rayon-Étagère-Niveau-Case)
  final String? locationId;
  final String? aisle;
  final String? shelf;
  final String? level;
  final String? position;

  const Medication({
    required this.id,
    required this.name,
    this.dci,
    this.genericName,
    this.dosage,
    this.form,
    this.presentation,
    this.photoUrl,
    this.barcodeEan13,
    this.pricePurchase = 0,
    this.priceSale = 0,
    this.tvaRate = 20,
    this.prescriptionRequired = false,
    this.reorderLevel = 0,
    this.minStock = 0,
    this.status = 'available',
    this.stockQuantity,
    this.locationId,
    this.aisle,
    this.shelf,
    this.level,
    this.position,
  });

  bool get inStock => (stockQuantity ?? 0) > 0;
  bool get isLowStock => (stockQuantity ?? 0) <= minStock;

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        dci: json['dci'] as String?,
        genericName:
            json['generic_name'] as String? ?? json['genericName'] as String?,
        dosage: json['dosage'] as String?,
        form: json['form'] as String?,
        presentation: json['presentation'] as String?,
        photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
        barcodeEan13:
            json['barcode_ean13'] as String? ?? json['barcodeEan13'] as String?,
        pricePurchase: _d(json['price_purchase'] ?? json['pricePurchase']),
        priceSale: _d(json['price_sale'] ?? json['priceSale']),
        tvaRate: _d(json['tva_rate'] ?? json['tvaRate'], 20),
        prescriptionRequired: json['prescription_required'] as bool? ??
            json['prescriptionRequired'] as bool? ??
            false,
        reorderLevel: _d(json['reorder_level'] ?? json['reorderLevel']),
        minStock: _d(json['min_stock'] ?? json['minStock']),
        status: json['status'] as String? ?? 'available',
        stockQuantity: json['stock_quantity'] != null
            ? _d(json['stock_quantity'])
            : (json['stock'] != null ? _d(json['stock']) : null),
      );

  static double _d(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}
