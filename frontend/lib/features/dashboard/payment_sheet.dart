import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';
import '../pos/payment_models.dart';

/// ============================================================
/// FEUILLE DE PAIEMENT PHARMA+ — Espèces · Carte · Tiers payant
/// Retourne un PaymentResult complet (method, amount, received, change…).
/// ============================================================
class PaymentSheet extends StatefulWidget {
  final double total;
  const PaymentSheet({super.key, required this.total});

  /// Ancienne signature compatible : retourne le montant reçu (espèces).
  static Future<double?> show(BuildContext context, double total) async {
    final result = await showFull(context, total);
    if (result == null) return null;
    return result.received ?? result.amount;
  }

  /// Nouvelle signature : retourne le PaymentResult complet.
  static Future<PaymentResult?> showFull(BuildContext context, double total) =>
      showModalBottomSheet<PaymentResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentSheet(total: total),
      );

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Espèces ──
  final _receivedCtrl = TextEditingController();
  double _received = 0;

  // ── Carte ──
  String _cardType = 'visa'; // visa | mastercard | other
  String _cardStatus = 'idle'; // idle | waiting | confirmed | refused | error
  final _refCtrl = TextEditingController();

  // ── Tiers payant ──
  final _creditRefCtrl = TextEditingController();
  double _creditAmount = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _creditAmount = widget.total;
  }

  @override
  void dispose() {
    _tab.dispose();
    _receivedCtrl.dispose();
    _refCtrl.dispose();
    _creditRefCtrl.dispose();
    super.dispose();
  }

  void _setReceived(String v) =>
      setState(() => _received = double.tryParse(v.replaceAll(',', '.')) ?? 0);

  void _quick(double v) {
    final next = v == widget.total ? v : _received + v;
    _receivedCtrl.text = next == next.roundToDouble()
        ? next.round().toString()
        : next.toStringAsFixed(2);
    setState(() => _received = next);
  }

  bool get _cashSufficient =>
      isPaymentSufficient(received: _received, total: widget.total);
  double get _change =>
      calculateChange(received: _received, total: widget.total);
  double get _due => remainingDue(received: _received, total: widget.total);

  void _validate() {
    switch (_tab.index) {
      case 0: // Espèces
        if (!_cashSufficient) return;
        Navigator.of(context).pop(PaymentResult.cash(
          amount: widget.total,
          received: _received,
          change: _change,
        ));
      case 1: // Carte
        if (_cardStatus != 'confirmed') return;
        Navigator.of(context).pop(PaymentResult.card(
          amount: widget.total,
          cardType: _cardType,
          reference: _refCtrl.text.trim().isNotEmpty
              ? _refCtrl.text.trim()
              : null,
        ));
      case 2: // Tiers payant
        if (_creditAmount <= 0) return;
        Navigator.of(context).pop(PaymentResult.credit(
          amount: _creditAmount,
          reference: _creditRefCtrl.text.trim().isNotEmpty
              ? _creditRefCtrl.text.trim()
              : null,
        ));
    }
  }

  bool get _canValidate {
    switch (_tab.index) {
      case 0:
        return _cashSufficient;
      case 1:
        return _cardStatus == 'confirmed';
      case 2:
        return _creditAmount > 0;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: Color(0xFF0C1F16),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.goldBorder))),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2))),
              ),
              // Header
              Row(children: [
                const Icon(Icons.payments_rounded,
                    color: AppColors.emeraldLight, size: 20),
                const SizedBox(width: 8),
                const Text('PAIEMENT',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6)),
                const Spacer(),
                Text(Fmt.money(widget.total),
                    style: const TextStyle(
                        color: Color(0xFFE9C873),
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 12),
              // ── ONGLETS MODE DE PAIEMENT ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  onTap: (_) => setState(() {}),
                  indicator: BoxDecoration(
                    color: const Color(0xFF17523A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E7A50)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF7BEBA4),
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Espèces'),
                    Tab(icon: Icon(Icons.credit_card_rounded, size: 18), text: 'Carte'),
                    Tab(icon: Icon(Icons.health_and_safety_rounded, size: 18), text: 'Tiers payant'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── CONTENU ──
              if (_tab.index == 0) _buildCashSection(),
              if (_tab.index == 1) _buildCardSection(),
              if (_tab.index == 2) _buildCreditSection(),
              const SizedBox(height: 14),
              // ── ACTIONS ──
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      child: const Text('Annuler',
                          style: TextStyle(fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                      onPressed: _canValidate ? _validate : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0FA958),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF0FA958).withValues(alpha: 0.25),
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                      label: Text(
                          _tab.index == 0
                              ? (_cashSufficient
                                  ? 'Valider · rendre ${Fmt.money(_change)} MAD'
                                  : 'Montant insuffisant')
                              : _tab.index == 1
                                  ? (_cardStatus == 'confirmed'
                                      ? 'Confirmer ${Fmt.money(widget.total)} MAD'
                                      : _cardStatus == 'refused'
                                          ? 'Paiement refusé'
                                          : 'Simuler paiement')
                                  : 'Valider · ${Fmt.money(_creditAmount)} MAD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12.5))),
                ),
              ]),
            ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  ESPÈCES
  // ═══════════════════════════════════════════════════════
  Widget _buildCashSection() {
    return Column(children: [
      TextField(
        controller: _receivedCtrl,
        autofocus: true,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
        ],
        onChanged: _setReceived,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900),
        decoration: InputDecoration(
            labelText: 'MONTANT REÇU (MAD)',
            labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _cashSufficient
                        ? const Color(0xFF2E7A50)
                        : AppColors.danger.withValues(alpha: 0.7))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC9A24B))),
            suffixIcon: _received > 0
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.white54),
                    onPressed: () {
                      _receivedCtrl.clear();
                      setState(() => _received = 0);
                    })
                : null),
      ),
      const SizedBox(height: 10),
      _QuickRow(
          total: widget.total,
          onAdd: _quick,
          onExact: () => _quick(widget.total)),
      const SizedBox(height: 14),
      _ChangeBanner(sufficient: _cashSufficient, change: _change, due: _due),
    ]);
  }

  // ═══════════════════════════════════════════════════════
  //  CARTE BANCAIRE
  // ═══════════════════════════════════════════════════════
  Widget _buildCardSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Type de carte
          Row(children: [
            _CardTypeChip(
                label: 'Visa',
                icon: Icons.credit_card,
                selected: _cardType == 'visa',
                onTap: () => setState(() => _cardType = 'visa')),
            const SizedBox(width: 8),
            _CardTypeChip(
                label: 'Mastercard',
                icon: Icons.credit_card,
                selected: _cardType == 'mastercard',
                onTap: () => setState(() => _cardType = 'mastercard')),
            const SizedBox(width: 8),
            _CardTypeChip(
                label: 'Autre',
                icon: Icons.credit_card_outlined,
                selected: _cardType == 'other',
                onTap: () => setState(() => _cardType = 'other')),
          ]),
          const SizedBox(height: 14),
          // Montant
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF0E2A1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7A50).withValues(alpha: 0.6))),
            child: Row(children: [
              const Icon(Icons.attach_money_rounded,
                  color: Color(0xFF7BEBA4), size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MONTANT À PAYER',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                Text('${Fmt.money(widget.total)} MAD',
                    style: const TextStyle(
                        color: Color(0xFF7BEBA4),
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          // Référence transaction
          TextField(
            controller: _refCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
                labelText: 'RÉFÉRENCE TRANSACTION (optionnel)',
                labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12)))),
          ),
          const SizedBox(height: 12),
          // Statut + bouton simulation
          _buildCardStatus(),
        ]);
  }

  Widget _buildCardStatus() {
    Color bgColor;
    Color borderColor;
    IconData icon;
    String label;
    String sub;

    switch (_cardStatus) {
      case 'waiting':
        bgColor = const Color(0xFF1A1A0A);
        borderColor = const Color(0xFFD6A84F).withValues(alpha: 0.6);
        icon = Icons.hourglass_top_rounded;
        label = 'EN ATTENTE';
        sub = 'Présentez la carte au terminal…';
        break;
      case 'confirmed':
        bgColor = const Color(0xFF0E2A1C);
        borderColor = const Color(0xFF2E7A50);
        icon = Icons.check_circle_rounded;
        label = 'PAIEMENT CONFIRMÉ';
        sub = 'Transaction validée';
        break;
      case 'refused':
        bgColor = const Color(0xFF2A1310);
        borderColor = AppColors.danger;
        icon = Icons.cancel_rounded;
        label = 'PAIEMENT REFUSÉ';
        sub = 'La transaction a été refusée par le terminal';
        break;
      case 'error':
        bgColor = const Color(0xFF2A1310);
        borderColor = AppColors.danger;
        icon = Icons.error_rounded;
        label = 'ERREUR';
        sub = 'Impossible de contacter le terminal';
        break;
      default:
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.12);
        icon = Icons.credit_card_rounded;
        label = 'PRÊT';
        sub = 'Appuyez sur « Simuler paiement »';
    }

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor)),
        child: Row(children: [
          Icon(icon, color: borderColor, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: borderColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8)),
            Text(sub,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      if (_cardStatus == 'idle' || _cardStatus == 'refused' || _cardStatus == 'error')
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _simulateCardPayment(),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6A84F)),
                foregroundColor: const Color(0xFFD6A84F),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.credit_card_rounded, size: 18),
            label: const Text('Simuler paiement',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }

  Future<void> _simulateCardPayment() async {
    setState(() => _cardStatus = 'waiting');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Simulation : en attente d'un vrai terminal, on confirme directement.
    // Architecture prête pour un vrai callback webhook/terminal.
    setState(() => _cardStatus = 'confirmed');
  }

  // ═══════════════════════════════════════════════════════
  //  TIERS PAYANT / ASSURANCE
  // ═══════════════════════════════════════════════════════
  Widget _buildCreditSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.pharmaGold.withValues(alpha: 0.4))),
            child: Row(children: [
              Icon(Icons.health_and_safety_rounded,
                  color: AppColors.pharmaGold, size: 22),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MONTANT ASSURANCE / TIERS PAYANT',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                Text('${Fmt.money(_creditAmount)} MAD',
                    style: TextStyle(
                        color: AppColors.pharmaGold,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            onChanged: (v) => setState(() =>
                _creditAmount = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
                labelText: 'MONTANT PRISE EN CHARGE (MAD)',
                labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12)))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _creditRefCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
                labelText: 'N° ORDONNANCE / RÉFÉRENCE ASSURANCE',
                labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12)))),
          ),
          const SizedBox(height: 10),
          // Reste à payer (part client)
          if (_creditAmount < widget.total)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFF0E2A1C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7A50).withValues(alpha: 0.6))),
              child: Row(children: [
                const Icon(Icons.person_rounded,
                    color: Color(0xFF7BEBA4), size: 18),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RESTE À PAYER (PART CLIENT)',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                  Text(
                      '${Fmt.money(widget.total - _creditAmount)} MAD',
                      style: const TextStyle(
                          color: Color(0xFF7BEBA4),
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),
        ]);
  }
}

