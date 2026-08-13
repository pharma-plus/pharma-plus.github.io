import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _alertFilter; // null | expired | expiring | low

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
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/stock/balances',
      query: {
        'limit': 200,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
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
      _items = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_alertFilter == null) return _items;
    if (_alertFilter == 'low') {
      return _items.where((item) {
        return _number(item['available']) <= _number(item['reorder_level']);
      }).toList();
    }
    return _items
        .where((item) => item['expiry_status'] == _alertFilter)
        .toList();
  }

  double _number(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _showStockActions(Map<String, dynamic> item) async {
    final locale = context.read<AuthStore>().locale;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.primary),
              title: Text(S.t('adjustStock', locale)),
              onTap: () => Navigator.pop(context, 'adjust'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(S.t('writeOff', locale)),
              onTap: () => Navigator.pop(context, 'writeOff'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'adjust') {
      await _adjustStock(item);
    } else {
      await _writeOff(item);
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> item) async {
    final locale = context.read<AuthStore>().locale;
    final quantity =
        TextEditingController(text: _number(item['available']).toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('adjustStock', locale)),
        content: TextField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: S.t('newQuantity', locale)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (confirmed != true) return;
    final newQuantity = double.tryParse(quantity.text.trim());
    final branchId = item['branch_id'] as String?;
    final medicationId = item['medication_id'] as String?;
    if (newQuantity == null ||
        newQuantity < 0 ||
        branchId == null ||
        medicationId == null) {
      return;
    }
    final result = await ApiClient.instance.post('/stock/adjustments', body: {
      'branchId': branchId,
      'items': [
        {'medication_id': medicationId, 'new_quantity': newQuantity}
      ],
    });
    if (!mounted) return;
    if (result.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error?.message ?? S.t('loadError', locale))));
    }
  }

  Future<void> _writeOff(Map<String, dynamic> item) async {
    final locale = context.read<AuthStore>().locale;
    final quantity = TextEditingController();
    final reason = TextEditingController();
    var expired = item['expiry_status'] == 'expired';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.t('writeOff', locale)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: S.t('writeOffQuantity', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: InputDecoration(labelText: S.t('reason', locale)),
              ),
              CheckboxListTile(
                value: expired,
                contentPadding: EdgeInsets.zero,
                title: Text(S.t('expired', locale)),
                onChanged: (value) => setState(() => expired = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('save', locale))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(quantity.text.trim());
    final branchId = item['branch_id'] as String?;
    final medicationId = item['medication_id'] as String?;
    if (amount == null ||
        amount <= 0 ||
        branchId == null ||
        medicationId == null) {
      return;
    }
    final result = await ApiClient.instance.post('/stock/write-off', body: {
      'branchId': branchId,
      'items': [
        {
          'medication_id': medicationId,
          'quantity': amount,
          'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
          'expired': expired,
        }
      ],
    });
    if (!mounted) return;
    if (result.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error?.message ?? S.t('loadError', locale))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('stock', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                    label: 'Tous',
                    selected: _alertFilter == null,
                    onTap: () => setState(() => _alertFilter = null)),
                _FilterChip(
                    label: 'Périmé',
                    selected: _alertFilter == 'expired',
                    color: AppColors.danger,
                    onTap: () => setState(() => _alertFilter = 'expired')),
                _FilterChip(
                    label: 'Expire < 90j',
                    selected: _alertFilter == 'expiring',
                    color: AppColors.warning,
                    onTap: () => setState(() => _alertFilter = 'expiring')),
                _FilterChip(
                    label: S.t('lowStock', locale),
                    selected: _alertFilter == 'low',
                    color: AppColors.info,
                    onTap: () => setState(() => _alertFilter = 'low')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filtered.isEmpty
                        ? Center(child: Text(S.t('noStock', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final item = _filtered[i];
                                final expired =
                                    item['expiry_status'] == 'expired';
                                final expiring =
                                    item['expiry_status'] == 'expiring';
                                final available = _number(item['available']);
                                final reorder = _number(item['reorder_level']);
                                final low = available <= reorder;
                                final location = item['locationId'] != null
                                    ? '${item['aisle'] ?? ''}-${item['shelf'] ?? ''}-${item['level'] ?? ''}-${item['position'] ?? ''}'
                                    : 'Non défini';
                                return _StockTile(
                                  name: (item['medication_name'] as String?) ??
                                      '—',
                                  detail:
                                      '${item['lot_number'] ?? '—'} · ${item['branch_name'] ?? ''} · ${location}',
                                  expiry: item['expiry_date'] as String?,
                                  quantity: available,
                                  price: _number(item['price_sale']),
                                  alert: expired
                                      ? _StockAlert.expired
                                      : expiring
                                          ? _StockAlert.expiring
                                          : low
                                              ? _StockAlert.low
                                              : _StockAlert.none,
                                  onTap: () => _showStockActions(item),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

enum _StockAlert { none, low, expiring, expired }

class _StockTile extends StatelessWidget {
  final String name;
  final String detail;
  final String? expiry;
  final double quantity;
  final double price;
  final _StockAlert alert;
  final VoidCallback onTap;

  const _StockTile({
    required this.name,
    required this.detail,
    this.expiry,
    required this.quantity,
    required this.price,
    required this.alert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final Color alertColor = switch (alert) {
      _StockAlert.expired => AppColors.danger,
      _StockAlert.expiring => AppColors.warning,
      _StockAlert.low => AppColors.info,
      _StockAlert.none => Colors.transparent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            if (alert != _StockAlert.none)
              Container(
                width: 8,
                height: 44,
                decoration: BoxDecoration(
                    color: alertColor, borderRadius: BorderRadius.circular(4)),
              )
            else
              const SizedBox(width: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (expiry != null)
                    Text(
                        '${S.t('expiryShort', locale)} ${Fmt.shortDate(DateTime.tryParse(expiry!))}',
                        style: TextStyle(
                            fontSize: 12,
                            color: alert == _StockAlert.expired
                                ? AppColors.danger
                                : alert == _StockAlert.expiring
                                    ? AppColors.warning
                                    : Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.number(quantity),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(Fmt.money(price),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color ?? AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
