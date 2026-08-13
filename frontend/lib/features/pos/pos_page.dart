import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/offline_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import 'pos_models.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final Cart _cart = Cart();
  final _search = TextEditingController();
  List<Medication> _results = [];
  bool _searching = false;
  bool _checkout = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchMedications(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/catalog/medications',
      query: {'q': query.trim(), 'limit': 25},
    );
    if (!mounted) return;
    final rows = result.success
        ? (result.data?['items'] as List? ?? const [])
        : const [];
    setState(() {
      _results = rows
          .whereType<Map<String, dynamic>>()
          .map(Medication.fromJson)
          .where((m) => m.stockQuantity == null || m.stockQuantity! > 0)
          .toList();
      _searching = false;
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      final result = await ApiClient.instance.get<Map<String, dynamic>>(
        '/catalog/medications/barcode/${Uri.encodeComponent(code)}',
      );
      if (!mounted) return;
      final medication = result.data;
      if (!result.success || medication == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  S.t('unknownBarcode', context.read<AuthStore>().locale))),
        );
        return;
      }
      setState(() {
        _cart.add(Medication.fromJson(medication));
      });
    }
  }

  Future<void> _checkoutFlow() async {
    if (_cart.isEmpty || _checkout) return;
    final auth = context.read<AuthStore>();
    setState(() => _checkout = true);
    try {
      final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/sales',
        body: {
          'branchId': auth.user?.branchId,
          'saleType': 'pos',
          'items': _cart.lines.map((l) => l.toPayload()).toList(),
          'payments': [
            {
              'method': 'cash',
              'amount': double.parse(_cart.total.toStringAsFixed(2)),
              'generateInvoice': true,
            }
          ],
        },
      );
      if (result.success) {
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('saleSuccess', auth.locale))),
          );
        }
      } else if (result.error?.code == 'NETWORK_ERROR') {
        // Mode hors-ligne : mise en file locale.
        await OfflineStore.instance.savePendingSale(
          'sale-${DateTime.now().millisecondsSinceEpoch}',
          {
            'branchId': auth.user?.branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
            'payments': [
              {
                'method': 'cash',
                'amount': double.parse(_cart.total.toStringAsFixed(2)),
              }
            ],
          },
        );
        await OfflineStore.instance.enqueue(
          method: 'POST',
          path: '/sales',
          body: {
            'branchId': auth.user?.branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
          },
        );
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('offline', auth.locale))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checkout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('pos', locale)),
        actions: [
          IconButton(
            onPressed: _scan,
            tooltip: S.t('barcode', locale),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final left = _buildProductPanel(locale);
        final right = _buildCartPanel(locale);
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: left),
              Container(width: 1, color: Theme.of(context).dividerColor),
              Expanded(flex: 2, child: right),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: left),
            Container(
              height: 8,
              decoration: const BoxDecoration(gradient: AppColors.goldGradient),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: right,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProductPanel(String locale) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: _searchMedications,
            decoration: InputDecoration(
              hintText: S.t('search', locale),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? const _EmptyProducts()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width >= 1200 ? 4 : 3,
                    childAspectRatio: 0.92,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, i) => _ProductCard(
                    medication: _results[i],
                    onTap: () => setState(() => _cart.add(_results[i])),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCartPanel(String locale) {
    return GlassCard(
      radius: BorderRadius.circular(0),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text(S.t('cart', locale),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (!_cart.isEmpty)
                TextButton(
                  onPressed: () => setState(_cart.clear),
                  child: Text(S.t('clearCart', locale)),
                ),
            ],
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(S.t('emptyCart', locale)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _cart.lines.length,
                    itemBuilder: (context, i) => _CartLineTile(
                      line: _cart.lines[i],
                      onQuantity: (q) =>
                          setState(() => _cart.lines[i].quantity = q),
                      onRemove: () => setState(
                          () => _cart.removeLine(_cart.lines[i].medication.id)),
                    ),
                  ),
          ),
          const Divider(height: 20),
          _TotalRow(label: S.t('subtotal', locale), value: _cart.subtotal),
          _TotalRow(label: S.t('tva', locale), value: _cart.tvaTotal),
          _TotalRow(
              label: S.t('total', locale), value: _cart.total, bold: true),
          const SizedBox(height: 10),
          GradientButton(
            label: '${S.t('checkout', locale)}  ${Fmt.money(_cart.total)}',
            icon: Icons.payments_outlined,
            loading: _checkout,
            onPressed: _checkoutFlow,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTap;
  const _ProductCard({required this.medication, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication,
                  size: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            medication.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.money(medication.priceSale),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  final ValueChanged<double> onQuantity;
  final VoidCallback onRemove;

  const _CartLineTile(
      {required this.line, required this.onQuantity, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.medication.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${Fmt.money(line.unitPrice)} × ${Fmt.number(line.quantity)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () =>
                onQuantity((line.quantity - 1).clamp(1, 999).toDouble()),
          ),
          SizedBox(
            width: 44,
            child: Text(
              Fmt.number(line.quantity),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => onQuantity(line.quantity + 1),
          ),
          SizedBox(
            width: 72,
            child: Text(
              Fmt.money(line.total),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(
            Fmt.money(value),
            style: TextStyle(
                fontSize: bold ? 18 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56, color: Colors.grey),
          const SizedBox(height: 8),
          Text(S.t('searchPrompt', locale)),
        ],
      ),
    );
  }
}

/// Écran de scan de code-barres.
class _ScannerScreen extends StatelessWidget {
  const _ScannerScreen();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('scanTitle', locale))),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code == null || code.isEmpty) return;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
