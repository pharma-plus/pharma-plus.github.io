import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _chatController = TextEditingController();
  final _messages = <Map<String, String>>[];
  Map<String, dynamic>? _insights;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _activeTab;

  static const _tabs = [
    ('reorder_soon', Icons.inventory_outlined),
    ('expiring_within_60d', Icons.event_busy_outlined),
    ('no_sales_30d', Icons.speed_outlined),
    ('top_sellers_30d', Icons.trending_up),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ApiClient.instance.get<Map<String, dynamic>>('/ai/insights');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.readableMessage ?? 'Erreur';
      });
      return;
    }
    setState(() {
      _insights = result.data;
      _loading = false;
      _activeTab ??= 'reorder_soon';
    });
  }

  Future<void> _send() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
      _chatController.clear();
    });
    final result = await ApiClient.instance
        .post<Map<String, dynamic>>('/ai/chat', body: {'query': text});
    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'ai',
        'text': result.success
            ? '${result.data?['reply']}'
            : result.error?.readableMessage ?? 'Erreur',
      });
      _sending = false;
    });
  }

  String get locale => context.watch<AuthStore>().locale;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('pharmaAi', locale))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.smart_toy_outlined,
                            size: 56, color: AppColors.warning),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(S.t('retry', locale)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          for (final m in _messages)
                            Align(
                              alignment: m['role'] == 'user'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: m['role'] == 'user'
                                      ? AppColors.greenGradient
                                      : null,
                                  color: m['role'] == 'user'
                                      ? null
                                      : AppColors.turquoise
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: 340),
                                  child: Text('${m['text']}'),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  decoration: InputDecoration(
                                    hintText: S.t('aiAssistant', locale),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: _sending ? null : _send,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            S.t('aiAnalytics', locale),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S.t('aiProductivity', locale),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTabs(),
                          const SizedBox(height: 12),
                          _buildInsightList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (key, icon) in _tabs)
          ChoiceChip(
            avatar: Icon(icon, size: 16),
            label: Text(_tabLabel(key)),
            selected: _activeTab == key,
            onSelected: (_) => setState(() => _activeTab = key),
          ),
      ],
    );
  }

  Widget _buildInsightList() {
    final rows = (_insights?[_activeTab] as List? ?? const []);
    if (rows.isEmpty) {
      return GlassCard(
        child: Text(S.t('noData', locale)),
      );
    }
    return Column(
      children: [
        for (final row in rows.whereType<Map<String, dynamic>>())
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.turquoise),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${row['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _rowValue(row),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _tabLabel(String key) {
    switch (key) {
      case 'reorder_soon':
        return S.t('lowStock', locale);
      case 'expiring_within_60d':
        return S.t('expiring', locale);
      case 'no_sales_30d':
        return S.t('noSales30d', locale);
      case 'top_sellers_30d':
        return S.t('topProducts', locale);
    }
    return key;
  }

  String _rowValue(Map<String, dynamic> row) {
    switch (_activeTab) {
      case 'reorder_soon':
        return '${S.t('stock', locale)}: ${_qty(row['current_stock'])}';
      case 'expiring_within_60d':
        return '${Fmt.shortDate(DateTime.tryParse('${row['expiry_date']}'), locale: locale)} · ${_qty(row['quantity'])}';
      case 'no_sales_30d':
        return '0 vente';
      case 'top_sellers_30d':
        return Fmt.money(double.tryParse('${row['revenue_30d'] ?? 0}') ?? 0);
    }
    return '';
  }

  static String _qty(dynamic v) =>
      Fmt.number(double.tryParse('$v') ?? 0, decimals: 0);
}
