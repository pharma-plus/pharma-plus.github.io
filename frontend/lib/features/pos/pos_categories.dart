import '../../core/models/medication.dart';
import '../../core/theme/colors.dart';
import 'package:flutter/material.dart';

/// Une catégorie de produits pour le POS.
class PosCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const PosCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.color = AppColors.pharmaGold,
  });
}

/// Grille 4×2 premium des 8 catégories du POS.
class PosCategoriesGrid extends StatelessWidget {
  static const categories = <PosCategory>[
    PosCategory(
      id: 'antalgiques',
      label: 'Antalgiques',
      icon: Icons.local_hospital_outlined,
      color: Color(0xFFEF4444),
    ),
    PosCategory(
      id: 'antibiotiques',
      label: 'Antibiotiques',
      icon: Icons.science_outlined,
      color: Color(0xFF3B82F6),
    ),
    PosCategory(
      id: 'cardiologie',
      label: 'Cardiologie',
      icon: Icons.favorite_outline,
      color: Color(0xFFEF4444),
    ),
    PosCategory(
      id: 'diabete',
      label: 'Diabète',
      icon: Icons.bloodtype_outlined,
      color: Color(0xFF2563EB),
    ),
    PosCategory(
      id: 'vitamines',
      label: 'Vitamines',
      icon: Icons.eco_outlined,
      color: AppColors.pharmaGreen,
    ),
    PosCategory(
      id: 'respiratoire',
      label: 'Respiratoire',
      icon: Icons.air,
      color: AppColors.chart,
    ),
    PosCategory(
      id: 'digestif',
      label: 'Digestif',
      icon: Icons.set_meal_outlined,
      color: Color(0xFFF59E0B),
    ),
    PosCategory(
      id: 'autres',
      label: 'Autres',
      icon: Icons.more_horiz_rounded,
      color: AppColors.pharmaMuted,
    ),
  ];

  final void Function(PosCategory category)? onSelected;

  const PosCategoriesGrid({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        final c = categories[index];
        return _CategoryTile(
          category: c,
          onTap: () => onSelected?.call(c),
        );
      }, childCount: categories.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final PosCategory category;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pharmaSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.pharmaSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBorder, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon,
                    size: 24, color: category.color.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 8),
              Text(
                category.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pharmaText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
