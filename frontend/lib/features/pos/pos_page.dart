import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
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
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final r = await ApiClient.instance.get<Map<String, dynamic>>('/branches');
    if (!mounted) return;
    if (r.success) {
      final list = (r.data as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final auth = context.read<AuthStore>();
      setState(() {
        _branches = list;
        _branchId = auth.user?.branchId ??
            (list.isNotEmpty ? '${list[0]['id']}' : null);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _branchName() {
    final b = _branches.where((e) => '${e['id']}' == _branchId).firstOrNull;
    final name = b?['name'];
    return (name != null && '$name'.trim().isNotEmpty) ? '$name' : 'PHARMA+';
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
    if (_branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('selectBranch', auth.locale))),
      );
      return;
    }
    setState(() => _checkout = true);
    try {
      final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/sales',
        body: {
          'branchId': _branchId,
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
        final lines = _cart.lines
            .map((l) => CartLineLike(
                  name: l.medication.name,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  tvaRate: l.tvaRate,
                ))
            .toList();
        final gdp = _cart.globalDiscountPercent;
        final pharmacyName = _branchName();
        _cart.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('saleSuccess', auth.locale))),
          );
          ReceiptPdf.printSaleReceipt(
            lines: lines,
            pharmacyName: pharmacyName,
            locale: auth.locale,
            globalDiscountPercent: gdp,
          );
        }
      } else if (result.error?.code == 'NETWORK_ERROR') {
        await OfflineStore.instance.savePendingSale(
          'sale-${DateTime.now().millisecondsSinceEpoch}',
          {
            'branchId': _branchId,
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
            'branchId': _branchId,
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
          if (_branches.isNotEmpty)
            DropdownButton<String>(
              value: _branchId,
              hint: Text(S.t('branch', locale)),
              underline: const SizedBox.shrink(),
              items: _branches
                  .map((b) => DropdownMenuItem(
                        value: '${b['id']}',
                        child: Text('${b['name'] ?? b['code']}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
            ),
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

  static int _gridColumns(double w) {
    if (w >= 1700) return 6;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 760) return 3;
    if (w >= 480) return 2;
    return 1;
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
                    crossAxisCount: _gridColumns(
                        MediaQuery.of(context).size.width),
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  '${Fmt.money(line.unitPrice)} × ${Fmt.number(line.quantity)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          _TouchStepper(
            quantity: line.quantity,
            onChanged: onQuantity,
          ),
          SizedBox(
            width: 80,
            child: Text(
              Fmt.money(line.total),
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          _TouchIconButton(
            icon: Icons.close,
            color: AppColors.danger,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Bouton tactile large (cible ≥ 48px) pour le POS.
class _TouchIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _TouchIconButton(
      {required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

/// Incrémenteur tactile (- / nombre / +) avec cibles ≥ 56px.
class _TouchStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;
  const _TouchStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TouchIconButton(
          icon: Icons.remove,
          color: AppColors.primary,
          onPressed: () =>
              onChanged((quantity - 1).clamp(1, 999).toDouble()),
        ),
        SizedBox(
          width: 56,
          child: Text(
            Fmt.number(quantity),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        _TouchIconButton(
          icon: Icons.add,
          color: AppColors.primary,
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
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
