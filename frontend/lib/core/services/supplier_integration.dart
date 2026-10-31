/// ============================================================
/// SUPPLIER INTEGRATION HUB — Architecture modulaire
/// Adaptateurs indépendants par partenaire (API REST, OAuth, EDI, CSV, XML)
/// ============================================================

import 'dart:async';
import 'dart:convert';

import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/offline_store.dart';

/// Interface commune pour tous les adaptateurs fournisseurs
abstract class SupplierAdapter {
  /// Identifiant unique du fournisseur (ex: 'ciphar', 'sotex', 'coopharma')
  String get supplierCode;

  /// Nom affiché
  String get displayName;

  /// Type de connexion: rest | oauth | edi | csv | xml
  String get connectionType;

  /// Teste la connectivité (ping / health check)
  Future<SupplierConnectionResult> testConnection();

  /// Synchronise le catalogue (produits, prix, dispo)
  Future<SupplierSyncResult> syncCatalog({
    DateTime? since,
    bool fullSync = false,
  });

  /// Vérifie la disponibilité d'une liste de codes-barres
  Future<Map<String, SupplierStockInfo>> checkStock(List<String> ean13List);

  /// Récupère les prix pour une liste de produits
  Future<Map<String, SupplierPriceInfo>> getPrices(List<String> ean13List);

  /// Passe une commande (retourne numéro de commande fournisseur)
  Future<SupplierOrderResult> placeOrder(SupplierOrderRequest request);

  /// Suit une commande (statut, expédition, livraison)
  Future<SupplierOrderTracking> trackOrder(String supplierOrderId);

  /// Récupère les factures / avoirs
  Future<List<SupplierInvoice>> getInvoices({DateTime? from, DateTime? to});
}

/// Résultat de test de connexion
class SupplierConnectionResult {
  final bool success;
  final String? error;
  final Duration? latency;
  final Map<String, dynamic>? metadata;

  const SupplierConnectionResult({
    required this.success,
    this.error,
    this.latency,
    this.metadata,
  });
}

/// Résultat de synchronisation catalogue
class SupplierSyncResult {
  final bool success;
  final String? error;
  final int productsAdded;
  final int productsUpdated;
  final int productsSkipped;
  final int conflicts;
  final Duration duration;
  final DateTime syncedAt;

  const SupplierSyncResult({
    required this.success,
    this.error,
    required this.productsAdded,
    required this.productsUpdated,
    required this.productsSkipped,
    required this.conflicts,
    required this.duration,
    required this.syncedAt,
  });
}

/// Info stock fournisseur
class SupplierStockInfo {
  final String ean13;
  final int available;
  final int reserved;
  final int incoming;
  final DateTime? nextDelivery;
  final String? warehouse;
  final bool isDiscontinued;

  const SupplierStockInfo({
    required this.ean13,
    required this.available,
    this.reserved = 0,
    this.incoming = 0,
    this.nextDelivery,
    this.warehouse,
    this.isDiscontinued = false,
  });
}

/// Info prix fournisseur
class SupplierPriceInfo {
  final String ean13;
  final double priceHT;
  final double? discountPercent;
  final double? discountAmount;
  final String currency;
  final DateTime validFrom;
  final DateTime? validTo;
  final String? conditions;

  const SupplierPriceInfo({
    required this.ean13,
    required this.priceHT,
    this.discountPercent,
    this.discountAmount,
    this.currency = 'MAD',
    required this.validFrom,
    this.validTo,
    this.conditions,
  });
}

/// Requête de commande fournisseur
class SupplierOrderRequest {
  final String pharmacyId;
  final List<SupplierOrderLine> lines;
  final String? deliveryAddress;
  final DateTime? requestedDate;
  final String? notes;
  final String? internalReference;

  const SupplierOrderRequest({
    required this.pharmacyId,
    required this.lines,
    this.deliveryAddress,
    this.requestedDate,
    this.notes,
    this.internalReference,
  });
}

class SupplierOrderLine {
  final String ean13;
  final int quantity;
  final double? unitPrice;
  final String? supplierRef;

