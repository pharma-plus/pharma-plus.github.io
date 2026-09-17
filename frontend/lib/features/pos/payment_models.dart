/// Modèles de paiement PHARMA+ — Espèces · Carte · Tiers payant
library;

/// Résultat retourné par la feuille de paiement.
class PaymentResult {
  final String method; // 'cash' | 'card' | 'credit'
  final double amount;
  final double? received; // montant reçu (espèces)
  final double? change; // monnaie à rendre (espèces)
  final String? cardType; // 'visa' | 'mastercard' | null
  final String? cardReference; // réf. transaction terminal
  final String status; // 'pending' | 'confirmed' | 'refused' | 'error'

  const PaymentResult({
    required this.method,
    required this.amount,
    this.received,
    this.change,
    this.cardType,
    this.cardReference,
    this.status = 'confirmed',
  });

  /// Paiement espèces validé.
  factory PaymentResult.cash({
    required double amount,
    required double received,
    required double change,
  }) =>
      PaymentResult(
        method: 'cash',
        amount: amount,
        received: received,
        change: change,
        status: 'confirmed',
      );

  /// Paiement carte — en attente confirmation terminal.
  factory PaymentResult.card({
    required double amount,
    required String cardType,
    String? reference,
    String status = 'confirmed',
  }) =>
      PaymentResult(
        method: 'card',
        amount: amount,
        cardType: cardType,
        cardReference: reference,
        status: status,
      );

  /// Tiers payant / assurance.
  factory PaymentResult.credit({
    required double amount,
    String? reference,
  }) =>
      PaymentResult(
        method: 'credit',
        amount: amount,
        cardReference: reference,
        status: 'confirmed',
      );

  Map<String, dynamic> toPayload() => {
        'method': method,
        'amount': amount,
        if (received != null) 'received': received,
        if (change != null) 'change': change,
        if (cardType != null) 'card_type': cardType,
        if (cardReference != null && cardReference!.isNotEmpty)
          'reference': cardReference,
      };

  bool get isValid => amount > 0 && status == 'confirmed';
}
