import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Pastille colorée de statut (commande, ordonnance, pointage, dépense…).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Couleur sémantique d'un statut (vert / orange / rouge / bleu).
Color statusColor(String? status) {
  switch (status) {
    case 'received':
    case 'active':
    case 'present':
    case 'filled':
    case 'approved':
    case 'available':
      return AppColors.success;
    case 'partial':
    case 'expiring':
    case 'late':
    case 'processing':
    case 'pending':
    case 'on_leave':
    case 'half_day':
      return AppColors.warning;
    case 'cancelled':
    case 'rejected':
    case 'absent':
    case 'expired':
    case 'inactive':
    case 'retired':
      return AppColors.danger;
    default:
      return AppColors.info;
  }
}
