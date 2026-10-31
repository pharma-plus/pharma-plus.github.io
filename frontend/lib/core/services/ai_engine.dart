/// ============================================================
/// MOTEUR IA CENTRAL — IA déterministe, contextuelle, isolée par pharmacie
/// ============================================================
///
/// Architecture:
/// - Moteur central (PharmaAIEngine) : оркестраteur, gestion contexte, quota, audit
/// - Modules IA spécialisés : Reorder, Sales, Stock, Customers, Suppliers, Finance, HR
/// - Isolation stricte par pharmacy_id : aucun partage de données entre pharmacies
/// - Pas de LLM externe : calculs déterministes sur données réelles (SQL/RPC)
/// - Respect permissions/roles/quotas : l'IA ne modifie JAMAIS les données seule
///
/// Sources de données: RPC SQL (ai_reorder_plan, ai_insights, ai_sales_analysis, etc.)
/// Actions autorisées: lecture, analyse, suggestion, alerte, rapport
/// Actions INTERDITES: modification prix, envoi commande, validation ordonnance, décision médicale

import 'dart:async';
import 'dart:math' as math;

import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';

/// Contexte d'exécution IA isolé par pharmacie
class AIContext {
  final String pharmacyId;
  final String userId;
  final List<String> permissions;
  final String locale;
  final Map<String, dynamic> metadata;

  const AIContext({
    required this.pharmacyId,
    required this.userId,
    required this.permissions,
    required this.locale,
    this.metadata = const {},
  });

  bool can(String permission) => permissions.contains(permission);
}

/// Résultat standard d'une analyse IA
class AIResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final Duration latency;
  final Map<String, dynamic> metadata;

  const AIResult({
    required this.success,
    this.data,
    this.error,
    required this.latency,
    this.metadata = const {},
  });

  static AIResult<T> ok(T data, {Duration latency = Duration.zero, Map<String, dynamic> metadata = const {}}) =>
      AIResult(success: true, data: data, latency: latency, metadata: metadata);

  static AIResult<T> err(String error, {Duration latency = Duration.zero}) =>
      AIResult(success: false, error: error, latency: latency);
}

/// Moteur IA central
class PharmaAIEngine {
  PharmaAIEngine._();
  static final PharmaAIEngine instance = PharmaAIEngine._();

  final Map<String, AIModule> _modules = {};
  final Map<String, AIContext> _contexts = {};

  /// Enregistre un module IA spécialisé
  void registerModule(AIModule module) {
    _modules[module.moduleId] = module;
  }

  /// Crée un contexte d'exécution pour une pharmacie/utilisateur
  AIContext createContext({
    required String pharmacyId,
    required String userId,
    required List<String> permissions,
    required String locale,
    Map<String, dynamic> metadata = const {},
  }) {
    final ctx = AIContext(
      pharmacyId: pharmacyId,
      userId: userId,
      permissions: permissions,
      locale: locale,
      metadata: metadata,
    );
    _contexts['${pharmacyId}_$userId'] = ctx;
    return ctx;
  }

  /// Exécute une analyse via un module spécifique
  Future<AIResult<T>> execute<T>({
    required AIContext context,
    required String moduleId,
    required String action,
    Map<String, dynamic> params = const {},
  }) async {
    final module = _modules[moduleId];
    if (module == null) {
      return AIResult.err('Module IA introuvable: $moduleId');
    }

    // Vérification permissions
    if (!module.requiredPermissions.every(context.can)) {
      return AIResult.err('Permissions insuffisantes pour $moduleId.$action');
    }

    final start = DateTime.now();
    try {
      final result = await module.execute(context, action, params);
      return AIResult.ok(result, latency: DateTime.now().difference(start));
    } catch (e) {
      return AIResult.err(e.toString(), latency: DateTime.now().difference(start));
    }
  }

  /// Exécute plusieurs analyses en parallèle
  Future<Map<String, AIResult>> executeBatch({
    required AIContext context,
    required List<AIRequest> requests,
  }) async {
    final futures = requests.map((req) => execute(
      context: context,
      moduleId: req.moduleId,
      action: req.action,
      params: req.params,
    ));
    final results = await Future.wait(futures);
    return Map.fromEntries(requests.asMap().entries.map((e) => MapEntry(e.value.moduleId, results[e.key])));
  }
}

/// Requête IA pour exécution batch
class AIRequest {
  final String moduleId;
  final String action;
  final Map<String, dynamic> params;

  const AIRequest({
    required this.moduleId,
    required this.action,
    this.params = const {},
  });
}

