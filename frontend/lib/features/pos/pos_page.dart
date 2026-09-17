import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/receipt_pdf.dart';
import '../../core/services/offline_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../dashboard/payment_sheet.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../shell/shell_nav.dart';
import '../../core/widgets/product_art.dart';
import 'pos_categories.dart';
import 'pos_models.dart';
import 'payment_models.dart';

class PosPage extends StatefulWidget {
  /// Panier pré-rempli (mini-POS du dashboard → POS complet),
  /// avec la remise déjà saisie par le vendeur.
  final List<Medication>? initialItems;
  final double initialDiscount;
  final bool initialDiscountIsPercent;

  /// Montant déjà validé dans la feuille de paiement du mini-POS :
  /// l'encaissement se fait automatiquement avec CE montant réel
  /// (pas de double saisie), la monnaie est calculée puis affichée.
  final double? initialReceived;
  const PosPage({
    super.key,
    this.initialItems,
    this.initialDiscount = 0,
    this.initialDiscountIsPercent = true,
    this.initialReceived,
  });

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
  List<Map<String, dynamic>> _customers = [];
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadCustomers();
    // CHARGEMENT INITIAL du catalogue : la page Ventes affiche ses
    // produits dès l'ouverture (plus jamais vide avant la recherche).
    _searchMedications('');
    // Pré-remplissage depuis le mini-POS du dashboard : mêmes lignes,
    // même remise (convertie en % si saisie en montant fixe).
    final items = widget.initialItems;
    if (items != null && items.isNotEmpty) {
      for (final m in items) {
        _cart.add(m);
      }
      if (widget.initialDiscount > 0) {
        _cart.globalDiscountPercent = widget.initialDiscountIsPercent
            ? widget.initialDiscount
            : _cart.subtotal > 0
                ? (widget.initialDiscount / _cart.subtotal) * 100
                : 0;
      }
    }
  }

  Future<void> _loadBranches() async {
    final r = await ApiClient.instance.get('/branches');
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
      // Paiement déjà validé dans l'encart POS du dashboard : on encaisse
      // directement avec le montant reçu (aucune seconde saisie).
      if (widget.initialReceived != null &&
          _cart.lines.isNotEmpty &&
          _branchId != null &&
          !_checkout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_checkout) {
            _checkoutFlow(PaymentResult.cash(
              amount: _cart.total,
              received: widget.initialReceived!,
              change: calculateChange(
                  received: widget.initialReceived!, total: _cart.total),
            ));
          }
        });
      }
    }
  }

  Future<void> _loadCustomers() async {
    final r = await ApiClient.instance.get('/customers', query: {'limit': 200});
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _customers = (r.data as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
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

  /// Dernier chargement serveur (liste complète) — la sélection de
  /// catégorie filtre CETTE liste côté client (les re-taps toggling).
  List<Medication> _catalog = [];
  String? _activeCategoryId;

  Future<void> _searchMedications(String query) async {
    setState(() => _searching = true);
    // Requête serveur : texte optionnel ; SANS texte, la première page
    // complète du catalogue est chargée (page de ventes JAMAIS vide).
    final q = query.trim();
    final Map<String, dynamic> params = {'limit': 60};
    if (q.isNotEmpty) params['q'] = q;
    final result = await ApiClient.instance.get(
      '/catalog/medications',
      query: params,
    );
    if (!mounted) return;
    if (!result.success) {
      debugPrint('[POS] catalog load failed: ${result.error} base=${ApiClient.instance.baseUrl}');
    }
    final rows = result.success
        ? ApiList.of(result.data)
        : <Map<String, dynamic>>[];
    _catalog = rows
        .map(Medication.fromJson)
        .where((m) => m.stockQuantity == null || m.stockQuantity! > 0)
        .toList();
    _applyFilter();
    if (mounted) setState(() => _searching = false);
    // Fallback PC : si catalogue vide au premier chargement (cold start),
    // on retente une fois après 1.2s (edge supabase en réveil)
    if (query.trim().isEmpty && _catalog.isEmpty && result.success) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      // Ne retente que si toujours vide et pas de recherche en cours
      if (_catalog.isEmpty && !_searching) _searchMedications('');
    }
  }

  /// Applique la catégorie active sur la liste chargée
  /// (aucune catégorie → catalogue complet affiché).
  void _applyFilter() {
    final cat = _activeCategoryId;
    if (cat == null || cat == 'autres') {
      setState(() => _results = List.of(_catalog));
    } else {
      final q = cat.toLowerCase();
      setState(() {
        _results = _catalog
            .where((m) =>
                (m.categoryName?.toLowerCase().contains(q) ?? false) ||
                (m.categoryId?.toLowerCase() == q))
            .toList();
      });
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      final result = await ApiClient.instance.get(
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
        final medMap = medication is Map ? Map<String, dynamic>.from(medication) : <String, dynamic>{};
        _cart.add(Medication.fromJson(medMap));
      });
    }
  }

  /// Ouvre la feuille de paiement multi-modes (Espèces · Carte · Tiers payant),
  /// puis encaisse avec le PaymentResult complet.
  Future<void> _openPayment() async {
    if (_cart.isEmpty || _checkout) return;
    final result = await PaymentSheet.showFull(context, _cart.total);
    if (result == null || !result.isValid) return; // paiement annulé
    if (!mounted) return;
    await _checkoutFlow(result);
  }

  Future<void> _checkoutFlow([PaymentResult? payment]) async {
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
      // Déterminer le paiement à envoyer
      final pay = payment ?? PaymentResult.cash(
        amount: _cart.total,
        received: _cart.total,
        change: 0,
      );
      final result = await ApiClient.instance.post(
        '/sales',
        body: {
          'branchId': _branchId,
          'saleType': 'pos',
          'items': _cart.lines.map((l) => l.toPayload()).toList(),
          if (_cart.globalDiscountPercent > 0)
            'discount_percent': _cart.globalDiscountPercent,
          if (_cart.globalDiscountFixed > 0)
            'discount_amount': _cart.globalDiscountFixed,
          if (_customerId != null) 'customerId': _customerId,
          'payments': [pay.toPayload()],
        },
      );
      if (result.success) {
        final change = pay.change ?? calculateChange(received: pay.amount, total: _cart.total);
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
          final msg = pay.method == 'card'
              ? '${S.t('saleSuccess', auth.locale)} · Carte ${pay.cardType ?? ''}'
              : change > 0
                  ? '${S.t('saleSuccess', auth.locale)} · Monnaie : ${Fmt.money(change)} MAD'
                  : S.t('saleSuccess', auth.locale);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
          ReceiptPdf.printSaleReceipt(
            lines: lines,
            pharmacyName: pharmacyName,
            locale: auth.locale,
            globalDiscountPercent: gdp,
            amountReceived: pay.received ?? pay.amount,
            change: change,
          );
        }
      } else if (result.error?.code == 'NETWORK_ERROR') {
        await OfflineStore.instance.savePendingSale(
          'sale-${DateTime.now().millisecondsSinceEpoch}',
          {
            'branchId': _branchId,
            'items': _cart.lines.map((l) => l.toPayload()).toList(),
            'payments': [pay.toPayload()],
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('pos', locale)),
        actions: [
          // Sélecteur client
          if (_customers.isNotEmpty)
            DropdownButton<String>(
              value: _customerId,
              hint: const Icon(Icons.person_outline_rounded, size: 20),
              underline: const SizedBox.shrink(),
              iconEnabledColor: Colors.white70,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Client comptoir',
                      style: TextStyle(fontSize: 13)),
                ),
                ..._customers.map((c) => DropdownMenuItem(
                      value: '${c['id']}',
                      child: Text(
                        '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
                            .trim(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _customerId = v),
            ),
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
    // FIX FORENSIQUE: le Column avec Expanded + GridView provoquait
    // RenderFlex overflow 223-266px sur PC 768p/600p (test) → contenu
    // masqué → page parait "vide" (seul AppBar visible). On rend le
    // panneau scrollable et la grille shrinkWrap.
    return SingleChildScrollView(
      child: Column(
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
                fillColor: AppColors.pharmaSurface,
                filled: true,
              ),
            ),
          ),
          // Catégories 4×2 premium
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              S.t('categories', locale),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.pharmaMuted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PosCategoriesGrid(
              onSelected: (cat) {
                // Toggle : re-tap sur la catégorie active → tout réafficher.
                setState(() {
                  _activeCategoryId =
                      _activeCategoryId == cat.id ? null : cat.id;
                });
                _applyFilter();
              },
            ),
          ),
          _searching && _results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0E8C4F))))
              : _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24), child: _EmptyProducts())
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        _gridColumns(MediaQuery.of(context).size.width),
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
      ],
    ));
  }

  bool _discountIsPercent = true;

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
          // ---- Remise globale ----
          if (!_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: S.t('discount', locale),
                        prefixIcon:
                            const Icon(Icons.local_offer_outlined, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        final d = double.tryParse(v) ?? 0;
                        setState(() {
                          _cart.globalDiscountPercent =
                              _discountIsPercent ? d : 0;
                          if (!_discountIsPercent) {
                            _cart.globalDiscountFixed = d;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('%', style: TextStyle(fontSize: 11)),
                    selected: _discountIsPercent,
                    onSelected: (v) => setState(() => _discountIsPercent = v),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label: const Text('MAD',
                        style: TextStyle(fontSize: 11)),
                    selected: !_discountIsPercent,
                    onSelected: (v) =>
                        setState(() => _discountIsPercent = !v),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          _TotalRow(label: S.t('subtotal', locale), value: _cart.subtotal),
          if (_cart.globalDiscount > 0)
            _TotalRow(
                label: '${S.t('discount', locale)} (${_discountIsPercent ? "${_cart.globalDiscountPercent.toStringAsFixed(0)}%" : Fmt.money(_cart.globalDiscountFixed)})',
                value: -_cart.globalDiscount),
          _TotalRow(label: S.t('tva', locale), value: _cart.tvaTotal),
          _TotalRow(
              label: S.t('total', locale), value: _cart.total, bold: true),
          const SizedBox(height: 10),
          GradientButton(
            label: '${S.t('checkout', locale)}  ${Fmt.money(_cart.total)}',
            icon: Icons.payments_outlined,
            loading: _checkout,
            onPressed: _openPayment,
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

  /// Miniature 3D dédiée selon le produit (Doliprane, Bion3, eau
  /// thermale, vitamine C, paracétamol, mucosolvan) — style maquette ;
  /// l'image réelle [Medication.photoUrl] reste prioritaire.
  ProductArt get art {
    final n = '${medication.name} ${medication.dci ?? ''}'.toLowerCase();
    if (n.contains('doliprane')) return ProductArt.doliprane;
    if (n.contains('paracétamol') || n.contains('paracetamol')) {
      return ProductArt.paracetamol;
    }
    if (n.contains('bion') || n.contains('bio3')) return ProductArt.bio3;
    if (n.contains('thermale') ||
        n.contains('la roche') ||
        n.contains('avène') ||
        n.contains('avene') ||
        n.contains('biafine') ||
        n.contains('thermale') ||
        n.contains('eau ')) {
      return ProductArt.eauThermale;
    }
    if (n.contains('vitamine') ||
        n.contains('vitamin') ||
        n.contains('acérola') ||
        n.contains('acerola')) {
      return ProductArt.vitamineC;
    }
    if (n.contains('mucosolvan') || n.contains('ambroxol')) {
      return ProductArt.mucosolvan;
    }
    return ProductArt.generic;
  }

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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              // Miniature 3D du produit (illustration peinte ou photo
              // réelle si disponible) — comme la maquette du panier.
              child: ProductThumb(
                art: art,
                image: medication.photoUrl,
                tint: AppColors.primary,
                size: 62,
                semanticLabel: medication.name,
              ),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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
          onPressed: () => onChanged((quantity - 1).clamp(1, 999).toDouble()),
        ),
        SizedBox(
          width: 56,
          child: Text(
            Fmt.number(quantity),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

/// Écran de scan du POS — caméra (formats EAN-13 / EAN-8 / Code128 / QR)
/// avec REPLI PROPRE si la caméra est indisponible (permission refusée,
/// navigateur sans caméra) : message clair + réessayer + champ de saisie
/// pour lecteur HID USB/Bluetooth (la douchette « tape » le code + Entrée).
/// Aucun plantage dans tous les cas.
class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  MobileScannerController? _controller;
  bool _error = false;
  String _errorMsg = '';
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final c = MobileScannerController(
        detectionSpeed: DetectionSpeed.unrestricted,
        facing: CameraFacing.back,
        autoStart: false,
      );
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await c.start();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _controller = null;
      });
    }
  }

  @override
  void dispose() {
    _controller?.stop();
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final code = v.trim();
    if (code.isNotEmpty) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFF08130E),
      appBar: AppBar(title: Text(S.t('scanTitle', locale))),
      body: Column(children: [
        Expanded(
          child: _error || _controller == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined,
                      size: 44, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Caméra indisponible sur cet appareil/navigateur.\n'
                      'Utilisez un lecteur USB/Bluetooth ci-dessous.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_errorMsg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 10)),
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = false);
                      _start();
                    },
                    child: const Text('Réessayer la caméra'),
                  ),
                ]))
              : MobileScanner(
                  controller: _controller!,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code == null || code.isEmpty) return;
                    Navigator.of(context).pop(code);
                  },
                ),
        ),
        // Repli HID : lecteur USB/Bluetooth (mode clavier) ou saisie manuelle.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _manual,
                  autofocus: _error,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText:
                        'Lecteur USB/Bluetooth : scannez ici (ou code + Entrée)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _submit(_manual.text),
                child: const Text('OK'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
