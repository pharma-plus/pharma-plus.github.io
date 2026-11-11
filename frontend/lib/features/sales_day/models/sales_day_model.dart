/// ============================================================
/// VENTES DU JOUR — Modèles de données (module indépendant)
/// Contrats JSON réellement exposés par l'API officielle :
///   GET /sales/day                → kpis, hourly, payment_breakdown,
///                                    top_products
///   GET /sales/day/transactions   → ventes paginées enrichies
/// Honnêteté des données : un champ absent du payload reste `null` /
///   `indisponible` — JAMAIS remplacé par une valeur inventée.
/// ============================================================

/// Erreur différenciée du module Ventes du jour.
enum SalesDayErrorKind {
  network,
  timeout,
  sessionExpired,
  forbidden,
  serverError,
  validation,
  unknown,
}

class SalesDayFailure {
  final SalesDayErrorKind kind;
  final String message;
  final String technical;

  const SalesDayFailure({
    required this.kind,
    required this.message,
    required this.technical,
  });

  String get userMessage {
    switch (kind) {
      case SalesDayErrorKind.network:
        return 'Connexion impossible — vérifiez votre connexion puis réessayez.';
      case SalesDayErrorKind.timeout:
        return 'Le serveur met trop de temps à répondre. Réessayez.';
      case SalesDayErrorKind.sessionExpired:
        return 'Session expirée — veuillez vous reconnecter.';
      case SalesDayErrorKind.forbidden:
        return 'Accès refusé : votre compte n\'a pas la permission ventes (sales:view).';
      case SalesDayErrorKind.validation:
        return 'Requête invalide — ajustez la période sélectionnée.';
      case SalesDayErrorKind.serverError:
        return 'Erreur serveur — réessayez dans un instant.';
      case SalesDayErrorKind.unknown:
        return message;
    }
  }
}

/// Les 8 KPI métier de la période (tous calculés côté API à partir des
/// données réelles de `sales`).
class SalesDayKpis {
  /// 1. CA brut TTC : Σ total (ventes terminées).
  final double grossRevenue;

  /// 2. CA net HT : Σ (subtotal − discount_total).
  final double netRevenue;

  /// TVA facturée Σ tax_total (info de cohérence, brut = net + TVA).
  final double taxTotal;

  /// 5. Total des remises : Σ discount_total.
  final double discountsTotal;

  /// 3. Nombre de ventes validées (status = completed).
  final int salesCount;

  /// 4. Panier moyen = CA brut / ventes validées (0 si aucune vente).
  final double averageBasket;

  /// 6a. Ventes annulées (status voided/cancelled).
  final int cancelledCount;

  /// 6b. Ventes retournées/refusées remboursées (status returned/refunded).
  final int returnedCount;

  /// 7. Montant encaissé : Σ (paid_amount − change_amount) sur ventes terminées.
  final double paidAmount;

  /// 8. Restant à encaisser : Σ max(total − paid_amount, 0).
  final double outstandingAmount;

  /// Remboursements réels (sale_returns) — null = non disponible.
  final double? refundedAmount;

  /// Coût des marchandises vendues (info marge, exposition honnête).
  final double costTotal;

  /// Toutes les lignes de la fenêtre (tous statuts).
  final int totalRows;

  const SalesDayKpis({
    required this.grossRevenue,
    required this.netRevenue,
    required this.taxTotal,
    required this.discountsTotal,
    required this.salesCount,
    required this.averageBasket,
    required this.cancelledCount,
    required this.returnedCount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.refundedAmount,
    required this.costTotal,
    required this.totalRows,
  });

  factory SalesDayKpis.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) {
      final x = num.tryParse('${v ?? ''}');
      return x?.toDouble() ?? 0;
    }

    return SalesDayKpis(
      grossRevenue: n(j['gross_revenue']),
      netRevenue: n(j['net_revenue']),
      taxTotal: n(j['tax_total']),
      discountsTotal: n(j['discounts_total']),
      salesCount: (n(j['sales_count'])).round(),
      averageBasket: n(j['average_basket']),
      cancelledCount: n(j['cancelled_count']).round(),
      returnedCount: n(j['returned_count']).round(),
      paidAmount: n(j['paid_amount']),
      outstandingAmount: n(j['outstanding_amount']),
      refundedAmount: j['refunded_amount'] == null
          ? null
          : n(j['refunded_amount']),
      costTotal: n(j['cost_total']),
      totalRows: n(j['total_rows']).round(),
    );
  }
}

