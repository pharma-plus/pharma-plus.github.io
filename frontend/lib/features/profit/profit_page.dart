import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../shell/shell_nav.dart';

/// Module Bénéfice — vue financière de la pharmacie connectée.
///
/// Affiche :
/// • Chiffre d'affaires (CA) : somme des ventes complétées.
/// • Coût d'achat : somme des coûts d'achat des produits vendus.
/// • Marge brute : CA − coût d'achat.
/// • Dépenses : frais de fonctionnement (loisirs, salaires, charges…).
/// • Bénéfice net : marge brute − dépenses.
///
/// Toutes les données proviennent de l'API réelle (ventes, achats, stock).
/// Aucune donnée fictive n'est affichée.
class ProfitPage extends StatefulWidget {
  const ProfitPage({super.key});

  @override
  State<ProfitPage> createState() => _ProfitPageState();
}

class _ProfitPageState extends State<ProfitPage> {
  bool _loading = true;
  String? _error;

  // Données financières
  double _chiffreAffaires = 0;
  double _coutAchats = 0;
  double _margeBrute = 0;
  double _depenses = 0;
  double _beneficeNet = 0;

  // Détails par période
  int _ventesCount = 0;
  int _achatsCount = 0;
  int _missingCostCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Récupère les données de ventes et d'achats depuis l'API
      final results = await Future.wait([
        ApiClient.instance.get(
          '/sales',
          query: {'status': 'eq.completed', 'limit': 1000},
        ),
        ApiClient.instance.get(
          '/purchases',
          query: {'limit': 1000},
        ),
      ]);

      if (!mounted) return;

      final salesRes = results[0];
      final purchasesRes = results[1];

      double ca = 0;
      double cogs = 0;
      int salesWithMissingCost = 0;
      if (salesRes.success && salesRes.data is List) {
        for (final s in salesRes.data as List) {
          if (s is Map) {
            ca += (s['total'] as num?)?.toDouble() ?? 0;
            final ct = (s['cost_total'] as num?)?.toDouble();
            if (ct != null) {
              cogs += ct;
            } else {
              salesWithMissingCost++;
            }
          }
        }
        _ventesCount = (salesRes.data as List).length;
      }

      // Les achats sont affichés à titre informatif (pas utilisés pour le COGS).
      double coutAchats = 0;
      if (purchasesRes.success && purchasesRes.data is List) {
        for (final p in purchasesRes.data as List) {
          if (p is Map) {
            coutAchats += (p['total'] as num?)?.toDouble() ?? 0;
          }
        }
        _achatsCount = (purchasesRes.data as List).length;
      }

      final margeBrute = ca - cogs;
      // Note : si des ventes n'ont pas de cost_total (anciennes données),
      // la marge est sous-estimée. On affiche un avertissement.
      final hasMissingCost = salesWithMissingCost > 0;

      // Les dépenses proviennent des cash sessions (entrées/sorties)
      // ou des achats non-stock (frais de fonctionnement)
      double depenses = 0;
      try {
        final cashRes = await ApiClient.instance.get(
          '/cash-sessions',
          query: {'limit': 100},
        );
        if (cashRes.success && cashRes.data is Map) {
          final data = cashRes.data as Map;
          depenses += (data['exits'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {
        // Les dépenses sont optionnelles — ne pas bloquer l'affichage
      }

      final beneficeNet = margeBrute - depenses;

      setState(() {
        _chiffreAffaires = ca;
        _coutAchats = coutAchats;
        _margeBrute = margeBrute;
        _depenses = depenses;
        _beneficeNet = beneficeNet;
        _missingCostCount = salesWithMissingCost;
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

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(S.t('profit', locale)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : période et résumé
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.t('profit', locale),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.inkDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vue financière de la pharmacie connectée',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Résumé rapide : bénéfice net en grand
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    'Bénéfice net',
                                    Fmt.money(_beneficeNet),
                                    _beneficeNet >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    Icons.trending_up,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    'Chiffre d\'affaires',
                                    Fmt.money(_chiffreAffaires),
                                    AppColors.pharmaGold,
                                    Icons.attach_money,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    'Marge brute',
                                    Fmt.money(_margeBrute),
                                    Colors.blue,
                                    Icons.show_chart,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    'Dépenses',
                                    Fmt.money(_depenses),
                                    Colors.orange,
                                    Icons.payments,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Détails financiers
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Détail',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.inkDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _detailRow(
                              'Chiffre d\'affaires (ventes complétées)',
                              Fmt.money(_chiffreAffaires),
                              _ventesCount.toString(),
                              AppColors.inkDark,
                            ),
                            _detailRow(
                              'Coût d\'achat (achats enregistrés)',
                              Fmt.money(_coutAchats),
                              _achatsCount.toString(),
                              AppColors.textMuted,
                            ),
                            _detailRow(
                              'Marge brute (CA − coût d\'achat)',
                              Fmt.money(_margeBrute),
                              '${_ventesCount} ventes',
                              Colors.blue,
                            ),
                            _detailRow(
                              'Dépenses de fonctionnement',
                              Fmt.money(_depenses),
                              'cash sessions',
                              Colors.orange,
                            ),
                            _detailRow(
                              'Bénéfice net (marge − dépenses)',
                              Fmt.money(_beneficeNet),
                              '${_beneficeNet >= 0 ? 'bénéficiaire' : 'déficitaire'}',
                              _beneficeNet >= 0 ? Colors.green : Colors.red,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isBold = false,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    String subLabel,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
