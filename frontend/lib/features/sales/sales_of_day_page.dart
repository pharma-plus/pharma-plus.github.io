import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';

/// Ventes du jour — vue de détail légère ouverte par le KPI « VENTES DU JOUR ».
///
/// CONTRAT : cette page NE charge JAMAIS le catalogue / clients / facets /
/// ventes suspendues (c'était la cause du gel du dashboard smartphone quand le
/// KPI basculait sur le POS complet). Un seul appel initial
/// `GET /sales?from=…&to=…` borné au jour LOCAL de la pharmacie (fuseau de
/// l'appareil — Maroc = Africa/Casablanca sur les postes réels), puis
/// pagination « Charger plus » sur demande.
///
/// Les montants affichés sont la somme des lignes réellement enregistrées :
/// les ventes annulées / retours sont comptées à part et exclues du total
/// encaissé (aligné sur le KPI backend qui filtre `status = 'completed'`).
class SalesOfDayPage extends StatefulWidget {
  const SalesOfDayPage({super.key});

  @override
  State<SalesOfDayPage> createState() => _SalesOfDayPageState();
}

class _SalesOfDayPageState extends State<SalesOfDayPage> {
  final List<Map<String, dynamic>> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0; // total serveur (meta.total) pour la pagination
  late final DateTime _day; // minuit local du jour consulté

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _loadFirst();
  }

  /// ISO 8601 avec décalage explicite du fuseau de l'appareil :
  /// « 2026-11-05T00:00:00+01:00 ». DateTime.toIso8601String() omet l'offset
  /// pour une date locale, ce que Joi.interpréterait en heure serveur —
  /// d'où un formatage manuel garanti.
  String _isoLocal(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
        'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}'
        '$sign${two(off.inHours)}:${two(off.inMinutes.remainder(60))}';
  }

  Map<String, String> get _dayQuery => {
        'from': _isoLocal(_day),
        'to': _isoLocal(_day.add(const Duration(days: 1))),
      };

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _sales.clear();
      _total = 0;
    });
    final result = await ApiClient.instance.get(
      '/sales',
      query: {'limit': 100, 'page': 1, ..._dayQuery},
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        // Ne JAMAIS rediriger sur une erreur de chargement (règle d'or) :
        // on affiche l'erreur avec un bouton « Recommencer ».
        _error = result.error?.message ?? 'Erreur de chargement';
      });
      return;
    }
    setState(() {
      _sales.addAll(ApiList.of(result.data));
      _total = ApiList.total(result.data, result.meta);
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _sales.length >= _total) return;
    setState(() => _loadingMore = true);
    final page = (_sales.length / 100).floor() + 1;
    final result = await ApiClient.instance.get(
      '/sales',
      query: {'limit': 100, 'page': page, ..._dayQuery},
    );
    if (!mounted) return;
    setState(() {
      if (result.success) {
        final rows = ApiList.of(result.data);
        // Anti-doublon : sauter les lignes déjà présentes (ventes créées
        // pendant le défilement, réponses en double réseau).
        final seen = _sales.map((s) => s['id']).toSet();
        for (final r in rows) {
          if (seen.add(r['id'])) _sales.add(r);
        }
        _total = ApiList.total(result.data, result.meta);
      }
      _loadingMore = false;
    });
  }

  // ── Agrégats réels (sommes des lignes chargées) ──────────────────────────
  double _amount(dynamic v) =>
      v == null ? 0 : (num.tryParse('$v') ?? 0).toDouble();

  List<Map<String, dynamic>> get _completed =>
      _sales.where((s) => (s['status'] ?? '') == 'completed').toList();

  List<Map<String, dynamic>> get _cancelled => _sales
      .where((s) => (s['status'] ?? '') != 'completed')
      .toList();

  double get _totalEncaisse =>
      _completed.fold(0.0, (sum, s) => sum + _amount(s['total']));

  String _hour(dynamic createdAt) {
    final s = createdAt?.toString();
    if (s == null || s.length < 16) return '--:--';
    // created_at serveur ISO : extraire l'heure affichable brute (HH:mm).
    return s.substring(11, 16);
  }

  String _saleLabel(dynamic status, String locale) {
    switch (status) {
      case 'completed':
        return 'Terminée';
      case 'returned':
        return 'Retour';
      case 'voided':
        return 'Annulée';
      default:
        return '$status';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'returned':
        return AppColors.warning;
      case 'voided':
        return AppColors.danger;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    const locale = 'fr';
    return Scaffold(
      backgroundColor: AppColors.pharmaSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Ventes du jour',
            style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFirst,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 56, color: AppColors.warning),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loadFirst,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Recommencer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.gold,
                  onRefresh: _loadFirst,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(locale),
                      const SizedBox(height: 16),
                      ..._completed.map(_buildSaleRow),
                      ..._cancelled.map(_buildSaleRow),
                      if (_sales.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_outlined,
                                  size: 56, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune vente enregistrée aujourd\'hui',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      if (_sales.length < _total)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: Text(_loadingMore
                                  ? 'Chargement…'
                                  : 'Charger plus (${_sales.length}/$_total)'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(String locale) {
    String two(int v) => v.toString().padLeft(2, '0');
    final dateLabel =
        '${two(_day.day)}/${two(_day.month)}/${_day.year}';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Résumé — $dateLabel',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiMini(
                  label: 'Total encaissé',
                  value: Fmt.money(_totalEncaisse),
                  icon: Icons.payments_rounded,
                  color: AppColors.emeraldRich,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiMini(
                  label: 'Ventes',
                  value: '${_completed.length}',
                  icon: Icons.receipt_rounded,
                  color: AppColors.cardBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiMini(
                  label: 'Annulées / Retours',
                  value: '${_cancelled.length}',
                  icon: Icons.replay_circle_filled_rounded,
                  color: _cancelled.isEmpty ? Colors.white24 : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleRow(Map<String, dynamic> s) {
    final customer = (s['customer_name'] as String?)?.trim();
    final user =
        '${s['user_first_name'] ?? ''} ${s['user_last_name'] ?? ''}'.trim();
    final status = s['status'] ?? '';
    final isVoid = status == 'voided' || status == 'returned';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.point_of_sale_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['number'] ?? '—'} · ${_hour(s['created_at'])}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (customer != null && customer.isNotEmpty) customer,
                      if (user.isNotEmpty) user,
                      '${s['payment_method'] ?? ''}',
                    ]
                        .where((p) => p.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.money(_amount(s['total'])),
                  style: TextStyle(
                    color: isVoid ? Colors.white38 : AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(
                  label: _saleLabel(status, 'fr'),
                  color: _statusColor(status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