/// Bucket horaire réel (heure locale de la pharmacie).
class SalesHourBucket {
  final int hour;
  final String label;
  final double revenue;
  final int count;

  const SalesHourBucket({
    required this.hour,
    required this.label,
    required this.revenue,
    required this.count,
  });

  factory SalesHourBucket.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => num.tryParse('${v ?? ''}')?.toDouble() ?? 0;
    return SalesHourBucket(
      hour: n(j['hour']).round(),
      label: '${j['label'] ?? '--:--'}',
      revenue: n(j['revenue']),
      count: n(j['count']).round(),
    );
  }
}

/// Tranche de paiement réelle (détail JSONB ou payment_method fallback).
class SalesPaymentSlice {
  final String method;
  final double amount;
  final int count;

  const SalesPaymentSlice({
    required this.method,
    required this.amount,
    required this.count,
  });

  static String methodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Espèces';
      case 'card':
        return 'Carte bancaire';
      case 'mobile':
        return 'Mobile / Wallet';
      case 'mixed':
        return 'Paiement mixte';
      case 'credit':
        return 'Crédit';
      case 'none':
        return 'Non spécifié';
      default:
        return m;
    }
  }

  String get label => methodLabel(method);

  factory SalesPaymentSlice.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => num.tryParse('${v ?? ''}')?.toDouble() ?? 0;
    return SalesPaymentSlice(
      method: '${j['method'] ?? ''}',
      amount: n(j['amount']),
      count: n(j['count']).round(),
    );
  }
}

/// Produit réel d'un classement (sale_items × medications).
/// [sortBy] indique le critère de classement : 'qty', 'rev' ou 'profit'.
class SalesProductRank {
  final String name;
  final String? dosage;
  final double quantity;
  final double revenue;
  final double profit;
  final double marginPct;
  final int sales;
  final String sortBy;

  const SalesProductRank({
    required this.name,
    required this.dosage,
    required this.quantity,
    required this.revenue,
    required this.profit,
    required this.marginPct,
    required this.sales,
    required this.sortBy,
  });

  String get displayName =>
      name.isEmpty ? 'Référence inconnue' : name;

  /// Libellé du critère de classement affiché.
  String get sortLabel {
    switch (sortBy) {
      case 'qty':
        return 'Quantité';
      case 'rev':
        return 'CA';
      case 'profit':
        return 'Bénéfice';
      default:
        return sortBy;
    }
  }

  factory SalesProductRank.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => num.tryParse('${v ?? ''}')?.toDouble() ?? 0;
    return SalesProductRank(
      name: '${j['name'] ?? ''}',
      dosage: j['dosage']?.toString(),
      quantity: n(j['quantity']),
      revenue: n(j['revenue']),
      profit: n(j['profit']),
      marginPct: n(j['marginPct']),
      sales: n(j['sales']).round(),
      sortBy: '${j['sortBy'] ?? 'rev'}',
    );
  }
}

/// Réponse complète de GET /sales/day.
class SalesDayAnalytics {
  final SalesDayKpis kpis;
  final List<SalesHourBucket> hourly;
  final List<SalesPaymentSlice> payments;
  /// Top 10 par quantité vendue.
  final List<SalesProductRank> topProductsQty;
  /// Top 10 par chiffre d'affaires.
  final List<SalesProductRank> topProductsRev;
  /// Top 10 par bénéfice brut.
  final List<SalesProductRank> topProductsProfit;

  const SalesDayAnalytics({
    required this.kpis,
    required this.hourly,
    required this.payments,
    required this.topProductsQty,
    required this.topProductsRev,
    required this.topProductsProfit,
  });