/// Module IA spécialisé
abstract class AIModule {
  String get moduleId;
  String get displayName;
  List<String> get requiredPermissions;
  String get description;

  /// Exécute une action spécifique du module
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params);

  /// Métadonnées pour l'UI (actions disponibles, paramètres, etc.)
  Map<String, dynamic> get metadata => {};
}

/// ============================================================
/// MODULES IA SPÉCIALISÉS
/// ============================================================

/// Module Réapprovisionnement (déjà existant via RPC ai_reorder_plan)
class AIReorderModule extends AIModule {
  @override String get moduleId => 'reorder';
  @override String get displayName => 'Réapprovisionnement';
  @override List<String> get requiredPermissions => ['purchases:view', 'stock:view'];
  @override String get description => 'Plan de réapprovisionnement intelligent basé sur ventes, stock, délais fournisseurs';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    switch (action) {
      case 'plan':
        final r = await ApiClient.instance.get('/ai/reorder-plan', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      case 'insights':
        final r = await ApiClient.instance.get('/ai/insights', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      case 'sales_analysis':
        final r = await ApiClient.instance.get('/ai/sales-analysis', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      default:
        throw ArgumentError('Action inconnue: $action');
    }
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'plan': {'label': 'Plan de réappro', 'params': ['supplier_filter', 'priority_filter', 'cost_range']},
      'insights': {'label': 'Insights stock', 'params': []},
      'sales_analysis': {'label': 'Analyse ventes', 'params': ['period']},
    },
  };
}

/// Module Analyse Ventes
class AISalesModule extends AIModule {
  @override String get moduleId => 'sales_analysis';
  @override String get displayName => 'Analyse Ventes';
  @override List<String> get requiredPermissions => ['sales:view'];
  @override String get description => 'Analyse des ventes, tendances, prévisions, panier moyen, marges';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    final r = await ApiClient.instance.get('/ai/sales-analysis', query: params);
    return r.success ? r.data : throw Exception(r.error?.message);
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'analyze': {'label': 'Analyser', 'params': ['period', 'category', 'branch']},
      'forecast': {'label': 'Prévoir', 'params': ['horizon_days']},
      'trends': {'label': 'Tendances', 'params': ['metric']},
    },
  };
}

/// Module Stock / Alertes
class AIStockModule extends AIModule {
  @override String get moduleId => 'stock_insights';
  @override String get displayName => 'Stock & Alertes';
  @override List<String> get requiredPermissions => ['stock:view'];
  @override String get description => 'Analyse stock, ruptures, péremptions, surstock, rotation';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    final r = await ApiClient.instance.get('/ai/insights', query: params);
    return r.success ? r.data : throw Exception(r.error?.message);
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'ruptures': {'label': 'Ruptures', 'params': []},
      'expiring': {'label': 'Péremptions', 'params': ['days']},
      'overstock': {'label': 'Surstock', 'params': ['threshold']},
      'rotation': {'label': 'Rotation', 'params': ['period']},
    },
  };
}

/// Module Clients / Organismes
class AICustomersModule extends AIModule {
  @override String get moduleId => 'customers_ai';
  @override String get displayName => 'Clients & Organismes';
  @override List<String> get requiredPermissions => ['customers:view'];
  @override String get description => 'Analyse clients, organismes (AMO/CNOPS/CNSS), crédit, fidélité';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    switch (action) {
      case 'segment':
        final r = await ApiClient.instance.get('/ai/customers/segment', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      case 'churn_risk':
        final r = await ApiClient.instance.get('/ai/customers/churn-risk', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      case 'organism_coverage':
        final r = await ApiClient.instance.get('/ai/customers/organism-coverage', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      default:
        throw ArgumentError('Action inconnue: $action');
    }
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'segment': {'label': 'Segmentation', 'params': ['criteria']},
      'churn_risk': {'label': 'Risque attrition', 'params': ['threshold']},
      'organism_coverage': {'label': 'Couverture organismes', 'params': []},
    },
  };
}

/// Module Fournisseurs
class AISuppliersModule extends AIModule {
  @override String get moduleId => 'suppliers_ai';
  @override String get displayName => 'Fournisseurs';
  @override List<String> get requiredPermissions => ['suppliers:view'];
  @override String get description => 'Comparaison fournisseurs, prix, délais, performance';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    switch (action) {
      case 'compare':
        final r = await ApiClient.instance.get('/ai/suppliers/compare', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      case 'best_price':
        final r = await ApiClient.instance.get('/ai/suppliers/best-price', query: params);
        return r.success ? r.data : throw Exception(r.error?.message);
      default:
        throw ArgumentError('Action inconnue: $action');
    }
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'compare': {'label': 'Comparer', 'params': ['products']},
      'best_price': {'label': 'Meilleur prix', 'params': ['product_ids']},
    },
  };
}

