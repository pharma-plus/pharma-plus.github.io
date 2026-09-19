import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// ============================================================
/// STATUTS DE COMMANDE FOURNISSEUR — libellés FR + couleurs.
/// workflow : Brouillon → Commandée → (Partiellement reçue) → Reçue
/// Annulée / Retournée sont des terminaisons.
/// ============================================================
const Map<String, String> kOrderStatusLabels = {
  'draft': 'Brouillon',
  'sent': 'Commandée',
  'confirmed': 'Confirmée',
  'partial': 'Partiellement reçue',
  'received': 'Reçue',
  'returned': 'Retournée',
  'cancelled': 'Annulée',
};

String orderStatusLabel(String status) => kOrderStatusLabels[status] ?? status;

Color orderStatusColor(String status) {
  switch (status) {
    case 'draft':
      return Colors.grey;
    case 'sent':
    case 'confirmed':
      return AppColors.primary;
    case 'partial':
      return AppColors.warning;
    case 'received':
      return AppColors.success;
    case 'returned':
      return AppColors.danger;
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.primary;
  }
}
