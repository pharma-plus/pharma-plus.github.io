import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// État vide standardisé PHARMA+
/// Remplace les Center(Text(...)) dans toutes les pages
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
    this.actionText,
    this.iconSize = 80,
    this.iconColor,
    this.titleStyle,
    this.messageStyle,
    this.spacing = 16,
    this.centered = true,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? action;
  final String? actionText;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final double spacing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    final effectiveIcon = icon ?? Icons.inbox_rounded;
    final effectiveIconColor = iconColor ??
        (isDark ? tokens.textTertiary.withValues(alpha: 0.6) : tokens.textDisabled);
    final effectiveTitleStyle = titleStyle ?? tokens.headlineSmall;
    final effectiveMessageStyle = messageStyle ?? tokens.bodyMedium.copyWith(
      color: isDark ? tokens.textTertiary : tokens.textDisabled,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          effectiveIcon,
          size: iconSize,
          color: effectiveIconColor,
        ),
        SizedBox(height: spacing),
        Text(
          title,
          style: effectiveTitleStyle,
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          SizedBox(height: tokens.sp2),
          Text(
            message!,
            style: effectiveMessageStyle,
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null && actionText != null) ...[
          SizedBox(height: spacing * 1.5),
          FilledButton(
            onPressed: action,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.brandPrimary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.sp6,
                vertical: tokens.sp3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.rButton),
              ),
            ),
            child: Text(actionText!, style: tokens.labelLarge),
          ),
        ],
      ],
    );

    if (centered) {
      return Center(child: content);
    }

    return content;
  }
}

/// Variantes prédéfinies pour cas courants
class AppEmptyStates {
  static AppEmptyState noData({
    String title = 'Aucune donnée',
    String? message,
    VoidCallback? onRefresh,
    String? refreshText,
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.inbox_rounded,
      action: onRefresh,
      actionText: refreshText ?? 'Actualiser',
    );
  }

  static AppEmptyState noResults({
    String title = 'Aucun résultat',
    String message = 'Essayez de modifier vos critères de recherche',
    VoidCallback? onClearFilters,
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.search_off_rounded,
      action: onClearFilters,
      actionText: 'Effacer les filtres',
    );
  }

  static AppEmptyState noConnection({
    String title = 'Pas de connexion',
    String message = 'Vérifiez votre connexion internet',
    VoidCallback? onRetry,
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.wifi_off_rounded,
      action: onRetry,
      actionText: 'Réessayer',
    );
  }

  static AppEmptyState accessDenied({
    String title = 'Accès refusé',
    String message = 'Vous n\'avez pas les permissions nécessaires',
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.lock_outline_rounded,
    );
  }

  static AppEmptyState noItemsYet({
    required String title,
    required String message,
    required VoidCallback onAdd,
    String addText = 'Ajouter',
    IconData icon = Icons.add_circle_outline_rounded,
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: icon,
      action: onAdd,
      actionText: addText,
    );
  }

  static AppEmptyState deleted({
    String title = 'Supprimé',
    String message = 'Cet élément a été supprimé',
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.delete_outline_rounded,
    );
  }

  static AppEmptyState filtered({
    String title = 'Aucun élément ne correspond',
    String message = 'Aucun résultat pour les filtres actuels',
    VoidCallback? onClearFilters,
  }) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.filter_list_off_rounded,
      action: onClearFilters,
      actionText: 'Réinitialiser les filtres',
    );
  }
}

/// Widget pour état vide dans un tableau
class AppTableEmptyState {
  const AppTableEmptyState({
    this.title = 'Aucune donnée',
    this.message,
    this.icon,
    this.action,
    this.actionText,
    this.columnCount = 1,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? action;
  final String? actionText;
  final int columnCount;

  TableRow build(BuildContext context) {
    final tokens = context.tokens;
    return TableRow(
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: EdgeInsets.all(tokens.space8),
            child: AppEmptyState(
              title: title,
              message: message,
              icon: icon,
              action: action,
              actionText: actionText,
            ),
          ),
        ),
        for (int i = 1; i < columnCount; i++)
          const TableCell(child: SizedBox.shrink()),
      ],
    );
  }
}