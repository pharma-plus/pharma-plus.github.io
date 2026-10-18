import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/download_file.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';
import 'invoice_ui.dart';

/// Page Factures — LECTURE SEULE.
///
/// Les factures ne sont jamais créées ici : le serveur les génère à la
/// vente crédit (`POST /sales`, en-tête FAC) et via les avoirs
/// (`POST /sales/returns`). Cette page liste, détaille et exporte
/// (format e-facture « pharma-facture-v1 »).
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _status; // null = tous les statuts

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance.get(
      '/invoices',
      query: {
        'limit': 100,
        if (_status != null) 'status': _status!,
      },
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      _items = ApiList.of(result.data);
      _loading = false;
    });
  }

  void _showDetail(Map<String, dynamic> invoice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InvoiceDetail(invoiceId: '${invoice['id']}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('invoices', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Filtres par statut (contrat exact de GET /invoices).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (value, labelKey) in <(String?, String)>[
                  (null, 'all'),
                  ('unpaid', 'invoiceUnpaid'),
                  ('partial', 'invoicePartial'),
                  ('paid', 'invoicePaid'),
                  ('cancelled', 'invoiceCancelled'),
                ])
                  ChoiceChip(
                    label: Text(S.t(labelKey, locale)),
                    selected: _status == value,
                    onSelected: (_) {
                      setState(() => _status = value);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(child: Text(S.t('noInvoices', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: _items.length,
                              itemBuilder: (context, i) => _InvoiceTile(
                                invoice: _items[i],
                                onTap: () => _showDetail(_items[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
      'paid' => AppColors.success,
      'unpaid' => AppColors.danger,
      'partial' => AppColors.warning,
      _ => Colors.grey,
    };

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final status = '${invoice['status'] ?? ''}';
    final customers = invoice['customers'];
    final customerName = customers is Map
        ? '${customers['name'] ?? ''}'
        : '';
    final total = double.tryParse('${invoice['total'] ?? 0}') ?? 0;
    final due = InvoiceUi.dueOf(invoice);
    final date = InvoiceUi.issueDate(invoice);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF3E2A00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${invoice['number'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      if (customerName.isNotEmpty) customerName,
                      if (date != null) Fmt.shortDate(date, locale: locale),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(
                  label: S.t(InvoiceUi.statusKey(status), locale),
                  color: _statusColor(status),
                ),
                const SizedBox(height: 4),
                Text(Fmt.money(total),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                if (status != 'paid' && due > 0)
                  Text(
                    '${S.t('invoiceDue', locale)}: ${Fmt.money(due)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.danger),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Détail d'une facture : lignes, totaux, export e-facture (JSON).
class _InvoiceDetail extends StatefulWidget {
  final String invoiceId;
  const _InvoiceDetail({required this.invoiceId});

  @override
  State<_InvoiceDetail> createState() => _InvoiceDetailState();
}

class _InvoiceDetailState extends State<_InvoiceDetail> {
  Map<String, dynamic>? _invoice;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await ApiClient.instance.get('/invoices/${widget.invoiceId}');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    final data = result.data;
    setState(() {
      _invoice = data is Map<String, dynamic> ? data : null;
      _loading = false;
      if (_invoice == null) _error = S.t('noInvoices', 'fr');
    });
  }

  Future<void> _export() async {
    final locale = context.read<AuthStore>().locale;
    setState(() => _exporting = true);
    final result =
        await ApiClient.instance.get('/invoices/${widget.invoiceId}/export');
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.message ?? '')),
      );
      return;
    }
    final payload = result.data;
    final invoiceMap = payload is Map ? payload['invoice'] : null;
    final number = invoiceMap is Map
        ? '${invoiceMap['number'] ?? 'facture'}'
        : 'facture';
    final safeName = number.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(payload));
    downloadBytes('$safeName.json', bytes, 'application/json');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('invoiceExported', locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final inv = _invoice;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : inv == null
                      ? Center(child: Text(S.t('noInvoices', locale)))
                      : _DetailBody(
                          invoice: inv,
                          locale: locale,
                          exporting: _exporting,
                          onExport: _export,
                        ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String locale;
  final bool exporting;
  final VoidCallback onExport;
  const _DetailBody({
    required this.invoice,
    required this.locale,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final status = '${invoice['status'] ?? ''}';
    final customers = invoice['customers'];
    final customerName = customers is Map ? '${customers['name'] ?? ''}' : '';
    final date = InvoiceUi.issueDate(invoice);
    final items = (invoice['invoice_items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];
    final subtotal = double.tryParse('${invoice['subtotal'] ?? 0}') ?? 0;
    final taxTotal = double.tryParse('${invoice['tax_total'] ?? 0}') ?? 0;
    final total = double.tryParse('${invoice['total'] ?? 0}') ?? 0;
    final paid = double.tryParse('${invoice['paid_amount'] ?? 0}') ?? 0;
    final due = InvoiceUi.dueOf(invoice);

    Widget totalRow(String label, String value,
        {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${invoice['number'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            StatusChip(
              label: S.t(InvoiceUi.statusKey(status), locale),
              color: switch (status) {
                'paid' => AppColors.success,
                'unpaid' => AppColors.danger,
                'partial' => AppColors.warning,
                _ => Colors.grey,
              },
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            if (customerName.isNotEmpty)
              '${S.t('invoiceCustomer', locale)}: $customerName',
            if (date != null) Fmt.dateTime(date, locale: locale),
          ].join(' · '),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Divider(height: 20),
        if (items.isEmpty)
          Text(S.t('noInvoices', locale),
              style: const TextStyle(color: Colors.grey))
        else
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${it['description'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${S.t('quantity', locale)} ${it['quantity'] ?? 0}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      Fmt.money(
                          double.tryParse('${it['line_total'] ?? 0}') ?? 0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        const Divider(height: 20),
        totalRow(S.t('invoiceHt', locale), Fmt.money(subtotal)),
        totalRow(S.t('tva', locale), Fmt.money(taxTotal)),
        totalRow(S.t('total', locale), Fmt.money(total), bold: true),
        totalRow(S.t('invoiceReceived', locale), Fmt.money(paid)),
        totalRow(S.t('invoiceDue', locale), Fmt.money(due),
            color: due > 0 ? AppColors.danger : AppColors.success,
            bold: true),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: exporting ? null : onExport,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: Text(S.t('invoiceExport', locale)),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