  factory SalesDayAnalytics.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> listOf(Object? raw) =>
        (raw is List ? raw : const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
    final empty = const SalesDayKpis(
      grossRevenue: 0,
      netRevenue: 0,
      taxTotal: 0,
      discountsTotal: 0,
      salesCount: 0,
      averageBasket: 0,
      cancelledCount: 0,
      returnedCount: 0,
      paidAmount: 0,
      outstandingAmount: 0,
      refundedAmount: null,
      costTotal: 0,
      totalRows: 0,
    );
    return SalesDayAnalytics(
      kpis: j['kpis'] is Map
          ? SalesDayKpis.fromJson(Map<String, dynamic>.from(j['kpis'] as Map))
          : empty,
      hourly: listOf(j['hourly']).map(SalesHourBucket.fromJson).toList(),
      payments: listOf(j['payment_breakdown'])
          .map(SalesPaymentSlice.fromJson)
          .toList(),
      topProductsQty:
          listOf(j['top_products_by_qty']).map(SalesProductRank.fromJson).toList(),
      topProductsRev:
          listOf(j['top_products_by_rev']).map(SalesProductRank.fromJson).toList(),
      topProductsProfit:
          listOf(j['top_products_by_profit']).map(SalesProductRank.fromJson).toList(),
    );
  }
}

/// Une transaction de la liste GET /sales/day/transactions.
class SalesTransaction {
  final String id;
  final String number;
  final DateTime? createdAt;
  final String status;
  final String saleType;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
  final double paidAmount;
  final double changeAmount;
  final String? paymentMethod;
  final String? customer;   // absent si indéchiffrable
  final double? itemsCount; // absent si enrichissement indisponible
  final String? userId;     // absent si enrichissement indisponible
  final String? userName;   // absent si enrichissement indisponible

  const SalesTransaction({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.status,
    required this.saleType,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    required this.customer,
    required this.itemsCount,
    required this.userId,
    required this.userName,
  });

  bool get isCompleted => status == 'completed';

  static DateTime? _ts(Object? raw) {
    final s = raw?.toString();
    final d = s == null ? null : DateTime.tryParse(s);
    return d;
  }

  factory SalesTransaction.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => num.tryParse('${v ?? ''}')?.toDouble() ?? 0;
    return SalesTransaction(
      id: '${j['id'] ?? ''}',
      number: '${j['number'] ?? ''}',
      createdAt: _ts(j['created_at']),
      status: '${j['status'] ?? ''}',
      saleType: '${j['sale_type'] ?? ''}',
      subtotal: n(j['subtotal']),
      discountTotal: n(j['discount_total']),
      taxTotal: n(j['tax_total']),
      total: n(j['total']),
      paidAmount: n(j['paid_amount']),
      changeAmount: n(j['change_amount']),
      paymentMethod: j['payment_method']?.toString(),
      customer: j['_customer']?.toString(),
      itemsCount: j['_items_count'] == null
          ? null
          : n(j['_items_count']),
      userId: j['user_id']?.toString(),
      userName: j['_user']?.toString(),
    );
  }

  /// Libellé d'honnêteté du statut (toutes valeurs réelles prises en compte).
  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Terminée';
      case 'returned':
        return 'Retour';
      case 'voided':
        return 'Annulée';
      case 'cancelled':
        return 'Annulée';
      case 'refunded':
        return 'Remboursée';
      case 'pending':
        return 'En attente';
      default:
        return status.isEmpty ? 'Inconnu' : status;
    }
  }
}

/// Page de transactions reçue du serveur.
class SalesTransactionsPage {
  final List<SalesTransaction> rows;
  final int totalServer;
  final int page;
  final int limit;

  const SalesTransactionsPage({
    required this.rows,
    required this.totalServer,
    required this.page,
    required this.limit,
  });

  factory SalesTransactionsPage.fromJson(
    Map<String, dynamic> j, {
    required int page,
    required int limit,
  }) {
    final raw = j['data'];
    final rows = (raw is List ? raw : const [])
        .whereType<Map>()
        .map((m) => SalesTransaction.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final meta = j['meta'] is Map ? Map<String, dynamic>.from(j['meta'] as Map) : const {};
    final total = num.tryParse('${meta['total'] ?? 0}')?.toInt() ?? rows.length;
    return SalesTransactionsPage(
      rows: rows,
      totalServer: total,
      page: num.tryParse('${meta['page'] ?? page}')?.toInt() ?? page,
      limit: num.tryParse('${meta['limit'] ?? limit}')?.toInt() ?? limit,
    );
  }
}
