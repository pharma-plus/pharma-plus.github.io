import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';

class ReferencePage extends StatefulWidget {
  const ReferencePage({super.key});

  @override
  State<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage> {
  final _search = TextEditingController();
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  Map<String, dynamic>? _syncStatus;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String? _activeCategory;
  int _page = 1;
  bool _hasMore = true;
  final int _limit = 30;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final categoriesResult =
        await ApiClient.instance.get<List<dynamic>>('/reference/categories');
    final statusResult = await ApiClient.instance
        .get<Map<String, dynamic>>('/reference/sync/status');
    if (!mounted) return;
    if (categoriesResult.success) {
      _categories = categoriesResult.data ?? [];
    }
    if (statusResult.success) {
      _syncStatus = statusResult.data;
    }
    await _loadProducts(reset: true);
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _products = [];
    }
    if (!_hasMore) return;
    final query = <String, dynamic>{
      'page': _page,
      'limit': _limit,
      if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      if (_activeCategory != null) 'category': _activeCategory!,
    };
    final result = await ApiClient.instance
        .get<List<dynamic>>('/reference/products', query: query);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.readableMessage ?? 'Erreur';
      });
      return;
    }
    final total = (result.meta?['total'] as num?)?.toInt() ?? 0;
    setState(() {
      _products = [..._products, ...?result.data];
      _page++;
      _hasMore = _products.length < total;
      _loading = false;
    });
  }

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    final result = await ApiClient.instance
        .post<Map<String, dynamic>>('/reference/sync');
    if (!mounted) return;
    if (result.success) {
      setState(() => _syncStatus = result.data);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.t('syncCompleted', locale))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')));
    }
    setState(() => _syncing = false);
  }

  Future<void> _import(dynamic product) async {
    final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/reference/products/${product['id']}/import',
        body: const {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
          ? S.t('importSuccess', locale)
          : result.error?.readableMessage ?? 'Erreur'),
    ));
  }

  String get locale => context.watch<AuthStore>().locale;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _syncStatus?['last_run'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('baseMaroc', locale)),
        actions: [
          IconButton(
            tooltip: S.t('syncNow', locale),
            onPressed: _syncing ? null : _runSync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_sync_outlined,
                      color: AppColors.turquoise),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${S.t('lastSync', locale)}: '
                          '${Fmt.dateTime(_parseDate(last?['finished_at']), locale: locale)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${S.t('referenceProducts', locale)}: '
                          '${_syncStatus?['total'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _syncing ? null : _runSync,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(_syncing
                        ? S.t('syncRunning', locale)
                        : S.t('syncNow', locale)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadProducts(reset: true),
              decoration: InputDecoration(
                hintText: S.t('searchReference', locale),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    _loadProducts(reset: true);
                  },
                ),
              ),
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(S.t('all', locale)),
                      selected: _activeCategory == null,
                      onSelected: (_) {
                        _activeCategory = null;
                        _loadProducts(reset: true);
                      },
                    ),
                  ),
                  for (final c in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('${c['name_fr'] ?? c['code'] ?? ''}'),
                        selected: _activeCategory == c['code'],
                        onSelected: (_) {
                          _activeCategory = '${c['code']}';
                          _loadProducts(reset: true);
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh),
                label: Text(S.t('retry', locale)),
              ),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(child: Text(S.t('noReferenceProducts', locale)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: _products.length + 1,
      itemBuilder: (context, i) {
        if (i == _products.length) {
          if (!_hasMore) return const SizedBox(height: 16);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: OutlinedButton(
                onPressed: _loadProducts,
                child: Text(S.t('loadMore', locale)),
              ),
            ),
          );
        }
        final p = _products[i] as Map<String, dynamic>;
        return _ProductTile(product: p, onImport: () => _import(p));
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onImport;
  const _ProductTile({required this.product, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = context.watch<AuthStore>().locale;
    final commercialised =
        product['commercial_status'] == 'commercialise';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconColor(product).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    color: _iconColor(product),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product['name']}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (product['dci'] != null)
                        Text(
                          '${product['dci']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (commercialised ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    commercialised
                        ? S.t('commercialise', locale)
                        : S.t('nonCommercialise', locale),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: commercialised
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _mini('${S.t('ppv', locale)}:',
                    _money(product['ppv']), isDark),
                _mini('${S.t('ph', locale)}:', _money(product['ph']), isDark),
                _mini('${S.t('pfht', locale)}:',
                    _money(product['pfht']), isDark),
                if (product['presentation'] != null)
                  _mini(S.t('productPresentation', locale),
                      '${product['presentation']}', isDark),
              ],
            ),
            if (product['laboratory'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${S.t('productLaboratory', locale)}: ${product['laboratory']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: commercialised ? onImport : null,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: Text(S.t('importToCatalog', locale)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, bool isDark) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static String _money(dynamic v) {
    final d = double.tryParse('$v') ?? 0;
    return d > 0 ? Fmt.money(d) : '—';
  }

  static Color _iconColor(Map<String, dynamic> p) {
    final raw = p['category_color'] as String? ?? '';
    return raw.isEmpty ? AppColors.turquoise : _parseColor(raw);
  }

  static Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse('0x$value'));
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}