  const SupplierOrderLine({
    required this.ean13,
    required this.quantity,
    this.unitPrice,
    this.supplierRef,
  });
}

/// Résultat de commande
class SupplierOrderResult {
  final bool success;
  final String? error;
  final String? supplierOrderId;
  final DateTime? estimatedDelivery;
  final List<SupplierOrderLineResult> lines;

  const SupplierOrderResult({
    required this.success,
    this.error,
    this.supplierOrderId,
    this.estimatedDelivery,
    this.lines = const [],
  });
}

class SupplierOrderLineResult {
  final String ean13;
  final int ordered;
  final int confirmed;
  final double? unitPrice;
  final String? status;

  const SupplierOrderLineResult({
    required this.ean13,
    required this.ordered,
    required this.confirmed,
    this.unitPrice,
    this.status,
  });
}

/// Suivi commande
class SupplierOrderTracking {
  final String supplierOrderId;
  final String status; // pending | confirmed | shipped | delivered | cancelled
  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? trackingNumber;
  final String? carrier;
  final List<SupplierTrackingEvent> events;

  const SupplierOrderTracking({
    required this.supplierOrderId,
    required this.status,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.trackingNumber,
    this.carrier,
    this.events = const [],
  });
}

class SupplierTrackingEvent {
  final DateTime timestamp;
  final String status;
  final String? location;
  final String? description;

  const SupplierTrackingEvent({
    required this.timestamp,
    required this.status,
    this.location,
    this.description,
  });
}

class SupplierInvoice {
  final String invoiceNumber;
  final DateTime date;
  final double amountHT;
  final double amountTTC;
  final String status; // draft | validated | paid | cancelled
  final String? pdfUrl;

  const SupplierInvoice({
    required this.invoiceNumber,
    required this.date,
    required this.amountHT,
    required this.amountTTC,
    required this.status,
    this.pdfUrl,
  });
}

/// ============================================================
/// REGISTRE CENTRAL — Gestion des adaptateurs enregistrés
/// ============================================================

class SupplierIntegrationHub {
  SupplierIntegrationHub._();
  static final SupplierIntegrationHub instance = SupplierIntegrationHub._();

  final Map<String, SupplierAdapter> _adapters = {};
  final Map<String, SupplierAdapterConfig> _configs = {};

  /// Enregistre un adaptateur
  void register(SupplierAdapter adapter, SupplierAdapterConfig config) {
    _adapters[adapter.supplierCode] = adapter;
    _configs[adapter.supplierCode] = config;
  }

  /// Récupère un adaptateur par code
  SupplierAdapter? get(String supplierCode) => _adapters[supplierCode];

  /// Liste des fournisseurs configurés
  List<SupplierAdapterConfig> get configured => _configs.values.toList();

  /// Vérifie si un fournisseur est configuré et actif
  bool isConfigured(String supplierCode) => _configs.containsKey(supplierCode) && _configs[supplierCode]!.enabled;

  /// Synchronise tous les fournisseurs actifs
  Future<Map<String, SupplierSyncResult>> syncAllActive({DateTime? since}) async {
    final results = <String, SupplierSyncResult>{};
    for (final config in _configs.values.where((c) => c.enabled)) {
      final adapter = _adapters[config.supplierCode];
      if (adapter != null) {
        try {
          results[config.supplierCode] = await adapter.syncCatalog(since: since);
        } catch (e) {
          results[config.supplierCode] = SupplierSyncResult(
            success: false,
            error: e.toString(),
            productsAdded: 0,
            productsUpdated: 0,
            productsSkipped: 0,
            conflicts: 0,
            duration: Duration.zero,
            syncedAt: DateTime.now(),
          );
        }
      }
    }
    return results;
  }
}

/// Configuration d'un adaptateur fournisseur
class SupplierAdapterConfig {
  final String supplierCode;
  final String displayName;
  final bool enabled;
  final Map<String, dynamic> credentials; // API keys, OAuth tokens, etc.
  final Map<String, dynamic> settings; // Mapping champs, filtres, etc.
  final Duration syncInterval;
  final DateTime? lastSync;