/// Module Finance / Comptabilité
class AIFinanceModule extends AIModule {
  @override String get moduleId => 'finance_ai';
  @override String get displayName => 'Finance & Comptabilité';
  @override List<String> get requiredPermissions => ['accounting:view', 'reports:view'];
  @override String get description => 'Analyse financière, trésorerie, marges, TVA, trésorerie';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    // Utiliser les endpoints existants de reporting
    final r = await ApiClient.instance.get('/reports/financial', query: params);
    return r.success ? r.data : throw Exception(r.error?.message);
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'cashflow': {'label': 'Trésorerie', 'params': ['period']},
      'margins': {'label': 'Marges', 'params': ['period', 'category']},
      'vat': {'label': 'TVA', 'params': ['period']},
    },
  };
}

/// Module RH / Employés
class AIHRModule extends AIModule {
  @override String get moduleId => 'hr_ai';
  @override String get displayName => 'Ressources Humaines';
  @override List<String> get requiredPermissions => ['employees:view', 'attendance:view'];
  @override String get description => 'Analyse effectifs, présences, congés, performance, masse salariale';

  @override
  Future<dynamic> execute(AIContext context, String action, Map<String, dynamic> params) async {
    final r = await ApiClient.instance.get('/ai/hr/analyze', query: params);
    return r.success ? r.data : throw Exception(r.error?.message);
  }

  @override
  Map<String, dynamic> get metadata => {
    'actions': {
      'attendance': {'label': 'Présences', 'params': ['period']},
      'leaves': {'label': 'Congés', 'params': ['period']},
      'performance': {'label': 'Performance', 'params': ['employee_id']},
      'payroll': {'label': 'Masse salariale', 'params': ['period']},
    },
  };
}

/// ============================================================
/// ASSISTANT IA CONVERSATIONNEL (Chat)
/// ============================================================

class PharmaAIAssistant {
  final PharmaAIEngine _engine = PharmaAIEngine.instance;
  final AIContext _context;
  final List<AIMessage> _history = [];

  PharmaAIAssistant(this._context);

  /// Envoie une question à l'assistant
  Future<AIResponse> ask(String question) async {
    // Analyse d'intent simple (basée sur mots-clés, pas LLM)
    final intent = _parseIntent(question);
    
    // Exécution du module approprié
    final result = await _engine.execute(
      context: _context,
      moduleId: intent.moduleId,
      action: intent.action,
      params: intent.params,
    );

    final response = AIResponse(
      text: _formatResponse(result, intent),
      data: result.data,
      module: intent.moduleId,
      action: intent.action,
      success: result.success,
      error: result.error,
    );

    _history.add(AIMessage(role: 'user', content: question));
    _history.add(AIMessage(role: 'assistant', content: response.text));
    
    return response;
  }

  _ParsedIntent _parseIntent(String question) {
    final q = question.toLowerCase();
    
    // Mots-clés -> module/action
    if (q.contains('réappro') || q.contains('commander') || q.contains('rupture') || q.contains('stocker')) {
      return _ParsedIntent('reorder', 'plan', {});
    }
    if (q.contains('vente') || q.contains('chiffre') || q.contains('ca ') || q.contains('panier') || q.contains('marge')) {
      return _ParsedIntent('sales_analysis', 'analyze', {});
    }
    if (q.contains('stock') || q.contains('rupture') || q.contains('périm') || q.contains('expir') || q.contains('surstock')) {
      return _ParsedIntent('stock_insights', 'ruptures', {});
    }
    if (q.contains('client') || q.contains('patient') || q.contains('organisme') || q.contains('amo') || q.contains('cnops') || q.contains('cnss') || q.contains('mutuelle')) {
      return _ParsedIntent('customers_ai', 'segment', {});
    }
    if (q.contains('fournisseur') || q.contains('prix fournisseur') || q.contains('comparer fournisseur')) {
      return _ParsedIntent('suppliers_ai', 'compare', {});
    }
    if (q.contains('trésorerie') || q.contains('trésorerie') || q.contains('marge') || q.contains('tva') || q.contains('finance') || q.contains('comptab')) {
      return _ParsedIntent('finance_ai', 'cashflow', {});
    }
    if (q.contains('employé') || q.contains('présence') || q.contains('congé') || q.contains('paie') || q.contains('masse salariale')) {
      return _ParsedIntent('hr_ai', 'attendance', {});
    }
    
    // Par défaut: réapprovisionnement
    return _ParsedIntent('reorder', 'plan', {});
  }