// ═══════════════════════════════════════════════════════
//  WIDGETS HELPER
// ═══════════════════════════════════════════════════════

class _CardTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CardTypeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF17523A)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? const Color(0xFF2E7A50)
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? const Color(0xFF7BEBA4)
                    : Colors.white54),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xFF7BEBA4)
                        : Colors.white54)),
          ]),
        ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  final double total;
  final void Function(double) onAdd;
  final VoidCallback onExact;
  const _QuickRow(
      {required this.total,
      required this.onAdd,
      required this.onExact});

  @override
  Widget build(BuildContext context) {
    const amounts = [20.0, 50.0, 100.0, 200.0];
    return Row(children: [
      for (var i = 0; i < amounts.length; i++) ...[
        Expanded(
          child: _QuickChip(
              label: '+${Fmt.money(amounts[i])}',
              onTap: () => onAdd(amounts[i])),
        ),
        if (i < amounts.length - 1) const SizedBox(width: 6),
      ],
      const SizedBox(width: 6),
      Expanded(
        child: _QuickChip(
            label: 'Exact ${Fmt.money(total)}',
            onTap: onExact,
            highlight: true),
      ),
    ]);
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _QuickChip(
      {required this.label, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFF17523A)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: highlight
                    ? const Color(0xFF2E7A50)
                    : Colors.white.withValues(alpha: 0.12))),
        child: Text(label,
            maxLines: 1,
            style: TextStyle(
                color: highlight ? const Color(0xFF7BEBA4) : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _ChangeBanner extends StatelessWidget {
  final bool sufficient;
  final double change;
  final double due;
  const _ChangeBanner(
      {required this.sufficient, required this.change, required this.due});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: sufficient
              ? const Color(0xFF0E2A1C)
              : const Color(0xFF2A1310),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sufficient
                  ? const Color(0xFF2E7A50).withValues(alpha: 0.8)
                  : AppColors.danger.withValues(alpha: 0.8))),
      child: Row(children: [
        Icon(
            sufficient
                ? Icons.savings_rounded
                : Icons.report_problem_rounded,
            color:
                sufficient ? const Color(0xFF7BEBA4) : AppColors.danger,
            size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sufficient ? 'MONNAIE À RENDRE' : 'MONTANT RESTANT',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          Text(
              sufficient
                  ? '${Fmt.money(change)} MAD'
                  : '${Fmt.money(due)} MAD',
              style: TextStyle(
                  color: sufficient
                      ? const Color(0xFF7BEBA4)
                      : AppColors.danger,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }
}
