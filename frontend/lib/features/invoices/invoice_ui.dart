/// Logique pure de présentation des factures — séparée de l'UI pour être
/// testable sans API (aucun import Flutter dans ce fichier).
class InvoiceUi {
  InvoiceUi._();

  /// Statuts admis par l'API (`GET /invoices` refuse toute autre valeur).
  static const statuses = ['unpaid', 'partial', 'paid', 'cancelled'];

  /// Clé i18n du libellé de statut. Repli honnête : la clé générique
  /// 'status' plutôt qu'un libellé inventé pour un statut inconnu.
  static String statusKey(String status) => switch (status) {
        'unpaid' => 'invoiceUnpaid',
        'partial' => 'invoicePartial',
        'paid' => 'invoicePaid',
        'cancelled' => 'invoiceCancelled',
        _ => 'status',
      };

  /// Reste dû = total TTC − encaissé, valeur brute (le serveur refuse le
  /// sous-paiement côté vente, mais un sursolde n'est pas écrêté ici :
  /// on affiche ce que la base contient).
  static double dueOf(Map<String, dynamic> inv) {
    final total = double.tryParse('${inv['total'] ?? 0}') ?? 0;
    final paid = double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0;
    return total - paid;
  }

  /// Date d'émission lue depuis `issue_date` (ISO) — null si illisible.
  static DateTime? issueDate(Map<String, dynamic> inv) {
    final raw = inv['issue_date'];
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
