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
import 'sales_design_system.dart';

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

  /// Filtres locaux complémentaires (les données enrichies ne sont pas
  /// filtrables côté API). Ils s'appliquent aux lignes chargées.
  String _employee = 'all';
  String _payment = 'all';
  bool _sortByAmount = false;

  List<SalesTransaction> _visibleRows(List<SalesTransaction> rows) {
    final filtered = rows.where((t) {
      final employeeOk =
          _employee == 'all' || (t.userName ?? 'Non identifié') == _employee;
      final paymentOk = _payment == 'all' ||
          SalesPaymentSlice.methodLabel(t.paymentMethod ?? '') == _payment;
      return employeeOk && paymentOk;
    }).toList();
    if (_sortByAmount) {
      filtered.sort((a, b) => b.total.compareTo(a.total));
    } else {
      filtered.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
    return filtered;
  }

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
        return SalesDesign.readable(AppColors.sageGreenInk);
      case 'returned':
      case 'voided':
      case 'cancelled':
      case 'refunded':
        return SalesDesign.readable(AppColors.pharmaDanger);
      case 'pending':
        return AppColors.pharmaWarning;
      default:
        return SalesDesign.onDarkMuted;
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
                  color: SalesDesign.onDark,
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
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: SalesDesign.onDarkMuted),
                    hintText: 'N° de vente…',
                    hintStyle: TextStyle(
                        color: SalesDesign.onDarkMuted, fontSize: 11.5),
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
                  style:
                      const TextStyle(color: SalesDesign.onDark, fontSize: 12),
                  textInputAction: TextInputAction.search,
                  onChanged: onSearch,
                  onSubmitted: onSearch,
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
            _chip('Annulées / retours', SalesTxFilter.problems, c.txStatus,
                onStatus),
            const SizedBox(width: 10, height: 10),
            Text(
              '${c.txTotal} transaction(s) au total',
              style: const TextStyle(
                  color: SalesDesign.onDarkMuted, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _filterDropdown(
              'Employé',
              _employee,
              {for (final t in c.txRows) t.userName ?? 'Non identifié'}.toList()
                ..sort(),
              (v) => setState(() => _employee = v),
            ),
            _filterDropdown(
              'Paiement',
              _payment,
              {
                for (final t in c.txRows)
                  SalesPaymentSlice.methodLabel(t.paymentMethod ?? '')
              }.toList()
                ..sort(),
              (v) => setState(() => _payment = v),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _sortByAmount = !_sortByAmount),
              icon: Icon(
                _sortByAmount ? Icons.sort_by_alpha : Icons.sort,
                size: 15,
                color: SalesDesign.onDark,
              ),
              label: Text(
                _sortByAmount ? 'Tri : montant' : 'Tri : date',
                style: const TextStyle(
                    color: SalesDesign.onDarkMuted, fontSize: 10.5),
              ),
            ),
            const Text(
              'Filtres locaux sur les lignes chargées',
              style: TextStyle(color: SalesDesign.onDarkSoft, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    style: TextStyle(
                        color: SalesDesign.readable(AppColors.pharmaDanger),
                        fontSize: 11),
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
                      color: SalesDesign.onDarkMuted.withValues(alpha: 0.5),
                      size: 34),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucune transaction sur la période pour ce filtre',
                    style:
                        TextStyle(color: SalesDesign.onDarkMuted, fontSize: 12),
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

  Widget _filterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 132,
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.pharmaSurface,
        iconEnabledColor: SalesDesign.onDark,
        style: const TextStyle(color: SalesDesign.onDark, fontSize: 10.5),
        hint:
            Text(label, style: const TextStyle(color: SalesDesign.onDarkMuted)),
        items: [
          DropdownMenuItem(value: 'all', child: Text('$label : tous')),
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (v) => onChanged(v ?? 'all'),
      ),
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
              ? SalesDesign.readable(AppColors.sageGreenInk)
                  .withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? SalesDesign.readable(AppColors.sageGreenInk)
                : AppColors.goldBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? SalesDesign.readable(AppColors.sageGreenInk)
                : SalesDesign.onDarkMuted,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> cells,
      {bool header = false, String? status, Widget? trailing}) {
    final color = header ? SalesDesign.onDarkMuted : SalesDesign.onDark;
    final style = TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
    );
    const widths = [1.2, 1.1, 0.9, 0.9, 0.9, 1.1, 1.0, 0.9];
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
                alignment: i >= 3 && i <= 5
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(t,
                    style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          if (trailing != null) const SizedBox(width: 4),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _detailButton(SalesTransaction t) {
    return IconButton(
      onPressed: () => _showDetail(t),
      icon: const Icon(Icons.visibility_outlined, size: 16),
      color: SalesDesign.onDark,
      tooltip: 'Voir le détail de ${t.number.isEmpty ? 'la vente' : t.number}',
      padding: EdgeInsets.zero,
      // Cible tactile mesurée 44x44 : 28x28 était inatteignable au doigt.
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    );
  }

  void _showDetail(SalesTransaction t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.pharmaSurface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalesSectionHeader(
                title: t.number.isEmpty ? 'Vente sans numéro' : t.number,
                subtitle:
                    '${_statusLabel(t.status)} · ${_method(t.paymentMethod)}',
              ),
              const SizedBox(height: 12),
              _detailLine('Date',
                  t.createdAt == null ? '—' : Fmt.dateTime(t.createdAt)),
              _detailLine('Type', t.saleType.isEmpty ? '—' : t.saleType),
              _detailLine('Employé', t.userName ?? 'Non identifié'),
              _detailLine('Articles',
                  t.itemsCount == null ? '—' : '${t.itemsCount!.round()}'),
              _detailLine('Client', t.customer ?? '—'),
              _detailLine('Sous-total TTC avant remise globale',
                  '${Fmt.number(t.subtotal, decimals: 2)} MAD'),
              _detailLine(
                  'Remise', '${Fmt.number(t.discountTotal, decimals: 2)} MAD'),
              _detailLine('TVA', '${Fmt.number(t.taxTotal, decimals: 2)} MAD'),
              _detailLine(
                  'Total TTC', '${Fmt.number(t.total, decimals: 2)} MAD'),
              _detailLine('Montant réglé (brut)',
                  '${Fmt.number(t.paidAmount, decimals: 2)} MAD'),
              _detailLine('Monnaie rendue',
                  '${Fmt.number(t.changeAmount, decimals: 2)} MAD'),
              _detailLine('Net encaissé',
                  '${Fmt.number(t.paidAmount - t.changeAmount, decimals: 2)} MAD'),
              _detailLine('Mode de paiement', _method(t.paymentMethod)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  // Le focus entre dans la feuille : Entrée / Espace ferment.
                  autofocus: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: SalesDesign.onDarkMuted, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(color: SalesDesign.onDark, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(SalesDayController c) {
    final rows = _visibleRows(c.txRows);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SalesDesign.panelFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Column(
        children: [
          _row(const [
            'Référence',
            'Date et heure',
            'Employé',
            'Articles',
            'Total',
            'Encaissé',
            'Paiement',
            'Statut',
          ], header: true),
          for (final t in rows)
            _row([
              t.number.isEmpty ? '—' : t.number,
              t.createdAt == null
                  ? '—'
                  : '${SalesAnalyticsService.hourMinute(t.createdAt)} · ${t.createdAt!.toLocal().day.toString().padLeft(2, '0')}',
              t.userName ?? 'Non identifié',
              t.itemsCount == null ? '—' : '${t.itemsCount!.round()}',
              Fmt.number(t.total, decimals: 2),
              Fmt.number(t.paidAmount, decimals: 2),
              _method(t.paymentMethod),
              _statusLabel(t.status),
            ], status: t.status, trailing: _detailButton(t)),
        ],
      ),
    );
  }

  Widget _buildCards(SalesDayController c) {
    return Column(
      children: [
        for (final t in _visibleRows(c.txRows))
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
                              color: SalesDesign.onDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                _statusColor(t.status).withValues(alpha: 0.14),
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
                        _detailButton(t),
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
                                color: SalesDesign.onDarkMuted, fontSize: 10.5),
                          ),
                        ),
                        Text(
                          '${Fmt.number(t.total, decimals: 2)} MAD',
                          style: const TextStyle(
                            color: SalesDesign.onDark,
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
                          color: SalesDesign.onDarkMuted, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.userName ?? 'Non identifié'} · '
                      '${t.itemsCount == null ? 'articles —' : '${t.itemsCount!.round()} article(s)'}',
                      style: const TextStyle(
                          color: SalesDesign.onDarkSoft, fontSize: 10),
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
