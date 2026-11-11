/// ============================================================
/// VENTES DU JOUR — Historique des transactions (pagination serveur)
/// ============================================================
/// Responsive : tableau (PC / tablette) ou cartes verticales
/// (smartphone, jamais de scroll horizontal illisible).
/// Recherche (numéro de vente, côté serveur), filtres de statut,
/// bouton « Charger plus » (pagination serveur honnête).
/// Les champs non fournis par l'API s'affichent « — ».
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../controllers/sales_day_controller.dart';

class SalesTransactionsTable extends StatefulWidget {
  final SalesDayController controller;
  final Function(String) onSearch;
  final Future<void> Function(String) onStatus;
  final VoidCallback onLoadMore;

  const SalesTransactionsTable({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onStatus,
    required this.onLoadMore,
  });

  @override
  State<SalesTransactionsTable> createState() => _SalesTransactionsTableState();
}

class _SalesTransactionsTableState extends State<SalesTransactionsTable> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Accès direct aux membres du widget (le reste du code reste inchangé).
  SalesDayController get controller => widget.controller;
  Function(String) get onSearch => widget.onSearch;
  Future<void> Function(String) get onStatus => widget.onStatus;
  VoidCallback get onLoadMore => widget.onLoadMore;

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.sageGreenInk;
      case 'returned':
      case 'voided':
      case 'cancelled':
      case 'refunded':
        return AppColors.pharmaDanger;
      case 'pending':
        return AppColors.pharmaWarning;
      default:
        return AppColors.pharmaMuted;
    }
  }

  String _method(String? m) {
    if (m == null || m.isEmpty) return '—';
    return SalesPaymentSlice.methodLabel(m);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isWide = MediaQuery.of(context).size.width >= 820;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Transactions',
                style: TextStyle(
                  color: AppColors.inkDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: AppColors.pharmaMuted),
                    hintText: 'N° de vente…',
                    hintStyle: TextStyle(
                        color: AppColors.pharmaMuted, fontSize: 11.5),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.goldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.goldBorder),
                    ),
                  ),
                  style: const TextStyle(
                      color: AppColors.inkDark, fontSize: 12),
                  onChanged: onSearch,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Filtres de statut (Wrap : ne déborde jamais sur écran étroit)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip('Toutes', SalesTxFilter.all, c.txStatus, onStatus),
            _chip('Terminées', SalesTxFilter.completed, c.txStatus, onStatus),
            _chip('Annulées / retours', SalesTxFilter.problems, c.txStatus, onStatus),
            const SizedBox(width: 10, height: 10),
            Text(
              '${c.txTotal} transaction(s) au total',
              style: const TextStyle(
                  color: AppColors.pharmaMuted, fontSize: 10.5),
            ),
          ],
        ),
        if (c.txError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.pharmaDanger, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.txError!.userMessage,
                    style: const TextStyle(
                        color: AppColors.pharmaDanger, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (c.txLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (c.txRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_outlined,
                      color: AppColors.pharmaMuted.withValues(alpha: 0.5),
                      size: 34),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucune transaction sur la période pour ce filtre',
                    style: TextStyle(color: AppColors.pharmaMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else if (isWide)
          _buildTable(c)
        else
          _buildCards(c),
        if (!c.txLoading && c.txHasMore)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: c.txLoadingMore ? null : onLoadMore,
                icon: c.txLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  c.txLoadingMore
                      ? 'Chargement…'
                      : 'Charger plus (${c.txRows.length} / ${c.txTotal})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, String value, String current,
      Future<void> Function(String) onStatus) {
    final active = current == value;
    return InkWell(
      onTap: () => onStatus(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.sageGreenInk.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.sageGreenInk : AppColors.goldBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.sageGreenInk : AppColors.pharmaMuted,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> cells, {bool header = false, String? status}) {
    final color = header ? AppColors.pharmaMuted : AppColors.inkDark;
    final style = TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
    );
    const widths = [1.35, 1.0, 0.9, 1.0, 1.0, 1.35, 0.9];
    return Container(
      decoration: header
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.goldBorder, width: 1),
              ),
            )
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.goldBorder.withValues(alpha: 0.5),
                  width: 0.6,
                ),
              ),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          for (final (i, t) in cells.indexed)
            Expanded(
              flex: (widths[i] * 100).round(),
              child: Align(
                alignment: i >= 2 && i <= 4 ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(t, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(SalesDayController c) {
    final rows = c.txRows;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.silver.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sageGreenDark.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        children: [
          _row(const [
            'Référence',
            'Date et heure',
            'Total',
            'Encaissé',
            'Reste',
            'Mode · Client',
            'Statut',
          ], header: true),
          for (final t in rows)
            _row([
              t.number.isEmpty ? '—' : t.number,
              t.createdAt == null
                  ? '—'
                  : '${SalesAnalyticsService.hourMinute(t.createdAt)} · ${t.createdAt!.toLocal().day.toString().padLeft(2, '0')}',
              Fmt.number(t.total, decimals: 2),
              Fmt.number(t.paidAmount, decimals: 2),
              Fmt.number((t.total - t.paidAmount).clamp(0, double.infinity), decimals: 2),
              [
                _method(t.paymentMethod),
                if (t.customer != null && t.customer!.isNotEmpty) t.customer!,
              ].where((s) => s.isNotEmpty).join(' · '),
              _statusLabel(t.status),
            ], status: t.status),
        ],
      ),
    );
  }

  Widget _buildCards(SalesDayController c) {
    return Column(
      children: [
        for (final t in c.txRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.pharmaSurface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldBorder, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.number.isEmpty ? 'Vente sans numéro' : t.number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(t.status).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusColor(t.status), width: 0.8),
                          ),
                          child: Text(
                            _statusLabel(t.status),
                            style: TextStyle(
                              color: _statusColor(t.status),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.createdAt == null
                                ? 'Date inconnue'
                                : Fmt.dateTime(t.createdAt),
                            style: const TextStyle(
                                color: AppColors.pharmaMuted, fontSize: 10.5),
                          ),
                        ),
                        Text(
                          '${Fmt.number(t.total, decimals: 2)} MAD',
                          style: const TextStyle(
                            color: AppColors.champagneInkLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Encaissé ${Fmt.number(t.paidAmount, decimals: 2)} MAD · '
                      '${_method(t.paymentMethod)}'
                      '${(t.customer != null && t.customer!.isNotEmpty) ? ' · ${t.customer!}' : ''}',
                      style: const TextStyle(
                          color: AppColors.pharmaMuted, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