  const SupplierAdapterConfig({
    required this.supplierCode,
    required this.displayName,
    this.enabled = true,
    this.credentials = const {},
    this.settings = const {},
    this.syncInterval = const Duration(hours: 6),
    this.lastSync,
  });
}

/// ============================================================
/// ADAPTATEURS CONCRETS (Exemples)
/// ============================================================

/// Adaptateur REST générique (OpenAPI / Swagger)
class RestSupplierAdapter implements SupplierAdapter {
  final SupplierAdapterConfig config;
  final ApiClient _api;

  RestSupplierAdapter(this.config) : _api = ApiClient.instance;

  @override
  String get supplierCode => config.supplierCode;

  @override
  String get displayName => config.displayName;

  @override
  String get connectionType => 'rest';

  @override
  Future<SupplierConnectionResult> testConnection() async {
    final start = DateTime.now();
    try {
      // Endpoint de santé typique: GET /health ou GET /api/v1/ping
      final r = await _api.get(config.settings['healthEndpoint'] ?? '/health');
      return SupplierConnectionResult(
        success: r.success,
        error: r.error?.message,
        latency: DateTime.now().difference(start),
      );
    } catch (e) {
      return SupplierConnectionResult(
        success: false,
        error: e.toString(),
        latency: DateTime.now().difference(start),
      );
    }
  }

