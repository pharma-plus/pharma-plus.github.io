/// ========================================================================
/// PHARMA+ — SUPER ADMIN DASHBOARD
/// ========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/shared/app_search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';

const Color _kSuperAdminDark = Color(0xFF03100D);
const Color _kSuperAdminSurface = Color(0xFF0A1E15);
const Color _kSuperAdminGold = Color(0xFFD9B45C);
const Color _kSuperAdminGoldLight = Color(0xFFE9C873);
const Color _kSuperAdminAccent = Color(0xFF2FB563);

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic>? _alerts;
  List<Map<String, dynamic>> _topPharmacies = [];
  List<Map<String, dynamic>> _subscriptionTrend = [];
  List<Map<String, dynamic>> _revenueTrend = [];
  List<Map<String, dynamic>> _recentPayments = [];
  bool _loading = true;
  String? _error;
  String _selectedPeriod = '30j';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/superadmin/dashboard-stats'),
        ApiClient.instance.get('/superadmin/dashboard-activity', query: {'limit': 10}),
        ApiClient.instance.get('/superadmin/dashboard-alerts'),
        ApiClient.instance.get('/superadmin/dashboard-subscription-trend', query: {'months': 6}),
        ApiClient.instance.get('/superadmin/dashboard-revenue-trend', query: {'months': 6}),
        ApiClient.instance.get('/superadmin/dashboard-top-pharmacies', query: {'limit': 8}),
        ApiClient.instance.get('/superadmin/dashboard-recent-payments', query: {'limit': 10}),
      ]);
      if (!mounted) return;
      // NOTE (P0-2, 07/11) : les routes superadmin/dashboard-* renvoient un
      // objet enveloppé ({trend: [...]}, {top_pharmacies: [...]}, …) alors
      // que le frontend attendait une liste directe. Appeler .map() sur un
      // Map lançait « NoSuchMethodError … Arguments: ['activeUsers', 5] »
      // (Map.map passe (clé, valeur) à la closure). On normalise ici.
      setState(() {
        _stats = (results[0].success ? results[0].data : null) as Map<String, dynamic>?;
        _recentActivity = _extractList(results[1], 'recentSales',
            transform: (e) => {
              ...e,
              'type': e['type'] ?? 'sale',
              'subject': e['subject'] ?? 'Vente #${e['id']}',
            });
        _alerts = (results[2].success ? results[2].data : null) as Map<String, dynamic>?;
        _subscriptionTrend = _extractList(results[3], 'trend',
            transform: (e) => {
              'month': e['month'],
              'count': e['count'] ?? e['new_subscriptions'] ?? 0,
            });
        _revenueTrend = _extractList(results[4], 'trend');
        _topPharmacies = _extractList(results[5], 'top_pharmacies',
            transform: (e) => {
              ...e,
              'name': e['name'] ?? e['pharmacy_name'],
              'city': e['city'] ?? '',
              'license_type': e['license_type'] ?? '',
            });
        _recentPayments = _extractList(results[6], 'recent_payments',
            transform: (e) => {
              ...e,
              'type': e['type'] ?? 'sale',
              'total': e['total'] ?? e['amount'] ?? 0,
              'pharmacy_name': e['pharmacy_name'] ?? e['pharmacy_id'] ?? '',
            });
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Extrait la liste attendue d'une réponse API : accepte une liste directe
  /// ou un objet enveloppé dont un champ [key] contient la liste.
  List<Map<String, dynamic>> _extractList(
    ApiResult<dynamic> r,
    String key, {
    Map<String, dynamic> Function(Map<String, dynamic>)? transform,
  }) {
    if (!r.success) return <Map<String, dynamic>>[];
    dynamic d = r.data;
    if (d is! List && d is Map && d[key] is List) d = d[key];
    if (d is! List) return <Map<String, dynamic>>[];
    return d
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((e) => transform != null ? transform(e) : e)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      appBar: AppBar(
        backgroundColor: _kSuperAdminDark.withValues(alpha: 0.95),
        elevation: 0,
        leading: const ShellBackButton(),
        title: const Text('PHARMA+ Super Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthStore>().signOut()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  color: _kSuperAdminGold,
                  onRefresh: _loadAll,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(locale),
                        const SizedBox(height: 24),
                        _buildKPIRow(locale),
                        const SizedBox(height: 24),
                        _buildChartsRow(locale),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Pharmacies les plus actives', locale),
                        const SizedBox(height: 12),
                        _buildTopPharmaciesTable(locale),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Alertes importantes', locale),
                        const SizedBox(height: 12),
                        _buildAlertsCard(locale),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Activité récente', locale),
                        const SizedBox(height: 12),
                        _buildRecentActivityList(locale),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Paiements récents', locale),
                        const SizedBox(height: 12),
                        _buildRecentPaymentsTable(locale),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _periodChip(String p) {
    final selected = _selectedPeriod == p;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(p, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w600, fontSize: 11)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedPeriod = p),
        selectedColor: _kSuperAdminGold,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildHeader(String locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Tableau de bord Super Admin', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        Row(
          children: ['7j', '30j', '90j', '1a'].map((p) => _periodChip(p)).toList(),
        ),
      ],
    );
  }

  Widget _buildChartsRow(String locale) {
    return Row(
      children: [
        Expanded(
          child: _buildSubscriptionChart(locale),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildRevenueChart(locale),
        ),
      ],
    );
  }

  Widget _buildKPIRow(String locale) {
    final ph = (_stats?['pharmacies'] as Map? ?? {});
    final actLic = _stats?['activeLicenses'] as int? ?? 0;
    final usr = _stats?['users'] as int? ?? 0;
    final sal = _stats?['sales'] as int? ?? 0;
    final rev = _stats?['revenue'] as num? ?? 0;

    final kpis = [
      _KPIData(key: 'pharmacies_total', label: S.t('totalPharmacies', locale), value: '${ph['total'] ?? 0}', icon: Icons.local_pharmacy, color: Colors.white),
      _KPIData(key: 'pharmacies_active', label: S.t('pharmacyActive', locale), value: '${ph['active'] ?? 0}', icon: Icons.check_circle, color: _kSuperAdminAccent),
      _KPIData(key: 'pharmacies_suspended', label: S.t('suspended', locale), value: '${ph['suspended'] ?? 0}', icon: Icons.block, color: Colors.orange),
      _KPIData(key: 'licenses_active', label: S.t('active', locale), value: '$actLic', icon: Icons.verified, color: Colors.green),
      _KPIData(key: 'licenses_expiring', label: 'Expirant 30j', value: '${ph['trial'] ?? 0}', icon: Icons.schedule, color: Colors.orange),
      _KPIData(key: 'users_total', label: S.t('totalUsers', locale), value: '$usr', icon: Icons.people, color: Colors.white),
      _KPIData(key: 'sales_total', label: S.t('totalSales', locale), value: '$sal', icon: Icons.shopping_cart, color: Colors.white),
      _KPIData(key: 'revenue_total', label: S.t('totalRevenue', locale), value: '${_formatMoney(rev)} MAD', icon: Icons.attach_money, color: _kSuperAdminGold),
      _KPIData(key: 'revenue_30d', label: 'Revenu 30j', value: '${_formatMoney(rev)} MAD', icon: Icons.trending_up, color: Colors.green),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 768 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 1.55,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: kpis.length,
          itemBuilder: (_, i) => _KPICard(kpi: kpis[i]),
        );
      },
    );
  }

  String _formatMoney(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  Widget _KPICard({required _KPIData kpi}) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        colors: [_kSuperAdminDark, _kSuperAdminSurface.withValues(alpha: 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kpi.label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              Container(width: 32, height: 32, decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(kpi.icon, color: kpi.color, size: 18)),
            ],
          ),
          const SizedBox(height: 10),
          Text(kpi.value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Container(width: 4, height: 20, decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildSubscriptionChart(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('subscriptionTrendTitle', locale), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: _subscriptionTrend.isEmpty
                ? Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.white70)))
                : _SubscriptionChart(data: _subscriptionTrend),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution des revenus', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: _revenueTrend.isEmpty
                ? Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.white70)))
                : _RevenueChart(data: _revenueTrend),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPharmaciesTable(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top 8', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              TextButton(onPressed: () {}, child: Text('Voir tout', style: TextStyle(color: _kSuperAdminGold, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          ..._topPharmacies.asMap().entries.map((entry) {
            final p = entry.value;
            final rank = entry.key + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: rank == 1 ? AppColors.goldGradient : null,
                      color: rank > 1 ? Colors.white.withValues(alpha: 0.1) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('$rank', style: TextStyle(color: rank == 1 ? Color(0xFF03100D) : Colors.white70, fontWeight: FontWeight.w900, fontSize: 12))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['name'] ?? '—'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${p['city'] ?? ''} · ${p['license_type'] ?? '—'}', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatMoney(p['total_revenue'] ?? 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('${p['nb_sales'] ?? 0} ventes', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(String locale) {
    final expiredVal = _alerts?['expired_licenses'];
    final expired = (expiredVal is List ? expiredVal as List : []);
    final suspendedVal = _alerts?['suspended_pharmacies'] ?? [];
    final suspended = (suspendedVal is List ? suspendedVal as List : []);

    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 8),
                  Text('Alertes actives', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
              Text('${expired.length + suspended.length}', style: const TextStyle(color: _kSuperAdminGold, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          if (expired.isNotEmpty) ...[
            _AlertItem(icon: Icons.warning, color: Colors.orange, title: 'Licence expirée', subtitle: '${expired[0]['pharmacy_name'] ?? ''} — ${expired[0]['type']}'),
            const SizedBox(height: 8),
          ],
          if (suspended.isNotEmpty) ...[
            _AlertItem(icon: Icons.block, color: Colors.red, title: 'Pharmacie suspendue', subtitle: '${suspended[0]['name'] ?? ''}'),
            const SizedBox(height: 8),
          ],
          if (expired.isEmpty && suspended.isEmpty)
            Center(child: Text('Aucune alerte', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._recentActivity.take(8).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: _kSuperAdminAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(_activityIcon(a['type'] as String?), color: _kSuperAdminAccent, size: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a['name'] ?? a['subject'] ?? a['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${a['pharmacy_name'] ?? ''} · ${_formatDate(a['created_at'])}', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _kSuperAdminGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(_typeLabel(a['type'] as String?, locale), style: TextStyle(color: _kSuperAdminGold, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          )).toList(),
          if (_recentActivity.isEmpty) Center(child: Text('Aucune activité', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildRecentPaymentsTable(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._recentPayments.take(8).map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['type'] == 'sale' ? 'Vente #' : 'Achats #'}${p['id']?.toString().substring(0, 8) ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${p['pharmacy_name'] ?? ''} · ${_formatDate(p['created_at'])}', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatMoney(p['total'] ?? 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(p['type'] == 'sale' ? 'Vente' : 'Achat', style: TextStyle(color: p['type'] == 'sale' ? _kSuperAdminAccent : Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          )).toList(),
          if (_recentPayments.isEmpty) Center(child: Text('Aucun paiement récent', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'pharmacy': return Icons.local_pharmacy;
      case 'user': return Icons.person_add;
      case 'sale': return Icons.attach_money;
      case 'ticket': return Icons.support_agent;
      default: return Icons.info;
    }
  }

  String _typeLabel(String? type, String locale) {
    switch (type) {
      case 'pharmacy': return 'Nouvelle';
      case 'sale': return 'Vente';
      case 'user': return 'Utilisateur';
      case 'ticket': return 'Ticket';
      default: return type ?? '';
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.parse(d.toString()));
    } catch (_) {
      return d.toString();
    }
  }
}

class _KPIData {
  final String key;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KPIData({required this.key, required this.label, required this.value, required this.icon, required this.color});
}

class _SubscriptionChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SubscriptionChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final max = data.isNotEmpty ? data.map((e) => (e['count'] as num? ?? 0).toInt()).reduce((a, b) => a > b ? a : b) : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / (data.length * 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...data.asMap().entries.map((entry) {
              final d = entry.value;
              final count = (d['count'] as num? ?? 0).toInt();
              final h = (count / max) * (constraints.maxHeight - 40);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Container(
                    width: barWidth * 0.6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_kSuperAdminAccent, _kSuperAdminGold]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: count > 0 ? const Center() : null,
                  )),
                  const SizedBox(height: 6),
                  Text(count.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(d['month']?.toString().substring(5, 7) ?? '', style: TextStyle(color: Colors.white54, fontSize: 9)),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final values = data.map((e) => (e['revenue'] as num? ?? 0).toDouble()).toList();
    final max = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _RevenueCurvePainter(values: values, max: max, width: constraints.maxWidth.toDouble(), height: constraints.maxHeight.toDouble()),
        );
      },
    );
  }
}

class _AlertItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AlertItem({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RevenueCurvePainter extends CustomPainter {
  final List<double> values;
  final double max;
  final double width;
  final double height;
  _RevenueCurvePainter({required this.values, required this.max, required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = _kSuperAdminGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = width / (values.length - 1 > 0 ? values.length - 1 : 1);
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = height - (values[i] / max) * (height - 20) - 10;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = height - (values[i] / max) * (height - 20) - 10;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = _kSuperAdminGold);
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueCurvePainter old) => true;
}
