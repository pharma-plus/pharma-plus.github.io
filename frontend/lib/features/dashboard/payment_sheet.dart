// PMG-PAYMENT-SHEET
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/calculations.dart';
import '../../core/utils/format.dart';

/// ============================================================
/// FEUILLE DE PAIEMENT PHARMA+ — espèces RÉEL :
/// TOTAL réel · MONTANT REÇU saisi · MONNAIE = reçu − total
/// (ex. total 140, reçu 1200 → monnaie 1060 MAD) via
/// calculateChange(). Si reçu < total : montant restant en
/// rouge et validation IMPOSSIBLE. Retourne le montant reçu.
/// ============================================================
class PaymentSheet extends StatefulWidget {
  final double total;
  const PaymentSheet({super.key, required this.total});

  static Future<double?> show(BuildContext context, double total) =>
      showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentSheet(total: total),
      );

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _receivedCtrl = TextEditingController();
  double _received = 0;

  @override
  void dispose() {
    _receivedCtrl.dispose();
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

  bool get _sufficient =>
      isPaymentSufficient(received: _received, total: widget.total);
  double get _change =>
      calculateChange(received: _received, total: widget.total);
  double get _due => remainingDue(received: _received, total: widget.total);

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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2))),
          Row(children: [
            const Icon(Icons.payments_rounded,
                color: AppColors.emeraldLight, size: 20),
            const SizedBox(width: 8),
            const Text('PAIEMENT — ESPÈCES',
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
          const SizedBox(height: 14),
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
                        color: _sufficient
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
          _ChangeBanner(sufficient: _sufficient, change: _change, due: _due),
          const SizedBox(height: 14),
          _PayActions(
              sufficient: _sufficient,
              change: _change,
              onCancel: () => Navigator.of(context).pop(),
              onValidate: () => Navigator.of(context).pop(_received)),
        ]),
      ),
    );
  }
}

/// Raccourcis billets : ajout au reçu · bouton « Exact » = total de la vente.
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
  const _QuickChip({required this.label, required this.onTap, this.highlight = false});

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

/// Bandeau MONNAIE / RESTE — calculé en direct, jamais de valeur figée.
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
            color: sufficient ? const Color(0xFF7BEBA4) : AppColors.danger,
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

/// Actions : Annuler · Valider (désactivé tant que reçu < total).
class _PayActions extends StatelessWidget {
  final bool sufficient;
  final double change;
  final VoidCallback onCancel;
  final VoidCallback onValidate;
  const _PayActions({
    required this.sufficient,
    required this.change,
    required this.onCancel,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
            onPressed: onCancel,
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
            onPressed: sufficient ? onValidate : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0FA958),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF0FA958).withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(vertical: 13)),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: Text(
                sufficient
                    ? 'Valider · rendre ${Fmt.money(change)} MAD'
                    : 'Montant insuffisant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 12.5))),
      ),
    ]);
  }
}