  @override
  Future<SupplierSyncResult> syncCatalog({DateTime? since, bool fullSync = false}) async {
    final start = DateTime.now();
    int added = 0, updated = 0, skipped = 0, conflicts = 0;

    try {
      final params = <String, dynamic>{'limit': 1000};
      if (!fullSync && since != null) {
        params['updated_since'] = since.toIso8601String();
      }
      if (config.settings['catalogEndpoint'] != null) {
        params['endpoint'] = config.settings['catalogEndpoint'];
      }

      final r = await _api.get(config.settings['catalogEndpoint'] ?? '/api/v1/products', query: params);
      if (!r.success) {
        return SupplierSyncResult(
          success: false, error: r.error?.message,
          productsAdded: 0, productsUpdated: 0, productsSkipped: 0, conflicts: 0,
          duration: DateTime.now().difference(start), syncedAt: DateTime.now(),
        );
      }

      final products = ApiList.of(r.data);
      for (final p in products) {
        // Mapper les champs selon config.settings['fieldMapping']
        final mapped = _mapProduct(p);
        // Upsert en base locale via API PHARMA+
        final result = await _upsertProduct(mapped);
        if (result == 'added') added++;
        else if (result == 'updated') updated++;
        else if (result == 'skipped') skipped++;
        else conflicts++;
      }

      return SupplierSyncResult(
        success: true, productsAdded: added, productsUpdated: updated,
        productsSkipped: skipped, conflicts: conflicts,
        duration: DateTime.now().difference(start), syncedAt: DateTime.now(),
      );
    } catch (e) {
      return SupplierSyncResult(
        success: false, error: e.toString(),
        productsAdded: 0, productsUpdated: 0, productsSkipped: 0, conflicts: 0,
        duration: DateTime.now().difference(start), syncedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> _mapProduct(Map<String, dynamic> src) {
    final mapping = config.settings['fieldMapping'] ?? {};
    return {
      'ean13': src[mapping['ean13'] ?? 'ean13'],
      'name': src[mapping['name'] ?? 'name'],
      'dci': src[mapping['dci'] ?? 'dci'],
      'dosage': src[mapping['dosage'] ?? 'dosage'],
      'form': src[mapping['form'] ?? 'form'],
      'presentation': src[mapping['presentation'] ?? 'presentation'],
      'laboratory': src[mapping['laboratory'] ?? 'laboratory'],
      'priceHT': (src[mapping['priceHT'] ?? 'price'] as num?)?.toDouble() ?? 0,
      'stock': (src[mapping['stock'] ?? 'stock'] as num?)?.toInt() ?? 0,
      'supplierRef': src[mapping['supplierRef'] ?? 'reference'],
    };
  }

  Future<String> _upsertProduct(Map<String, dynamic> product) async {
    // Vérifier si existe par EAN-13
    final existing = await ApiClient.instance.get(
      '/catalog/medications/barcode/${product['ean13']}',
    );
    if (existing.success && existing.data != null) {
      // UPDATE
      await ApiClient.instance.put(
        '/catalog/medications/${existing.data['id']}',
        body: product,
      );
      return 'updated';
    } else {
      // INSERT
      await ApiClient.instance.post('/catalog/medications', body: product);
      return 'added';
    }
  }

  @override
  Future<Map<String, SupplierStockInfo>> checkStock(List<String> ean13List) async {
    final result = <String, SupplierStockInfo>{};
    final chunked = <List<String>>[];
    for (var i = 0; i < ean13List.length; i += 100) {
      chunked.add(ean13List.sublist(i, (i + 100).clamp(0, ean13List.length)));
    }
    for (final chunk in chunked) {
      final r = await _api.get(
        config.settings['stockEndpoint'] ?? '/api/v1/stock',
        query: {'ean13': chunk.join(',')},
      );
      if (r.success && r.data is List) {
        for (final item in r.data) {
          if (item is Map) {
            result[item['ean13']] = SupplierStockInfo(
              ean13: item['ean13'],
              available: (item['available'] as num?)?.toInt() ?? 0,
              reserved: (item['reserved'] as num?)?.toInt() ?? 0,
              incoming: (item['incoming'] as num?)?.toInt() ?? 0,
              nextDelivery: item['nextDelivery'] != null
                  ? DateTime.tryParse(item['nextDelivery']) : null,
            );
          }
        }
      }
    }
    return result;
  }

  @override
  Future<Map<String, SupplierPriceInfo>> getPrices(List<String> ean13List) async {
    final result = <String, SupplierPriceInfo>{};
    final chunked = <List<String>>[];
    for (var i = 0; i < ean13List.length; i += 100) {
      chunked.add(ean13List.sublist(i, (i + 100).clamp(0, ean13List.length)));
    }
    for (final chunk in chunked) {
      final r = await _api.get(
        config.settings['priceEndpoint'] ?? '/api/v1/prices',
        query: {'ean13': chunk.join(',')},
      );
      if (r.success && r.data is List) {
        for (final item in r.data) {
          if (item is Map) {
            result[item['ean13']] = SupplierPriceInfo(
              ean13: item['ean13'],
              priceHT: (item['price'] as num?)?.toDouble() ?? 0,
              discountPercent: (item['discount'] as num?)?.toDouble(),
              currency: item['currency'] as String? ?? 'MAD',
              validFrom: DateTime.tryParse(item['validFrom']) ?? DateTime.now(),
              validTo: item['validTo'] != null ? DateTime.tryParse(item['validTo']) : null,
            );
          }
        }
      }
    }
    return result;
  }

  @override
  Future<SupplierOrderResult> placeOrder(SupplierOrderRequest request) async {
    final body = {
      'pharmacyId': request.pharmacyId,
      'lines': request.lines.map((l) => {
        'ean13': l.ean13,
        'quantity': l.quantity,
        'unitPrice': l.unitPrice,
        'supplierRef': l.supplierRef,
      }).toList(),
      'deliveryAddress': request.deliveryAddress,
      'requestedDate': request.requestedDate?.toIso8601String(),
      'notes': request.notes,
      'internalReference': request.internalReference,
    };
    final r = await _api.post(
      config.settings['orderEndpoint'] ?? '/api/v1/orders',
      body: body,
    );
    if (!r.success) {
      return SupplierOrderResult(success: false, error: r.error?.message);
    }
    final data = r.data as Map?;
    return SupplierOrderResult(
      success: true,
      supplierOrderId: data?['orderId']?.toString(),
      estimatedDelivery: data?['estimatedDelivery'] != null
          ? DateTime.tryParse(data!['estimatedDelivery']) : null,
      lines: (data?['lines'] as List?)?.map((l) => SupplierOrderLineResult(
        ean13: l['ean13'],
        ordered: l['quantity'],
        confirmed: l['confirmed'],
        unitPrice: (l['unitPrice'] as num?)?.toDouble(),
        status: l['status'],
      )).toList() ?? [],
    );
  }

  @override
  Future<SupplierOrderTracking> trackOrder(String supplierOrderId) async {
    final r = await _api.get(
      '${config.settings['orderEndpoint'] ?? '/api/v1/orders'}/$supplierOrderId/tracking',
    );
    if (!r.success) {
      return SupplierOrderTracking(
        supplierOrderId: supplierOrderId,
        status: 'unknown',
        events: [],
      );
    }
    final data = r.data as Map?;
    return SupplierOrderTracking(
      supplierOrderId: supplierOrderId,
      status: data?['status'] ?? 'unknown',
      confirmedAt: data?['confirmedAt'] != null ? DateTime.tryParse(data!['confirmedAt']) : null,
      shippedAt: data?['shippedAt'] != null ? DateTime.tryParse(data!['shippedAt']) : null,
      deliveredAt: data?['deliveredAt'] != null ? DateTime.tryParse(data!['deliveredAt']) : null,
      trackingNumber: data?['trackingNumber'],
      carrier: data?['carrier'],
      events: (data?['events'] as List?)?.map((e) => SupplierTrackingEvent(
        timestamp: DateTime.tryParse(e['timestamp']) ?? DateTime.now(),
        status: e['status'],
        location: e['location'],
        description: e['description'],
      )).toList() ?? [],
    );
  }

  @override
  Future<List<SupplierInvoice>> getInvoices({DateTime? from, DateTime? to}) async {
    final query = <String, dynamic>{};
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    final r = await _api.get(
      config.settings['invoiceEndpoint'] ?? '/api/v1/invoices',
      query: query,
    );
    if (!r.success || r.data is! List) return [];
    return (r.data as List).map((item) => SupplierInvoice(
      invoiceNumber: item['invoiceNumber'],
      date: DateTime.tryParse(item['date']) ?? DateTime.now(),
      amountHT: (item['amountHT'] as num?)?.toDouble() ?? 0,
      amountTTC: (item['amountTTC'] as num?)?.toDouble() ?? 0,
      status: item['status'] ?? 'unknown',
      pdfUrl: item['pdfUrl'],
    )).toList();
  }
}

/// Adaptateur CSV (import fichier)
class CsvSupplierAdapter implements SupplierAdapter {
  final SupplierAdapterConfig config;

  CsvSupplierAdapter(this.config);

  @override String get supplierCode => config.supplierCode;
  @override String get displayName => config.displayName;
  @override String get connectionType => 'csv';

  @override Future<SupplierConnectionResult> testConnection() async =>
      const SupplierConnectionResult(success: true);

  @override Future<SupplierSyncResult> syncCatalog({DateTime? since, bool fullSync = false}) async {
    // Implémentation: lecture fichier CSV/Excel, parsing, upsert
    return const SupplierSyncResult(
      success: true, productsAdded: 0, productsUpdated: 0,
      productsSkipped: 0, conflicts: 0,
      duration: Duration.zero, syncedAt: DateTime.now(),
    );
  }

  @override Future<Map<String, SupplierStockInfo>> checkStock(List<String> ean13List) async => {};
  @override Future<Map<String, SupplierPriceInfo>> getPrices(List<String> ean13List) async => {};
  @override Future<SupplierOrderResult> placeOrder(SupplierOrderRequest request) async =>
      const SupplierOrderResult(success: false, error: 'Non supporté');
  @override Future<SupplierOrderTracking> trackOrder(String supplierOrderId) async =>
      SupplierOrderTracking(supplierOrderId: supplierOrderId, status: 'unknown');
  @override Future<List<SupplierInvoice>> getInvoices({DateTime? from, DateTime? to}) async => [];
}

/// ============================================================
/// PAGE FLUTTER — Gestion des fournisseurs connectés
/// ============================================================

// Fichier: frontend/lib/features/suppliers/supplier_connectivity_page.dart
// (À créer - UI de gestion des connexions fournisseurs, test, sync, mapping)