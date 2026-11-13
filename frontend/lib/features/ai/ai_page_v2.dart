import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/ai_engine.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../shell/shell_nav.dart';

/// Page IA — Centre intelligent PHARMA+
class AIPageV2 extends StatefulWidget {
  const AIPageV2({super.key});

  @override
  State<AIPageV2> createState() => _AIPageV2State();
}

class _AIPageV2State extends State<AIPageV2> {
  late final PharmaAIAssistant _assistant;
  final _controller = TextEditingController();
  final _messages = <AIMessage>[];
  bool _sending = false;
  AIContext? _context;

  // Centre de contrôle : insights et réapprovisionnement
  Map<String, dynamic>? _insights;
  Map<String, dynamic>? _reorderPlan;
  bool _loadingInsights = true;
  String? _insightsError;

  @override
  void initState() {
    super.initState();
    final auth = AuthStore.instance;
    _context = AIContext(
      pharmacyId: auth.user?.pharmacyId ?? '',
      userId: auth.user?.id ?? '',
      permissions: auth.permissions.toList(),
      locale: auth.locale,
    );
    _assistant = PharmaAIAssistant(_context!);
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() { _loadingInsights = true; _insightsError = null; });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/ai/insights'),
        ApiClient.instance.get('/ai/reorder-plan'),
      ]);
      if (!mounted) return;
      setState(() {
        _insights = results[0].success ? results[0].data as Map<String, dynamic>? : null;
        _reorderPlan = results[1].success ? results[1].data as Map<String, dynamic>? : null;
        _loadingInsights = false;
        if (!results[0].success && !results[1].success) {
          _insightsError = 'Impossible de charger les insights. Vérifiez votre connexion.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() { _loadingInsights = false; _insightsError = 'Erreur: $e'; });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final locale = context.watch<AuthStore>().locale;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('pharmaAi', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
            tooltip: 'Actualiser les insights',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => setState(() => _messages.clear()),
            tooltip: 'Effacer la conversation',
          ),
        ],
      ),
      body: Column(children: [
        // Centre de contrôle : insights et alertes
        if (_loadingInsights)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_insightsError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_insightsError!, style: const TextStyle(color: Colors.red)),
          )
        else
          _buildInsightsPanel(context),
        const Divider(height: 1),
        // Conversation
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
                hintText: S.t('aiAssistant', locale),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildInsightsPanel(BuildContext context) {
    final insights = _insights;
    final reorder = _reorderPlan;
    final items = (reorder?['items'] as List?) ?? [];
    final urgentCount = items.where((i) => i['priority'] == 'urgent' || i['priority'] == 'high').length;

    return Container(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _insightCard(
            icon: Icons.warning_amber_rounded,
            label: 'Ruptures / sous seuil',
            value: '${items.length}',
            color: items.isEmpty ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          _insightCard(
            icon: Icons.priority_high,
            label: 'Urgents',
            value: '$urgentCount',
            color: urgentCount == 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          _insightCard(
            icon: Icons.local_shipping_outlined,
            label: 'Réappro. suggérés',
            value: '${reorder?['total_suggested_qty'] ?? 0}',
            color: AppColors.pharmaGold,
          ),
          const SizedBox(width: 8),
          _insightCard(
            icon: Icons.calendar_today,
            label: 'Périm. < 60j',
            value: '${(insights?['expiring_within_60d'] as List?)?.length ?? 0}',
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          _insightCard(
            icon: Icons.trending_down,
            label: 'Sans vente 30j',
            value: '${(insights?['no_sales_30d'] as List?)?.length ?? 0}',
            color: Colors.grey,
          ),
        ]),
      ),
    );
  }

  Widget _insightCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