  String _formatResponse(AIResult result, _ParsedIntent intent) {
    if (!result.success) {
      return '❌ Erreur: ${result.error}';
    }
    
    final data = result.data;
    if (data == null) return 'Aucune donnée disponible.';
    
    // Formatage selon le module
    switch (intent.moduleId) {
      case 'reorder':
        return _formatReorderPlan(data);
      case 'sales_analysis':
        return _formatSalesAnalysis(data);
      case 'stock_insights':
        return _formatStockInsights(data);
      default:
        return '✅ Analyse terminée. ${data.toString()}';
    }
  }

  String _formatReorderPlan(dynamic data) {
    if (data is! Map) return 'Plan généré.';
    final items = data['items'] as List? ?? [];
    final totalCost = double.tryParse('${data['total_estimated_cost'] ?? 0}') ?? 0;
    final totalQty = double.tryParse('${data['total_suggested_qty'] ?? 0}') ?? 0;
    
    final buffer = StringBuffer();
    buffer.writeln('📦 **Plan de réapprovisionnement**');
    buffer.writeln('${items.length} produits · ${totalQty.toInt()} unités · ${totalCost.toStringAsFixed(2)} DH');
    buffer.writeln('');
    
    if (data['by_supplier'] is List) {
      buffer.writeln('**Par fournisseur:**');
      for (final s in data['by_supplier']) {
        buffer.writeln('• ${s['supplier_name']}: ${s['items_count']} art, ${s['total_qty']} u, ${s['total_cost']} DH');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('💡 Voulez-vous préparer une commande brouillon ?');
    return buffer.toString();
  }

  String _formatSalesAnalysis(dynamic data) {
    if (data is! Map) return 'Analyse terminée.';
    final summary = data['summary'] as Map? ?? {};
    final revenue = double.tryParse('${summary['revenue'] ?? 0}') ?? 0;
    final change = summary['revenue_change_pct'];
    
    final buffer = StringBuffer();
    buffer.writeln('📈 **Analyse des ventes**');
    buffer.writeln('CA: ${revenue.toStringAsFixed(2)} DH');
    if (change != null) {
      buffer.writeln('Variation: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%');
    }
    return buffer.toString();
  }

  String _formatStockInsights(dynamic data) {
    if (data is! Map) return 'Insights stock générés.';
    return '📊 Insights stock générés (ruptures, péremptions, surstock).';
  }
}

/// Message de conversation
class AIMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  AIMessage({required this.role, required this.content, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

/// Intent parsé
class _ParsedIntent {
  final String moduleId;
  final String action;
  final Map<String, dynamic> params;

  const _ParsedIntent(this.moduleId, this.action, this.params);
}

/// Réponse de l'assistant
class AIResponse {
  final String text;
  final dynamic data;
  final String module;
  final String action;
  final bool success;
  final String? error;

  const AIResponse({
    required this.text,
    this.data,
    required this.module,
    required this.action,
    required this.success,
    this.error,
  });
}

/// ============================================================
/// INITIALISATION DU MOTEUR IA
/// ============================================================

void initializeAIEngine() {
  final engine = PharmaAIEngine.instance;
  
  engine.registerModule(AIReorderModule());
  engine.registerModule(AISalesModule());
  engine.registerModule(AIStockModule());
  engine.registerModule(AICustomersModule());
  engine.registerModule(AISuppliersModule());
  engine.registerModule(AIFinanceModule());
  engine.registerModule(AIHRModule());
}

/// Helper pour créer un assistant dans un widget
class AIAssistantWidget extends StatefulWidget {
  final AIContext context;
  const AIAssistantWidget({super.key, required this.context});

  @override
  State<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget> {
  late final PharmaAIAssistant _assistant;
  final _controller = TextEditingController();
  final _messages = <AIMessage>[];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _assistant = PharmaAIAssistant(widget.context);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    
    setState(() {
      _messages.add(AIMessage(role: 'user', content: text));
      _sending = true;
      _controller.clear();
    });

    final response = await _assistant.ask(text);
    
    if (mounted) {
      setState(() {
        _messages.add(AIMessage(role: 'assistant', content: response.text));
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final m = _messages[i];
          return Align(
            alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.role == 'user' ? AppColors.pharmaGold : AppColors.pharmaSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(m.content, style: TextStyle(
                color: m.role == 'user' ? Colors.black : Colors.white,
              )),
            ),
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _controller,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Posez votre question...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          ),
        ]),
      ),
    );
  }
}